variable "project_id" {
  description = "Project that owns the notification channels. A budget can use channels from any project, but they are usually kept with the rest of the FinOps tooling."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "email_addresses" {
  description = "Email addresses to create a channel for, one channel each."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.email_addresses) > 0
    error_message = "email_addresses must contain at least one address."
  }

  validation {
    condition     = alltrue([for e in var.email_addresses : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "each email_addresses entry must look like an email address."
  }

  validation {
    condition     = length(distinct(var.email_addresses)) == length(var.email_addresses)
    error_message = "email_addresses must not contain duplicates."
  }
}

variable "display_name_prefix" {
  description = "Prefix for each channel's display name; the address is appended, e.g. `FinOps <you@example.com>`."
  type        = string
  nullable    = false
  default     = "Email"
}

variable "description" {
  description = "Description applied to every channel."
  type        = string
  nullable    = true
  default     = null
}

variable "enabled" {
  description = "Whether the channels deliver. Disabling keeps them (and every reference to them) but silences delivery."
  type        = bool
  nullable    = false
  default     = true
}

variable "labels" {
  description = "User labels applied to every channel."
  type        = map(string)
  nullable    = false
  default     = {}
}
