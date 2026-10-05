variable "billing_account" {
  description = "ID of the Cloud Billing account the budget belongs to, e.g. `012345-6789AB-CDEF01`. The bare ID, not `billingAccounts/<id>`."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}$", var.billing_account))
    error_message = "billing_account must be a bare billing account ID like 012345-6789AB-CDEF01 (no billingAccounts/ prefix)."
  }
}

variable "display_name" {
  description = "Display name of the budget. Unlike an AWS budget name it is not unique — Google identifies budgets by a generated ID — so pick something you can find in the console."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.display_name) > 0 && length(var.display_name) <= 60
    error_message = "display_name must be 1-60 characters."
  }
}

variable "amount" {
  description = "The budget amount per period, in the billing account's currency (e.g. 50 or 12.5). Set this OR `use_last_period_amount`, not both."
  type        = number
  nullable    = true
  default     = null

  validation {
    condition     = var.amount == null || try(var.amount > 0, false)
    error_message = "amount must be greater than 0."
  }
}

variable "use_last_period_amount" {
  description = "Set the budget to 100% of last period's spend instead of a fixed `amount`. Useful as a \"did anything change\" tripwire; useless on a new billing account with no last period."
  type        = bool
  nullable    = false
  default     = false
}

variable "currency_code" {
  description = "ISO 4217 currency code for `amount`. Null (default) uses the billing account's currency. If set it MUST match the billing account's currency, otherwise the API rejects the budget."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.currency_code == null || can(regex("^[A-Z]{3}$", var.currency_code))
    error_message = "currency_code must be a 3-letter uppercase ISO 4217 code, e.g. USD."
  }
}

variable "calendar_period" {
  description = "Recurring period the amount applies to: MONTH (default), QUARTER, or YEAR. Periods start at 12 AM US Pacific time, not UTC. Ignored when `custom_period` is set."
  type        = string
  nullable    = false
  default     = "MONTH"

  validation {
    condition     = contains(["MONTH", "QUARTER", "YEAR"], var.calendar_period)
    error_message = "calendar_period must be MONTH, QUARTER or YEAR."
  }
}

variable "custom_period" {
  description = "A one-off, non-recurring period instead of `calendar_period`. Dates are `YYYY-MM-DD`; `end_date` null means \"from start_date onward\"."
  type = object({
    start_date = string
    end_date   = optional(string)
  })
  nullable = true
  default  = null

  validation {
    condition = var.custom_period == null || alltrue([
      for d in compact([try(var.custom_period.start_date, null), try(var.custom_period.end_date, null)]) :
      can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", d))
    ])
    error_message = "custom_period dates must be formatted YYYY-MM-DD."
  }
}

variable "projects" {
  description = <<-EOT
    Projects whose usage counts toward the budget, as `projects/<PROJECT_NUMBER>`. Empty (default) means
    every project on the billing account.

    The project NUMBER, not the project ID. The API accepts only numbers here, and passing an ID fails
    with an error that does not say so — hence the validation.
  EOT
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for p in var.projects : can(regex("^projects/[0-9]+$", p))])
    error_message = "projects entries must be projects/<PROJECT_NUMBER> (digits only). Find it with: gcloud projects describe <id> --format='value(projectNumber)'."
  }
}

variable "resource_ancestors" {
  description = "Folders or organizations (`folders/<id>`, `organizations/<id>`) whose projects count toward the budget. Empty (default) = no ancestor filter."
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for a in var.resource_ancestors : can(regex("^(folders|organizations)/[0-9]+$", a))])
    error_message = "resource_ancestors entries must be folders/<id> or organizations/<id>."
  }
}

variable "services" {
  description = "Billing services (`services/<SERVICE_ID>`, e.g. `services/24E6-581D-38E5` for BigQuery) to scope the budget to. Empty (default) = every service."
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for s in var.services : can(regex("^services/[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$", s))])
    error_message = "services entries must be services/<SERVICE_ID>, e.g. services/24E6-581D-38E5."
  }
}

variable "label_filter" {
  description = "Scope the budget to resources carrying ONE label key/value pair, e.g. `{ team = \"platform\" }`. The API supports a single pair only. Empty (default) = no label filter."
  type        = map(string)
  nullable    = false
  default     = {}

  validation {
    condition     = length(var.label_filter) <= 1
    error_message = "label_filter supports at most one key/value pair (an API limit)."
  }
}

variable "credit_types_treatment" {
  description = <<-EOT
    How credits affect the spend compared against thresholds.

      - INCLUDE_ALL_CREDITS (default) — net spend: what you are invoiced.
      - EXCLUDE_ALL_CREDITS — gross spend: what you consumed. Use this on a Free Trial or
        promotional-credit account, where net spend sits at $0 while real resources run.
      - INCLUDE_SPECIFIED_CREDITS — subtract only the types listed in `credit_types`.
  EOT
  type        = string
  nullable    = false
  default     = "INCLUDE_ALL_CREDITS"

  validation {
    condition     = contains(["INCLUDE_ALL_CREDITS", "EXCLUDE_ALL_CREDITS", "INCLUDE_SPECIFIED_CREDITS"], var.credit_types_treatment)
    error_message = "credit_types_treatment must be INCLUDE_ALL_CREDITS, EXCLUDE_ALL_CREDITS or INCLUDE_SPECIFIED_CREDITS."
  }
}

variable "credit_types" {
  description = "Credit types subtracted from gross cost when `credit_types_treatment = INCLUDE_SPECIFIED_CREDITS`, e.g. [\"PROMOTION\", \"FREE_TIER\"]. Must be empty otherwise."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "threshold_rules" {
  description = <<-EOT
    Thresholds that trigger an alert, as 1.0-based fractions of the amount (0.5 = 50%).

      - `spend_basis` — CURRENT_SPEND (default) fires on spend already incurred; FORECASTED_SPEND fires
        on Google's projection for the period and is the only forward-looking signal a budget offers.

    Required and non-empty: without a threshold the email recipients are never told anything (Pub/Sub
    still receives periodic status updates, but those are a feed, not an alert).
  EOT
  type = list(object({
    threshold_percent = number
    spend_basis       = optional(string, "CURRENT_SPEND")
  }))
  nullable = false

  validation {
    condition     = length(var.threshold_rules) > 0
    error_message = "threshold_rules must not be empty: a budget without one alerts nobody."
  }

  validation {
    condition     = alltrue([for r in var.threshold_rules : r.threshold_percent > 0])
    error_message = "each threshold_percent must be greater than 0 (it is a fraction: 0.5 = 50%)."
  }

  validation {
    condition     = alltrue([for r in var.threshold_rules : contains(["CURRENT_SPEND", "FORECASTED_SPEND"], r.spend_basis)])
    error_message = "spend_basis must be CURRENT_SPEND or FORECASTED_SPEND."
  }
}

variable "notification_channel_ids" {
  description = "Cloud Monitoring notification channels (`projects/<project>/notificationChannels/<id>`) told when a threshold is crossed. At most 5 (an API limit). The `gcp/notification-channels` module produces these."
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = length(var.notification_channel_ids) <= 5
    error_message = "a budget accepts at most 5 monitoring notification channels."
  }

  validation {
    condition     = alltrue([for c in var.notification_channel_ids : can(regex("^projects/[^/]+/notificationChannels/[0-9]+$", c))])
    error_message = "notification_channel_ids entries must be projects/<project>/notificationChannels/<id>."
  }
}

variable "pubsub_topic" {
  description = <<-EOT
    Pub/Sub topic (`projects/<project>/topics/<topic>`) that receives budget status messages. Null
    (default) = none.

    Not an alert channel: Billing publishes the current spend to it several times a day whether or not a
    threshold was crossed. It is the hook for automation (chat, enforcement), and the topic must let
    `serviceAccount:billing-budget-alert@system.gserviceaccount.com` publish — the `gcp/pubsub-topic`
    module can make that grant.
  EOT
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.pubsub_topic == null || can(regex("^projects/[^/]+/topics/[^/]+$", var.pubsub_topic))
    error_message = "pubsub_topic must be projects/<project>/topics/<topic>."
  }
}

variable "disable_default_iam_recipients" {
  description = "Stop emailing Billing Account Administrators and Billing Account Users on threshold crossings. Default false: on a personal account those people are you, and a second copy of an alert is cheap."
  type        = bool
  nullable    = false
  default     = false
}

variable "enable_project_level_recipients" {
  description = "Also email the project's Owners. Only takes effect when `projects` lists exactly one project."
  type        = bool
  nullable    = false
  default     = false
}

variable "ownership_scope" {
  description = "Who may see the budget: ALL_USERS or BILLING_ACCOUNT (only billing-account-level users). Null (default) leaves Google's default."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.ownership_scope == null || contains(["ALL_USERS", "BILLING_ACCOUNT"], coalesce(var.ownership_scope, "ALL_USERS"))
    error_message = "ownership_scope must be ALL_USERS or BILLING_ACCOUNT."
  }
}
