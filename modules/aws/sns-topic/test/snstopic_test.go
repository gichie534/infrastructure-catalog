package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestSnsTopicBasic applies examples/basic (a topic that AWS Budgets and Cost Anomaly Detection may
// publish to), asserts on the outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestSnsTopicBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	topicName := "sns-topic-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": topicName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	name := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, topicName, name)

	// SNS ARNs are arn:aws:sns:<region>:<account>:<name>. Asserting the suffix proves the topic was
	// created under the name we asked for without hardcoding an account id in the test.
	arn := terraform.Output(t, terraformOptions, "arn")
	assert.True(t, strings.HasPrefix(arn, "arn:aws:sns:"), "expected an SNS ARN, got %q", arn)
	assert.True(t, strings.HasSuffix(arn, ":"+topicName), "expected ARN to end in the topic name, got %q", arn)

	// The example grants two service principals, so a policy must be managed. A successful apply is
	// itself the assertion that SNS accepted the generated policy document.
	assert.Equal(t, "true", terraform.Output(t, terraformOptions, "policy_managed"))
}
