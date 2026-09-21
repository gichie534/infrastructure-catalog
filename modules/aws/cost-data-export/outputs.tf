output "export_arn" {
  description = "ARN of the data export."
  value       = aws_bcmdataexports_export.this.arn
}

output "export_name" {
  description = "Name of the data export."
  value       = var.export_name
}

output "s3_uri" {
  description = "S3 URI the export is delivered to. The first objects appear within roughly 24 hours of creation, not immediately."
  value       = var.s3_prefix == "" ? "s3://${var.s3_bucket}" : "s3://${var.s3_bucket}/${var.s3_prefix}"
}

output "query_statement" {
  description = "The SQL statement actually sent to Data Exports, after column defaults are resolved. Useful when an export delivers a different schema than you expected."
  value       = local.query_statement
}

output "table_configurations" {
  description = "The table configuration actually applied (granularity, resource inclusion, …), after defaults are resolved."
  value       = local.table_configurations
}

output "required_bucket_policy_json" {
  description = "The bucket policy Data Exports requires. Attach this yourself when `manage_bucket_policy` is false — without it AWS refuses to create the export."
  value       = data.aws_iam_policy_document.delivery.json
}

output "bucket_policy_managed" {
  description = "Whether this module attached the delivery bucket policy."
  value       = var.manage_bucket_policy
}
