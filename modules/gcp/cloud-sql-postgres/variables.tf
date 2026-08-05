variable "name" {
  description = "Name of the Cloud SQL instance. Also used as the prefix for the database."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.name))
    error_message = "name must be 2-63 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "project_id" {
  description = "The ID of the project in which to create the instance."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "region" {
  description = "Region for the Cloud SQL instance (e.g. us-central1)."
  type        = string
  nullable    = false
}

variable "network" {
  description = "Self link or ID of the VPC network the instance gets a private IP on. Wire this to the vpc module's network_self_link output; the VPC must have Private Service Access configured."
  type        = string
  nullable    = false
}

variable "database_version" {
  description = "PostgreSQL version for the instance (e.g. POSTGRES_16)."
  type        = string
  nullable    = false
  default     = "POSTGRES_16"

  validation {
    condition     = can(regex("^POSTGRES_\\d+$", var.database_version))
    error_message = "database_version must be a PostgreSQL version like POSTGRES_16."
  }
}

variable "tier" {
  description = "Machine tier for the instance (e.g. db-custom-1-3840, db-f1-micro)."
  type        = string
  nullable    = false
  default     = "db-custom-1-3840"
}

variable "edition" {
  description = "The edition of the Cloud SQL instance. ENTERPRISE_PLUS unlocks higher performance and availability features; the chosen tier must be compatible with the edition."
  type        = string
  nullable    = false
  default     = "ENTERPRISE"

  validation {
    condition     = contains(["ENTERPRISE", "ENTERPRISE_PLUS"], var.edition)
    error_message = "edition must be either ENTERPRISE or ENTERPRISE_PLUS."
  }
}

variable "database_name" {
  description = "Name of the application database to create on the instance."
  type        = string
  nullable    = false
  default     = "app"

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.database_name))
    error_message = "database_name must start with a letter or underscore and contain only letters, numbers, and underscores."
  }
}

variable "enable_public_ip" {
  description = <<-EOT
    Give the instance a public IPv4 endpoint in addition to its private IP. Off by default
    (private-IP-only is the production shape). A migration or bootstrap that must reach the instance
    from outside the VPC (e.g. an operator running pg_restore) can enable it, paired with a narrow
    authorized_networks allowlist and ssl_mode = ENCRYPTED_ONLY.
  EOT
  type        = bool
  nullable    = false
  default     = false
}

variable "authorized_networks" {
  description = <<-EOT
    Public CIDR allowlist for the instance's public IP. Only meaningful when enable_public_ip is
    true. Each entry has a name (label) and value (CIDR). Keep this narrow (e.g. a single operator /32).
  EOT
  type = list(object({
    name  = string
    value = string
  }))
  nullable = false
  default  = []

  validation {
    condition     = alltrue([for n in var.authorized_networks : can(cidrhost(n.value, 0))])
    error_message = "each authorized_networks value must be a valid CIDR (e.g. 203.0.113.10/32)."
  }
}

variable "ssl_mode" {
  description = <<-EOT
    Enforcement of TLS on connections. ENCRYPTED_ONLY requires TLS but not a client cert;
    ALLOW_UNENCRYPTED_AND_ENCRYPTED permits plaintext; TRUSTED_CLIENT_CERTIFICATE_REQUIRED also
    demands a client certificate. Null (default) leaves the provider default in place.
  EOT
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.ssl_mode == null || contains(["ALLOW_UNENCRYPTED_AND_ENCRYPTED", "ENCRYPTED_ONLY", "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"], var.ssl_mode)
    error_message = "ssl_mode must be one of ALLOW_UNENCRYPTED_AND_ENCRYPTED, ENCRYPTED_ONLY, TRUSTED_CLIENT_CERTIFICATE_REQUIRED, or null."
  }
}

variable "admin_password" {
  description = <<-EOT
    When set, assigns this password to the built-in `postgres` user (a member of cloudsqlsuperuser),
    enabling password authentication for that admin role. Required for a password-auth migration that
    restores as `postgres`. Leave null to keep the instance IAM-auth-only.
  EOT
  type        = string
  nullable    = true
  default     = null
  sensitive   = true
}

variable "iam_service_account_emails" {
  description = <<-EOT
    Email addresses of Google service accounts to register as IAM database users. A GKE pod
    authenticates to the instance (no password) by running under a Kubernetes SA bound via
    Workload Identity to one of these GSAs. The GSAs and their project-level IAM grants
    (roles/cloudsql.client, roles/cloudsql.instanceUser) are owned by the consumer, not this module.
  EOT
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for e in var.iam_service_account_emails : can(regex("^[^@]+@[^@]+\\.iam\\.gserviceaccount\\.com$", e))])
    error_message = "each entry must be a Google service account email ending in .iam.gserviceaccount.com."
  }
}

variable "deletion_protection" {
  description = "Whether the instance is protected from deletion. Keep true for real environments; examples/tests set it false."
  type        = bool
  nullable    = false
  default     = true
}

variable "user_labels" {
  description = "Labels applied to the Cloud SQL instance."
  type        = map(string)
  nullable    = false
  default     = {}
}
