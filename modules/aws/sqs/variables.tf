variable "name" {
  description = <<-EOT
    Name of the SQS queue. For a FIFO queue (fifo_queue = true) the name must end in `.fifo`;
    the module validates that pairing so a misconfiguration fails fast at plan time.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+(\\.fifo)?$", var.name)) && length(var.name) <= 80
    error_message = "name must be <=80 chars of alphanumerics, hyphens or underscores (optionally ending in .fifo for FIFO queues)."
  }
}

variable "fifo_queue" {
  description = "Whether to create a FIFO queue. When true, name must end in `.fifo`. Default false (a standard queue), which is sufficient for most workloads and supports higher throughput."
  type        = bool
  nullable    = false
  default     = false

  validation {
    condition     = var.fifo_queue == false || endswith(var.name, ".fifo")
    error_message = "a FIFO queue (fifo_queue = true) requires the queue name to end in .fifo."
  }
}

variable "visibility_timeout_seconds" {
  description = "Seconds a message is hidden from other consumers after one consumer receives it, before it becomes visible again (0-43200). Set this above your consumer's worst-case processing time."
  type        = number
  nullable    = false
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 0 and 43200 (12 hours)."
  }
}

variable "message_retention_seconds" {
  description = "Seconds SQS retains a message that is not deleted (60-1209600). Default 4 days (345600)."
  type        = number
  nullable    = false
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds must be between 60 and 1209600 (14 days)."
  }
}

variable "receive_wait_time_seconds" {
  description = "Seconds a ReceiveMessage call waits for a message to arrive before returning empty (0-20). Greater than 0 enables long polling, which cuts empty receives and cost. Default 0 (short polling)."
  type        = number
  nullable    = false
  default     = 0

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "receive_wait_time_seconds must be between 0 and 20."
  }
}

variable "sqs_managed_sse_enabled" {
  description = "Enable SQS-managed server-side encryption (SSE-SQS) for messages at rest. Default true — encryption on by default; set false only if you have a specific reason."
  type        = bool
  nullable    = false
  default     = true
}

variable "tags" {
  description = "Tags applied to the queue (the one taggable resource this module creates)."
  type        = map(string)
  nullable    = false
  default     = {}
}
