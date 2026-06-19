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

output "validation_record_names" {
  description = "Map of validation-record label to the fully-qualified name actually created (echoes the input names; useful for assertions and debugging)."
  value       = { for k, r in google_dns_record_set.validation : k => r.name }
}

output "delegation_record_name" {
  description = "The NS delegation record name written into the parent zone, or null when delegate_to_parent_zone is unset."
  value       = var.delegate_to_parent_zone == null ? null : google_dns_record_set.delegation[0].name
}
