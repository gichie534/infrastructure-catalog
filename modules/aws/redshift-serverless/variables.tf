variable "name" {
  description = "Base name for the warehouse. Used for the namespace, the workgroup, and the COPY IAM role unless `namespace_name` / `workgroup_name` override the first two."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9-]{3,64}$", var.name))
    error_message = "name must be 3-64 chars of lowercase letters, numbers, and hyphens (Redshift Serverless rejects uppercase and underscores)."
  }
}

variable "namespace_name" {
  description = "Override the namespace name. Defaults to `name`."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.namespace_name == null || can(regex("^[a-z0-9-]{3,64}$", var.namespace_name))
    error_message = "namespace_name must be 3-64 chars of lowercase letters, numbers, and hyphens."
  }
}

variable "workgroup_name" {
  description = "Override the workgroup name. Defaults to `name`."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.workgroup_name == null || can(regex("^[a-z0-9-]{3,64}$", var.workgroup_name))
    error_message = "workgroup_name must be 3-64 chars of lowercase letters, numbers, and hyphens."
  }
}

variable "database_name" {
  description = "Name of the first database created in the namespace. This is what a Data API call passes as `Database`."
  type        = string
  nullable    = false
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,63}$", var.database_name))
    error_message = "database_name must start with a lowercase letter and contain only lowercase letters, numbers, and underscores."
  }
}

variable "admin_username" {
  description = "Username of the database administrator. Note that `admin` is reserved by Redshift and rejected."
  type        = string
  nullable    = false
  default     = "dbadmin"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,127}$", var.admin_username))
    error_message = "admin_username must start with a lowercase letter and contain only lowercase letters, numbers, and underscores."
  }
}

variable "admin_user_password" {
  description = <<-EOT
    Admin password. Leave null (the default) and Redshift creates and rotates the credential secret in
    Secrets Manager instead — no password in your variables or in Terraform state. Only set this if
    something genuinely needs a static password; Data API access with IAM authentication does not.
  EOT
  type        = string
  nullable    = true
  default     = null
  sensitive   = true
}

variable "subnet_ids" {
  description = <<-EOT
    Subnets the workgroup's compute is placed in. Redshift Serverless requires **at least three
    subnets spanning three different Availability Zones**, and each needs enough free IPs for the
    chosen `base_capacity`. Private subnets are the right choice — the Data API does not need the
    workgroup to be reachable from outside the VPC.
  EOT
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) >= 3
    error_message = "subnet_ids must contain at least three subnets spanning three Availability Zones — Redshift Serverless rejects fewer."
  }

  validation {
    condition     = length(distinct(var.subnet_ids)) == length(var.subnet_ids)
    error_message = "subnet_ids must not contain duplicates."
  }
}

variable "security_group_ids" {
  description = "Security groups attached to the workgroup. Empty (the default) lets AWS attach the VPC's default security group. An egress-only group is sufficient when queries arrive via the Data API."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "base_capacity" {
  description = <<-EOT
    Base compute capacity in Redshift Processing Units, in multiples of 8. Billed per RPU-second while
    queries run, so 8 (the minimum, and the default) is the right choice for a warehouse that serves
    occasional loads and queries rather than sustained analytics.
  EOT
  type        = number
  nullable    = false
  default     = 8

  validation {
    condition     = var.base_capacity >= 8 && var.base_capacity <= 1024 && var.base_capacity % 8 == 0
    error_message = "base_capacity must be between 8 and 1024 and a multiple of 8."
  }
}

variable "max_capacity" {
  description = "Optional ceiling on RPUs used to serve queries, in multiples of 8. Null (the default) applies no explicit ceiling. Worth setting as a cost guard on a warehouse anyone can query."
  type        = number
  nullable    = true
  default     = null

  validation {
    condition     = var.max_capacity == null || (var.max_capacity >= 8 && var.max_capacity <= 5632 && var.max_capacity % 8 == 0)
    error_message = "max_capacity must be between 8 and 5632 and a multiple of 8 when set."
  }
}

variable "publicly_accessible" {
  description = "Whether the workgroup accepts connections from the public internet. Default false — with Data API access there is no reason to expose it."
  type        = bool
  nullable    = false
  default     = false
}

variable "enhanced_vpc_routing" {
  description = "Force traffic between the workgroup and other services through your VPC instead of over the internet. Default false; enabling it requires VPC endpoints or NAT for S3 reachability."
  type        = bool
  nullable    = false
  default     = false
}

variable "s3_read_bucket_arns" {
  description = <<-EOT
    Bucket ARNs the COPY role is granted read access to (`s3:GetObject` on their contents, plus
    `ListBucket`/`GetBucketLocation` on the buckets themselves). Empty (the default) creates the role
    with no S3 access, which is only useful if a consumer attaches its own policy. Pass the `arn`
    output of `aws/s3-bucket`, not an object ARN.
  EOT
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition = alltrue([
      for arn in var.s3_read_bucket_arns :
      can(regex("^arn:aws[a-zA-Z-]*:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", arn))
    ])
    error_message = "every entry in s3_read_bucket_arns must be an S3 bucket ARN (e.g. arn:aws:s3:::my-bucket), not an object ARN."
  }
}

variable "log_exports" {
  description = "Log types the namespace exports to CloudWatch Logs. Valid values are `userlog`, `connectionlog`, and `useractivitylog`. Empty by default."
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition = alltrue([
      for l in var.log_exports : contains(["userlog", "connectionlog", "useractivitylog"], l)
    ])
    error_message = "log_exports entries must be one of userlog, connectionlog, useractivitylog."
  }
}

variable "config_parameters" {
  description = "Database configuration parameters applied to the workgroup, as a map of parameter key to value (e.g. `{ require_ssl = \"true\" }`). Empty by default."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module (namespace, workgroup, COPY role)."
  type        = map(string)
  nullable    = false
  default     = {}
}
