package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestEcsClusterBasic applies examples/basic (a Fargate cluster), asserts on the outputs, and always
// destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestEcsClusterBasic(t *testing.T) {
	t.Parallel()

	name := "ecs-cluster-test-" + strings.ToLower(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, name, terraform.Output(t, terraformOptions, "cluster_name"))
	assert.Contains(t, terraform.Output(t, terraformOptions, "cluster_arn"), ":cluster/"+name)
}
