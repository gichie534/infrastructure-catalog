output "bucket" {
  description = "Name (id) of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "ARN of the S3 bucket. Use it to scope IAM/bucket policy resources (e.g. arn and arn/*)."
  value       = aws_s3_bucket.this.arn
}

output "lifecycle_rule_ids" {
  description = "IDs of the lifecycle rules managed on this bucket, in declaration order. Empty when no lifecycle configuration is managed."
  value       = [for r in var.lifecycle_rules : r.id]
}
