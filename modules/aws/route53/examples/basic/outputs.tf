output "zone_id" {
  description = "The hosted-zone ID."
  value       = module.route53.zone_id
}

output "name" {
  description = "The domain name of the zone."
  value       = module.route53.name
}

output "name_servers" {
  description = "The zone's authoritative name servers."
  value       = module.route53.name_servers
}

output "record_fqdns" {
  description = "Map of relative record name to FQDN."
  value       = module.route53.record_fqdns
}
