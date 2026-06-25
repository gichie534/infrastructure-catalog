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

// TestServiceAccountBasic applies examples/basic (the service-account module with a project role),
// asserts on outputs, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with application-default
// credentials available.
func TestServiceAccountBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	accountID := fmt.Sprintf("sa-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"account_id": accountID,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	email := terraform.Output(t, terraformOptions, "email")
	expectedSuffix := "@" + projectID + ".iam.gserviceaccount.com"
	assert.True(t, strings.HasSuffix(email, expectedSuffix), "SA email should belong to the project, got %q", email)
	assert.True(t, strings.HasPrefix(email, accountID+"@"), "SA email should start with the account_id, got %q", email)

	assert.Equal(t, "serviceAccount:"+email, terraform.Output(t, terraformOptions, "member"))
}
