variable "project_id" {
  description = "The ID of the project in which to create the certificates, DNS authorizations, and certificate map."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "name" {
  description = <<-EOT
    Base name for the certificate map and the prefix for every certificate/DNS-authorization/map-entry
    this module creates (each is named "<name>-<label>"). This is also the value a GKE Ingress puts in
    its `networking.gke.io/certmap` annotation to attach the certs.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.name))
    error_message = "name must be 2-63 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "location" {
  description = <<-EOT
    Certificate Manager location. Use "global" for GKE Ingress (the external Application Load Balancer
    is global). Regional locations exist for regional load balancers and are out of scope for the
    GKE-Ingress use case.
  EOT
  type        = string
  nullable    = false
  default     = "global"
}

variable "certificates" {
  description = <<-EOT
    Managed certificates to create, keyed by a short stable label (used in resource names, so it must
    match [a-z0-9-]). One DNS-authorized, auto-renewing certificate is created per entry, plus a map
    entry that routes that exact hostname (SNI) to the cert.

    - domain: the single fully-qualified hostname the certificate covers (e.g. "api.example.com").
              PER-HOST ONLY: wildcards ("*.example.com") are rejected — create one entry per host.

    Each domain needs its DNS-authorization CNAME published in the zone before it will validate; this
    module outputs those records (see dns_authorization_records) — wire them into gcp/cloud-dns.
  EOT
  type = map(object({
    domain = string
  }))
  nullable = false

  validation {
    condition     = length(var.certificates) > 0
    error_message = "provide at least one certificate."
  }

  validation {
    condition     = alltrue([for k in keys(var.certificates) : can(regex("^[a-z][a-z0-9-]*$", k))])
    error_message = "each certificate key must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens (it is used in resource names)."
  }

  validation {
    condition     = alltrue([for c in values(var.certificates) : !startswith(c.domain, "*.")])
    error_message = "wildcard domains are not allowed — this module is per-host. Provide explicit hostnames."
  }
}

variable "labels" {
  description = "Labels applied to every resource created by this module (DNS authorizations, certificates, the map, and map entries)."
  type        = map(string)
  nullable    = false
  default     = {}
}
