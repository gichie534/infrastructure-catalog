package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestVPCBasic applies examples/basic against a sandbox project, asserts that the
// network, subnets, GKE secondary ranges, and Private Service Access range are
// created, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestVPCBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id": projectID,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	networkID := terraform.Output(t, terraformOptions, "network_id")
	assert.NotEmpty(t, networkID)

	networkSelfLink := terraform.Output(t, terraformOptions, "network_self_link")
	assert.Contains(t, networkSelfLink, "example-gke-vpc")

	// The single example subnet must expose Pods and Services secondary ranges.
	secondary := terraform.OutputMapOfObjects(t, terraformOptions, "subnets_secondary_ranges")
	ranges, ok := secondary["gke"].([]interface{})
	require.True(t, ok, "expected secondary ranges for the 'gke' subnet")
	assert.Len(t, ranges, 2, "GKE subnet should have Pods and Services secondary ranges")

	// Private Service Access peering range must be reserved.
	psaRange := terraform.Output(t, terraformOptions, "private_service_access_range")
	assert.NotEmpty(t, psaRange)
}