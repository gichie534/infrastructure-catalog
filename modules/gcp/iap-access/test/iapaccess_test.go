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

// TestIapAccessBasic applies examples/basic (a throwaway service account plus the iap-access unit
// that grants it roles/iap.httpsResourceAccessor at the project-wide IAP web scope), asserts on the
// outputs, and always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with application-default
// credentials available and the IAP API enabled.
func TestIapAccessBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	accountID := fmt.Sprintf("iap-acc-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"account_id": accountID,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, "roles/iap.httpsResourceAccessor", terraform.Output(t, terraformOptions, "role"))
	assert.Equal(t, "project", terraform.Output(t, terraformOptions, "scope"))

	saEmail := terraform.Output(t, terraformOptions, "service_account_email")
	assert.True(t, strings.HasSuffix(saEmail, "@"+projectID+".iam.gserviceaccount.com"),
		"example SA email should belong to the project, got %q", saEmail)

	members := terraform.OutputList(t, terraformOptions, "members")
	require.Len(t, members, 1)
	assert.Equal(t, "serviceAccount:"+saEmail, members[0])

	// examples/basic defaults cors_allow_http_options to true, so the module manages IAP settings on
	// the same (project-wide) scope as the IAM grant.
	assert.Equal(t, "true", terraform.Output(t, terraformOptions, "cors_allow_http_options"))
	assert.Equal(t, fmt.Sprintf("projects/%s/iap_web", projectID),
		terraform.Output(t, terraformOptions, "settings_resource_name"))
}

// TestIapAccessSettingsUnmanaged applies examples/basic with cors_allow_http_options explicitly null
// and asserts the module creates NO google_iap_settings — the default contract for consumers that
// only want IAM grants, so enabling settings stays strictly opt-in.
func TestIapAccessSettingsUnmanaged(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	accountID := fmt.Sprintf("iap-uns-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":              projectID,
			"account_id":              accountID,
			"cors_allow_http_options": nil,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Empty(t, terraform.Output(t, terraformOptions, "settings_resource_name"),
		"settings_resource_name should be null when cors_allow_http_options is unset")
	assert.Empty(t, terraform.Output(t, terraformOptions, "cors_allow_http_options"),
		"cors_allow_http_options should be null when unset")
}
