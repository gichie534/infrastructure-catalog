variable "project_id" {
  description = "The ID of the project that owns the workload identity pool (always <project_id>.svc.id.goog for a GKE cluster in this project) and, by default, the resources being granted."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "project_number" {
  description = "The NUMBER (not ID) of the project that owns the GKE cluster. It forms the workload identity pool path in the principal string. Find it with: gcloud projects describe <project_id> --format='value(projectNumber)'."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+$", var.project_number))
    error_message = "project_number must be all digits."
  }
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace of the service account the workload runs as."
  type        = string
  nullable    = false
}

variable "kubernetes_service_account" {
  description = "Kubernetes service account name (within kubernetes_namespace) the pod runs as. IAM roles are granted directly to this KSA's federated principal — no Google service account is created or impersonated."
  type        = string
  nullable    = false
}

variable "bucket_iam" {
  description = "GCS bucket access to grant the KSA principal directly, as a map of arbitrary stable label => { bucket, role } (e.g. role roles/storage.objectViewer). Wire bucket from the gcs module's name output. Map keys must be known at plan time. Each entry becomes a bucket-scoped IAM member on the KSA principal."
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

variable "project_roles" {
  description = "Project-level IAM roles to grant the KSA principal directly (e.g. roles/logging.logWriter). Resource-scoped access (like a single bucket) is handled by its own input, not here."
  type        = set(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for r in var.project_roles : startswith(r, "roles/")])
    error_message = "each project_roles entry must be a role ID starting with roles/."
  }
}
