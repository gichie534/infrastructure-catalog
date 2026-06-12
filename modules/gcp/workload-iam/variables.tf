variable "project_id" {
  description = "The ID of the project that owns the workload's Google service account and the secrets it accesses."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "account_id" {
  description = "The account_id (local part) of the workload Google service account to create. The full email becomes <account_id>@<project_id>.iam.gserviceaccount.com."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.account_id))
    error_message = "account_id must be 6 to 30 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace of the service account that impersonates the GSA via Workload Identity."
  type        = string
  nullable    = false
}

variable "kubernetes_service_account" {
  description = "Kubernetes service account name (within kubernetes_namespace) that the pod runs as and that impersonates the GSA."
  type        = string
  nullable    = false
}

variable "secret_ids" {
  description = "Secret Manager secrets the workload may read, as a map of arbitrary stable label => fully-qualified secret ID (projects/<project>/secrets/<name>). Wire each value from a secret-manager module's secret_id output. The map keys must be known at plan time (don't derive them from resource attributes). The GSA is granted roles/secretmanager.secretAccessor on each."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "project_roles" {
  description = "Project-level IAM roles to grant the workload GSA (e.g. roles/cloudsql.client and roles/cloudsql.instanceUser for Cloud SQL IAM auth). Resource-scoped access (like secret access) is handled by its own input, not here."
  type        = set(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for r in var.project_roles : startswith(r, "roles/")])
    error_message = "each project_roles entry must be a role ID starting with roles/."
  }
}

variable "bucket_iam" {
  description = "GCS bucket access to grant the workload GSA, as a map of arbitrary stable label => { bucket, role } (e.g. role roles/storage.objectViewer or roles/storage.objectUser). Wire bucket from the gcs-bucket module's name output. The map keys must be known at plan time. Each entry becomes a bucket-scoped IAM member."
  type = map(object({
    bucket = string
    role   = string
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for b in var.bucket_iam : startswith(b.role, "roles/storage.")])
    error_message = "each bucket_iam role must be a Cloud Storage role starting with roles/storage."
  }
}

variable "artifact_registry_repositories" {
  description = "Artifact Registry repositories the workload may pull from, as a map of arbitrary stable label => fully-qualified repository name (projects/<p>/locations/<loc>/repositories/<id>). Wire each value from an artifact-registry module's name output. The map keys must be known at plan time. The GSA is granted roles/artifactregistry.reader on each. Note: GKE image pulls usually authenticate as the node service account, not the workload GSA."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "display_name" {
  description = "Human-readable display name for the workload service account."
  type        = string
  nullable    = false
  default     = "Workload identity service account"
}
