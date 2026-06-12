package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestWorkloadIdentityBasic applies examples/basic (secret-manager secrets, a GCS bucket,
// plus the workload-iam unit that creates the GSA, the Workload Identity binding, and the
// secret/bucket access grants), asserts on outputs, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestWorkloadIdentityBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	bucketName := fmt.Sprintf("example-wi-%s", strings.ToLower(random.UniqueId()))
	repositoryID := fmt.Sprintf("example-wi-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":    projectID,
			"bucket_name":   bucketName,
			"repository_id": repositoryID,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	saEmail := terraform.Output(t, terraformOptions, "service_account_email")
	assert.True(t, strings.HasSuffix(saEmail, "@"+projectID+".iam.gserviceaccount.com"),
		"workload GSA email should belong to the project, got %q", saEmail)

	secretIDs := terraform.OutputList(t, terraformOptions, "secret_ids")
	assert.Len(t, secretIDs, 2)
	for _, id := range secretIDs {
		assert.Contains(t, id, projectID)
	}

	assert.Equal(t, bucketName, terraform.Output(t, terraformOptions, "bucket_name"))
	assert.Contains(t, terraform.Output(t, terraformOptions, "repository_name"), repositoryID)
}
