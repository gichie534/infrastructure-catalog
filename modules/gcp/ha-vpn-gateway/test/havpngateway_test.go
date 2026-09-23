package test

import (
	"fmt"
	"net"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestHaVpnGatewayBasic applies examples/basic against a sandbox project and asserts the gateway
// exposes exactly two routable external IPv4 interface addresses — the contract a peer (e.g. an AWS
// customer gateway) is configured from. Always destroys via defer.
//
// Requires GOOGLE_PROJECT (or GCP_PROJECT) pointing at a sandbox project with application-default
// credentials available. The gateway itself is not billed; no tunnels are created here.
func TestHaVpnGatewayBasic(t *testing.T) {
	t.Parallel()

	projectID := os.Getenv("GOOGLE_PROJECT")
	if projectID == "" {
		projectID = os.Getenv("GCP_PROJECT")
	}
	require.NotEmpty(t, projectID, "set GOOGLE_PROJECT (or GCP_PROJECT) to a sandbox project to run this test")

	name := fmt.Sprintf("test-havpn-%s", random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"name":       name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	selfLink := terraform.Output(t, terraformOptions, "self_link")
	assert.Contains(t, selfLink, name)

	// An HA VPN gateway always has two interfaces; a peer needs both addresses to build a
	// redundant pair of tunnels, so a single-address result would be a contract regression.
	addresses := terraform.OutputList(t, terraformOptions, "interface_ip_addresses")
	require.Len(t, addresses, 2, "an HA VPN gateway must expose two interface addresses")

	for i, addr := range addresses {
		ip := net.ParseIP(addr)
		require.NotNil(t, ip, "interface %d address %q is not a valid IP", i, addr)
		require.NotNil(t, ip.To4(), "interface %d address %q is not IPv4", i, addr)
		assert.False(t, ip.IsPrivate(), "interface %d address %q must be a public address a peer can reach", i, addr)
	}

	assert.NotEqual(t, addresses[0], addresses[1], "the two interfaces must have distinct addresses")
}
