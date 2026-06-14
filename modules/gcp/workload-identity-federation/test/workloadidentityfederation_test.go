package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestWorkloadIdentityFederationBasic applies examples/basic (a Workload Identity Pool with a
// GitHub OIDC provider plus a CI service-account binding) against a sandbox project, asserts on
// the outputs, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestWorkloadIdentityFederationBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	// Unique suffix so repeated/parallel runs don't collide on pool or SA IDs.
	unique := random.UniqueId()
	poolID := "ci-pool-" + unique
	accountID := "wif-ci-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":        projectID,
			"pool_id":           poolID,
			"account_id":        accountID,
			"github_repository": "octo-org/example-repo",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	poolName := terraform.Output(t, terraformOptions, "pool_name")
	assert.Contains(t, poolName, "workloadIdentityPools/"+poolID)

	providerName := terraform.Output(t, terraformOptions, "provider_name")
	assert.Contains(t, providerName, "/providers/github")

	saEmail := terraform.Output(t, terraformOptions, "service_account_email")
	assert.Contains(t, saEmail, accountID+"@")
}
