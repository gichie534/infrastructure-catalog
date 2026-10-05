# A single Cloud Billing budget and the thresholds attached to it.
#
# One module instance == one budget, for the same reason as aws/budget: a budget is a self-contained
# decision (this amount, over this period, on this slice of spend, telling these people), so it is also the
# right unit to plan, version and destroy on its own.
#
# Things that differ from AWS and shape this module:
#
#   - A budget belongs to the BILLING ACCOUNT, not a project. The project only appears as a filter, and
#     only by project NUMBER. The caller therefore needs a billing-account role
#     (roles/billing.costsManager or roles/billing.admin), not a project one.
#   - With user ADC the Budgets API demands a quota project: the consumer's provider needs
#     `billing_project` + `user_project_override = true`, or every call is a 403. That is provider
#     configuration, so it is the consumer's job; the README says so.
#   - Budgets carry no labels, so this module takes no `labels` input.
#
# What this module does NOT do: cap or stop spend. A budget is measurement. Enforcement on GCP means a
# Pub/Sub-triggered function that detaches billing (destructive, project-wide) or a Spend Cap (preview,
# console-only, a few services). Both are deliberately out of scope.

locals {
  custom_start = var.custom_period == null ? null : split("-", var.custom_period.start_date)
  custom_end   = try(var.custom_period.end_date, null) == null ? null : split("-", var.custom_period.end_date)

  # The API takes money as whole units + nanos. floor(x + 0.5) rounds, so 0.1 does not become 99999999 nanos.
  amount_units = var.amount == null ? null : tostring(floor(var.amount))
  amount_nanos = var.amount == null ? null : floor((var.amount - floor(var.amount)) * 1000000000 + 0.5)

  has_human_recipient = (
    !var.disable_default_iam_recipients
    || length(var.notification_channel_ids) > 0
    || (var.enable_project_level_recipients && length(var.projects) == 1)
  )
}

resource "google_billing_budget" "this" {
  billing_account = var.billing_account
  display_name    = var.display_name
  ownership_scope = var.ownership_scope

  amount {
    dynamic "specified_amount" {
      for_each = var.use_last_period_amount ? [] : [1]
      content {
        currency_code = var.currency_code
        units         = local.amount_units
        nanos         = local.amount_nanos
      }
    }

    last_period_amount = var.use_last_period_amount ? true : null
  }

  budget_filter {
    projects               = var.projects
    resource_ancestors     = var.resource_ancestors
    services               = var.services
    labels                 = var.label_filter
    credit_types_treatment = var.credit_types_treatment
    credit_types           = var.credit_types

    calendar_period = var.custom_period == null ? var.calendar_period : null

    dynamic "custom_period" {
      for_each = var.custom_period == null ? [] : [var.custom_period]
      content {
        start_date {
          year  = tonumber(local.custom_start[0])
          month = tonumber(local.custom_start[1])
          day   = tonumber(local.custom_start[2])
        }

        dynamic "end_date" {
          for_each = local.custom_end == null ? [] : [local.custom_end]
          content {
            year  = tonumber(end_date.value[0])
            month = tonumber(end_date.value[1])
            day   = tonumber(end_date.value[2])
          }
        }
      }
    }
  }

  dynamic "threshold_rules" {
    for_each = var.threshold_rules
    content {
      threshold_percent = threshold_rules.value.threshold_percent
      spend_basis       = threshold_rules.value.spend_basis
    }
  }

  all_updates_rule {
    monitoring_notification_channels = var.notification_channel_ids
    pubsub_topic                     = var.pubsub_topic
    schema_version                   = var.pubsub_topic == null ? null : "1.0"
    disable_default_iam_recipients   = var.disable_default_iam_recipients
    enable_project_level_recipients  = var.enable_project_level_recipients
  }

  lifecycle {
    precondition {
      condition     = (var.amount == null) != (var.use_last_period_amount == false)
      error_message = "budget '${var.display_name}': set exactly one of amount or use_last_period_amount = true."
    }

    precondition {
      condition     = var.credit_types_treatment == "INCLUDE_SPECIFIED_CREDITS" || length(var.credit_types) == 0
      error_message = "budget '${var.display_name}': credit_types may only be set when credit_types_treatment = INCLUDE_SPECIFIED_CREDITS."
    }

    # The API happily accepts a budget whose only recipients are switched off. Fail at plan time instead:
    # that is a guardrail you would discover was mute only when the alert never arrived. A Pub/Sub topic
    # does not count — it is a feed for machines, not a way for a human to hear about a threshold.
    precondition {
      condition     = local.has_human_recipient
      error_message = "budget '${var.display_name}' alerts nobody: default IAM recipients are disabled and no notification channel (or single-project owner recipient) is configured."
    }
  }
}
