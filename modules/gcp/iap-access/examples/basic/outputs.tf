output "role" {
  description = "The IAM role granted through IAP."
  value       = module.iap_access.role
}

output "members" {
  description = "The principals granted access through IAP."
  value       = module.iap_access.members
}

output "scope" {
  description = "The scope of the grant."
  value       = module.iap_access.scope
}

output "service_account_email" {
  description = "Email of the example service-account principal."
  value       = google_service_account.example.email
}
