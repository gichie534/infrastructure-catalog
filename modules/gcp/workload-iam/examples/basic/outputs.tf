output "service_account_email" {
  description = "Email of the workload GSA the pod impersonates."
  value       = module.workload_identity.service_account_email
}

output "secret_ids" {
  description = "Resource IDs of the secrets the workload was granted access to."
  value       = [module.db_password.secret_id, module.api_key.secret_id]
}

output "bucket_name" {
  description = "Name of the bucket the workload was granted access to."
  value       = module.uploads.name
}

output "repository_name" {
  description = "Name of the Artifact Registry repository the workload was granted access to."
  value       = module.images.name
}
