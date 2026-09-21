variable "bucket_name" {
  description = "Name of the S3 bucket. Must be globally unique and DNS-compliant (3-63 chars, lowercase letters, numbers, dots, and hyphens; start/end alphanumeric)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 chars, lowercase alphanumeric plus dots/hyphens, and start and end alphanumeric."
  }
}

variable "force_destroy" {
  description = <<-EOT
    Whether to allow Terraform to delete the bucket even when it still contains objects. Leave `false`
    for anything you care about; set `true` in throwaway lab environments so `terraform destroy`
    tears down cleanly without a manual empty step.
  EOT
  type        = bool
  nullable    = false
  default     = false
}

variable "bucket_policy" {
  description = <<-EOT
    Optional bucket policy as a JSON string. When set, the module attaches it via an
    `aws_s3_bucket_policy` — the raw passthrough mirrors how `iam-instance-profile` takes inline
    policies. Typically produced from an `aws_iam_policy_document` data source (e.g. an ABAC policy
    matching `aws:PrincipalTag/*`). When null (the default) no bucket policy is created.
  EOT
  type        = string
  nullable    = true
  default     = null
}

variable "cors_rules" {
  description = <<-EOT
    Optional CORS rules for the bucket. Empty (default) creates no CORS configuration. Each rule sets
    the allowed methods and origins (required) plus optional allowed/exposed headers and a max age.
    Typically needed so a browser can PUT directly to a presigned upload URL from a web page served on
    a different origin.
  EOT
  type = list(object({
    allowed_headers = optional(list(string), [])
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3600)
  }))
  nullable = false
  default  = []
}

variable "lifecycle_rules" {
  description = <<-EOT
    Optional object-lifecycle rules. Empty (default) creates no lifecycle configuration at all, so
    existing consumers are unaffected. Each rule needs a unique `id`; every other field is optional,
    and a rule that sets none of the expiry/transition fields is rejected (it would be a no-op).

    `prefix` scopes the rule to a key prefix — null or "" applies it to every object in the bucket.
    `transitions` moves objects to a cheaper storage class after N days (e.g. STANDARD_IA at 30,
    GLACIER_IR at 90); `expiration_days` deletes them outright.
    `abort_incomplete_multipart_upload_days` cleans up failed multipart uploads, which are invisible
    in the console but still billed — worth setting on any bucket that receives large objects.

    Typical use: keep a cost/usage export or log bucket from growing without bound.
  EOT
  type = list(object({
    id                                     = string
    enabled                                = optional(bool, true)
    prefix                                 = optional(string, null)
    expiration_days                        = optional(number, null)
    noncurrent_version_expiration_days     = optional(number, null)
    abort_incomplete_multipart_upload_days = optional(number, null)
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
  }))
  nullable = false
  default  = []

  validation {
    condition     = length(distinct([for r in var.lifecycle_rules : r.id])) == length(var.lifecycle_rules)
    error_message = "each lifecycle rule id must be unique."
  }

  validation {
    condition = alltrue([
      for r in var.lifecycle_rules :
      r.expiration_days != null ||
      r.noncurrent_version_expiration_days != null ||
      r.abort_incomplete_multipart_upload_days != null ||
      length(r.transitions) > 0
    ])
    error_message = "each lifecycle rule must set at least one of expiration_days, noncurrent_version_expiration_days, abort_incomplete_multipart_upload_days, or transitions."
  }

  validation {
    condition = alltrue(flatten([
      for r in var.lifecycle_rules : [
        for t in r.transitions : contains(
          ["STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER_IR", "GLACIER", "DEEP_ARCHIVE"],
          t.storage_class
        )
      ]
    ]))
    error_message = "transition storage_class must be one of STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, GLACIER_IR, GLACIER, DEEP_ARCHIVE."
  }
}

variable "tags" {
  description = "Tags applied to the S3 bucket."
  type        = map(string)
  nullable    = false
  default     = {}
}
