variable "name" {
  description = "Name of the compute instance"
  type        = string
  nullable = false
}

variable "project_id" {
  description = "The ID of the project in which to create the instance"
  type        = string
  nullable = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }

  validation {
    condition     = !can(regex("google|ssl|undefined|null", var.project_id))
    error_message = "project_id cannot contain restricted strings such as 'google', 'ssl', 'undefined', or 'null'."
  }
}

variable "machine_type" {
  description = "Machine type for the instance"
  type        = string
  nullable = false
  default     = "e2-micro"
}

variable "zone" {
  description = "Zone where the instance will be created"
  type        = string
  nullable = false
  default     = "us-central1-a"
}

variable "image" {
  description = "Boot disk image"
  type        = string
  nullable = false
  default     = "debian-cloud/debian-12"
}

variable "network" {
  description = "VPC network for the instance"
  type        = string
  nullable = false
  default     = "default"
}
