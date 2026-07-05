package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestRoute53Basic applies examples/basic (a public hosted zone with two records), asserts on the
// outputs, and always destroys via defer.
//
// Requires AWS credentials in the environment (and AWS_DEFAULT_REGION or the default us-east-1).
func TestRoute53Basic(t *testing.T) {
	t.Parallel()

	// Unique zone name so parallel/repeated runs don't collide on assertions.
	zoneName := "r53-test-" + strings.ToLower(random.UniqueId()) + ".example.com"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"zone_name": zoneName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Route 53 stores the zone name with a trailing dot.
	name := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, zoneName+".", name)

	zoneID := terraform.Output(t, terraformOptions, "zone_id")
	assert.NotEmpty(t, zoneID)

	nameServers := terraform.OutputList(t, terraformOptions, "name_servers")
	assert.NotEmpty(t, nameServers, "a public zone must have authoritative name servers")

	fqdns := terraform.OutputMap(t, terraformOptions, "record_fqdns")
	assert.Equal(t, "api."+zoneName, fqdns["api"])
	assert.Equal(t, "www."+zoneName, fqdns["www"])
}
