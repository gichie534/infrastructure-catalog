output "service_account_email" {
  description = "Email of the workload Google service account. Annotate the Kubernetes service account with this (iam.gke.io/gcp-service-account) to complete Workload Identity."
  value       = google_service_account.this.email
}

output "service_account_id" {
  description = "Fully-qualified ID of the workload Google service account (projects/<project>/serviceAccounts/<email>)."
  value       = google_service_account.this.id
}
