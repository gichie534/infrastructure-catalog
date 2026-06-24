package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestSQSBasic applies examples/basic (a single standard queue with long polling), asserts on the
// queue outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestSQSBasic(t *testing.T) {
	t.Parallel()

	// Unique suffix so repeated/parallel runs don't collide on the queue name.
	unique := strings.ToLower(random.UniqueId())
	name := "sqs-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	queueName := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, name, queueName)

	arn := terraform.Output(t, terraformOptions, "arn")
	assert.Contains(t, arn, ":"+name)
	assert.True(t, strings.HasPrefix(arn, "arn:aws:sqs:"))

	url := terraform.Output(t, terraformOptions, "url")
	assert.Contains(t, url, name)
	assert.True(t, strings.HasPrefix(url, "https://"))
}
