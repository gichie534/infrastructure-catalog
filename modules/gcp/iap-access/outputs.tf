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
