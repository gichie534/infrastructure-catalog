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

// TestBigQueryDatasetBasic applies examples/basic (an empty US multi-region dataset), asserts on the
// outputs, and always destroys via defer. An empty dataset costs nothing.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) with bigquery.googleapis.com enabled and ADC available.
func TestBigQueryDatasetBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	// Dataset IDs reject hyphens, so the random suffix joins with an underscore.
	datasetID := "dataset_test_" + strings.ToLower(random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"dataset_id": datasetID,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, datasetID, terraform.Output(t, terraformOptions, "dataset_id"))
	assert.Equal(t, "US", terraform.Output(t, terraformOptions, "location"))
	assert.Equal(t, projectID+"."+datasetID, terraform.Output(t, terraformOptions, "fully_qualified_name"))
}
