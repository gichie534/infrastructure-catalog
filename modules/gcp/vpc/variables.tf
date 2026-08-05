variable "name" {
  description = "Name applied to the VPC network and used as the prefix for its subnetworks and related resources."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.name))
    error_message = "name must be 1-63 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "project_id" {
  description = "The ID of the project in which to create the network and its resources."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "routing_mode" {
  description = "Network-wide routing mode for the VPC. REGIONAL keeps routes within a region; GLOBAL shares them across regions."
  type        = string
  nullable    = false
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "routing_mode must be either REGIONAL or GLOBAL."
  }
}

variable "subnets" {
  description = <<-EOT
    GKE-ready subnetworks to create in the VPC. Each subnet has a primary range plus named
    secondary ranges for GKE Pods and Services (used by VPC-native clusters as alias IP ranges).
  EOT
  type = list(object({
    name                  = string
    region                = string
    ip_cidr_range         = string
    pods_cidr_range       = optional(string)
    services_cidr_range   = optional(string)
    pods_range_name       = optional(string, "pods")
    services_range_name   = optional(string, "services")
    private_google_access = optional(bool, true)
    flow_logs             = optional(bool, false)
  }))
  nullable = false

  validation {
    condition     = length(var.subnets) > 0
    error_message = "At least one subnet must be defined."
  }

  validation {
    condition     = length(distinct([for s in var.subnets : s.name])) == length(var.subnets)
    error_message = "subnet names must be unique."
  }

  validation {
    condition     = alltrue([for s in var.subnets : can(cidrhost(s.ip_cidr_range, 0))])
    error_message = "every subnet ip_cidr_range must be a valid CIDR (e.g. 10.0.0.0/20)."
  }

  validation {
    condition     = alltrue([for s in var.subnets : s.pods_cidr_range == null || can(cidrhost(s.pods_cidr_range, 0))])
    error_message = "every subnet pods_cidr_range, when set, must be a valid CIDR."
  }

  validation {
    condition     = alltrue([for s in var.subnets : s.services_cidr_range == null || can(cidrhost(s.services_cidr_range, 0))])
    error_message = "every subnet services_cidr_range, when set, must be a valid CIDR."
  }
}

variable "private_service_access" {
  description = <<-EOT
    Enable Private Service Access (VPC peering) for Google-managed services such as Cloud SQL and,
    when a GKE control plane uses a private endpoint, services that reach the cluster's VPC. This
    reserves a global address range and creates the servicenetworking peering connection.
  EOT
  type        = bool
  nullable    = false
  default     = true
}

variable "private_service_access_cidr" {
  description = "CIDR block reserved for Private Service Access peering. Only used when private_service_access is true."
  type        = string
  nullable    = false
  default     = "10.250.0.0/16"

  validation {
    condition     = can(cidrhost(var.private_service_access_cidr, 0))
    error_message = "private_service_access_cidr must be a valid CIDR (e.g. 10.250.0.0/16)."
  }
}

variable "private_service_access_deletion_policy" {
  description = <<-EOT
    Deletion policy for the Private Service Access peering connection. ABANDON (default) removes the
    connection from Terraform state on destroy without waiting for Google to release attached producer
    services (Cloud SQL, Memorystore), which avoids the common "producer services are still using this
    connection" teardown error. Set to null to have Terraform delete the connection and block until it
    is released.
  EOT
  type        = string
  nullable    = true
  default     = "ABANDON"

  validation {
    condition     = var.private_service_access_deletion_policy == null || var.private_service_access_deletion_policy == "ABANDON"
    error_message = "private_service_access_deletion_policy must be \"ABANDON\" or null."
  }
}

variable "iap_ssh_enabled" {
  description = "Create a firewall rule allowing SSH (tcp/22) from Google's IAP TCP-forwarding range (35.235.240.0/20) to instances tagged with iap_ssh_target_tags. Lets an operator reach a host via `gcloud compute ssh --tunnel-through-iap` without any public SSH exposure."
  type        = bool
  nullable    = false
  default     = false
}

variable "iap_ssh_target_tags" {
  description = "Network tags the IAP SSH firewall rule targets. Only used when iap_ssh_enabled is true; an empty list would target the whole network, so set the tag(s) your host carries."
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = !var.iap_ssh_enabled || length(var.iap_ssh_target_tags) > 0
    error_message = "iap_ssh_target_tags must be non-empty when iap_ssh_enabled is true."
  }
}

variable "create_nat" {
  description = "Create a Cloud Router and Cloud NAT so nodes without external IPs (typical for private GKE) can reach the internet for egress."
  type        = bool
  nullable    = false
  default     = true
}

variable "nat_reserve_static_ip" {
  description = "Reserve a static regional external IP for Cloud NAT (MANUAL_ONLY allocation) instead of dynamic AUTO_ONLY. Only used when create_nat is true. Use this when an external system must allowlist a stable egress address for instances that have no public IP of their own (e.g. a migration host reaching a database in another cloud)."
  type        = bool
  nullable    = false
  default     = false
}

variable "nat_region" {
  description = "Region for the Cloud Router and Cloud NAT. Defaults to the region of the first subnet when null."
  type        = string
  nullable    = true
  default     = null
}

# Note: GCP VPC networks, subnetworks, routers, NATs, and global addresses do not
# support resource labels, so this module intentionally does not expose a `labels`
# input. Add one here only if a labellable resource is introduced.
