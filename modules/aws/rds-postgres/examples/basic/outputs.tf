output "address" {
  description = "Hostname of the instance endpoint."
  value       = module.rds.address
}

output "endpoint" {
  description = "Connection endpoint (host:port)."
  value       = module.rds.endpoint
}

output "db_name" {
  description = "Initial database name."
  value       = module.rds.db_name
}

output "security_group_id" {
  description = "Security group controlling ingress to the instance."
  value       = module.rds.security_group_id
}
