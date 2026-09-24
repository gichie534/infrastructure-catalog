output "arn" {
  description = "ARN of the stream. Use this in IAM policy resource statements granting PutRecord/GetRecords, and as the source ARN for a Firehose delivery stream or Lambda event source mapping."
  value       = aws_kinesis_stream.this.arn
}

output "name" {
  description = "Name of the stream. This is what producers and consumers pass to the Kinesis API as StreamName."
  value       = aws_kinesis_stream.this.name
}

output "id" {
  description = "ID of the stream (equal to its name)."
  value       = aws_kinesis_stream.this.id
}

output "stream_mode" {
  description = "Capacity mode the stream was created with (PROVISIONED or ON_DEMAND)."
  value       = var.stream_mode
}

output "shard_count" {
  description = "Number of shards for a PROVISIONED stream, or null for ON_DEMAND. A consumer reading shards directly uses this to know how many shard iterators to open."
  value       = var.stream_mode == "PROVISIONED" ? var.shard_count : null
}

output "retention_period_hours" {
  description = "Replay window in hours — how far back a consumer can re-read records."
  value       = aws_kinesis_stream.this.retention_period
}
