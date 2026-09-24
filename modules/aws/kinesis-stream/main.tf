# A single Kinesis Data Stream — the ordered, replayable buffer producers write records into and one
# or more consumers read from independently, each at its own position.
#
# This module owns only the stream. It deliberately does NOT create producer/consumer IAM policies,
# nor any downstream delivery (Firehose, Lambda event source): those are the consumer's composition
# concern, wired via the stream ARN this module outputs. Keeping the module single-purpose keeps it
# reusable across labs.
#
# Capacity is either PROVISIONED (you pick shard_count and pay per shard-hour) or ON_DEMAND (AWS
# scales shards for you at a higher per-GB rate). Server-side encryption is on by default using the
# AWS-managed `alias/aws/kinesis` key.
resource "aws_kinesis_stream" "this" {
  name = var.name

  # shard_count is meaningful only in PROVISIONED mode; ON_DEMAND rejects it. The variable
  # validation enforces the pairing, and this expression keeps the attribute unset for ON_DEMAND.
  shard_count = var.stream_mode == "PROVISIONED" ? var.shard_count : null

  retention_period = var.retention_period_hours

  stream_mode_details {
    stream_mode = var.stream_mode
  }

  encryption_type = var.encryption_type
  kms_key_id      = var.encryption_type == "KMS" ? var.kms_key_id : null

  # Per-shard CloudWatch metrics. Empty by default because these bill as custom metrics; enable the
  # ones you need to observe write throttling (WriteProvisionedThroughputExceeded) or consumer lag
  # (IteratorAgeMilliseconds).
  shard_level_metrics = var.shard_level_metrics

  # Allow `terraform destroy` to remove the stream even when registered enhanced fan-out consumers
  # still exist. Useful in throwaway lab environments.
  enforce_consumer_deletion = var.enforce_consumer_deletion

  tags = var.tags
}
