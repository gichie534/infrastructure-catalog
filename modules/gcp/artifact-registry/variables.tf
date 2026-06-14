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

variable "reader_members" {
  description = <<-EOT
    Existing IAM members to grant repo-scoped roles/artifactregistry.reader, as a map of arbitrary
    stable label => IAM member string (e.g. "serviceAccount:<num>-compute@developer.gserviceaccount.com"
    for a GKE node SA that pulls images). Map keys must be known at plan time. Use this for identities
    that already exist; for a GSA created by another module, wire that module against the `name` output
    instead.
  EOT
  type        = map(string)
  nullable    = false
  default     = {}

  validation {
    condition     = alltrue([for m in values(var.reader_members) : can(regex("^(user|serviceAccount|group|domain|principal|principalSet):", m))])
    error_message = "each reader_members value must be a valid IAM member (user:, serviceAccount:, group:, domain:, principal:, or principalSet:)."
  }
}

variable "writer_members" {
  description = <<-EOT
    Existing IAM members to grant repo-scoped roles/artifactregistry.writer, as a map of arbitrary
    stable label => IAM member string (e.g. a CI identity that pushes images). Map keys must be known
    at plan time. Use this for identities that already exist.
  EOT
  type        = map(string)
  nullable    = false
  default     = {}

  validation {
    condition     = alltrue([for m in values(var.writer_members) : can(regex("^(user|serviceAccount|group|domain|principal|principalSet):", m))])
    error_message = "each writer_members value must be a valid IAM member (user:, serviceAccount:, group:, domain:, principal:, or principalSet:)."
  }
}
