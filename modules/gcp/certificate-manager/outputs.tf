output "certificate_map_name" {
  description = "Name of the certificate map. Put this in the GKE Ingress `networking.gke.io/certmap` annotation to attach the certs."
  value       = google_certificate_manager_certificate_map.this.name
}

output "certificate_map_id" {
  description = "Full resource ID of the certificate map."
  value       = google_certificate_manager_certificate_map.this.id
}

output "certificate_ids" {
  description = "Map of certificate label to the managed certificate's full resource ID."
  value       = { for k, m in module.certificate : k => m.certificate_id }
}

output "dns_authorization_records" {
  description = <<-EOT
    Per certificate label, the CNAME record that must be published in the domain's zone for the
    certificate to validate and auto-renew. The certificate stays pending until this resolves. Feed
    these into the gcp/cloud-dns module (rrdatas = [data]).
  EOT
  value       = { for k, m in module.certificate : k => m.dns_authorization_record }
}
