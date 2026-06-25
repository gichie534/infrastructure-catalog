output "email" {
  description = "Email of the created service account."
  value       = module.service_account.email
}

output "member" {
  description = "IAM member string for the created service account."
  value       = module.service_account.member
}
