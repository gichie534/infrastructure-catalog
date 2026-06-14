package test

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestWorkloadIdentityFederationBasic applies examples/basic (a Workload Identity Pool with a
// GitHub OIDC provider plus a direct project-IAM grant to the federated principalSet) against a
// sandbox project, asserts on the outputs, and always destroys via defer.
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

	// Unique suffix so repeated/parallel runs don't collide on the pool ID. pool_id only allows
	// lowercase, so downcase the (mixed-case) random ID.
	unique := strings.ToLower(random.UniqueId())
	poolID := "ci-pool-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":        projectID,
			"pool_id":           poolID,
			"github_repository": "octo-org/example-repo",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	poolName := terraform.Output(t, terraformOptions, "pool_name")
	assert.Contains(t, poolName, "workloadIdentityPools/"+poolID)

	providerName := terraform.Output(t, terraformOptions, "provider_name")
	assert.Contains(t, providerName, "/providers/github")

	// Direct WIF: the repo's principalSet is granted a project role with no service account.
	member := terraform.Output(t, terraformOptions, "principal_set_member")
	assert.Contains(t, member, "principalSet://iam.googleapis.com/")
	assert.Contains(t, member, "attribute.repository/octo-org/example-repo")
}
