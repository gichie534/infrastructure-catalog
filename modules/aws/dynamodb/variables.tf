variable "name" {
  description = "Name of the DynamoDB table."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{3,255}$", var.name))
    error_message = "name must be 3-255 chars of [a-zA-Z0-9_.-]."
  }
}

variable "billing_mode" {
  description = "Capacity mode: PAY_PER_REQUEST (on-demand, default — costs nothing when idle) or PROVISIONED (fixed read/write capacity)."
  type        = string
  nullable    = false
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be one of: PAY_PER_REQUEST, PROVISIONED."
  }
}

variable "hash_key" {
  description = "Name of the partition (hash) key attribute. Required."
  type        = string
  nullable    = false
}

variable "hash_key_type" {
  description = "Attribute type of the hash key: S (string), N (number), or B (binary)."
  type        = string
  nullable    = false
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "hash_key_type must be one of: S, N, B."
  }
}

variable "range_key" {
  description = "Name of the sort (range) key attribute. Null (default) creates a table keyed only by the hash key."
  type        = string
  nullable    = true
  default     = null
}

variable "range_key_type" {
  description = "Attribute type of the range key when range_key is set: S (string), N (number), or B (binary)."
  type        = string
  nullable    = false
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.range_key_type)
    error_message = "range_key_type must be one of: S, N, B."
  }
}

variable "read_capacity" {
  description = "Provisioned read capacity units. Required (and only used) when billing_mode is PROVISIONED; leave null for on-demand."
  type        = number
  nullable    = true
  default     = null

  validation {
    condition     = var.billing_mode != "PROVISIONED" || (var.read_capacity != null && var.read_capacity > 0)
    error_message = "read_capacity must be set to a positive number when billing_mode is PROVISIONED."
  }
}

variable "write_capacity" {
  description = "Provisioned write capacity units. Required (and only used) when billing_mode is PROVISIONED; leave null for on-demand."
  type        = number
  nullable    = true
  default     = null

  validation {
    condition     = var.billing_mode != "PROVISIONED" || (var.write_capacity != null && var.write_capacity > 0)
    error_message = "write_capacity must be set to a positive number when billing_mode is PROVISIONED."
  }
}

variable "point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery (continuous backups). Default false to keep lab tables cheap; enable for anything you'd need to restore."
  type        = bool
  nullable    = false
  default     = false
}

variable "deletion_protection_enabled" {
  description = "Block table deletion until disabled. Default false so a lab tears down cleanly; enable for tables you care about."
  type        = bool
  nullable    = false
  default     = false
}

variable "tags" {
  description = "Tags applied to the table (the one taggable resource this module creates)."
  type        = map(string)
  nullable    = false
  default     = {}
}
