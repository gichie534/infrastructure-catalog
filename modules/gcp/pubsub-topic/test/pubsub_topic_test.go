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

// TestPubSubTopicBasic applies examples/basic (a topic the Cloud Billing service account may publish to,
// with one pull subscription), asserts on the outputs, and always destroys via defer. An idle topic and
// subscription cost nothing.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) with pubsub.googleapis.com enabled and ADC available.
func TestPubSubTopicBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	name := "topic-test-" + strings.ToLower(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"name":       name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, "projects/"+projectID+"/topics/"+name, terraform.Output(t, terraformOptions, "id"))

	// The grant is the module's reason to exist: without it Billing's publishes are refused silently.
	assert.Equal(t,
		[]string{"serviceAccount:billing-budget-alert@system.gserviceaccount.com"},
		terraform.OutputList(t, terraformOptions, "publisher_members"))

	subs := terraform.OutputMap(t, terraformOptions, "subscription_ids")
	assert.Equal(t, "projects/"+projectID+"/subscriptions/"+name+"-pull", subs[name+"-pull"])
}
