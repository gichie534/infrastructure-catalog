variable "name" {
  description = "Name of the GKE cluster."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,38}[a-z0-9])?$", var.name))
    error_message = "name must be 1-40 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "project_id" {
  description = "The ID of the project in which to create the cluster."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "region" {
  description = "Region for the regional Autopilot cluster (e.g. us-central1)."
  type        = string
  nullable    = false
}

variable "network" {
  description = "Self link or name of the VPC network to attach the cluster to. Wire this to the vpc module's network_self_link output."
  type        = string
  nullable    = false
}

variable "subnetwork" {
  description = "Self link or name of the subnetwork for the cluster nodes. Wire this to the vpc module's subnets_self_links output."
  type        = string
  nullable    = false
}

variable "pods_range_name" {
  description = "Name of the subnetwork secondary range to use for Pod IPs (VPC-native alias IPs). Matches the vpc module's pods_range_name."
  type        = string
  nullable    = false
  default     = "pods"
}

variable "services_range_name" {
  description = "Name of the subnetwork secondary range to use for Service IPs. Matches the vpc module's services_range_name."
  type        = string
  nullable    = false
  default     = "services"
}

variable "release_channel" {
  description = "GKE release channel that governs cluster version and auto-upgrade cadence. Autopilot clusters must be enrolled in a channel."
  type        = string
  nullable    = false
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "EXTENDED"], var.release_channel)
    error_message = "release_channel must be one of RAPID, REGULAR, STABLE, or EXTENDED."
  }
}

variable "master_ipv4_cidr_block" {
  description = "The /28 CIDR range for the cluster's hosted control plane. Must not overlap with subnet or secondary ranges."
  type        = string
  nullable    = false
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0)) && tonumber(split("/", var.master_ipv4_cidr_block)[1]) == 28
    error_message = "master_ipv4_cidr_block must be a valid /28 CIDR (e.g. 172.16.0.0/28)."
  }
}

variable "enable_private_endpoint" {
  description = "When true, the control plane is reachable only via its private endpoint. Default false keeps a public endpoint (locked down with master_authorized_networks) while nodes stay private."
  type        = bool
  nullable    = false
  default     = false
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to reach the control plane endpoint. Each entry is a display name and a CIDR. An empty list allows no external access."
  type = list(object({
    display_name = string
    cidr_block   = string
  }))
  nullable = false
  default  = []

  validation {
    condition     = alltrue([for n in var.master_authorized_networks : can(cidrhost(n.cidr_block, 0))])
    error_message = "every master_authorized_networks cidr_block must be a valid CIDR."
  }
}

variable "deletion_protection" {
  description = "Whether the cluster is protected from deletion via Terraform. Keep true for real environments; examples/tests set it false."
  type        = bool
  nullable    = false
  default     = true
}

variable "resource_labels" {
  description = "Labels applied to the GKE cluster and the resources it manages."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "enable_secret_manager_addon" {
  description = "Enable the GKE-managed Secret Manager add-on (the Google-managed build of the Secrets Store CSI Driver and its GCP provider). When true, pods may mount Secret Manager secrets as files via a SecretProviderClass referencing the secrets-store-gke.csi.k8s.io driver. Disabled by default to keep the cluster minimal."
  type        = bool
  nullable    = false
  default     = false
}

variable "enable_secret_sync" {
  description = "Enable the SecretSync controller (secret_sync_config) on the cluster. The controller materializes a Secret Manager secret as a Kubernetes Secret (referenced via valueFrom.secretKeyRef / envFrom) given a SecretProviderClass. This is an independent feature from enable_secret_manager_addon — either, both, or neither may be enabled, depending on whether the workload needs file mounts, env-var consumption, or both. Requires a GKE control plane version that supports the feature (1.33+ at the time of writing)."
  type        = bool
  nullable    = false
  default     = false
}
