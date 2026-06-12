output "secret_id" {
  description = "Fully-qualified resource ID of the secret."
  value       = module.secret.secret_id
}

output "secret_name" {
  description = "Short secret_id of the secret."
  value       = module.secret.secret_name
}
