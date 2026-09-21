# A single AWS Budget and the notification thresholds attached to it.
#
# One module instance == one budget. A budget is a self-contained decision — this limit, over this period,
# on this slice of spend, telling these people — so it is also the right unit to version, plan and destroy
# on its own. Consumers that want several budgets instantiate the module several times, which keeps each
# one's diff, state and blast radius separate.
#
# What this module does NOT do: budget actions (`aws_budgets_budget_action`). An action needs an IAM role
# and either an IAM policy target or an SCP, and the SCP variant only exists with AWS Organizations.
# Enforcement is a separate concern from measurement, and mixing them here would put a resource with real
# blast radius behind an innocuous-looking input.

locals {
  # Resolve each threshold's subscribers, falling back to the budget-level channel so it is declared once
  # rather than repeated on every threshold.
  notifications = [
    for notification in var.notifications : merge(notification, {
      subscriber_email_addresses = (
        length(notification.subscriber_email_addresses) > 0
        ? notification.subscriber_email_addresses
        : var.subscriber_email_addresses
      )
      subscriber_sns_topic_arns = (
        length(notification.subscriber_sns_topic_arns) > 0
        ? notification.subscriber_sns_topic_arns
        : var.subscriber_sns_topic_arns
      )
    })
  ]
}

resource "aws_budgets_budget" "this" {
  name = var.name

  budget_type  = var.budget_type
  limit_amount = var.limit_amount
  limit_unit   = var.limit_unit

  time_unit         = var.time_unit
  time_period_start = var.time_period_start
  time_period_end   = var.time_period_end

  # Scope the budget to a slice of spend (a service, a tag value, a cost category, a linked account).
  # Omitted = the whole account.
  dynamic "cost_filter" {
    for_each = var.cost_filters
    content {
      name   = cost_filter.key
      values = cost_filter.value
    }
  }

  # Which charge classes count toward the limit. Null attributes fall through to the AWS defaults.
  dynamic "cost_types" {
    for_each = var.cost_types == null ? [] : [var.cost_types]
    content {
      include_credit             = cost_types.value.include_credit
      include_discount           = cost_types.value.include_discount
      include_other_subscription = cost_types.value.include_other_subscription
      include_recurring          = cost_types.value.include_recurring
      include_refund             = cost_types.value.include_refund
      include_subscription       = cost_types.value.include_subscription
      include_support            = cost_types.value.include_support
      include_tax                = cost_types.value.include_tax
      include_upfront            = cost_types.value.include_upfront
      use_amortized              = cost_types.value.use_amortized
      use_blended                = cost_types.value.use_blended
    }
  }

  dynamic "notification" {
    for_each = local.notifications
    content {
      threshold           = notification.value.threshold
      threshold_type      = notification.value.threshold_type
      notification_type   = notification.value.notification_type
      comparison_operator = notification.value.comparison_operator

      subscriber_email_addresses = notification.value.subscriber_email_addresses
      subscriber_sns_topic_arns  = notification.value.subscriber_sns_topic_arns
    }
  }

  tags = var.tags

  lifecycle {
    # AWS accepts a notification with no subscribers, which creates a threshold that fires into the void.
    # Fail at plan time instead: this is exactly the misconfiguration you would not notice until the alert
    # you were relying on never arrived.
    precondition {
      condition = alltrue([
        for n in local.notifications :
        length(n.subscriber_email_addresses) + length(n.subscriber_sns_topic_arns) > 0
      ])
      error_message = "budget '${var.name}' has a notification with no subscribers: set subscriber_email_addresses / subscriber_sns_topic_arns on the notification, or on the module."
    }
  }
}
