output "zone_name" {
  description = "The managed-zone resource name (used to add records or grant DNS IAM)."
  value       = google_dns_managed_zone.this.name
}

output "dns_name" {
  description = "The DNS domain of the zone (with trailing dot)."
  value       = google_dns_managed_zone.this.dns_name
}

output "name_servers" {
  description = "The zone's authoritative name servers. For a public zone, delegate the domain to these at your registrar. Empty/unused for private zones."
  value       = google_dns_managed_zone.this.name_servers
}

output "record_fqdns" {
  description = "Map of relative record name to its fully-qualified domain name (with trailing dot)."
  value       = local.record_fqdns
}
