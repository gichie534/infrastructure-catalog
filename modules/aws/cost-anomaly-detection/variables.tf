variable "monitors" {
  description = <<-EOT
    Cost monitors to create, keyed by monitor name (used verbatim).

    A monitor defines WHAT is watched; it does not notify anyone on its own — that is a subscription.

      - `monitor_type` — DIMENSIONAL (default) watches every value of one dimension; CUSTOM watches an
        arbitrary Cost Explorer expression.
      - `monitor_dimension` — required for DIMENSIONAL. `SERVICE` (default) is the one the API
        documents for a standalone account, and it is the right default: it tracks every service you
        use, including ones you did not know you had turned on.
      - `monitor_specification` — required for CUSTOM: a Cost Explorer `Expression` as a JSON string.

    Note that monitors on linked account, cost allocation tag, or cost category can only be created
    from an AWS Organizations management account.
  EOT

  type = map(object({
    monitor_type          = optional(string, "DIMENSIONAL")
    monitor_dimension     = optional(string, "SERVICE")
    monitor_specification = optional(string, null)
  }))

  nullable = false

  validation {
    condition     = alltrue([for m in var.monitors : contains(["DIMENSIONAL", "CUSTOM"], m.monitor_type)])
    error_message = "monitor_type must be DIMENSIONAL or CUSTOM."
  }

  validation {
    condition = alltrue([
      for m in var.monitors :
      m.monitor_type != "DIMENSIONAL" || (m.monitor_dimension != null && m.monitor_specification == null)
    ])
    error_message = "a DIMENSIONAL monitor needs monitor_dimension and must not set monitor_specification."
  }

  validation {
    condition = alltrue([
      for m in var.monitors :
      m.monitor_type != "CUSTOM" || m.monitor_specification != null
    ])
    error_message = "a CUSTOM monitor needs monitor_specification (a Cost Explorer Expression as JSON)."
  }
}

variable "subscriptions" {
  description = <<-EOT
    Alert subscriptions, keyed by subscription name (used verbatim). Every monitor needs at least one
    subscription or nothing is ever delivered.

      - `frequency` — IMMEDIATE, DAILY (default), or WEEKLY. AWS ties the channel to the frequency:
        IMMEDIATE is delivered only via SNS, DAILY and WEEKLY only by email. The module rejects the
        wrong pairing rather than letting you create a silent subscription.
      - `monitor_keys` — which monitors this subscribes to, by their key in `monitors`. Empty (default)
        subscribes to all of them.
      - `email_subscribers` / `sns_topic_arns` — the recipients.
      - `absolute_impact_threshold` — alert when the anomaly's dollar impact is at least this much.
      - `percentage_impact_threshold` — alert when actual spend exceeds expected by at least this
        percentage.
      - `threshold_combinator` — OR (default) or AND, when both thresholds are set.

    At least one threshold is required: AWS needs a threshold expression, and there is no sensible
    default dollar figure a module could pick for you. A percentage alone fires on a $2 anomaly that
    tripled; an absolute alone misses a steady 30% overspend. OR-ing a small absolute floor with a
    percentage is the usual starting point.
  EOT

  type = map(object({
    frequency                   = optional(string, "DAILY")
    monitor_keys                = optional(list(string), [])
    email_subscribers           = optional(list(string), [])
    sns_topic_arns              = optional(list(string), [])
    absolute_impact_threshold   = optional(number, null)
    percentage_impact_threshold = optional(number, null)
    threshold_combinator        = optional(string, "OR")
  }))

  nullable = false

  validation {
    condition     = alltrue([for s in var.subscriptions : contains(["IMMEDIATE", "DAILY", "WEEKLY"], s.frequency)])
    error_message = "frequency must be IMMEDIATE, DAILY or WEEKLY."
  }

  validation {
    condition     = alltrue([for s in var.subscriptions : contains(["OR", "AND"], s.threshold_combinator)])
    error_message = "threshold_combinator must be OR or AND."
  }

  validation {
    condition = alltrue([
      for s in var.subscriptions :
      s.absolute_impact_threshold != null || s.percentage_impact_threshold != null
    ])
    error_message = "each subscription needs absolute_impact_threshold and/or percentage_impact_threshold — AWS requires a threshold expression."
  }

  validation {
    condition = alltrue([
      for s in var.subscriptions :
      s.frequency != "IMMEDIATE" || length(s.sns_topic_arns) > 0
    ])
    error_message = "an IMMEDIATE subscription is delivered only via SNS: set sns_topic_arns."
  }

  validation {
    condition = alltrue([
      for s in var.subscriptions :
      !contains(["DAILY", "WEEKLY"], s.frequency) || length(s.email_subscribers) > 0
    ])
    error_message = "a DAILY or WEEKLY summary is delivered only by email: set email_subscribers."
  }

  validation {
    condition = alltrue([
      for s in var.subscriptions :
      s.absolute_impact_threshold == null || s.absolute_impact_threshold > 0
    ])
    error_message = "absolute_impact_threshold must be greater than 0."
  }

  validation {
    condition = alltrue([
      for s in var.subscriptions :
      s.percentage_impact_threshold == null || s.percentage_impact_threshold > 0
    ])
    error_message = "percentage_impact_threshold must be greater than 0."
  }
}

variable "tags" {
  description = "Tags applied to every monitor and subscription."
  type        = map(string)
  nullable    = false
  default     = {}
}
