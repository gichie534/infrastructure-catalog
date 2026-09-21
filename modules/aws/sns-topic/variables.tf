variable "name" {
  description = "Name of the SNS topic. Must be unique per account and region."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,256}$", var.name))
    error_message = "name must be 1-256 characters of alphanumerics, hyphens or underscores."
  }
}

variable "display_name" {
  description = "Optional friendly name for the topic. It is what recipients see as the sender label on email notifications, so a readable value ('FinOps alerts') is worth setting. Default null leaves it unset."
  type        = string
  nullable    = true
  default     = null
}

variable "kms_master_key_id" {
  description = <<-EOT
    Optional KMS key id/alias/ARN for server-side encryption of messages at rest. Default null = no
    encryption.

    Important when AWS services publish to this topic (see `allowed_service_principals`): the
    AWS-managed key `alias/aws/sns` will NOT work, because its key policy cannot be edited to grant
    a service principal `kms:GenerateDataKey*`/`kms:Decrypt`. Messages are silently dropped. Use a
    customer-managed key whose policy grants those actions to the same principals, or leave
    encryption off.
  EOT
  type        = string
  nullable    = true
  default     = null
}

variable "allowed_service_principals" {
  description = <<-EOT
    AWS service principals allowed to publish to this topic, e.g.
    `["budgets.amazonaws.com", "costalerts.amazonaws.com"]`. Empty (default) adds no service
    statements.

    A service publishing to SNS is doing so as the service, not as your IAM identity, so it needs an
    explicit resource-policy grant — an IAM policy on your side cannot substitute for it. This is the
    single most common reason a budget or anomaly alert never arrives.
  EOT
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for p in var.allowed_service_principals : can(regex("^[a-z0-9.-]+\\.amazonaws\\.com$", p))])
    error_message = "each entry must be an AWS service principal ending in .amazonaws.com."
  }
}

variable "restrict_service_publish_to_source_account" {
  description = <<-EOT
    When true, service-principal publish statements are conditioned on
    `aws:SourceAccount` matching this account, so another account's copy of the same service cannot
    publish here. Default false.

    Off by default deliberately: a service that does not populate `aws:SourceAccount` on its publish
    call is silently denied, and not every billing service documents that it does. Turn it on only
    after confirming alerts still arrive. AWS Budgets documents support for it; Cost Anomaly
    Detection does not.
  EOT
  type        = bool
  nullable    = false
  default     = false
}

variable "include_default_owner_statement" {
  description = <<-EOT
    When true (default), the generated topic policy includes the equivalent of the policy AWS attaches
    to a new topic: the owning account may manage and publish to the topic, conditioned on
    `AWS:SourceOwner`.

    Attaching any topic policy REPLACES the AWS default, so leaving this off while setting
    `allowed_service_principals` produces a topic whose resource policy grants the service but not
    you. Only set false if you intend that.
  EOT
  type        = bool
  nullable    = false
  default     = true
}

variable "topic_policy" {
  description = <<-EOT
    Optional raw topic policy as a JSON string. When set it is attached verbatim and every generated
    statement (`allowed_service_principals`, `include_default_owner_statement`) is ignored — the
    escape hatch for a policy this module's inputs cannot express. Default null uses the generated
    policy.
  EOT
  type        = string
  nullable    = true
  default     = null
}

variable "email_subscribers" {
  description = <<-EOT
    Email addresses subscribed to the topic. Empty (default) creates no subscriptions.

    Each address receives an AWS confirmation email and must click through before any notification is
    delivered. Terraform cannot do that for you: the subscription applies successfully and sits at
    `PendingConfirmation`, so a silent alert channel is the expected state until someone confirms.
  EOT
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for e in var.email_subscribers : can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[a-zA-Z]{2,}$", e))])
    error_message = "each email_subscribers entry must look like an email address."
  }
}

variable "tags" {
  description = "Tags applied to the SNS topic."
  type        = map(string)
  nullable    = false
  default     = {}
}
