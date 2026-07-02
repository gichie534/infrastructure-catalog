package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestAutoScalingGroupBasic applies examples/basic (an Auto Scaling group with a CPU target-tracking
// policy in the default VPC), asserts on the outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1), and
// a default VPC in that region.
func TestAutoScalingGroupBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	name := "asg-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.True(t, strings.HasPrefix(asgName, name))

	launchTemplateID := terraform.Output(t, terraformOptions, "launch_template_id")
	assert.True(t, strings.HasPrefix(launchTemplateID, "lt-"))
}
