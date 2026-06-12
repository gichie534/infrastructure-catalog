package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestGCSBucketBasic applies examples/basic (a single bucket with a randomised, unique
// name), asserts on outputs, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestGCSBucketBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	bucketName := fmt.Sprintf("example-gcs-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":  projectID,
			"bucket_name": bucketName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	name := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, bucketName, name)

	url := terraform.Output(t, terraformOptions, "url")
	assert.Equal(t, "gs://"+bucketName, url)
}
