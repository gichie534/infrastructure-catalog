output "external_gateway_id" {
  description = "ID of the external VPN gateway describing the peer."
  value       = google_compute_external_vpn_gateway.this.id
}

output "external_gateway_name" {
  description = "Name of the external VPN gateway describing the peer."
  value       = google_compute_external_vpn_gateway.this.name
}

output "redundancy_type" {
  description = "Redundancy type Google derived from the number of peer interfaces supplied."
  value       = google_compute_external_vpn_gateway.this.redundancy_type
}

output "router_name" {
  description = "Name of the Cloud Router running BGP for this peering. Use it with `gcloud compute routers get-status` to read learned routes."
  value       = google_compute_router.this.name
}

output "router_id" {
  description = "ID of the Cloud Router running BGP for this peering."
  value       = google_compute_router.this.id
}

output "bgp_asn" {
  description = "BGP ASN of this side's Cloud Router. The peer must use this as its neighbour ASN."
  value       = var.bgp_asn
}

output "tunnel_names" {
  description = "Map of tunnel index (as a string) to the VPN tunnel name. Use with `gcloud compute vpn-tunnels describe` to check establishment."
  value       = { for k, t in google_compute_vpn_tunnel.this : k => t.name }
}

output "tunnel_self_links" {
  description = "Map of tunnel index (as a string) to the VPN tunnel self link."
  value       = { for k, t in google_compute_vpn_tunnel.this : k => t.self_link }
}

output "bgp_peer_names" {
  description = "Map of tunnel index (as a string) to the Cloud Router BGP peer name."
  value       = { for k, p in google_compute_router_peer.this : k => p.name }
}

output "advertised_ip_ranges" {
  description = "Extra IP ranges advertised to the peer beyond the VPC's own subnets (e.g. a GKE Pod secondary range)."
  value       = [for r in var.advertised_ip_ranges : r.range]
}
