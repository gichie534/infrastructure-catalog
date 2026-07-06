package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestDynamoDBBasic applies examples/basic (a single on-demand table keyed by ImageKey), asserts on
// the table outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestDynamoDBBasic(t *testing.T) {
	t.Parallel()

	// Unique suffix so repeated/parallel runs don't collide on the table name.
	unique := strings.ToLower(random.UniqueId())
	name := "dynamodb-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	tableName := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, name, tableName)

	id := terraform.Output(t, terraformOptions, "id")
	assert.Equal(t, name, id)

	arn := terraform.Output(t, terraformOptions, "arn")
	assert.True(t, strings.HasPrefix(arn, "arn:aws:dynamodb:"))
	assert.Contains(t, arn, ":table/"+name)
}
