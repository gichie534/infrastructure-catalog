variable "name" {
  description = "Name of the Kinesis data stream. Unique per account and region."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{1,128}$", var.name))
    error_message = "name must be 1-128 chars of alphanumerics, underscores, hyphens or dots."
  }
}

variable "stream_mode" {
  description = <<-EOT
    Capacity mode. `PROVISIONED` (default) means you choose `shard_count` and pay per shard-hour —
    cheapest and predictable when you know your throughput. `ON_DEMAND` lets AWS scale shards
    automatically at a higher per-GB rate, and ignores `shard_count`.
  EOT
  type        = string
  nullable    = false
  default     = "PROVISIONED"

  validation {
    condition     = contains(["PROVISIONED", "ON_DEMAND"], var.stream_mode)
    error_message = "stream_mode must be PROVISIONED or ON_DEMAND."
  }
}

variable "shard_count" {
  description = <<-EOT
    Number of shards, used only when `stream_mode` is `PROVISIONED`. Each shard takes 1 MiB/s or
    1,000 records/s of writes and 2 MiB/s of reads. Must be null when `stream_mode` is `ON_DEMAND`.
  EOT
  type        = number
  nullable    = true
  default     = 1

  validation {
    condition     = var.shard_count == null || var.shard_count >= 1
    error_message = "shard_count must be at least 1 when set."
  }

  validation {
    condition     = var.stream_mode == "ON_DEMAND" ? var.shard_count == null : var.shard_count != null
    error_message = "set shard_count for PROVISIONED streams and leave it null for ON_DEMAND streams."
  }
}

variable "retention_period_hours" {
  description = <<-EOT
    Hours a record stays readable in the stream (24-8760). This is the replay window: a consumer can
    re-read anything inside it. Default 24 (the free tier); beyond 24 hours incurs extended-retention
    charges.
  EOT
  type        = number
  nullable    = false
  default     = 24

  validation {
    condition     = var.retention_period_hours >= 24 && var.retention_period_hours <= 8760
    error_message = "retention_period_hours must be between 24 and 8760 (365 days)."
  }
}

variable "encryption_type" {
  description = "Server-side encryption for records at rest. `KMS` (default) encrypts with the key in `kms_key_id`; `NONE` disables encryption and should only be used with a specific reason."
  type        = string
  nullable    = false
  default     = "KMS"

  validation {
    condition     = contains(["KMS", "NONE"], var.encryption_type)
    error_message = "encryption_type must be KMS or NONE."
  }
}

variable "kms_key_id" {
  description = "KMS key used when `encryption_type` is `KMS`. Accepts an alias, key ID, or ARN. Defaults to the AWS-managed Kinesis key, which costs nothing extra."
  type        = string
  nullable    = false
  default     = "alias/aws/kinesis"
}

variable "shard_level_metrics" {
  description = <<-EOT
    Per-shard CloudWatch metrics to enable. Empty by default because each one bills as a custom
    metric. `WriteProvisionedThroughputExceeded` surfaces producer throttling and
    `IteratorAgeMilliseconds` surfaces consumer lag — the two worth enabling first.
  EOT
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition = alltrue([
      for m in var.shard_level_metrics : contains([
        "IncomingBytes", "IncomingRecords", "OutgoingBytes", "OutgoingRecords",
        "WriteProvisionedThroughputExceeded", "ReadProvisionedThroughputExceeded",
        "IteratorAgeMilliseconds", "ALL",
      ], m)
    ])
    error_message = "shard_level_metrics entries must be valid Kinesis shard-level metric names (or ALL)."
  }
}

variable "enforce_consumer_deletion" {
  description = "Allow the stream to be destroyed even when registered enhanced fan-out consumers still exist. Leave false for anything you care about; set true in throwaway lab environments so destroy runs clean."
  type        = bool
  nullable    = false
  default     = false
}

variable "tags" {
  description = "Tags applied to the stream (the one taggable resource this module creates)."
  type        = map(string)
  nullable    = false
  default     = {}
}
