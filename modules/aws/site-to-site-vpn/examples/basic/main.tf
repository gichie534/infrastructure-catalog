provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for the example resources."
  type        = string
  default     = "example-s2s-vpn"
}

variable "peer_gateway_ip_addresses" {
  description = <<-EOT
    Public IPv4 addresses of the peer gateway interfaces. The defaults are from the
    documentation-only TEST-NET-3 range, so the connections are created but the tunnels never
    establish — enough to assert this module's contract without standing up a second cloud.
  EOT
  type        = list(string)
  default     = ["203.0.113.1", "203.0.113.2"]
}

# A minimal VPC to attach the virtual private gateway to.
resource "aws_vpc" "this" {
  cidr_block = "10.90.0.0/16"

  tags = { Name = var.name }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-private" }
}

# NOTE: a VPN connection is billed per hour while it exists, whether or not its tunnels are up.
# Destroy this example promptly.
module "site_to_site_vpn" {
  source = "../../"

  name   = var.name
  vpc_id = aws_vpc.this.id

  peer_gateway_ip_addresses = var.peer_gateway_ip_addresses

  peer_bgp_asn    = 65001
  amazon_side_asn = 64512

  route_table_ids = [aws_route_table.private.id]

  tags = { Example = "basic" }
}

output "vpn_gateway_id" {
  description = "ID of the virtual private gateway."
  value       = module.site_to_site_vpn.vpn_gateway_id
}

output "customer_gateway_ids" {
  description = "Customer gateway IDs, keyed by peer-interface index."
  value       = module.site_to_site_vpn.customer_gateway_ids
}

output "vpn_connection_ids" {
  description = "VPN connection IDs, keyed by peer-interface index."
  value       = module.site_to_site_vpn.vpn_connection_ids
}

output "tunnel_outside_addresses" {
  description = "Public address of every AWS tunnel endpoint."
  value       = module.site_to_site_vpn.tunnel_outside_addresses
}

output "amazon_side_asn" {
  description = "BGP ASN of the Amazon side."
  value       = module.site_to_site_vpn.amazon_side_asn
}

# Exposed so the test can assert the per-tunnel contract the peer is built from. Sensitive because
# it carries the pre-shared keys.
output "tunnels" {
  description = "Per-tunnel details the peer side is configured from."
  value       = module.site_to_site_vpn.tunnels
  sensitive   = true
}
