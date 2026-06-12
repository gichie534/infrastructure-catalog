package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestGKEBasic applies examples/basic (which composes the vpc module and a regional
// Autopilot cluster) against a sandbox project, asserts on cluster outputs, and always
// destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestGKEBasic(t *testing.T) {
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

	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	assert.Equal(t, "example-autopilot", clusterName)

	clusterID := terraform.Output(t, terraformOptions, "cluster_id")
	assert.NotEmpty(t, clusterID)

	endpoint := terraform.Output(t, terraformOptions, "endpoint")
	assert.NotEmpty(t, endpoint)

	networkSelfLink := terraform.Output(t, terraformOptions, "network_self_link")
	assert.Contains(t, networkSelfLink, "example-gke")
}
