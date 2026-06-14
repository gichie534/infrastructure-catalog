output "pool_name" {
  description = "Full resource name of the Workload Identity Pool."
  value       = module.wif.pool_name
}

output "provider_name" {
  description = "Full resource name of the GitHub OIDC provider. CI passes this as its workload_identity_provider."
  value       = module.wif.provider_names["github"]
}

output "service_account_email" {
  description = "Email of the CI service account the federated identity impersonates."
  value       = google_service_account.ci.email
}
