variable "project_id" {
  description = "The ID of the project that owns the Workload Identity Pool and its providers."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "pool_id" {
  description = "ID of the Workload Identity Pool to create (the last path segment of its resource name)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.pool_id))
    error_message = "pool_id must be 4-32 characters of lowercase letters, numbers, or hyphens."
  }
}

variable "pool_display_name" {
  description = "Human-readable display name for the Workload Identity Pool."
  type        = string
  nullable    = false
  default     = "Workload Identity Pool"
}

variable "pool_description" {
  description = "Description of the Workload Identity Pool."
  type        = string
  nullable    = false
  default     = "Federates external OIDC identities to Google service accounts."
}

variable "oidc_providers" {
  description = <<-EOT
    OIDC providers to attach to the pool, keyed by provider ID. The module is IdP-neutral: each entry
    describes one external issuer (GitHub Actions, GitLab CI, Terraform Cloud, another cloud, ...).

    - issuer_uri:          the provider's OIDC issuer URL (e.g. https://token.actions.githubusercontent.com).
    - attribute_mapping:   map of Google STS attributes to assertion expressions. Must map google.subject.
                           Add attribute.<name> entries for any claim you want to gate on later.
    - attribute_condition: optional CEL expression that an incoming token must satisfy to be accepted
                           (the security gate, e.g. restrict to one repo/owner). Strongly recommended.
    - allowed_audiences:   optional list of accepted audiences. Empty means GCP accepts the provider's
                           default audience (the full provider resource URL), which suits most setups.
  EOT
  type = map(object({
    issuer_uri          = string
    attribute_mapping   = map(string)
    attribute_condition = optional(string)
    allowed_audiences   = optional(list(string), [])
    display_name        = optional(string)
    description         = optional(string)
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for p in values(var.oidc_providers) : contains(keys(p.attribute_mapping), "google.subject")])
    error_message = "each provider's attribute_mapping must define google.subject."
  }

  validation {
    condition     = alltrue([for p in values(var.oidc_providers) : startswith(p.issuer_uri, "https://")])
    error_message = "each provider issuer_uri must be an https:// URL."
  }
}

variable "service_account_bindings" {
  description = <<-EOT
    Grants federated identities permission to impersonate Google service accounts via
    roles/iam.workloadIdentityUser, keyed by an arbitrary stable label.

    - service_account_id: fully-qualified GSA resource ID (projects/<p>/serviceAccounts/<email>).
                          Wire this from the workload-iam module's service_account_id output.
    - principal_set:      the member suffix appended to the pool resource name. Use an attribute
                          selector to scope to matching identities, e.g.
                          "attribute.repository/OWNER/REPO" (all tokens whose repository attribute
                          equals OWNER/REPO), or "*" for every identity in the pool.

    The module assembles the full principalSet:// member from the pool name and this suffix, so
    callers never hardcode the project number.
  EOT
  type = map(object({
    service_account_id = string
    principal_set      = string
  }))
  nullable = false
  default  = {}
}
