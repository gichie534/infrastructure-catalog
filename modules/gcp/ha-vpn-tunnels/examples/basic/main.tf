provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP project to create resources in."
  type        = string
}

variable "region" {
  description = "Region for the network, HA VPN gateway, Cloud Router, and tunnels."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Name prefix for the example resources."
  type        = string
  default     = "example-vpn-tun"
}

variable "peer_gateway_interfaces" {
  description = <<-EOT
    Public IPv4 addresses of the peer tunnel endpoints. The defaults are from the documentation-only
    TEST-NET-3 range, so the tunnels are created but never establish — enough to assert this module's
    contract without standing up a peer in another cloud.
  EOT
  type        = list(string)
  default     = ["203.0.113.1", "203.0.113.2"]
}

resource "google_compute_network" "this" {
  name                    = var.name
  project                 = var.project_id
  auto_create_subnetworks = false
}

# A subnet with a secondary range, so the example exercises advertising a range that
# advertise_all_subnets would never cover (the GKE Pod case).
resource "google_compute_subnetwork" "this" {
  name          = var.name
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = "10.91.0.0/20"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.92.0.0/16"
  }
}

resource "google_compute_ha_vpn_gateway" "this" {
  name    = var.name
  project = var.project_id
  region  = var.region
  network = google_compute_network.this.self_link
}

# NOTE: Cloud VPN tunnels are billed hourly from creation, whether or not they establish. Destroy
# this example promptly.
module "ha_vpn_tunnels" {
  source = "../../"

  name       = var.name
  project_id = var.project_id
  region     = var.region
  network    = google_compute_network.this.self_link

  ha_vpn_gateway          = google_compute_ha_vpn_gateway.this.self_link
  peer_gateway_interfaces = var.peer_gateway_interfaces

  # One tunnel per HA VPN interface, each paired with its own peer endpoint — the shape a redundant
  # peering takes. The link-local /30s here stand in for the ones a real peer would report back.
  tunnels = [
    {
      vpn_gateway_interface           = 0
      peer_external_gateway_interface = 0
      router_interface_ip_range       = "169.254.10.2/30"
      peer_ip_address                 = "169.254.10.1"
      peer_asn                        = 64512
    },
    {
      vpn_gateway_interface           = 1
      peer_external_gateway_interface = 1
      router_interface_ip_range       = "169.254.11.2/30"
      peer_ip_address                 = "169.254.11.1"
      peer_asn                        = 64512
    },
  ]

  tunnel_shared_secrets = ["example-secret-tunnel-0", "example-secret-tunnel-1"]

  bgp_asn = 65001

  # The Pod secondary range is not a subnet, so advertise_all_subnets never covers it.
  advertised_ip_ranges = [
    { range = "10.92.0.0/16", description = "GKE Pod range" },
  ]

  depends_on = [google_compute_subnetwork.this]
}

output "router_name" {
  description = "Name of the Cloud Router running BGP."
  value       = module.ha_vpn_tunnels.router_name
}

output "external_gateway_name" {
  description = "Name of the external VPN gateway describing the peer."
  value       = module.ha_vpn_tunnels.external_gateway_name
}

output "redundancy_type" {
  description = "Redundancy type derived from the peer interface count."
  value       = module.ha_vpn_tunnels.redundancy_type
}

output "tunnel_names" {
  description = "Created tunnel names, keyed by tunnel index."
  value       = module.ha_vpn_tunnels.tunnel_names
}

output "bgp_peer_names" {
  description = "Created BGP peer names, keyed by tunnel index."
  value       = module.ha_vpn_tunnels.bgp_peer_names
}

output "advertised_ip_ranges" {
  description = "Extra ranges advertised to the peer."
  value       = module.ha_vpn_tunnels.advertised_ip_ranges
}
