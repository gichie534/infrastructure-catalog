package test

import (
	"os"
	"regexp"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestNotificationChannelsBasic applies examples/basic (one email channel), asserts the channel resource
// name has the shape a budget accepts, and always destroys via defer. Notification channels are free.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) with monitoring.googleapis.com enabled and ADC available.
func TestNotificationChannelsBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":          projectID,
			"display_name_prefix": "test-" + strings.ToLower(random.UniqueId()),
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	ids := terraform.OutputList(t, terraformOptions, "ids")
	require.Len(t, ids, 1)

	// Budgets reject anything that is not projects/<project>/notificationChannels/<numeric id>.
	pattern := regexp.MustCompile(`^projects/[^/]+/notificationChannels/[0-9]+$`)
	assert.Regexp(t, pattern, ids[0])
}
