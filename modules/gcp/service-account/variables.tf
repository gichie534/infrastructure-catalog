variable "project_id" {
  description = "The ID of the project that owns the service account."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "account_id" {
  description = "The account_id (local part) of the service account. The full email becomes <account_id>@<project_id>.iam.gserviceaccount.com."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.account_id))
    error_message = "account_id must be 6 to 30 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "display_name" {
  description = "Human-readable display name for the service account."
  type        = string
  nullable    = false
  default     = "Service account"
}

variable "description" {
  description = "Human-readable description for the service account."
  type        = string
  nullable    = false
  default     = "Managed by Terraform"
}

variable "project_roles" {
  description = "Project-level IAM roles to grant the service account, as a set of role IDs (each starting with roles/)."
  type        = set(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for r in var.project_roles : startswith(r, "roles/")])
    error_message = "each project_roles entry must be a role ID starting with roles/."
  }
}

variable "token_creators" {
  description = "IAM principals granted roles/iam.serviceAccountTokenCreator ON this service account, as a map of arbitrary stable label => member (e.g. \"user:alice@example.com\"). This lets them impersonate the account to mint short-lived credentials (OIDC ID tokens, signed JWTs) without a key. The map keys must be known at plan time."
  type        = map(string)
  nullable    = false
  default     = {}

  validation {
    condition     = alltrue([for m in var.token_creators : can(regex("^(user|group|serviceAccount|domain|principal|principalSet):", m))])
    error_message = "each token_creators member must be a fully-qualified IAM principal (user:, group:, serviceAccount:, domain:, principal:, or principalSet:)."
  }
}
