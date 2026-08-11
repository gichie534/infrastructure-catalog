variable "project_id" {
  description = "The ID of the project in which to reserve the address."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "name" {
  description = "Name of the reserved global address. Referenced by an Ingress's kubernetes.io/ingress.global-static-ip-name annotation."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.name))
    error_message = "name must be 1-63 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "description" {
  description = "Human-readable description of the address's purpose."
  type        = string
  nullable    = false
  default     = ""
}
