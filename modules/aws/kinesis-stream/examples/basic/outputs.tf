output "arn" {
  description = "ARN of the stream."
  value       = module.kinesis_stream.arn
}

output "name" {
  description = "Name of the stream."
  value       = module.kinesis_stream.name
}

output "shard_count" {
  description = "Number of shards on the stream."
  value       = module.kinesis_stream.shard_count
}

output "retention_period_hours" {
  description = "Replay window in hours."
  value       = module.kinesis_stream.retention_period_hours
}
