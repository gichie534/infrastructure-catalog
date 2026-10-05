package test

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestBillingBudgetBasic applies examples/basic (a monthly project-scoped budget with two current-spend
// thresholds and a forecast tripwire), asserts on the outputs, and always destroys via defer.
//
// Budgets are free, so this test costs nothing to run.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) and GOOGLE_BILLING_ACCOUNT, with application-default credentials
// holding roles/billing.costsManager (or roles/billing.admin) on that billing account, and the
// billingbudgets.googleapis.com API enabled on the project.
func TestBillingBudgetBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	billingAccount := os.Getenv("GOOGLE_BILLING_ACCOUNT")
	require.NotEmpty(t, billingAccount, "set GOOGLE_BILLING_ACCOUNT to the sandbox billing account ID")

	displayName := "budget-test-" + strings.ToLower(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":      projectID,
			"billing_account": billingAccount,
			"display_name":    displayName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, displayName, terraform.Output(t, terraformOptions, "display_name"))

	// A resource name only comes back once Google has actually created the budget.
	name := terraform.Output(t, terraformOptions, "name")
	assert.True(t, strings.HasPrefix(name, "billingAccounts/"+billingAccount+"/budgets/"), "unexpected budget name %q", name)

	assert.Equal(t, "3", terraform.Output(t, terraformOptions, "threshold_count"))
}
