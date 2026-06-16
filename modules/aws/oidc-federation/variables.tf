variable "provider_url" {
  description = <<-EOT
    The OIDC issuer URL of the single identity provider this module instance creates (e.g.
    https://token.actions.githubusercontent.com). The module is IdP-neutral — point it at GitHub
    Actions, GitLab CI, Terraform Cloud, or any OIDC issuer.

    ONE PROVIDER PER INSTANCE: this module creates exactly one IAM OIDC provider. If you need to
    federate more than one issuer, instantiate the module once per issuer (e.g. a separate Terragrunt
    unit each).

    SHARING CAVEAT: an AWS account may hold only ONE OIDC provider per issuer URL. This module is
    create-only, so if the provider already exists in the account (created by another stack/unit),
    apply will collide. Import it into this state or have a single owner create it.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.provider_url, "https://")
    error_message = "provider_url must be an https:// URL."
  }
}

variable "client_id_list" {
  description = <<-EOT
    Accepted audiences (the token `aud` claim) for the OIDC provider. For GitHub Actions this is
    ["sts.amazonaws.com"] unless you override the requested audience.
  EOT
  type        = list(string)
  nullable    = false
  default     = ["sts.amazonaws.com"]

  validation {
    condition     = length(var.client_id_list) > 0
    error_message = "client_id_list must contain at least one audience."
  }
}

variable "thumbprint_list" {
  description = <<-EOT
    OPTIONAL server-certificate thumbprints for the OIDC provider. For the well-known IdPs (GitHub,
    GitLab, etc.) AWS uses its own trust store and a thumbprint is not required — leave this empty.
    Supply thumbprints only for a private/self-hosted issuer AWS doesn't already trust.
  EOT
  type        = list(string)
  nullable    = false
  default     = []
}

variable "roles" {
  description = <<-EOT
    IAM roles assumable via OIDC web identity federation against this module's provider, keyed by a
    stable label. Each role is gated by subject conditions — the direct-federation pattern: external
    CI assumes the role itself with a short-lived OIDC token, no long-lived access keys.

    - subjects:            allowed values of the token `sub` claim (StringLike, so wildcards work).
                           For GitHub Actions the sub looks like "repo:OWNER/REPO:ref:refs/heads/main"
                           or "repo:OWNER/REPO:environment:prod"; use "repo:OWNER/REPO:*" to allow any
                           workflow in a repo. ALWAYS scope this — never leave it open to all repos.
    - audiences:           OPTIONAL override of the audience condition (`aud`). Defaults to the
                           provider's client_id_list, which is what you want almost always.
    - managed_policy_arns: AWS-managed or customer-managed policy ARNs to attach to the role.
    - inline_policy:       OPTIONAL inline policy JSON for permissions you don't have a managed
                           policy for (scope-downs, single-resource grants). null = no inline policy.
    - max_session_seconds: OPTIONAL max session duration (default 3600).
  EOT
  type = map(object({
    subjects            = list(string)
    audiences           = optional(list(string))
    managed_policy_arns = optional(list(string), [])
    inline_policy       = optional(string)
    max_session_seconds = optional(number, 3600)
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for r in values(var.roles) : length(r.subjects) > 0])
    error_message = "each role must list at least one subject — refusing to trust all subjects of a provider."
  }
}

variable "name_prefix" {
  description = "Prefix applied to created IAM role names, keeping them grouped and collision-resistant in the account."
  type        = string
  nullable    = false
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]*$", var.name_prefix))
    error_message = "name_prefix may contain only characters valid in an IAM role name."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module."
  type        = map(string)
  nullable    = false
  default     = {}
}
