package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestCostAnomalyDetectionBasic applies examples/basic (a SERVICE monitor plus a daily email
// subscription thresholded on absolute OR percentage impact), asserts on the outputs, and always
// destroys via defer.
//
// Cost Anomaly Detection is free, so this test costs nothing to run.
//
// Requires AWS credentials in the environment. Cost Explorer is global via its us-east-1 endpoint and
// the example pins that region itself.
func TestCostAnomalyDetectionBasic(t *testing.T) {
	t.Parallel()

	unique := strings.ToLower(random.UniqueId())
	namePrefix := "cad-test-" + unique

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"name_prefix": namePrefix,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	monitorName := namePrefix + "-services"
	subscriptionName := namePrefix + "-daily"

	assert.Equal(t, []string{monitorName}, terraform.OutputList(t, terraformOptions, "monitor_names"))
	assert.Equal(t, []string{subscriptionName}, terraform.OutputList(t, terraformOptions, "subscription_names"))

	monitorArns := terraform.OutputMap(t, terraformOptions, "monitor_arns")
	assert.True(t, strings.HasPrefix(monitorArns[monitorName], "arn:aws:ce:"),
		"expected a Cost Explorer ARN, got %q", monitorArns[monitorName])

	// The example leaves monitor_keys empty, so the module's "empty means every monitor" default must
	// have resolved the subscription onto the one declared monitor. Getting this wrong produces a
	// subscription that is valid, applies cleanly, and watches nothing.
	monitorKeys := terraform.OutputMapOfObjects(t, terraformOptions, "subscription_monitor_keys")
	assert.Contains(t, monitorKeys[subscriptionName], monitorName)
}
