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

output "public_ip_address" {
  description = "The public IPv4 address of the instance, or null when enable_public_ip is false."
  value       = var.enable_public_ip ? google_sql_database_instance.this.public_ip_address : null
}

output "iam_user_names" {
  description = "Map of GSA email to the IAM database username registered on the instance. Use the username as the Postgres login role."
  value       = local.iam_user_names
}

output "availability_type" {
  description = "The configured availability shape of the primary (REGIONAL = synchronous standby in a second zone with automatic failover)."
  value       = google_sql_database_instance.this.settings[0].availability_type
}

output "replica_instance_names" {
  description = "Map of read_replicas key to the created replica instance name."
  value       = { for k, r in google_sql_database_instance.replica : k => r.name }
}

output "replica_connection_names" {
  description = "Map of read_replicas key to the replica's connection name (project:region:instance), for connectors and the Auth Proxy."
  value       = { for k, r in google_sql_database_instance.replica : k => r.connection_name }
}

output "replica_private_ip_addresses" {
  description = "Map of read_replicas key to the replica's private IP address on the VPC — the read endpoint, and the write endpoint after a promotion."
  value       = { for k, r in google_sql_database_instance.replica : k => r.private_ip_address }
}
