variable "name" {
  description = "The display name of the project."
  type        = string
}

variable "project_id" {
  description = "The unique project ID. Must be globally unique across GCP."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }

  validation {
    condition     = !can(regex("google|ssl|undefined|null", var.project_id))
    error_message = "project_id cannot contain restricted strings such as 'google', 'ssl', 'undefined', or 'null'."
  }
}

variable "folder_id" {
  description = "The parent folder ID (e.g. folders/123456)."
  type        = string
}

variable "shared_vpc_host_project_id" {
  description = "The ID of the Shared VPC host project to attach this project to as a service project. Wire this from a gcp/host-project's host_project_id output."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.shared_vpc_host_project_id))
    error_message = "shared_vpc_host_project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "billing_account" {
  description = "The billing account ID to associate with this project."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels to apply to the project."
  type        = map(string)
  default     = {}
}

variable "activate_apis" {
  description = "List of Google APIs to activate on the project. Must include compute.googleapis.com — attaching to a Shared VPC host requires the Compute API."
  type        = list(string)
  default     = ["compute.googleapis.com"]

  validation {
    condition     = contains(var.activate_apis, "compute.googleapis.com")
    error_message = "activate_apis must include compute.googleapis.com for a Shared VPC service project."
  }
}

variable "deletion_policy" {
  description = "The deletion policy for the project. One of PREVENT, ABANDON, or DELETE."
  type        = string
  default     = "PREVENT"

  validation {
    condition     = contains(["PREVENT", "ABANDON", "DELETE"], var.deletion_policy)
    error_message = "deletion_policy must be one of: PREVENT, ABANDON, DELETE."
  }
}
