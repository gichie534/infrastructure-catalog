package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestEcrBasic applies examples/basic (a scan-on-push repository with force_delete and an untagged
// expiry lifecycle policy), asserts on the outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestEcrBasic(t *testing.T) {
	t.Parallel()

	name := "ecr-test-" + strings.ToLower(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, name, terraform.Output(t, terraformOptions, "name"))

	repoURL := terraform.Output(t, terraformOptions, "repository_url")
	assert.True(t, strings.HasSuffix(repoURL, "/"+name), "repository_url should end with /%s, got %q", name, repoURL)

	arn := terraform.Output(t, terraformOptions, "arn")
	assert.Contains(t, arn, ":repository/"+name)
}
