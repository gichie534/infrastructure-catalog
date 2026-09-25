output "namespace_name" {
  description = "Name of the namespace."
  value       = module.redshift.namespace_name
}

output "workgroup_name" {
  description = "Name of the workgroup."
  value       = module.redshift.workgroup_name
}

output "workgroup_arn" {
  description = "ARN of the workgroup."
  value       = module.redshift.workgroup_arn
}

output "database_name" {
  description = "Name of the first database in the namespace."
  value       = module.redshift.database_name
}

output "copy_role_arn" {
  description = "ARN of the IAM role Redshift assumes to read S3."
  value       = module.redshift.copy_role_arn
}

output "admin_username" {
  description = "Username of the database administrator."
  value       = module.redshift.admin_username
  sensitive   = true
}

output "admin_password_secret_arn" {
  description = "ARN of the Redshift-managed admin credentials secret."
  value       = module.redshift.admin_password_secret_arn
}

output "endpoint_address" {
  description = "DNS address of the workgroup endpoint."
  value       = module.redshift.endpoint_address
}

output "source_bucket" {
  description = "Name of the source bucket created by the fixture."
  value       = aws_s3_bucket.source.bucket
}
