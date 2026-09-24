output "namespace_name" {
  description = "Name of the namespace."
  value       = aws_redshiftserverless_namespace.this.namespace_name
}

output "namespace_arn" {
  description = "ARN of the namespace."
  value       = aws_redshiftserverless_namespace.this.arn
}

output "namespace_id" {
  description = "ID of the namespace."
  value       = aws_redshiftserverless_namespace.this.namespace_id
}

output "workgroup_name" {
  description = "Name of the workgroup. This is what a Redshift Data API call passes as `WorkgroupName`."
  value       = aws_redshiftserverless_workgroup.this.workgroup_name
}

output "workgroup_arn" {
  description = "ARN of the workgroup. Use this in IAM policy resource statements granting Data API access."
  value       = aws_redshiftserverless_workgroup.this.arn
}

output "workgroup_id" {
  description = "ID of the workgroup."
  value       = aws_redshiftserverless_workgroup.this.workgroup_id
}

output "database_name" {
  description = "Name of the first database in the namespace. A Data API call passes this as `Database`."
  value       = aws_redshiftserverless_namespace.this.db_name
}

output "endpoint_address" {
  description = "DNS address of the workgroup's VPC endpoint. Only needed for a direct SQL connection; Data API callers do not use it."
  value       = try(aws_redshiftserverless_workgroup.this.endpoint[0].address, null)
}

output "endpoint_port" {
  description = "Port the workgroup listens on."
  value       = try(aws_redshiftserverless_workgroup.this.endpoint[0].port, null)
}

output "copy_role_arn" {
  description = "ARN of the IAM role Redshift assumes to read S3. Pass this to `COPY ... IAM_ROLE '<arn>'`, or use `IAM_ROLE default` since the module sets it as the namespace default."
  value       = aws_iam_role.copy.arn
}

output "copy_role_name" {
  description = "Name of the IAM role Redshift assumes to read S3."
  value       = aws_iam_role.copy.name
}

output "admin_username" {
  description = "Username of the database administrator."
  value       = aws_redshiftserverless_namespace.this.admin_username
}

output "admin_password_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the admin credentials, when Redshift manages them. Null if a password was supplied explicitly."
  value       = aws_redshiftserverless_namespace.this.admin_password_secret_arn
}
