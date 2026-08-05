variable "name" {
  description = "Name of the RDS instance. Used as the DB identifier and the prefix for its subnet group, security group, and parameter group."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.name))
    error_message = "name must be 2-63 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the instance's security group is created in."
  type        = string
  nullable    = false
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group. Use public subnets when publicly_accessible is true (so the instance gets a routable address), private subnets otherwise. Span at least two AZs."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "at least two subnet IDs (in different AZs) are required for a DB subnet group."
  }
}

variable "engine_version" {
  description = "PostgreSQL engine version. A major-only value (e.g. \"16\") tracks the latest supported minor for that major."
  type        = string
  nullable    = false
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t4g.micro, db.m6g.large)."
  type        = string
  nullable    = false
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage allocated to the instance, in GiB."
  type        = number
  nullable    = false
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB for PostgreSQL."
  }
}

variable "max_allocated_storage" {
  description = "Upper limit (GiB) for storage autoscaling. Set to 0 to disable autoscaling. Must be >= allocated_storage when enabled."
  type        = number
  nullable    = false
  default     = 0
}

variable "storage_type" {
  description = "EBS storage type for the instance (gp3, gp2, io1, io2)."
  type        = string
  nullable    = false
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Encrypt the instance's storage at rest with the default RDS KMS key."
  type        = bool
  nullable    = false
  default     = true
}

variable "db_name" {
  description = "Name of the initial database created on the instance."
  type        = string
  nullable    = false
  default     = "app"

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter or underscore and contain only letters, numbers, and underscores."
  }
}

variable "master_username" {
  description = "Master (admin) login role created with the instance. On RDS this role is a member of rds_superuser."
  type        = string
  nullable    = false
  default     = "postgres"
}

variable "master_password" {
  description = "Password for the master user. Required (no default) so it is supplied deliberately, never baked into the module."
  type        = string
  nullable    = false
  sensitive   = true
}

variable "port" {
  description = "TCP port the instance listens on."
  type        = number
  nullable    = false
  default     = 5432
}

variable "publicly_accessible" {
  description = "Give the instance a public endpoint. Combine with a tight allowed_cidr_blocks and rds.force_ssl for a lab/migration source reachable from outside the VPC; keep false for production."
  type        = bool
  nullable    = false
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the instance on its port via the module-created security group. Keep this narrow (e.g. a single operator /32)."
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_cidr_blocks : can(cidrhost(c, 0))])
    error_message = "every entry in allowed_cidr_blocks must be a valid CIDR (e.g. 203.0.113.10/32)."
  }
}

variable "multi_az" {
  description = "Deploy a standby in a second AZ for HA failover. Off by default to keep labs cheap."
  type        = bool
  nullable    = false
  default     = false
}

variable "parameter_group_family" {
  description = "DB parameter group family, matching the engine major version (e.g. postgres16)."
  type        = string
  nullable    = false
  default     = "postgres16"
}

variable "parameters" {
  description = <<-EOT
    DB parameters applied via a module-managed parameter group. Common entries: rds.force_ssl=1 to
    require TLS, and rds.logical_replication=1 (apply_method=pending-reboot) to enable logical
    decoding for CDC-based migrations. apply_method is "immediate" or "pending-reboot".
  EOT
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  nullable = false
  default  = []

  validation {
    condition     = alltrue([for p in var.parameters : contains(["immediate", "pending-reboot"], p.apply_method)])
    error_message = "each parameter's apply_method must be \"immediate\" or \"pending-reboot\"."
  }
}

variable "backup_retention_period" {
  description = "Days to retain automated backups. 0 disables automated backups (fine for an ephemeral lab)."
  type        = number
  nullable    = false
  default     = 0
}

variable "deletion_protection" {
  description = "Block deletion of the instance until disabled. Keep true for real environments; examples/labs set it false to tear down cleanly."
  type        = bool
  nullable    = false
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. True for ephemeral labs; false (a final snapshot is taken) for anything you might need to restore."
  type        = bool
  nullable    = false
  default     = false
}

variable "apply_immediately" {
  description = "Apply modifications immediately instead of during the next maintenance window."
  type        = bool
  nullable    = false
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Allow RDS to apply minor engine upgrades automatically during maintenance windows."
  type        = bool
  nullable    = false
  default     = true
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights on the instance."
  type        = bool
  nullable    = false
  default     = false
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module."
  type        = map(string)
  nullable    = false
  default     = {}
}
