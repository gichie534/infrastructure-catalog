package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestOIDCFederationBasic applies examples/basic (a GitHub OIDC provider plus one role a single
// repo may assume via web identity federation), asserts on the outputs, and always destroys via
// defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestOIDCFederationBasic(t *testing.T) {
	t.Parallel()

	// Unique suffix so repeated/parallel runs don't collide on the role name. Note: the OIDC
	// PROVIDER (token.actions.githubusercontent.com) is account-global and create-only, so this test
	// will fail if that provider already exists in the account — see the module's sharing caveat.
	unique := strings.ToLower(random.UniqueId())
	repo := fmt.Sprintf("octo-org/example-%s", unique)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name":              "oidc-test-" + unique,
			"github_repository": repo,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	providerArn := terraform.Output(t, terraformOptions, "provider_arn")
	assert.Contains(t, providerArn, ":oidc-provider/token.actions.githubusercontent.com")

	roleArn := terraform.Output(t, terraformOptions, "role_arn")
	assert.Contains(t, roleArn, ":role/oidc-test-"+unique+"-deployer")

	roleName := terraform.Output(t, terraformOptions, "role_name")
	assert.Equal(t, "oidc-test-"+unique+"-deployer", roleName)
}
