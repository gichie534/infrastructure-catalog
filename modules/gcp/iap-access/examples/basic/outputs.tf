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

output "settings_resource_name" {
  description = "The IAP resource name that settings are managed on (null when unmanaged)."
  value       = module.iap_access.settings_resource_name
}

output "cors_allow_http_options" {
  description = "Whether HTTP OPTIONS calls skip IAP authorization (null when settings are unmanaged)."
  value       = module.iap_access.cors_allow_http_options
}
