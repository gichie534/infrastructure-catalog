variable "project_id" {
  description = "Project to create the dataset in."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "dataset_id" {
  description = "Dataset ID: letters, digits and underscores only (no hyphens — a common trip-up coming from other GCP resource names)."
  type        = string
  nullable    = false

  validation {
    # Length checked separately: RE2 caps a repetition count at 1000, so {1,1024} would not even compile.
    condition     = can(regex("^[A-Za-z0-9_]+$", var.dataset_id)) && length(var.dataset_id) <= 1024
    error_message = "dataset_id may contain only letters, digits and underscores (max 1024)."
  }
}

variable "location" {
  description = <<-EOT
    Dataset location: a multi-region (`US`, `EU`) or a region (`us-central1`). Immutable after creation.

    For a Cloud Billing export this choice is not cosmetic: only a multi-region dataset receives the
    current and previous month retroactively when the export is first enabled. A regional dataset gets
    data from the day of enablement only.
  EOT
  type        = string
  nullable    = false
}

variable "friendly_name" {
  description = "Human-readable name shown in the console."
  type        = string
  nullable    = true
  default     = null
}

variable "description" {
  description = "Dataset description."
  type        = string
  nullable    = true
  default     = null
}

variable "default_table_expiration_ms" {
  description = "Default lifetime of NEW tables, in ms. Null (default) = tables never expire. Leave null for a billing export: Google warns that an expired export table cannot be backfilled."
  type        = number
  nullable    = true
  default     = null

  validation {
    condition     = var.default_table_expiration_ms == null || try(var.default_table_expiration_ms >= 3600000, false)
    error_message = "default_table_expiration_ms must be at least 3600000 (one hour)."
  }
}

variable "default_partition_expiration_ms" {
  description = "Default lifetime of partitions in NEW partitioned tables, in ms. Null (default) = partitions never expire. This is how retention is bounded on a time-partitioned table without deleting the table."
  type        = number
  nullable    = true
  default     = null
}

variable "delete_contents_on_destroy" {
  description = "Whether `destroy` deletes the dataset even if it contains tables. Default false, because for data that cannot be recreated (a billing export) losing it to a routine teardown is the worst outcome."
  type        = bool
  nullable    = false
  default     = false
}

variable "kms_key_name" {
  description = "CMEK key for the dataset default. Null (default) = Google-managed encryption. Immutable in practice: changing it later does not re-encrypt existing tables."
  type        = string
  nullable    = true
  default     = null
}

variable "iam_members" {
  description = "Additive dataset-level grants, e.g. `{ role = \"roles/bigquery.dataViewer\", member = \"group:finops@example.com\" }`. Never authoritative — see main.tf for why."
  type = list(object({
    role   = string
    member = string
  }))
  nullable = false
  default  = []

  validation {
    condition     = alltrue([for b in var.iam_members : startswith(b.role, "roles/")])
    error_message = "each iam_members role must be a role name like roles/bigquery.dataViewer."
  }
}

variable "labels" {
  description = "Labels applied to the dataset."
  type        = map(string)
  nullable    = false
  default     = {}
}
