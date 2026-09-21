package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestCostAllocationBasic applies examples/basic (a cost category with tag rules, a dimension rule and
// a default value), asserts on the outputs, and always destroys via defer.
//
// Cost categories and tag activation are free, so this test costs nothing to run.
//
// The example activates no cost allocation tag keys: AWS only accepts keys it has already discovered on
// a real resource, which cannot be arranged inside a test run.
//
// Requires AWS credentials in the environment. Cost Explorer is global via its us-east-1 endpoint and
// the example pins that region itself.
func TestCostAllocationBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	namePrefix := "costalloc-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name_prefix": namePrefix,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	categoryName := namePrefix + "-team"
	assert.Equal(t, []string{categoryName}, terraform.OutputList(t, terraformOptions, "cost_category_names"))

	arns := terraform.OutputMap(t, terraformOptions, "cost_category_arns")
	assert.True(t, strings.HasPrefix(arns[categoryName], "arn:aws:ce:"),
		"expected a Cost Explorer ARN, got %q", arns[categoryName])

	// Nothing activated means nothing reported — proves the module does not activate keys the consumer
	// did not ask for, which would fail against an account that has never used them.
	assert.Empty(t, terraform.OutputList(t, terraformOptions, "active_cost_allocation_tag_keys"))
}
