output "zone_id" {
  description = "The hosted-zone ID (used to add records or wire other resources such as ALB alias records)."
  value       = aws_route53_zone.this.zone_id
}

output "zone_arn" {
  description = "ARN of the hosted zone."
  value       = aws_route53_zone.this.arn
}

output "name" {
  description = "The domain name of the zone."
  value       = aws_route53_zone.this.name
}

output "name_servers" {
  description = "The zone's authoritative name servers. For a public zone, delegate the domain to these at your registrar (or parent zone). Unused for private zones."
  value       = aws_route53_zone.this.name_servers
}

output "record_fqdns" {
  description = "Map of relative record name to its fully-qualified domain name."
  value       = local.record_fqdns
}

output "validation_record_fqdns" {
  description = "Map of validation-record label to the fully-qualified name actually created (echoes the input names; useful for assertions and debugging)."
  value       = { for k, r in aws_route53_record.validation : k => r.fqdn }
}

output "delegation_record_name" {
  description = "The NS delegation record name written into the parent zone, or null when delegate_to_parent_zone is unset."
  value       = var.delegate_to_parent_zone == null ? null : aws_route53_record.delegation[0].name
}
