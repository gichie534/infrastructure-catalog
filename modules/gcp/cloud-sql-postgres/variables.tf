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

variable "availability_type" {
  description = <<-EOT
    High availability shape of the instance. REGIONAL provisions a standby in a second zone of the
    same region with SYNCHRONOUS replication and automatic failover (zero RPO for a zonal failure);
    ZONAL is a single zone with no standby. Production instances should be REGIONAL.
  EOT
  type        = string
  nullable    = false
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be either ZONAL or REGIONAL."
  }
}

variable "disk_size" {
  description = "Size of the data disk in GB. Null leaves the Cloud SQL default (10 GB). The disk can grow but never shrink."
  type        = number
  nullable    = true
  default     = null

  validation {
    condition     = var.disk_size == null || var.disk_size >= 10
    error_message = "disk_size must be at least 10 GB."
  }
}

variable "disk_type" {
  description = "Data disk type. PD_SSD is the default for production; PD_HDD is cheaper and slower. Null leaves the provider default."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.disk_type == null || contains(["PD_SSD", "PD_HDD", "HYPERDISK_BALANCED"], var.disk_type)
    error_message = "disk_type must be one of PD_SSD, PD_HDD, HYPERDISK_BALANCED, or null."
  }
}

variable "disk_autoresize" {
  description = "Let Cloud SQL grow the data disk automatically when it fills up. Null leaves the provider default (true)."
  type        = bool
  nullable    = true
  default     = null
}

variable "disk_autoresize_limit" {
  description = "Upper bound in GB for automatic disk growth. 0 means no limit. Only meaningful when disk_autoresize is enabled."
  type        = number
  nullable    = true
  default     = null

  validation {
    condition     = var.disk_autoresize_limit == null || var.disk_autoresize_limit >= 0
    error_message = "disk_autoresize_limit must be 0 (no limit) or a positive number of GB."
  }
}

variable "backup_configuration" {
  description = <<-EOT
    Automated backups and point-in-time recovery. Null (the default) creates no backup configuration
    at all, leaving the instance unbacked-up — set this for any environment holding real data.

    - `start_time` is UTC `HH:MM`; pick a low-traffic window.
    - `location` stores the backups in a different (multi-)region from the instance, so one region's
      loss can't take the data and its backups together. Null keeps them in the instance's region.
    - `point_in_time_recovery_enabled` turns on write-ahead-log archiving, allowing a restore to any
      point inside `transaction_log_retention_days` rather than only to the last nightly backup.
    - `retention_unit` is `COUNT`, so `retained_backups` is a number of backups, not days.
  EOT
  type = object({
    enabled                        = optional(bool, true)
    start_time                     = optional(string, "03:00")
    location                       = optional(string)
    point_in_time_recovery_enabled = optional(bool, true)
    transaction_log_retention_days = optional(number, 7)
    retained_backups               = optional(number, 30)
    retention_unit                 = optional(string, "COUNT")
  })
  nullable = true
  default  = null

  validation {
    condition     = var.backup_configuration == null || can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup_configuration.start_time))
    error_message = "backup_configuration.start_time must be a UTC time in HH:MM 24-hour form."
  }

  validation {
    condition = var.backup_configuration == null || (
      var.backup_configuration.transaction_log_retention_days >= 1 &&
      var.backup_configuration.transaction_log_retention_days <= 35
    )
    error_message = "backup_configuration.transaction_log_retention_days must be between 1 and 35."
  }

  validation {
    condition     = var.backup_configuration == null || var.backup_configuration.retained_backups >= 1
    error_message = "backup_configuration.retained_backups must be at least 1."
  }
}

variable "maintenance_window" {
  description = <<-EOT
    Weekly window in which Cloud SQL may apply maintenance (a brief restart / failover). `day` is
    1 (Monday) to 7 (Sunday), `hour` is 0-23 UTC. `update_track` of `stable` receives updates later
    than `canary`, which is what a production instance normally wants. Null leaves it unmanaged, so
    maintenance can land at any time.
  EOT
  type = object({
    day          = number
    hour         = number
    update_track = optional(string, "stable")
  })
  nullable = true
  default  = null

  validation {
    condition     = var.maintenance_window == null || (var.maintenance_window.day >= 1 && var.maintenance_window.day <= 7)
    error_message = "maintenance_window.day must be between 1 (Monday) and 7 (Sunday)."
  }

  validation {
    condition     = var.maintenance_window == null || (var.maintenance_window.hour >= 0 && var.maintenance_window.hour <= 23)
    error_message = "maintenance_window.hour must be between 0 and 23 (UTC)."
  }

  validation {
    condition     = var.maintenance_window == null || contains(["canary", "stable", "week5"], var.maintenance_window.update_track)
    error_message = "maintenance_window.update_track must be one of canary, stable, week5."
  }
}

variable "read_replicas" {
  description = <<-EOT
    Read replicas to create, keyed by a short suffix appended to the instance name (e.g. `dr` gives
    `<name>-dr`). Set `region` to a DIFFERENT region than the primary for a cross-region replica: it
    survives the loss of the primary's region and can be promoted to a standalone primary, which is
    the regional-disaster recovery path. Replication is ASYNCHRONOUS, so the RPO is the replication
    lag (usually seconds), not zero — pair it with a REGIONAL primary for zero-RPO zonal failover.

    Each replica inherits the primary's tier / disk settings unless it overrides them. Backups are
    not configurable on a replica (Cloud SQL rejects it); IAM database users replicate from the
    primary. The VPC's Private Service Access allocation is global, so no extra network setup is
    needed for the replica's region.
  EOT
  type = map(object({
    region                = string
    tier                  = optional(string)
    availability_type     = optional(string, "ZONAL")
    disk_size             = optional(number)
    disk_type             = optional(string)
    disk_autoresize       = optional(bool)
    disk_autoresize_limit = optional(number)
    user_labels           = optional(map(string))
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for r in var.read_replicas : contains(["ZONAL", "REGIONAL"], r.availability_type)])
    error_message = "each read_replicas availability_type must be either ZONAL or REGIONAL."
  }

  validation {
    condition     = alltrue([for k, r in var.read_replicas : can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", k))])
    error_message = "each read_replicas key must be lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen (it becomes part of the instance name)."
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
