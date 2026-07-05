variable "name" {
  description = "The domain name of the hosted zone, e.g. example.com or aws.example.com. A trailing dot is optional (Route 53 normalizes it)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}\\.?$", lower(var.name)))
    error_message = "name must be a valid DNS domain (e.g. example.com or sub.example.com), lowercase labels separated by dots."
  }
}

variable "visibility" {
  description = "Zone visibility: 'public' (resolvable on the internet) or 'private' (resolvable only on the associated VPCs)."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be either public or private."
  }
}

variable "vpc_associations" {
  description = "VPCs the private zone is resolvable on. Required (non-empty) for private zones and must be empty for public zones. vpc_region defaults to the provider region when omitted."
  type = list(object({
    vpc_id     = string
    vpc_region = optional(string)
  }))
  nullable = false
  default  = []

  validation {
    condition     = !(var.visibility == "private") || length(var.vpc_associations) > 0
    error_message = "private zones require at least one entry in vpc_associations."
  }

  validation {
    condition     = !(var.visibility == "public") || length(var.vpc_associations) == 0
    error_message = "public zones must not set vpc_associations."
  }
}

variable "records" {
  description = <<-EOT
    DNS records to create in the zone, keyed by the record name relative to the zone's name.
    Use "" for the zone apex. Each value sets the record type, ttl, and records (the record values).
    Example: { "api" = { type = "A", records = ["203.0.113.10"] }, "" = { type = "TXT", records = ["\"v=spf1 -all\""] } }
  EOT
  type = map(object({
    type    = string
    ttl     = optional(number, 300)
    records = list(string)
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for r in values(var.records) : length(r.records) > 0])
    error_message = "each record must have at least one entry in records."
  }
}

variable "validation_records" {
  description = <<-EOT
    Records whose NAME is computed (known only after apply) — chiefly ACM certificate DNS-validation
    CNAMEs. Unlike `records` (which is keyed by the record name), this map is keyed by a STABLE
    caller-chosen label, with the fully-qualified record name carried in the value. That keeps the
    for_each keys known at plan time, so you can wire an ACM certificate's
    domain_validation_options straight in without Terraform complaining that the keys are unknown.

    - name:    the fully-qualified record name (ACM returns an absolute FQDN, e.g.
               "_x1.api.example.com."). Written verbatim; NOT expanded against the zone name.
    - type:    record type (typically "CNAME").
    - ttl:     optional, default 300.
    - records: the record values.

    Example (wiring an ACM certificate):
      validation_records = {
        for dvo in aws_acm_certificate.this.domain_validation_options :
        dvo.domain_name => { name = dvo.resource_record_name, type = dvo.resource_record_type, records = [dvo.resource_record_value] }
      }
  EOT
  type = map(object({
    name    = string
    type    = optional(string, "CNAME")
    ttl     = optional(number, 300)
    records = list(string)
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for r in values(var.validation_records) : length(r.records) > 0])
    error_message = "each validation record must have at least one entry in records."
  }
}

variable "delegate_to_parent_zone" {
  description = <<-EOT
    Optionally delegate this (sub)zone from an existing PARENT hosted zone. When set, the module
    writes an NS record for this zone's name into the named parent zone, pointing at this zone's own
    authoritative name servers. This makes a delegated subdomain self-contained and reproducible:
    Route 53 assigns fresh name servers each time the zone is recreated, and the NS delegation is
    rewritten in lock-step, so destroy/recreate never leaves a stale delegation.

    Use this when this zone is a child of another Route 53 zone in the same account (e.g. zone
    "sub.example.com" delegated from the existing "example.com" zone). Leave null (default) for a
    top-level zone whose delegation is handled at an external registrar.

    - zone_id: the parent's Route 53 hosted-zone ID to write the NS record into.
    - ttl:     TTL for the NS delegation record (default 300).
  EOT
  type = object({
    zone_id = string
    ttl     = optional(number, 300)
  })
  nullable = true
  default  = null
}

variable "comment" {
  description = "Comment attached to the hosted zone."
  type        = string
  nullable    = false
  default     = "Managed by Terraform"
}

variable "force_destroy" {
  description = "Whether to allow Terraform to destroy the zone even when it still contains records not managed by this module. Set true in throwaway lab environments so `terraform destroy` tears down cleanly."
  type        = bool
  nullable    = false
  default     = false
}

variable "tags" {
  description = "Tags applied to the hosted zone."
  type        = map(string)
  nullable    = false
  default     = {}
}
