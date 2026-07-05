package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestLambdaBasic applies examples/basic (a Lambda function built from a placeholder bootstrap zip,
// with its execution role and log group), asserts on the outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestLambdaBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	name := "lambda-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	functionName := terraform.Output(t, terraformOptions, "function_name")
	assert.Equal(t, name, functionName)

	functionARN := terraform.Output(t, terraformOptions, "function_arn")
	assert.Contains(t, functionARN, ":function:"+name)

	roleARN := terraform.Output(t, terraformOptions, "role_arn")
	assert.Contains(t, roleARN, ":role/"+name+"-exec")
}

// TestLambdaIgnoreCodeChanges applies examples/basic with ignore_code_changes = true — the variant
// that hands code rollouts to an external deployer — and asserts the function is still created and
// its outputs resolve (the code-managing resource selection is transparent to consumers). Always
// destroys via defer.
func TestLambdaIgnoreCodeChanges(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	name := "lambda-ignore-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name":                name,
			"ignore_code_changes": true,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	functionName := terraform.Output(t, terraformOptions, "function_name")
	assert.Equal(t, name, functionName)

	functionARN := terraform.Output(t, terraformOptions, "function_arn")
	assert.Contains(t, functionARN, ":function:"+name)
}
