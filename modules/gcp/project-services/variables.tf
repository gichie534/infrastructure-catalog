variable "project_id" {
  description = "The ID of the EXISTING project to enable APIs on. This module never creates or manages the project resource itself."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "activate_apis" {
  description = "Set of Google API service names to enable on the project, e.g. [\"iap.googleapis.com\"]."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.activate_apis) > 0
    error_message = "activate_apis must contain at least one service name."
  }

  validation {
    condition     = alltrue([for s in var.activate_apis : can(regex("^[a-z0-9-]+\\.googleapis\\.com$", s))])
    error_message = "each activate_apis entry must be a Google API service name ending in .googleapis.com."
  }
}

variable "disable_dependent_services" {
  description = "Whether to also disable services that depend on a service being disabled (only takes effect on disable, which this module never does since disable_on_destroy is hardcoded false; kept as a passthrough for forward compatibility)."
  type        = bool
  nullable    = false
  default     = true
}
