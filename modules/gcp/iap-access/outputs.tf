output "role" {
  description = "The IAM role granted to every member (roles/iap.httpsResourceAccessor)."
  value       = local.role
}

output "members" {
  description = "The set of IAM principals granted access through IAP."
  value       = values(var.members)
}

output "scope" {
  description = "The scope of the grant: \"project\" (all IAP-protected backends in the project) or \"backend-service\" (a single named backend service)."
  value       = var.backend_service == null ? "project" : "backend-service"
}

output "settings_resource_name" {
  description = "The IAP resource name that IAP settings are managed on, or null when cors_allow_http_options is unset (no settings managed)."
  value       = var.cors_allow_http_options == null ? null : local.settings_name
}

output "cors_allow_http_options" {
  description = "Whether HTTP OPTIONS calls skip IAP authorization for this scope, or null when IAP settings are not managed by this module."
  value       = var.cors_allow_http_options
}
