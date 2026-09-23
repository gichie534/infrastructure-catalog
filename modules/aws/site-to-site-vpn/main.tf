# aws/site-to-site-vpn module.
#
# The AWS half of a BGP-routed IPsec VPN to a peer gateway in another network — typically another
# cloud. It owns the virtual private gateway, one customer gateway and one VPN connection per peer
# interface, and the route propagation that makes the learned routes usable.
#
# It does NOT own the peer side. The peer's addresses come in as inputs; everything the peer needs
# back (tunnel outside addresses, the link-local inside addresses for BGP, and the pre-shared keys)
# comes out in the `tunnels` output. That asymmetry is deliberate: each side of a VPN can only be
# configured once the other side exists, so the contract is "give me your addresses, here are mine".

locals {
  # One connection per peer interface, keyed by stringified index so the map keys are stable and the
  # ordering of peer_gateway_ip_addresses is preserved in resource addresses.
  connections = { for idx, ip in var.peer_gateway_ip_addresses : tostring(idx) => ip }

  # Optional per-connection overrides, looked up by the same index.
  inside_cidrs = { for idx, e in var.tunnel_inside_cidrs : tostring(idx) => e }
  psks         = { for idx, e in var.tunnel_preshared_keys : tostring(idx) => e }

  # Flatten every tunnel of every connection into one list a peer can iterate.
  #
  # AWS creates TWO tunnels per connection. A Google Cloud HA VPN peer pairs one interface with one
  # AWS connection, so it consumes only tunnel_index 1 of each — the consumer filters. The unused
  # tunnel staying DOWN is expected, not a fault.
  tunnels = flatten([
    for idx, ip in var.peer_gateway_ip_addresses : [
      for tnum in [1, 2] : {
        connection_index = idx
        tunnel_index     = tnum
        connection_id    = aws_vpn_connection.this[tostring(idx)].id
        peer_gateway_ip  = ip

        # Public address of the AWS tunnel endpoint — the peer's tunnel destination.
        outside_address = tnum == 1 ? aws_vpn_connection.this[tostring(idx)].tunnel1_address : aws_vpn_connection.this[tostring(idx)].tunnel2_address

        # The link-local /30 carrying the BGP session, and each end's address within it.
        inside_cidr = tnum == 1 ? aws_vpn_connection.this[tostring(idx)].tunnel1_inside_cidr : aws_vpn_connection.this[tostring(idx)].tunnel2_inside_cidr

        # AWS's own inside address: the peer's BGP neighbour.
        vgw_inside_address = tnum == 1 ? aws_vpn_connection.this[tostring(idx)].tunnel1_vgw_inside_address : aws_vpn_connection.this[tostring(idx)].tunnel2_vgw_inside_address

        # The address AWS expects the PEER to hold: the peer's own router interface address.
        cgw_inside_address = tnum == 1 ? aws_vpn_connection.this[tostring(idx)].tunnel1_cgw_inside_address : aws_vpn_connection.this[tostring(idx)].tunnel2_cgw_inside_address

        # Ready-to-use prefixed form, because a peer router interface is configured with an address
        # AND a mask while AWS returns them separately. The mask is read from inside_cidr rather
        # than hardcoded to /30, so an AWS change of allocation size can't silently corrupt it.
        cgw_inside_address_cidr = format(
          "%s/%s",
          tnum == 1 ? aws_vpn_connection.this[tostring(idx)].tunnel1_cgw_inside_address : aws_vpn_connection.this[tostring(idx)].tunnel2_cgw_inside_address,
          split("/", tnum == 1 ? aws_vpn_connection.this[tostring(idx)].tunnel1_inside_cidr : aws_vpn_connection.this[tostring(idx)].tunnel2_inside_cidr)[1],
        )

        # ASNs from each end's perspective, so the peer never has to re-derive them.
        amazon_side_asn = var.amazon_side_asn
        peer_bgp_asn    = var.peer_bgp_asn

        preshared_key = tnum == 1 ? aws_vpn_connection.this[tostring(idx)].tunnel1_preshared_key : aws_vpn_connection.this[tostring(idx)].tunnel2_preshared_key
      }
    ]
  ])
}

# --- Virtual private gateway ------------------------------------------------
resource "aws_vpn_gateway" "this" {
  vpc_id          = var.vpc_id
  amazon_side_asn = tostring(var.amazon_side_asn)

  tags = merge(var.tags, { Name = var.name })
}

# Without propagation the tunnels establish and BGP exchanges routes, but nothing in the VPC has a
# route back to the peer — the failure looks like a one-way network rather than a missing route.
resource "aws_vpn_gateway_route_propagation" "this" {
  for_each = toset(var.route_table_ids)

  vpn_gateway_id = aws_vpn_gateway.this.id
  route_table_id = each.value
}

# --- Customer gateways (one per peer interface) -----------------------------
resource "aws_customer_gateway" "this" {
  for_each = local.connections

  bgp_asn    = tostring(var.peer_bgp_asn)
  ip_address = each.value
  type       = "ipsec.1"

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

# --- VPN connections (one per customer gateway) -----------------------------
resource "aws_vpn_connection" "this" {
  for_each = local.connections

  vpn_gateway_id      = aws_vpn_gateway.this.id
  customer_gateway_id = aws_customer_gateway.this[each.key].id
  type                = "ipsec.1"
  static_routes_only  = var.static_routes_only

  local_ipv4_network_cidr  = var.local_ipv4_network_cidr
  remote_ipv4_network_cidr = var.remote_ipv4_network_cidr

  tunnel1_ike_versions   = var.ike_versions
  tunnel2_ike_versions   = var.ike_versions
  tunnel1_startup_action = var.tunnel_startup_action
  tunnel2_startup_action = var.tunnel_startup_action

  # Null lets AWS allocate/generate, which is the default path; an override wins when supplied.
  tunnel1_inside_cidr = try(local.inside_cidrs[each.key].tunnel1, null)
  tunnel2_inside_cidr = try(local.inside_cidrs[each.key].tunnel2, null)

  tunnel1_preshared_key = try(local.psks[each.key].tunnel1, null)
  tunnel2_preshared_key = try(local.psks[each.key].tunnel2, null)

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}
