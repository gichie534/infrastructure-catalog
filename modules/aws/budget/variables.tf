variable "name" {
  description = "Name of the budget. Unique per account, and used verbatim."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 100
    error_message = "name must be 1-100 characters."
  }
}

variable "budget_type" {
  description = "What the budget measures: COST (default), USAGE, or an RI / Savings Plans utilisation or coverage type."
  type        = string
  nullable    = false
  default     = "COST"

  validation {
    condition = contains(
      ["COST", "USAGE", "RI_UTILIZATION", "RI_COVERAGE", "SAVINGS_PLANS_UTILIZATION", "SAVINGS_PLANS_COVERAGE"],
      var.budget_type
    )
    error_message = "budget_type must be one of COST, USAGE, RI_UTILIZATION, RI_COVERAGE, SAVINGS_PLANS_UTILIZATION, SAVINGS_PLANS_COVERAGE."
  }
}

variable "limit_amount" {
  description = "The budget limit, as a string (e.g. \"50\"). AWS takes this as a decimal string, not a number."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?$", var.limit_amount))
    error_message = "limit_amount must be a non-negative decimal string, e.g. \"50\" or \"12.50\"."
  }
}

variable "limit_unit" {
  description = "Unit for `limit_amount`: a currency code such as USD (default) for a COST budget, or the usage unit (e.g. GB) for a USAGE budget."
  type        = string
  nullable    = false
  default     = "USD"
}

variable "time_unit" {
  description = "The period the limit applies to: DAILY, MONTHLY (default), QUARTERLY, or ANNUALLY."
  type        = string
  nullable    = false
  default     = "MONTHLY"

  validation {
    condition     = contains(["DAILY", "MONTHLY", "QUARTERLY", "ANNUALLY"], var.time_unit)
    error_message = "time_unit must be one of DAILY, MONTHLY, QUARTERLY, ANNUALLY."
  }
}

variable "time_period_start" {
  description = "When the budget starts tracking, formatted `YYYY-MM-DD_HH:MM`. Null (default) lets AWS use the start of the chosen period, which is what a recurring budget wants."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.time_period_start == null || can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}:[0-9]{2}$", var.time_period_start))
    error_message = "time_period_start must be formatted YYYY-MM-DD_HH:MM (e.g. 2026-01-01_00:00)."
  }
}

variable "time_period_end" {
  description = "When the budget stops tracking, formatted `YYYY-MM-DD_HH:MM`. Null (default) means it never expires."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.time_period_end == null || can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}:[0-9]{2}$", var.time_period_end))
    error_message = "time_period_end must be formatted YYYY-MM-DD_HH:MM (e.g. 2026-12-31_23:59)."
  }
}

variable "cost_filters" {
  description = <<-EOT
    Map of AWS Budgets filter dimension to values, scoping the budget to a slice of spend. Empty
    (default) covers the whole account.

    Examples: `{ Service = ["Amazon Elastic Compute Cloud - Compute"] }`,
    `{ TagKeyValue = ["user:team$platform"] }`, `{ LinkedAccount = ["123456789012"] }`,
    `{ CostCategories = ["team$platform"] }`.
  EOT
  type        = map(list(string))
  nullable    = false
  default     = {}
}

variable "cost_types" {
  description = <<-EOT
    Which charge classes count toward the limit. Null (default) uses the AWS defaults.

    Worth setting deliberately: the AWS defaults track your net invoice with credits included, so a
    credit-funded account can sit at $0 while consuming real resources. `include_credit = false` makes the
    budget track consumption instead. `use_amortized = true` spreads upfront RI / Savings Plans payments
    across the term rather than charging them to the month they were bought.
  EOT
  type = object({
    include_credit             = optional(bool, null)
    include_discount           = optional(bool, null)
    include_other_subscription = optional(bool, null)
    include_recurring          = optional(bool, null)
    include_refund             = optional(bool, null)
    include_subscription       = optional(bool, null)
    include_support            = optional(bool, null)
    include_tax                = optional(bool, null)
    include_upfront            = optional(bool, null)
    use_amortized              = optional(bool, null)
    use_blended                = optional(bool, null)
  })
  nullable = true
  default  = null
}

variable "notifications" {
  description = <<-EOT
    The thresholds to alert on. A budget with no notifications is invisible, and AWS will happily create
    one, so this input is required and must be non-empty.

      - `threshold` + `threshold_type` — PERCENTAGE (default) of the limit, or ABSOLUTE_VALUE in the
        budget's unit.
      - `notification_type` — ACTUAL (default) fires on spend already incurred; FORECASTED fires on AWS's
        projection for the period, and is the only forward-looking signal budgets offer.
      - `comparison_operator` — GREATER_THAN (default), LESS_THAN, EQUAL_TO.
      - subscribers — fall back to the module-level `subscriber_email_addresses` /
        `subscriber_sns_topic_arns` when left empty, so the channel is declared once per budget rather
        than once per threshold.
  EOT
  type = list(object({
    threshold                  = number
    threshold_type             = optional(string, "PERCENTAGE")
    notification_type          = optional(string, "ACTUAL")
    comparison_operator        = optional(string, "GREATER_THAN")
    subscriber_email_addresses = optional(list(string), [])
    subscriber_sns_topic_arns  = optional(list(string), [])
  }))
  nullable = false

  validation {
    condition     = length(var.notifications) > 0
    error_message = "notifications must not be empty: a budget without one alerts nobody."
  }

  validation {
    condition     = alltrue([for n in var.notifications : contains(["ACTUAL", "FORECASTED"], n.notification_type)])
    error_message = "notification_type must be ACTUAL or FORECASTED."
  }

  validation {
    condition     = alltrue([for n in var.notifications : contains(["PERCENTAGE", "ABSOLUTE_VALUE"], n.threshold_type)])
    error_message = "threshold_type must be PERCENTAGE or ABSOLUTE_VALUE."
  }

  validation {
    condition     = alltrue([for n in var.notifications : contains(["GREATER_THAN", "LESS_THAN", "EQUAL_TO"], n.comparison_operator)])
    error_message = "comparison_operator must be GREATER_THAN, LESS_THAN or EQUAL_TO."
  }

  validation {
    condition     = alltrue([for n in var.notifications : n.threshold > 0])
    error_message = "each notification threshold must be greater than 0."
  }
}

variable "subscriber_email_addresses" {
  description = "Email addresses notified for any threshold that does not list its own subscribers. Lets the channel be declared once per budget."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "subscriber_sns_topic_arns" {
  description = <<-EOT
    SNS topic ARNs notified for any threshold that does not list its own subscribers.

    The topic's resource policy must allow `budgets.amazonaws.com` to `SNS:Publish`, otherwise the publish
    is denied silently and nothing is delivered. The `aws/sns-topic` module handles that grant.
  EOT
  type        = list(string)
  nullable    = false
  default     = []
}

variable "tags" {
  description = "Tags applied to the budget."
  type        = map(string)
  nullable    = false
  default     = {}
}
