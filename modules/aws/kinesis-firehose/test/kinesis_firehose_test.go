package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestKinesisFirehoseBasic applies examples/basic (a Kinesis-sourced delivery stream writing to S3),
// asserts the delivery stream, its owned IAM role, and the delivery log group exist and are wired
// together, then always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestKinesisFirehoseBasic(t *testing.T) {
	t.Parallel()

	// Unique suffix so repeated/parallel runs don't collide on the stream or bucket name.
	unique := strings.ToLower(random.UniqueId())
	name := "firehose-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name":        name,
			"stream_name": name + "-source",
			"bucket_name": name + "-dest",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, name, terraform.Output(t, terraformOptions, "name"))

	arn := terraform.Output(t, terraformOptions, "arn")
	assert.True(t, strings.HasPrefix(arn, "arn:aws:firehose:"))
	assert.Contains(t, arn, ":deliverystream/"+name)

	// The module owns its delivery role — a consumer should never have to supply one.
	roleARN := terraform.Output(t, terraformOptions, "delivery_role_arn")
	assert.True(t, strings.HasPrefix(roleARN, "arn:aws:iam::"))
	assert.Contains(t, roleARN, name+"-firehose-delivery")

	// Delivery layout and latency floor are part of the contract a downstream loader depends on.
	assert.Equal(t, "stream/", terraform.Output(t, terraformOptions, "prefix"))
	assert.Equal(t, "60", terraform.Output(t, terraformOptions, "buffering_interval_seconds"))

	// Logging is on by default so delivery failures are not silent.
	assert.Equal(t, "/aws/kinesisfirehose/"+name, terraform.Output(t, terraformOptions, "log_group_name"))
}
