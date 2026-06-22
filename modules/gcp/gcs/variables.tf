variable "project_id" {
  description = "The ID of the project in which to create the bucket."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "name" {
  description = "Globally-unique name of the bucket."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_.-]{1,61}[a-z0-9]$", var.name))
    error_message = "name must be 3-63 characters of lowercase letters, numbers, hyphens, underscores, or dots, and start and end with a letter or number."
  }
}

variable "location" {
  description = "Location of the bucket (e.g. US, EU, or a region like us-central1)."
  type        = string
  nullable    = false
}

variable "force_destroy" {
  description = "When true, deleting the bucket also deletes its objects. Keep false for real environments; examples/tests set it true."
  type        = bool
  nullable    = false
  default     = false
}

variable "labels" {
  description = "Labels applied to the bucket."
  type        = map(string)
  nullable    = false
  default     = {}
}
