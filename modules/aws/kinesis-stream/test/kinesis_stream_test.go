package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestKinesisStreamBasic applies examples/basic (a single-shard provisioned stream), asserts on the
// stream outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestKinesisStreamBasic(t *testing.T) {
	t.Parallel()

	// Unique suffix so repeated/parallel runs don't collide on the stream name.
	unique := strings.ToLower(random.UniqueId())
	name := "kinesis-stream-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	streamName := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, name, streamName)

	arn := terraform.Output(t, terraformOptions, "arn")
	assert.True(t, strings.HasPrefix(arn, "arn:aws:kinesis:"))
	assert.Contains(t, arn, ":stream/"+name)

	// The example asks for one shard and leaves retention at the module default.
	assert.Equal(t, "1", terraform.Output(t, terraformOptions, "shard_count"))
	assert.Equal(t, "24", terraform.Output(t, terraformOptions, "retention_period_hours"))
}
