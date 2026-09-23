provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP project to create resources in."
  type        = string
}

variable "region" {
  description = "Region for the VPC subnet and the HA VPN gateway."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "Name prefix for the example resources."
  type        = string
  default     = "example-ha-vpn"
}

# A minimal network to attach the gateway to. The gateway itself is free; only tunnels are billed,
# and this example creates none — so it is a cheap way to assert the interface addresses exist.
resource "google_compute_network" "this" {
  name                    = var.name
  project                 = var.project_id
  auto_create_subnetworks = false
}

module "ha_vpn_gateway" {
  source = "../../"

  name       = var.name
  project_id = var.project_id
  region     = var.region
  network    = google_compute_network.this.self_link
}

output "interface_ip_addresses" {
  description = "The two external IPv4 addresses Google assigned to the gateway interfaces."
  value       = module.ha_vpn_gateway.interface_ip_addresses
}

output "self_link" {
  description = "Self link of the created gateway."
  value       = module.ha_vpn_gateway.self_link
}
