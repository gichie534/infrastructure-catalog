output "repository_id" {
  description = "Short repository ID of the created repository."
  value       = module.repository.repository_id
}

output "name" {
  description = "Fully-qualified name of the created repository."
  value       = module.repository.name
}

output "registry_url" {
  description = "Host/path prefix for image references."
  value       = module.repository.registry_url
}

output "puller_email" {
  description = "Email of the example puller SA granted repo reader."
  value       = google_service_account.puller.email
}
