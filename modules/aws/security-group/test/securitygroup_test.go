package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestSecurityGroupBasic applies examples/basic (a security group in the default VPC with one HTTP
// ingress rule and default allow-all egress), asserts on the outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1), and
// a default VPC in that region.
func TestSecurityGroupBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	name := "sg-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	sgID := terraform.Output(t, terraformOptions, "security_group_id")
	assert.True(t, strings.HasPrefix(sgID, "sg-"))

	sgARN := terraform.Output(t, terraformOptions, "security_group_arn")
	assert.Contains(t, sgARN, ":security-group/")
}
