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

variable "tags" {
  description = "Tags applied to the S3 bucket."
  type        = map(string)
  nullable    = false
  default     = {}
}
