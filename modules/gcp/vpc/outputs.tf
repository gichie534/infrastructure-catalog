output "network_id" {
  description = "The ID of the VPC network."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "The URI (self link) of the VPC network, used when wiring GKE clusters and peerings."
  value       = google_compute_network.this.self_link
}

output "subnets" {
  description = "Map of subnet name (as supplied in var.subnets) to its key attributes."
  value = {
    for k, s in google_compute_subnetwork.this : k => {
      id            = s.id
      name          = s.name
      self_link     = s.self_link
      region        = s.region
      ip_cidr_range = s.ip_cidr_range
    }
  }
}

output "subnets_self_links" {
  description = "Map of subnet name to self link."
  value       = { for k, s in google_compute_subnetwork.this : k => s.self_link }
}

output "subnets_secondary_ranges" {
  description = "Map of subnet name to its secondary range names (Pods/Services) for VPC-native GKE clusters."
  value = {
    for k, s in google_compute_subnetwork.this : k => [
      for r in s.secondary_ip_range : {
        range_name    = r.range_name
        ip_cidr_range = r.ip_cidr_range
      }
    ]
  }
}

output "private_service_access_range" {
  description = "Name of the reserved global address range used for Private Service Access, or null when disabled."
  value       = var.private_service_access ? google_compute_global_address.private_service_access[0].name : null
}

output "nat_router_name" {
  description = "Name of the Cloud Router backing Cloud NAT, or null when NAT is disabled."
  value       = var.create_nat ? google_compute_router.this[0].name : null
}
