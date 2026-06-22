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

// TestGKEWorkloadIdentityBasic applies examples/basic (a bucket plus a direct WIF grant to a KSA
// principal), asserts on the principal string and bucket name, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) and GCP_PROJECT_NUMBER for a sandbox project with
// application-default credentials available.
func TestGKEWorkloadIdentityBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	projectNumber := os.Getenv("GCP_PROJECT_NUMBER")
	require.NotEmpty(t, projectNumber, "set GCP_PROJECT_NUMBER to the sandbox project's number to run this test")

	bucketName := fmt.Sprintf("example-gke-wi-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":     projectID,
			"project_number": projectNumber,
			"bucket_name":    bucketName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	principal := terraform.Output(t, terraformOptions, "principal")
	expected := fmt.Sprintf(
		"principal://iam.googleapis.com/projects/%s/locations/global/workloadIdentityPools/%s.svc.id.goog/subject/ns/demo/sa/reader",
		projectNumber, projectID,
	)
	assert.Equal(t, expected, principal)

	name := terraform.Output(t, terraformOptions, "bucket_name")
	assert.Equal(t, bucketName, name)
}
