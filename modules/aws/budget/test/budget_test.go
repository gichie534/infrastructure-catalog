package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestBudgetBasic applies examples/basic (a monthly cost budget with two actual thresholds and a
// forecast tripwire), asserts on the outputs, and always destroys via defer.
//
// Budgets are free within the first two per account, so this test costs nothing to run.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestBudgetBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	budgetName := "budget-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name": budgetName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, budgetName, terraform.Output(t, terraformOptions, "name"))

	// An ARN comes back only once AWS has actually created the budget.
	arn := terraform.Output(t, terraformOptions, "arn")
	assert.True(t, strings.HasPrefix(arn, "arn:aws:budgets:"), "expected a budgets ARN, got %q", arn)

	// The subscriber fallback is the module's main behaviour: the example sets no subscriber on any
	// individual threshold, so all three must still have resolved to the budget-level email. Without the
	// fallback the apply would have failed the precondition, so reaching here with 3 proves both halves.
	assert.Equal(t, "3", terraform.Output(t, terraformOptions, "notification_count"))
}
