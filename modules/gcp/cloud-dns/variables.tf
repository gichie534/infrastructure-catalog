variable "project_id" {
  description = "The ID of the project in which to create the managed zone."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "name" {
  description = "Name of the managed zone (the Cloud DNS resource name, not the domain)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.name))
    error_message = "name must be 2-63 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "dns_name" {
  description = "The DNS domain of the zone, with a trailing dot (e.g. internal.example.com.)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("\\.$", var.dns_name))
    error_message = "dns_name must be fully qualified with a trailing dot (e.g. example.com.)."
  }
}

variable "visibility" {
  description = "Zone visibility: 'public' (resolvable on the internet) or 'private' (resolvable only on the attached VPC networks)."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be either public or private."
  }
}

variable "networks" {
  description = "Self links of the VPC networks the zone is visible on. Required (non-empty) for private zones and must be empty for public zones. Wire from the vpc module's network_self_link output."
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = !(var.visibility == "private") || length(var.networks) > 0
    error_message = "private zones require at least one entry in networks."
  }

  validation {
    condition     = !(var.visibility == "public") || length(var.networks) == 0
    error_message = "public zones must not set networks."
  }
}

variable "records" {
  description = <<-EOT
    DNS records to create in the zone, keyed by the record name relative to the zone's dns_name.
    Use "" for the zone apex. Each value sets the record type, ttl, and rrdatas (the record values).
    Example: { "api" = { type = "A", rrdatas = ["10.0.0.10"] }, "" = { type = "TXT", rrdatas = ["\"v=spf1 -all\""] } }
  EOT
  type = map(object({
    type    = string
    ttl     = optional(number, 300)
    rrdatas = list(string)
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for r in values(var.records) : length(r.rrdatas) > 0])
    error_message = "each record must have at least one entry in rrdatas."
  }
}

variable "labels" {
  description = "Labels applied to the managed zone."
  type        = map(string)
  nullable    = false
  default     = {}
}
