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

// TestCertificateManagerBasic applies examples/basic (DNS authorizations + Google-managed certs +
// a certificate map + per-host map entries for two hosts, plus a public zone holding the validation
// CNAMEs), asserts on outputs, and always destroys via defer.
//
// This is a lightweight test: a DNS-authorized managed certificate is created in PENDING and only
// goes ACTIVE once its authorization CNAME resolves on the public internet, which apply does not
// wait for. The test asserts the module emits the right resources rather than that a cert issues.
//
// The example creates a PUBLIC zone, and GCP refuses to create one for reserved domains like
// example.com. So the test injects a unique, creatable base domain (the zone is torn down on
// destroy and never delegated, so it serves no real DNS).
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) to point at a sandbox project with application-default
// credentials available.
func TestCertificateManagerBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	// Unique apex under a real TLD: a recognized TLD (Certificate Manager rejects made-up ones like
	// ".example"), yet not reserved/registered (GCP refuses a public zone for those). A random label
	// makes a collision with a registered domain effectively impossible.
	baseDomain := fmt.Sprintf("cm-test-%s.com", strings.ToLower(random.UniqueId()))

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id":  projectID,
			"base_domain": baseDomain,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// The certificate map is what a GKE Ingress references via networking.gke.io/certmap.
	assert.Equal(t, "example-public", terraform.Output(t, terraformOptions, "certificate_map_name"))

	// One managed certificate per host, named "<map>-<label>".
	certIDs := terraform.OutputMap(t, terraformOptions, "certificate_ids")
	require.Contains(t, certIDs, "api")
	require.Contains(t, certIDs, "app")
	assert.Contains(t, certIDs["api"], "/certificates/example-public-api")
	assert.Contains(t, certIDs["app"], "/certificates/example-public-app")

	// Each cert exposes a DNS-authorization CNAME (name/type/data) to publish in the zone. Assert the
	// shape: an _acme-challenge name for the right host, CNAME type, and non-empty target.
	records := terraform.OutputMapOfObjects(t, terraformOptions, "dns_authorization_records")
	expectedNames := map[string]string{
		"api": fmt.Sprintf("_acme-challenge.api.%s.", baseDomain),
		"app": fmt.Sprintf("_acme-challenge.app.%s.", baseDomain),
	}
	for label, wantName := range expectedNames {
		require.Contains(t, records, label)
		rec, ok := records[label].(map[string]interface{})
		require.True(t, ok, "record for %q should be an object", label)

		assert.Equal(t, wantName, rec["name"], "authorization record name for %q", label)
		assert.Equal(t, "CNAME", rec["type"], "authorization record for %q should be a CNAME", label)
		assert.NotEmpty(t, rec["data"], "authorization record for %q should have a target", label)
	}
}
