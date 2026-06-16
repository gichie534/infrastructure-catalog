output "provider_arn" {
  description = "ARN of the created GitHub OIDC provider."
  value       = module.oidc.provider_arn
}

output "role_arn" {
  description = "ARN of the role CI assumes (set as the workflow's role-to-assume / AWS_ROLE_ARN)."
  value       = module.oidc.role_arns["deployer"]
}

output "role_name" {
  description = "Name of the deployer role."
  value       = module.oidc.role_names["deployer"]
}
