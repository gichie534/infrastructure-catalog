output "pool_name" {
  description = "Full resource name of the Workload Identity Pool."
  value       = module.wif.pool_name
}

output "provider_name" {
  description = "Full resource name of the GitHub OIDC provider. CI passes this as its workload_identity_provider."
  value       = module.wif.provider_names["github"]
}

output "principal_set_member" {
  description = "The principalSet:// IAM member that was granted the project role directly."
  value       = module.wif.principal_set_members["github_repo"]
}
