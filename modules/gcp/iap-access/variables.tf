variable "project_id" {
  description = "The ID of the project that owns the IAP-protected web resource."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "members" {
  description = "IAM members granted access THROUGH IAP (role roles/iap.httpsResourceAccessor), as a map of arbitrary stable label => member. Each value is a standard IAM principal, e.g. \"user:alice@example.com\", \"group:eng@example.com\", or \"serviceAccount:svc@<project>.iam.gserviceaccount.com\". The map keys must be known at plan time."
  type        = map(string)
  nullable    = false

  validation {
    condition     = length(var.members) > 0
    error_message = "members must contain at least one principal."
  }

  validation {
    condition     = alltrue([for m in var.members : can(regex("^(user|group|serviceAccount|domain|principal|principalSet):", m))])
    error_message = "each member must be a fully-qualified IAM principal (user:, group:, serviceAccount:, domain:, principal:, or principalSet:)."
  }
}

variable "backend_service" {
  description = "Optional name of a specific Compute backend service to scope the grant to. When null (default), access is granted at the project-wide IAP web level (all IAP-protected backends in the project). GKE Ingress creates backend services with generated names, so the project-wide default is usually what a GKE lab wants."
  type        = string
  nullable    = true
  default     = null
}

variable "cors_allow_http_options" {
  description = "When set, manages IAP settings for this scope so cross-origin preflight requests can reach the backend: true lets HTTP OPTIONS calls skip IAP authorization, false makes IAP apply its normal authorization to them. Leave null (default) to not manage IAP settings at all, which leaves any existing configuration untouched. Set this to true when a browser app on one origin calls an IAP-protected API on another: the preflight OPTIONS request carries no credentials, so IAP would otherwise reject it and the actual request never gets sent."
  type        = bool
  nullable    = true
  default     = null
}
