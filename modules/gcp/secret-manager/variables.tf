variable "project_id" {
  description = "The ID of the project in which to create the secret."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "secret_id" {
  description = "The secret ID (name) to create. The module creates one empty secret container; the value (version) is added out-of-band by apps/CI, not by this module."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,255}$", var.secret_id))
    error_message = "secret_id must be 1-255 characters of letters, numbers, underscores, or hyphens."
  }
}

variable "labels" {
  description = "Labels applied to the secret."
  type        = map(string)
  nullable    = false
  default     = {}
}
