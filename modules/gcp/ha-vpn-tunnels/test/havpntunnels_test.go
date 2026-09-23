package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestHaVpnTunnelsBasic applies examples/basic against a sandbox project and asserts the module built
// one tunnel, router interface and BGP peer per tunnels entry, derived the right redundancy type from
// the peer interface count, and advertised the extra (Pod) range that advertise_all_subnets cannot
// cover. Always destroys via defer.
//
// The example points at documentation-range peer addresses, so the tunnels never establish — that is
// intentional. This asserts the module's contract, not that a peer exists.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) pointing at a sandbox project. NOTE: Cloud VPN tunnels are
// billed hourly from creation regardless of state; the deferred destroy matters here.
func TestHaVpnTunnelsBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	name := fmt.Sprintf("ex-vpntun-%s", random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"name":       name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Two peer interfaces must yield TWO_IPS_REDUNDANCY; getting this wrong silently halves the
	// redundancy of a peering that looks correct otherwise.
	assert.Equal(t, "TWO_IPS_REDUNDANCY", terraform.Output(t, terraformOptions, "redundancy_type"))

	assert.Equal(t, name+"-router", terraform.Output(t, terraformOptions, "router_name"))
	assert.Equal(t, name+"-peer", terraform.Output(t, terraformOptions, "external_gateway_name"))

	// One tunnel and one BGP peer per tunnels entry, addressed by index.
	tunnelNames := terraform.OutputMap(t, terraformOptions, "tunnel_names")
	require.Len(t, tunnelNames, 2, "expected one tunnel per tunnels entry")
	assert.Equal(t, name+"-0", tunnelNames["0"])
	assert.Equal(t, name+"-1", tunnelNames["1"])

	peerNames := terraform.OutputMap(t, terraformOptions, "bgp_peer_names")
	require.Len(t, peerNames, 2, "expected one BGP peer per tunnel")
	assert.Equal(t, name+"-0", peerNames["0"])
	assert.Equal(t, name+"-1", peerNames["1"])

	// The Pod secondary range must be advertised: it is not a subnet, so advertise_all_subnets never
	// covers it, and without it a Pod reaching the peer has no return route.
	advertised := terraform.OutputList(t, terraformOptions, "advertised_ip_ranges")
	require.Len(t, advertised, 1)
	assert.Equal(t, "10.92.0.0/16", advertised[0])
}
