output "secret_id" {
  description = "The fully-qualified resource ID of the secret (projects/<project>/secrets/<name>). Wire this into the workload-iam module to grant accessor IAM."
  value       = google_secret_manager_secret.this.id
}

output "secret_name" {
  description = "The short secret_id, as referenced by application code at access time."
  value       = google_secret_manager_secret.this.secret_id
}
