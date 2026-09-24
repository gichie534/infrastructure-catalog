output "arn" {
  description = "ARN of the delivery stream."
  value       = module.firehose.arn
}

output "name" {
  description = "Name of the delivery stream."
  value       = module.firehose.name
}

output "delivery_role_arn" {
  description = "ARN of the IAM role Firehose assumes."
  value       = module.firehose.delivery_role_arn
}

output "prefix" {
  description = "Key prefix delivered objects are written under."
  value       = module.firehose.prefix
}

output "buffering_interval_seconds" {
  description = "Configured buffer interval, the floor on delivery latency."
  value       = module.firehose.buffering_interval_seconds
}

output "log_group_name" {
  description = "Log group Firehose reports delivery failures to."
  value       = module.firehose.log_group_name
}

output "destination_bucket" {
  description = "Name of the destination bucket created by the fixture."
  value       = aws_s3_bucket.destination.bucket
}

output "source_stream_arn" {
  description = "ARN of the source Kinesis stream created by the fixture."
  value       = aws_kinesis_stream.source.arn
}
