output "id" {
  description = "The RDS instance identifier."
  value       = aws_db_instance.this.id
}

output "arn" {
  description = "The ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "resource_id" {
  description = "The stable RDS-generated resource ID (dbi-...), used for IAM database-auth policy ARNs."
  value       = aws_db_instance.this.resource_id
}

output "address" {
  description = "The hostname of the instance endpoint. Use this as the psql/pg_dump -h host."
  value       = aws_db_instance.this.address
}

output "endpoint" {
  description = "The connection endpoint in host:port form."
  value       = aws_db_instance.this.endpoint
}

output "port" {
  description = "The port the instance listens on."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "The name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "master_username" {
  description = "The master (admin) username."
  value       = aws_db_instance.this.username
}

output "security_group_id" {
  description = "ID of the module-created security group controlling ingress to the instance."
  value       = aws_security_group.this.id
}

output "parameter_group_name" {
  description = "Name of the module-created parameter group, or null when no parameters were supplied."
  value       = local.create_parameter_group ? aws_db_parameter_group.this[0].name : null
}
