output "bucket" {
  description = "Name (id) of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "ARN of the S3 bucket. Use it to scope IAM/bucket policy resources (e.g. arn and arn/*)."
  value       = aws_s3_bucket.this.arn
}
