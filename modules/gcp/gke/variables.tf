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

variable "secret_manager_addon_rotation" {
  description = "Automatic rotation for the Secret Manager add-on's mounted volumes: periodically re-fetches secret values so mounted files pick up a new version without a pod restart. Ignored unless enable_secret_manager_addon is true. enabled defaults to true (rotation on); rotation_interval is a duration string (e.g. \"120s\") and defaults to the API's own default (2 minutes) when null."
  type = object({
    enabled           = optional(bool, true)
    rotation_interval = optional(string)
  })
  nullable = false
  default  = {}

  validation {
    condition     = var.secret_manager_addon_rotation.rotation_interval == null || can(regex("^[0-9]+(\\.[0-9]+)?s$", var.secret_manager_addon_rotation.rotation_interval))
    error_message = "secret_manager_addon_rotation.rotation_interval must be a duration string in seconds, e.g. \"120s\"."
  }
}

variable "enable_secret_sync" {
  description = "Enable the SecretSync controller (secret_sync_config) on the cluster. The controller materializes a Secret Manager secret as a Kubernetes Secret (referenced via valueFrom.secretKeyRef / envFrom) given a SecretProviderClass. This is an independent feature from enable_secret_manager_addon — either, both, or neither may be enabled, depending on whether the workload needs file mounts, env-var consumption, or both. Requires a GKE control plane version that supports the feature (1.33+ at the time of writing)."
  type        = bool
  nullable    = false
  default     = false
}

variable "secret_sync_rotation" {
  description = "Automatic rotation for SecretSync-materialized Kubernetes Secrets: periodically checks Secret Manager for a new secret version and updates the Kubernetes Secret's data (consumers must detect and reload it themselves — this does not restart pods). Ignored unless enable_secret_sync is true. enabled defaults to true (rotation on); rotation_interval is a duration string (e.g. \"120s\") and defaults to the API's own default (2 minutes) when null."
  type = object({
    enabled           = optional(bool, true)
    rotation_interval = optional(string)
  })
  nullable = false
  default  = {}

  validation {
    condition     = var.secret_sync_rotation.rotation_interval == null || can(regex("^[0-9]+(\\.[0-9]+)?s$", var.secret_sync_rotation.rotation_interval))
    error_message = "secret_sync_rotation.rotation_interval must be a duration string in seconds, e.g. \"120s\"."
  }
}

variable "create_node_service_account" {
  description = <<-EOT
    Create a dedicated, least-privilege service account for the cluster's nodes and grant it
    node_service_account_roles on project_id. When false (the default, which preserves the behaviour
    of earlier versions of this module) GKE falls back to the project's Compute Engine default
    service account.

    That fallback is a trap on projects created after Google stopped automatically granting
    roles/editor to the Compute Engine default service account (and on any project where the
    iam.automaticIamGrantsForDefaultServiceAccounts org policy is enforced): the default account then
    holds no roles at all, nodes boot but cannot register, the control plane deletes them, and the
    cluster sits RUNNING with zero nodes while every pod stays Pending. The console surfaces this
    only as an advisory to "grant roles/container.defaultNodeServiceAccount to the Node service
    account".

    Set this true to make the node identity explicit and owned by Terraform. Takes precedence over
    node_service_account.
  EOT
  type        = bool
  nullable    = false
  default     = false
}

variable "node_service_account" {
  description = "Email of an existing service account to run the cluster's nodes as. It must already hold roles/container.defaultNodeServiceAccount on the project. Ignored when create_node_service_account is true. Leave null to let GKE use the Compute Engine default service account."
  type        = string
  default     = null

  validation {
    condition     = var.node_service_account == null || can(regex("^[^@]+@[^@]+\\.iam\\.gserviceaccount\\.com$|^[^@]+@developer\\.gserviceaccount\\.com$", var.node_service_account))
    error_message = "node_service_account must be a service account email, e.g. nodes@my-project.iam.gserviceaccount.com."
  }
}

variable "node_service_account_id" {
  description = "Account ID (the local part of the email) for the service account created when create_node_service_account is true. Defaults to \"<name>-nodes\", truncated to the 30-character limit."
  type        = string
  default     = null

  validation {
    condition     = var.node_service_account_id == null || can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.node_service_account_id))
    error_message = "node_service_account_id must be 6-30 characters, lowercase letters, numbers or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "node_service_account_roles" {
  description = "Project-level roles granted to the service account created when create_node_service_account is true. The default is the minimum GKE requires for nodes to register and run system tasks such as logging, monitoring and image pulls; add to it for workloads that need more (e.g. roles/artifactregistry.reader for a private registry in another project)."
  type        = list(string)
  nullable    = false
  default     = ["roles/container.defaultNodeServiceAccount"]

  validation {
    condition     = alltrue([for r in var.node_service_account_roles : can(regex("^(roles/|projects/[^/]+/roles/|organizations/[0-9]+/roles/)", r))])
    error_message = "every entry in node_service_account_roles must be a role name, e.g. roles/container.defaultNodeServiceAccount."
  }
}
