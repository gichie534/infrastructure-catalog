package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestS3BucketBasic applies examples/basic (a hardened bucket with force_destroy and an ABAC bucket
// policy), asserts on the outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestS3BucketBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	bucketName := "s3-bucket-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"bucket_name": bucketName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	bucket := terraform.Output(t, terraformOptions, "bucket")
	assert.Equal(t, bucketName, bucket)

	arn := terraform.Output(t, terraformOptions, "arn")
	assert.Equal(t, "arn:aws:s3:::"+bucketName, arn)
}
