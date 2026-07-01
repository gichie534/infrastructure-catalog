variable "name" {
  description = "Name for the IAM role and instance profile. Both resources share this name."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]{1,128}$", var.name))
    error_message = "name must be 1-128 chars of the IAM name character set ([a-zA-Z0-9+=,.@_-])."
  }
}

variable "managed_policy_arns" {
  description = <<-EOT
    ARNs of existing (AWS-managed or customer-managed) IAM policies to attach to the role. Use this
    for capabilities that AWS already ships a policy for — e.g. `AmazonSSMManagedInstanceCore` to let
    the instance be reached via SSM Session Manager. Empty by default.
  EOT
  type        = list(string)
  nullable    = false
  default     = []
}

variable "inline_policies" {
  description = <<-EOT
    Map of inline least-privilege policies to embed in the role, keyed by policy name. Each value is
    a JSON IAM policy document (typically from an `aws_iam_policy_document` data source). Use this for
    the narrow, workload-specific grants that don't warrant a standalone managed policy — e.g. a
    single `s3:ListAllMyBuckets` statement. Empty by default.
  EOT
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "tags" {
  description = "Tags applied to the IAM role (the taggable resource this module creates)."
  type        = map(string)
  nullable    = false
  default     = {}
}
