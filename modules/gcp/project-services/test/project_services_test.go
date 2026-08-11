package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestProjectServicesBasic applies examples/basic (enables iap.googleapis.com on an existing
// project), asserts the exported output, and always destroys via defer. Destroy leaves the API
// enabled (disable_on_destroy is hardcoded false in the module) since disabling shared project APIs
// on test teardown would be disruptive to a sandbox project used by other tests.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestProjectServicesBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id": projectID,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	enabledAPIs := terraform.OutputList(t, terraformOptions, "enabled_apis")
	assert.Contains(t, enabledAPIs, "iap.googleapis.com")
}
