output "certificate_id" {
  description = "Full resource ID of the managed certificate."
  value       = google_certificate_manager_certificate.this.id
}

output "dns_authorization_record" {
  description = "The CNAME record ({ name, type, data }) that must be published in the zone for the certificate to validate and auto-renew."
  value = {
    name = google_certificate_manager_dns_authorization.this.dns_resource_record[0].name
    type = google_certificate_manager_dns_authorization.this.dns_resource_record[0].type
    data = google_certificate_manager_dns_authorization.this.dns_resource_record[0].data
  }
}
