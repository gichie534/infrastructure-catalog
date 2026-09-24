variable "name" {
  description = "Name of the Firehose delivery stream. Unique per account and region; also used to name the delivery IAM role and log group."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{1,64}$", var.name))
    error_message = "name must be 1-64 chars of alphanumerics, underscores, hyphens or dots."
  }
}

variable "destination_bucket_arn" {
  description = "ARN of the S3 bucket buffered records are delivered to. The bucket is NOT created by this module — pass one the consumer owns (e.g. the `arn` output of `aws/s3-bucket`). The delivery role is granted write on it."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.destination_bucket_arn))
    error_message = "destination_bucket_arn must be an S3 bucket ARN (e.g. arn:aws:s3:::my-bucket), not an object ARN."
  }
}

variable "source_kinesis_stream_arn" {
  description = <<-EOT
    ARN of a Kinesis data stream to read from. When set, Firehose polls that stream and the delivery
    role is granted read on it. Leave null (the default) for a Direct PUT delivery stream that
    producers write to with the Firehose PutRecord API instead.
  EOT
  type        = string
  nullable    = true
  default     = null
}

variable "prefix" {
  description = <<-EOT
    Key prefix for delivered objects. Null (the default) uses Firehose's own `YYYY/MM/DD/HH/` layout.
    Set something like `stream/` to keep delivered data separate from other writers in the same
    bucket — useful when a downstream COPY needs to target only these objects. Supports Firehose
    prefix expressions such as `stream/!{timestamp:yyyy/MM/dd}/`.
  EOT
  type        = string
  nullable    = true
  default     = null
}

variable "error_output_prefix" {
  description = "Key prefix for records Firehose failed to deliver. Null (the default) writes them alongside successful output. Setting a distinct prefix such as `errors/` keeps failures from being picked up by a downstream load."
  type        = string
  nullable    = true
  default     = null
}

variable "buffering_size_mb" {
  description = <<-EOT
    Buffer records until this many MB have accumulated, then flush to S3 (1-128). Firehose flushes on
    whichever of size/interval is hit first.
  EOT
  type        = number
  nullable    = false
  default     = 5

  validation {
    condition     = var.buffering_size_mb >= 1 && var.buffering_size_mb <= 128
    error_message = "buffering_size_mb must be between 1 and 128."
  }
}

variable "buffering_interval_seconds" {
  description = <<-EOT
    Buffer records for at most this many seconds, then flush to S3 (0-900). This is the floor on
    end-to-end latency for anything reading the delivered objects, so it is the dominant term in how
    fresh streamed data can be. Default 300; 60 is the lowest practical value for a low-latency
    pipeline.
  EOT
  type        = number
  nullable    = false
  default     = 300

  validation {
    condition     = var.buffering_interval_seconds >= 0 && var.buffering_interval_seconds <= 900
    error_message = "buffering_interval_seconds must be between 0 and 900."
  }
}

variable "compression_format" {
  description = "Compression applied to delivered objects. `UNCOMPRESSED` (default) keeps them directly readable, which matters when a downstream loader or human inspects them. `GZIP` cuts storage and transfer cost."
  type        = string
  nullable    = false
  default     = "UNCOMPRESSED"

  validation {
    condition     = contains(["UNCOMPRESSED", "GZIP", "ZIP", "Snappy", "HADOOP_SNAPPY"], var.compression_format)
    error_message = "compression_format must be one of UNCOMPRESSED, GZIP, ZIP, Snappy, HADOOP_SNAPPY."
  }
}

variable "enable_cloudwatch_logging" {
  description = "Create a log group and have Firehose report delivery failures to it. Default true — without it a delivery stream that cannot write to S3 fails silently."
  type        = bool
  nullable    = false
  default     = true
}

variable "log_retention_in_days" {
  description = "Retention for the delivery log group. Only used when `enable_cloudwatch_logging` is true."
  type        = number
  nullable    = false
  default     = 7

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_in_days
    )
    error_message = "log_retention_in_days must be a retention value CloudWatch Logs accepts (0 for never expire, else 1, 3, 5, 7, 14, 30, 60, 90, ...)."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module (delivery stream, IAM role, log group)."
  type        = map(string)
  nullable    = false
  default     = {}
}
