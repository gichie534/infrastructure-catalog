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

variable "record_sets" {
  description = <<-EOT
    DNS records keyed by a caller-chosen LABEL, with the record name carried in the value. This is the
    general form of `records` and the one to prefer for a real zone.

    `records` is keyed by record name, so it can hold only ONE record per name. A live apex needs
    several — e.g. grace.io. simultaneously has A (the site), MX (mail), and TXT (SPF + domain
    verification). Use `record_sets` whenever a name needs more than one type; the label is arbitrary
    and only has to be unique.

    - name:    record name RELATIVE to dns_name; "" is the zone apex. (Contrast `validation_records`,
               whose name is absolute.)
    - type:    record type.
    - ttl:     optional, default 300.
    - rrdatas: the record values. TXT values must include their own escaped quotes.

    Example:
      record_sets = {
        apex_a   = { name = "", type = "A",   rrdatas = ["203.0.113.10"] }
        apex_mx  = { name = "", type = "MX",  rrdatas = ["10 mail.example.com."] }
        apex_spf = { name = "", type = "TXT", rrdatas = ["\"v=spf1 -all\""] }
      }
  EOT
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    rrdatas = list(string)
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for r in values(var.record_sets) : length(r.rrdatas) > 0])
    error_message = "each record set must have at least one entry in rrdatas."
  }

  validation {
    condition     = alltrue([for r in values(var.record_sets) : !endswith(r.name, ".")])
    error_message = "record_sets names are relative to dns_name and must not end with a dot (use \"\" for the apex)."
  }
}

variable "validation_records" {
  description = <<-EOT
    Records whose NAME is computed (known only after apply) — chiefly ACME / Certificate Manager
    DNS-authorization CNAMEs. Unlike `records` (which is keyed by the record name), this map is keyed
    by a STABLE caller-chosen label, with the fully-qualified record name carried in the value. That
    keeps the for_each keys known at plan time, so you can wire a certificate module's
    dns_authorization_records straight in without Terraform complaining that the keys are unknown.

    - name:    the fully-qualified record name (Certificate Manager returns an absolute FQDN, e.g.
               "_acme-challenge.api.example.com." — trailing dot optional). Written verbatim; NOT
               expanded against dns_name.
    - type:    record type (typically "CNAME").
    - ttl:     optional, default 300.
    - rrdatas: the record values.

    Example (wiring a certificate module):
      validation_records = module.certs.dns_authorization_records  # { api = { name, type, data }, ... }
      # if the source shape uses `data` instead of `rrdatas`, adapt with a for-expression.
  EOT
  type = map(object({
    name    = string
    type    = optional(string, "CNAME")
    ttl     = optional(number, 300)
    rrdatas = list(string)
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for r in values(var.validation_records) : length(r.rrdatas) > 0])
    error_message = "each validation record must have at least one entry in rrdatas."
  }
}

variable "delegate_to_parent_zone" {
  description = <<-EOT
    Optionally delegate this (sub)zone from an existing PARENT managed zone. When set, the module
    writes an NS record for this zone's dns_name into the named parent zone, pointing at this zone's
    own authoritative name servers. This makes a delegated subdomain self-contained and reproducible:
    GCP assigns fresh name servers each time the zone is recreated, and the NS delegation is rewritten
    in lock-step, so destroy/recreate never leaves a stale delegation.

    Use this when this zone is a child of another Cloud DNS zone in the same org (e.g. zone
    "sub.example.com." delegated from the existing "example.com." zone). Leave null (default) for a
    top-level zone whose delegation is handled at an external registrar.

    - zone_name:  the parent's Cloud DNS managed-zone resource name (NOT the domain) to write the NS
                  record into.
    - project_id: project of the parent zone, if different from this zone's project_id (default null
                  uses project_id).
    - ttl:        TTL for the NS delegation record (default 300).
  EOT
  type = object({
    zone_name  = string
    project_id = optional(string)
    ttl        = optional(number, 300)
  })
  nullable = true
  default  = null
}

variable "labels" {
  description = "Labels applied to the managed zone."
  type        = map(string)
  nullable    = false
  default     = {}
}
