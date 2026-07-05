package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestEcsFargateServiceBasic applies examples/basic (a Fargate service running a public image in the
// default VPC, no load balancer), asserts on the outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1) plus
// a default VPC in the region.
func TestEcsFargateServiceBasic(t *testing.T) {
	t.Parallel()

	name := "ecs-svc-test-" + strings.ToLower(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, name, terraform.Output(t, terraformOptions, "service_name"))
	assert.Equal(t, name, terraform.Output(t, terraformOptions, "task_definition_family"))
	assert.Equal(t, "/ecs/"+name, terraform.Output(t, terraformOptions, "log_group_name"))
}
