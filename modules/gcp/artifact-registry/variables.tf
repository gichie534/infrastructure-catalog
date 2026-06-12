variable "project_id" {
  description = "The ID of the project in which to create the repository."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "repository_id" {
  description = "The ID (name) of the repository."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.repository_id))
    error_message = "repository_id must be 2-63 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "location" {
  description = "Location of the repository (e.g. us-central1)."
  type        = string
  nullable    = false
}

variable "format" {
  description = "Artifact format of the repository (e.g. DOCKER, MAVEN, NPM, PYTHON). Immutable tags are enforced for DOCKER repositories."
  type        = string
  nullable    = false
  default     = "DOCKER"

  validation {
    condition     = can(regex("^[A-Z]+$", var.format))
    error_message = "format must be an uppercase Artifact Registry format like DOCKER, MAVEN, NPM, or PYTHON."
  }
}

variable "description" {
  description = "Human-readable description of the repository."
  type        = string
  nullable    = false
  default     = ""
}

variable "labels" {
  description = "Labels applied to the repository."
  type        = map(string)
  nullable    = false
  default     = {}
}
