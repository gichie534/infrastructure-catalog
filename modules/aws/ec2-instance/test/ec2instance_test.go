package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestEC2InstanceBasic applies examples/basic (a single Amazon Linux 2023 instance in the default
// VPC), asserts on the outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1), and
// a default VPC in that region.
func TestEC2InstanceBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	name := "ec2-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	assert.True(t, strings.HasPrefix(instanceID, "i-"))
}
