package test

import (
	"fmt"
	"net"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestSiteToSiteVPNBasic applies examples/basic against a sandbox account and asserts the contract a
// peer gateway is configured from: one customer gateway and one connection per peer interface, and a
// complete per-tunnel description (outside address, link-local inside addresses, ASNs, PSK).
//
// The example points at documentation-range peer addresses, so the tunnels never establish — that is
// intentional. This test asserts the module's contract, not that a peer exists.
//
// Requires AWS credentials for a sandbox account. NOTE: VPN connections are billed hourly from
// creation regardless of tunnel state; the deferred destroy matters here.
func TestSiteToSiteVPNBasic(t *testing.T) {
	t.Parallel()

	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	name := fmt.Sprintf("test-s2s-%s", random.UniqueId())

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/basic",
		Vars: map[string]interface{}{
			"region": region,
			"name":   name,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	assert.NotEmpty(t, terraform.Output(t, terraformOptions, "vpn_gateway_id"))

	// The example passes two peer interfaces, so exactly two customer gateways and two connections
	// must exist — one per interface. Collapsing them into a single connection would break an HA VPN
	// peer, since AWS only accepts traffic from the address its customer gateway names.
	cgws := terraform.OutputMap(t, terraformOptions, "customer_gateway_ids")
	require.Len(t, cgws, 2, "expected one customer gateway per peer interface")

	conns := terraform.OutputMap(t, terraformOptions, "vpn_connection_ids")
	require.Len(t, conns, 2, "expected one VPN connection per peer interface")

	// AWS builds two tunnels per connection.
	outsideAddresses := terraform.OutputList(t, terraformOptions, "tunnel_outside_addresses")
	require.Len(t, outsideAddresses, 4, "expected two tunnels per connection")
	for i, addr := range outsideAddresses {
		require.NotNil(t, net.ParseIP(addr), "tunnel %d outside address %q is not a valid IP", i, addr)
	}
	assert.Len(t, uniq(outsideAddresses), 4, "every tunnel endpoint must have a distinct address")

	tunnels := terraform.OutputListOfObjects(t, terraformOptions, "tunnels")
	require.Len(t, tunnels, 4, "tunnels must describe every tunnel of every connection")

	for _, tunnel := range tunnels {
		label := fmt.Sprintf("connection %v tunnel %v", tunnel["connection_index"], tunnel["tunnel_index"])

		// A peer cannot be configured without all of these, so each is part of the contract.
		for _, field := range []string{
			"connection_id", "peer_gateway_ip", "outside_address", "inside_cidr",
			"vgw_inside_address", "cgw_inside_address", "cgw_inside_address_cidr", "preshared_key",
		} {
			assert.NotEmpty(t, tunnel[field], "%s: %s must be populated", label, field)
		}

		// BGP runs over a link-local /30, and each end holds one usable address in it.
		insideCIDR, ok := tunnel["inside_cidr"].(string)
		require.True(t, ok, "%s: inside_cidr must be a string", label)
		assert.True(t, strings.HasSuffix(insideCIDR, "/30"), "%s: inside_cidr %q should be a /30", label, insideCIDR)

		_, insideNet, err := net.ParseCIDR(insideCIDR)
		require.NoError(t, err, "%s: inside_cidr %q must parse", label, insideCIDR)

		vgwAddr, _ := tunnel["vgw_inside_address"].(string)
		cgwAddr, _ := tunnel["cgw_inside_address"].(string)
		assert.True(t, insideNet.Contains(net.ParseIP(vgwAddr)), "%s: vgw_inside_address %q must sit inside %q", label, vgwAddr, insideCIDR)
		assert.True(t, insideNet.Contains(net.ParseIP(cgwAddr)), "%s: cgw_inside_address %q must sit inside %q", label, cgwAddr, insideCIDR)
		assert.NotEqual(t, vgwAddr, cgwAddr, "%s: the two ends of the tunnel must not share an address", label)

		// The prefixed form is what a peer router interface is configured with; it must agree with
		// the bare address and the /30 rather than being independently derived.
		assert.Equal(t, cgwAddr+"/30", tunnel["cgw_inside_address_cidr"], "%s: cgw_inside_address_cidr must combine the address with the inside prefix", label)

		// ASNs are echoed from both perspectives so the peer never re-derives them.
		assert.EqualValues(t, 64512, toInt(tunnel["amazon_side_asn"]), "%s: amazon_side_asn", label)
		assert.EqualValues(t, 65001, toInt(tunnel["peer_bgp_asn"]), "%s: peer_bgp_asn", label)
	}

	assert.Equal(t, 64512, toInt(terraform.Output(t, terraformOptions, "amazon_side_asn")), "amazon_side_asn output")
}

func uniq(in []string) []string {
	seen := make(map[string]struct{}, len(in))
	out := make([]string, 0, len(in))
	for _, v := range in {
		if _, ok := seen[v]; ok {
			continue
		}
		seen[v] = struct{}{}
		out = append(out, v)
	}
	return out
}

// toInt normalises the numeric forms Terraform outputs arrive as (float64 from JSON, string from a
// plain output read) into an int for comparison.
func toInt(v interface{}) int {
	switch n := v.(type) {
	case float64:
		return int(n)
	case int:
		return n
	case string:
		var parsed int
		if _, err := fmt.Sscanf(n, "%d", &parsed); err != nil {
			return 0
		}
		return parsed
	default:
		return 0
	}
}
