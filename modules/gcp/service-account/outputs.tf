output "email" {
  description = "Email of the service account (<account_id>@<project_id>.iam.gserviceaccount.com)."
  value       = google_service_account.this.email
}

output "id" {
  description = "Fully-qualified ID of the service account (projects/<project>/serviceAccounts/<email>)."
  value       = google_service_account.this.id
}

output "name" {
  description = "The resource name of the service account (projects/<project>/serviceAccounts/<unique_id>)."
  value       = google_service_account.this.name
}

output "member" {
  description = "The IAM member string for the service account (serviceAccount:<email>), ready to pass to other IAM grants."
  value       = "serviceAccount:${google_service_account.this.email}"
}

output "unique_id" {
  description = "The numeric unique ID of the service account."
  value       = google_service_account.this.unique_id
}
