variable "name" {
  description = "Name of the EKS cluster, used as the prefix for its IAM roles, node groups, and related resources."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,99}$", var.name))
    error_message = "name must be 1-100 characters, start with a letter or digit, and contain only alphanumeric characters and hyphens."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the control plane (e.g. 1.31). Node groups inherit this version."
  type        = string
  nullable    = false
  default     = "1.31"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must be a MAJOR.MINOR version (e.g. 1.31)."
  }
}

variable "subnet_ids" {
  description = "Subnet IDs for the cluster control plane ENIs and the worker nodes. Use private subnets for nodes. Wire to the vpc module's private_subnet_ids."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "at least two subnets in different availability zones are required."
  }
}

variable "endpoint_public_access" {
  description = "Whether the Kubernetes API server is reachable from the public internet (locked down with endpoint_public_access_cidrs)."
  type        = bool
  nullable    = false
  default     = true
}

variable "endpoint_private_access" {
  description = "Whether the Kubernetes API server is reachable privately from within the VPC."
  type        = bool
  nullable    = false
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API server endpoint. Only used when endpoint_public_access is true."
  type        = list(string)
  nullable    = false
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for c in var.endpoint_public_access_cidrs : can(cidrhost(c, 0))])
    error_message = "every entry in endpoint_public_access_cidrs must be a valid CIDR."
  }
}

variable "node_groups" {
  description = <<-EOT
    Managed node groups to create, keyed by name. Each group runs in the cluster's subnets and
    scales between min_size and max_size. instance_types and capacity_type (ON_DEMAND or SPOT)
    are per group.
  EOT
  type = map(object({
    instance_types = optional(list(string), ["t3.medium"])
    capacity_type  = optional(string, "ON_DEMAND")
    desired_size   = optional(number, 2)
    min_size       = optional(number, 1)
    max_size       = optional(number, 3)
    disk_size      = optional(number, 20)
    labels         = optional(map(string), {})
  }))
  nullable = false
  default = {
    default = {}
  }

  validation {
    condition     = length(var.node_groups) > 0
    error_message = "at least one node group must be defined."
  }

  validation {
    condition     = alltrue([for g in var.node_groups : contains(["ON_DEMAND", "SPOT"], g.capacity_type)])
    error_message = "each node group capacity_type must be ON_DEMAND or SPOT."
  }

  validation {
    condition     = alltrue([for g in var.node_groups : g.min_size <= g.desired_size && g.desired_size <= g.max_size])
    error_message = "each node group must satisfy min_size <= desired_size <= max_size."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "addons" {
  description = <<-EOT
    EKS managed add-ons to install, keyed by add-on name (e.g. vpc-cni, coredns, kube-proxy,
    eks-pod-identity-agent). Omit a key to leave that add-on unmanaged by this module. Per add-on:
    version (null = EKS default), conflict-resolution strategy on create/update, a JSON
    configuration_values string, and an optional service_account_role_arn for Pod Identity/IRSA.
  EOT
  type = map(object({
    version                     = optional(string)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    configuration_values        = optional(string)
    service_account_role_arn    = optional(string)
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for a in var.addons : contains(["OVERWRITE", "NONE", "PRESERVE"], a.resolve_conflicts_on_create)])
    error_message = "each addon resolve_conflicts_on_create must be OVERWRITE, NONE, or PRESERVE."
  }

  validation {
    condition     = alltrue([for a in var.addons : contains(["OVERWRITE", "NONE", "PRESERVE"], a.resolve_conflicts_on_update)])
    error_message = "each addon resolve_conflicts_on_update must be OVERWRITE, NONE, or PRESERVE."
  }
}
