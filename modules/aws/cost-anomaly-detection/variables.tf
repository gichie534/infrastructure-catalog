variable "monitors" {
  description = <<-EOT
    Cost monitors to create, keyed by monitor name (used verbatim). Empty (default) creates none — use
    that together with a subscription's `monitor_arns` to attach alerts to a monitor you do not manage.

    A monitor defines WHAT is watched; it does not notify anyone on its own — that is a subscription.

      - `monitor_type` — DIMENSIONAL watches every value of one dimension; CUSTOM (default) watches an
        arbitrary Cost Explorer expression.
      - `monitor_dimension` — required for DIMENSIONAL. `SERVICE` is the usual choice.
      - `monitor_specification` — required for CUSTOM: a Cost Explorer `Expression` as a JSON string.

    **Read this before creating a DIMENSIONAL monitor.** AWS allows exactly
    [one AWS-managed monitor for AWS services per account](https://docs.aws.amazon.com/cost-management/latest/userguide/management-limits.html),
    and it creates that monitor for you when Cost Anomaly Detection is enabled. So on essentially any
    real account, creating a `DIMENSIONAL`/`SERVICE` monitor fails with
    `ValidationException: Limit exceeded on dimensional spend monitor creation`. The fix is not a bigger
    quota — it is to stop creating one and point your subscriptions at the monitor that already exists
    via `monitor_arns`. The default is CUSTOM for that reason: customer-managed monitors are limited to
    500 per account, so they compose freely.

    Monitors on linked account, cost allocation tag, or cost category can only be created from an AWS
    Organizations management account.
  EOT

  type = map(object({
    monitor_type          = optional(string, "CUSTOM")
    monitor_dimension     = optional(string, null)
    monitor_specification = optional(string, null)
  }))

  nullable = false
  default  = {}

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
      - `monitor_keys` — monitors from this module's `monitors`, by key.
      - `monitor_arns` — monitors this module does NOT manage, by ARN. This is how you attach alerts to
        the AWS-managed "AWS services" monitor that already exists in your account (see `monitors`).
      - When both `monitor_keys` and `monitor_arns` are empty, the subscription covers every monitor in
        `monitors`. Setting either one means "exactly what I listed" — the two are unioned, never
        combined with the implicit all.
      - `email_subscribers` / `sns_topic_arns` — the recipients. AWS permits at most 1 SNS topic and 10
        email recipients per subscription.
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
    monitor_arns                = optional(list(string), [])
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

  # AWS quota: 1 SNS topic per subscription. Exceeding it fails at apply with a validation error, so
  # catch it at plan time. Fan-out to several destinations is the topic's job, not the subscription's.
  validation {
    condition     = alltrue([for s in var.subscriptions : length(s.sns_topic_arns) <= 1])
    error_message = "AWS allows at most 1 SNS topic per alert subscription: use one topic and fan out from there."
  }

  # AWS quota: 10 email recipients per subscription.
  validation {
    condition     = alltrue([for s in var.subscriptions : length(s.email_subscribers) <= 10])
    error_message = "AWS allows at most 10 email recipients per alert subscription."
  }
}

variable "tags" {
  description = "Tags applied to every monitor and subscription."
  type        = map(string)
  nullable    = false
  default     = {}
}
