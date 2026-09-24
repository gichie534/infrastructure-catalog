output "arn" {
  description = "ARN of the delivery stream."
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}

output "name" {
  description = "Name of the delivery stream. Direct PUT producers pass this to the Firehose API as DeliveryStreamName."
  value       = aws_kinesis_firehose_delivery_stream.this.name
}

output "delivery_role_arn" {
  description = "ARN of the IAM role Firehose assumes. Exported so a consumer can grant it additional access (e.g. a KMS key on the destination bucket)."
  value       = aws_iam_role.delivery.arn
}

output "delivery_role_name" {
  description = "Name of the IAM role Firehose assumes."
  value       = aws_iam_role.delivery.name
}

output "prefix" {
  description = "Key prefix delivered objects are written under, or null when Firehose's default `YYYY/MM/DD/HH/` layout is used. A downstream loader uses this to scope which objects to read."
  value       = var.prefix
}

output "buffering_interval_seconds" {
  description = "Configured buffer interval. This is the floor on delivery latency, so a consumer measuring end-to-end freshness needs it."
  value       = var.buffering_interval_seconds
}

output "log_group_name" {
  description = "Name of the CloudWatch log group Firehose reports delivery failures to, or null when logging is disabled."
  value       = var.enable_cloudwatch_logging ? aws_cloudwatch_log_group.this[0].name : null
}
