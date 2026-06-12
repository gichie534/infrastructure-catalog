output "instance_name" {
  description = "The name of the Cloud SQL instance (used as the connection target and by the Auth Proxy / connectors)."
  value       = google_sql_database_instance.this.name
}

output "instance_connection_name" {
  description = "Connection name in the form project:region:instance, used by Cloud SQL connectors and the Auth Proxy."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "The private IP address of the instance on the VPC. Pods connect to this address."
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  description = "The name of the application database."
  value       = google_sql_database.this.name
}

output "iam_user_names" {
  description = "Map of GSA email to the IAM database username registered on the instance. Use the username as the Postgres login role."
  value       = local.iam_user_names
}
