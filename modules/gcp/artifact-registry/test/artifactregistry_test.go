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

// TestArtifactRegistryBasic applies examples/basic (a single DOCKER repository with a
// randomised, unique ID), asserts on outputs, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with
// application-default credentials available.
func TestArtifactRegistryBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	repositoryID := fmt.Sprintf("example-ar-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":    projectID,
			"repository_id": repositoryID,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, repositoryID, terraform.Output(t, terraformOptions, "repository_id"))

	name := terraform.Output(t, terraformOptions, "name")
	assert.Contains(t, name, repositoryID)

	registryURL := terraform.Output(t, terraformOptions, "registry_url")
	assert.Contains(t, registryURL, "-docker.pkg.dev/"+projectID+"/"+repositoryID)
}
