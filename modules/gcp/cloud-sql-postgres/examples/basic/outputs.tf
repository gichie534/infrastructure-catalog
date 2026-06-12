output "instance_connection_name" {
  description = "Connection name (project:region:instance) of the created instance."
  value       = module.cloud_sql.instance_connection_name
}

output "private_ip_address" {
  description = "Private IP of the created instance."
  value       = module.cloud_sql.private_ip_address
}

output "database_name" {
  description = "The application database name."
  value       = module.cloud_sql.database_name
}

output "iam_user_names" {
  description = "GSA email to IAM database username mapping."
  value       = module.cloud_sql.iam_user_names
}

output "workload_service_account_email" {
  description = "Email of the workload GSA the pod impersonates."
  value       = module.workload_iam.service_account_email
}
