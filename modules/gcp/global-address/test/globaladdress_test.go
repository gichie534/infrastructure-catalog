package test

import (
	"net"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestGlobalAddressBasic applies examples/basic (a single reserved global IPv4 address), asserts
// the exported outputs, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestGlobalAddressBasic(t *testing.T) {
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

	name := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, "example-ingress-ip", name)

	address := terraform.Output(t, terraformOptions, "address")
	assert.NotEmpty(t, net.ParseIP(address), "address output must be a valid IP")

	selfLink := terraform.Output(t, terraformOptions, "self_link")
	assert.Contains(t, selfLink, projectID)
	assert.Contains(t, selfLink, name)
}
