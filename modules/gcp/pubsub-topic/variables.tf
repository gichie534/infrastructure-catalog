variable "project_id" {
  description = "Project to create the topic (and subscriptions) in."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "name" {
  description = "Topic name (the short ID, not the full resource name)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9._~%+-]{2,254}$", var.name)) && !startswith(lower(var.name), "goog")
    error_message = "name must be 3-255 characters, start with a letter, use only letters, digits and - _ . ~ + %, and not start with 'goog'."
  }
}

variable "publisher_members" {
  description = <<-EOT
    IAM members granted roles/pubsub.publisher on the topic, e.g.
    `serviceAccount:billing-budget-alert@system.gserviceaccount.com` for Cloud Billing budget messages.

    Additive grants: anything already on the topic is left alone. On an organization that enforces
    `iam.allowedPolicyMemberDomains`, a Google-owned service account is outside your domain and the grant
    is rejected — the project needs an exemption.
  EOT
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for m in var.publisher_members : can(regex("^(serviceAccount|user|group|domain|principal|principalSet):.+$", m))])
    error_message = "publisher_members entries must be IAM member strings such as serviceAccount:<email>."
  }
}

variable "pull_subscriptions" {
  description = <<-EOT
    Pull subscriptions to create, keyed by subscription name. Without at least one subscription the topic
    discards every message published to it.

      - `ack_deadline_seconds` (default 60)
      - `message_retention_duration` (default "604800s", 7 days — the maximum)
      - `retain_acked_messages` (default false)
      - `expiration_ttl` (default "" = never expire). Google's own default deletes a subscription after
        31 days without activity, which is what a quiet alert feed looks like.
  EOT
  type = map(object({
    ack_deadline_seconds       = optional(number, 60)
    message_retention_duration = optional(string, "604800s")
    retain_acked_messages      = optional(bool, false)
    expiration_ttl             = optional(string, "")
  }))
  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for k, v in var.pull_subscriptions : v.ack_deadline_seconds >= 10 && v.ack_deadline_seconds <= 600])
    error_message = "ack_deadline_seconds must be between 10 and 600."
  }

  validation {
    condition     = alltrue([for k, v in var.pull_subscriptions : can(regex("^[0-9]+s$", v.message_retention_duration))])
    error_message = "message_retention_duration must be a duration in seconds, e.g. \"604800s\"."
  }
}

variable "message_retention_duration" {
  description = "How long the TOPIC retains messages (so a subscription created later can seek back). Null (default) = no topic-level retention, which is free."
  type        = string
  nullable    = true
  default     = null
}

variable "kms_key_name" {
  description = "CMEK key for the topic. Null (default) = Google-managed encryption. A CMEK key also needs the Pub/Sub service agent granted on it, which is the consumer's job."
  type        = string
  nullable    = true
  default     = null
}

variable "labels" {
  description = "Labels applied to the topic and its subscriptions."
  type        = map(string)
  nullable    = false
  default     = {}
}
