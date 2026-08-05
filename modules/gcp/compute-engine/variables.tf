variable "name" {
  description = "Name of the compute instance"
  type        = string
  nullable    = false
}

variable "project_id" {
  description = "The ID of the project in which to create the instance"
  type        = string
  nullable    = false

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
  nullable    = false
  default     = "e2-micro"
}

variable "zone" {
  description = "Zone where the instance will be created"
  type        = string
  nullable    = false
  default     = "us-central1-a"
}

variable "image" {
  description = "Boot disk image"
  type        = string
  nullable    = false
  default     = "debian-cloud/debian-12"
}

variable "network" {
  description = "VPC network for the instance. Used only when subnetwork is not set (auto-mode networks)."
  type        = string
  nullable    = false
  default     = "default"
}

variable "subnetwork" {
  description = "Self link or name of the subnetwork to attach the instance to. Required for custom-mode VPCs; when set it takes precedence over network."
  type        = string
  nullable    = true
  default     = null
}

variable "enable_public_ip" {
  description = "Attach an ephemeral external IP so the instance can reach the internet directly (e.g. a migration host reaching an external database and installing packages). Default: no public IP."
  type        = bool
  nullable    = false
  default     = false
}

variable "tags" {
  description = "Network tags applied to the instance (targeted by firewall rules)."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "labels" {
  description = "Labels applied to the instance."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "metadata" {
  description = "Instance metadata key/value pairs."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "startup_script" {
  description = "Shell script run on first boot (e.g. to install packages). Null (default) sets no startup script."
  type        = string
  nullable    = true
  default     = null
}

variable "service_account_email" {
  description = "Email of the service account to attach. Null (default) leaves the instance on the project default compute service account."
  type        = string
  nullable    = true
  default     = null
}

variable "service_account_scopes" {
  description = "OAuth scopes for the attached service account. Only used when service_account_email is set."
  type        = list(string)
  nullable    = false
  default     = ["cloud-platform"]
}
