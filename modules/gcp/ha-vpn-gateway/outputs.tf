output "id" {
  description = "The ID of the HA VPN gateway."
  value       = google_compute_ha_vpn_gateway.this.id
}

output "name" {
  description = "The name of the HA VPN gateway."
  value       = google_compute_ha_vpn_gateway.this.name
}

output "self_link" {
  description = "The server-defined URL (self link) of the HA VPN gateway. Wire this to the ha-vpn-tunnels module's ha_vpn_gateway input."
  value       = google_compute_ha_vpn_gateway.this.self_link
}

output "region" {
  description = "The region the gateway was created in."
  value       = google_compute_ha_vpn_gateway.this.region
}

output "interface_ip_addresses" {
  description = "External IPv4 address of each gateway interface, ordered by interface ID (index 0 = interface 0). Configure the PEER with these — e.g. one AWS customer gateway per address."
  value       = [for i in google_compute_ha_vpn_gateway.this.vpn_interfaces : i.ip_address]
}
