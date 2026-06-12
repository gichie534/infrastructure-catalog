output "zone_name" {
  description = "The managed-zone resource name."
  value       = module.dns.zone_name
}

output "dns_name" {
  description = "The DNS domain of the zone."
  value       = module.dns.dns_name
}

output "record_fqdns" {
  description = "Map of relative record name to FQDN."
  value       = module.dns.record_fqdns
}
