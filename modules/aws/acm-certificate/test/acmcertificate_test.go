package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestAcmCertificateBasic applies examples/basic against a REAL, publicly-delegated Route 53 zone,
// asserts the certificate reaches ISSUED, and always destroys via defer.
//
// DNS-validated public certs can only be issued when the validation records resolve on the public
// internet, so this test needs a real zone. Provide it via env vars:
//
//	TEST_HOSTED_ZONE_ID  — an existing public hosted zone you control (e.g. Z0123...)
//	TEST_ZONE_NAME       — that zone's domain (e.g. aws.example.com)
//
// The test issues a cert for a unique subdomain of TEST_ZONE_NAME. It is skipped when the vars are
// unset so the wider suite can run without a domain. First issuance can take a few minutes.
func TestAcmCertificateBasic(t *testing.T) {
	t.Parallel()

	zoneID := os.Getenv("TEST_HOSTED_ZONE_ID")
	zoneName := os.Getenv("TEST_ZONE_NAME")
	if zoneID == "" || zoneName == "" {
		t.Skip("set TEST_HOSTED_ZONE_ID and TEST_ZONE_NAME to run the ACM certificate test")
	}

	domain := fmt.Sprintf("acm-test-%s.%s", strings.ToLower(random.UniqueId()), zoneName)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"hosted_zone_id": zoneID,
			"domain_name":    domain,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.Equal(t, "ISSUED", terraform.Output(t, terraformOptions, "status"))
	assert.Contains(t, terraform.Output(t, terraformOptions, "certificate_arn"), ":certificate/")
}
