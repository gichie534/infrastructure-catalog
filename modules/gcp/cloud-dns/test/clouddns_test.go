package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestCloudDNSBasic applies examples/basic (a VPC plus a private managed zone with two
// records), asserts on outputs, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestCloudDNSBasic(t *testing.T) {
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

	assert.Equal(t, "example-internal", terraform.Output(t, terraformOptions, "zone_name"))
	assert.Equal(t, "internal.example.com.", terraform.Output(t, terraformOptions, "dns_name"))

	fqdns := terraform.OutputMap(t, terraformOptions, "record_fqdns")
	assert.Equal(t, "api.internal.example.com.", fqdns["api"])
	assert.Equal(t, "db.internal.example.com.", fqdns["db"])
}
