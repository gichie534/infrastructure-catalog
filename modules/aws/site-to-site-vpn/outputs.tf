output "vpn_gateway_id" {
  description = "ID of the virtual private gateway attached to the VPC."
  value       = aws_vpn_gateway.this.id
}

output "amazon_side_asn" {
  description = "BGP ASN of the Amazon side. The peer configures this as its BGP neighbour's ASN."
  value       = var.amazon_side_asn
}

output "customer_gateway_ids" {
  description = "Map of peer-interface index (as a string) to the customer gateway ID created for it."
  value       = { for k, cgw in aws_customer_gateway.this : k => cgw.id }
}

output "vpn_connection_ids" {
  description = "Map of peer-interface index (as a string) to the VPN connection ID created for it."
  value       = { for k, c in aws_vpn_connection.this : k => c.id }
}

output "tunnel_outside_addresses" {
  description = "Public address of every AWS tunnel endpoint, ordered by connection then tunnel. Use these as the peer's external gateway interfaces. Non-sensitive, so it is safe to print while diagnosing connectivity."
  value       = [for t in local.tunnels : t.outside_address]
}

output "tunnels" {
  description = <<-EOT
    Everything the peer side needs, one entry per tunnel (two per connection), ordered by connection
    then tunnel: connection_index, tunnel_index, connection_id, peer_gateway_ip, outside_address,
    inside_cidr, vgw_inside_address (the peer's BGP neighbour), cgw_inside_address and
    cgw_inside_address_cidr (the address the peer's own router interface must hold),
    amazon_side_asn, peer_bgp_asn, and preshared_key.

    Marked sensitive as a whole because it carries the pre-shared keys; consume it from another
    module rather than printing it. Use tunnel_outside_addresses for anything you need to read.
  EOT
  value       = local.tunnels
  sensitive   = true
}
