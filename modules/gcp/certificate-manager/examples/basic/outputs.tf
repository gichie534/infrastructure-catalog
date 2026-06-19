output "certificate_map_name" {
  description = "Certificate map name for the GKE Ingress networking.gke.io/certmap annotation."
  value       = module.certs.certificate_map_name
}

output "certificate_ids" {
  description = "Map of label to certificate resource ID."
  value       = module.certs.certificate_ids
}

output "dns_authorization_records" {
  description = "Validation CNAMEs required per certificate."
  value       = module.certs.dns_authorization_records
}
