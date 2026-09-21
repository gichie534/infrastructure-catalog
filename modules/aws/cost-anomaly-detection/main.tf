# AWS Cost Anomaly Detection: monitors (what is watched) plus alert subscriptions (who hears about it).
#
# Both halves live in one module because neither is useful alone — a monitor with no subscription
# detects anomalies nobody sees, and a subscription must reference a monitor ARN to exist at all.
# Subscriptions refer to monitors by their key in `monitors`, so a consumer never handles ARNs.
#
# This is the complement to a budget, not a substitute. A budget compares spend to a number you chose;
# anomaly detection compares spend to a model of your own history, so it catches the shape of problem a
# limit cannot: a service that quietly costs ten times what it did last week while the monthly total
# still sits comfortably under budget. It is also free, which makes it the cheapest signal in FinOps.
#
# Cost Explorer is a global service reachable only through its us-east-1 endpoint — configure the
# provider for us-east-1 in the calling unit.

resource "aws_ce_anomaly_monitor" "this" {
  for_each = var.monitors

  name         = each.key
  monitor_type = each.value.monitor_type

  # Exactly one of these applies, enforced by the variable validations.
  monitor_dimension     = each.value.monitor_type == "DIMENSIONAL" ? each.value.monitor_dimension : null
  monitor_specification = each.value.monitor_type == "CUSTOM" ? each.value.monitor_specification : null

  tags = var.tags
}

locals {
  # Resolve each subscription's monitor keys (empty = every monitor) and turn the two threshold inputs
  # into the list of dimension clauses AWS expects.
  subscriptions = {
    for key, subscription in var.subscriptions : key => merge(subscription, {
      resolved_monitor_keys = (
        length(subscription.monitor_keys) > 0 ? subscription.monitor_keys : keys(var.monitors)
      )

      thresholds = concat(
        subscription.absolute_impact_threshold == null ? [] : [{
          key   = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
          value = tostring(subscription.absolute_impact_threshold)
        }],
        subscription.percentage_impact_threshold == null ? [] : [{
          key   = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
          value = tostring(subscription.percentage_impact_threshold)
        }],
      )
    })
  }
}

resource "aws_ce_anomaly_subscription" "this" {
  for_each = local.subscriptions

  name      = each.key
  frequency = each.value.frequency

  monitor_arn_list = [
    for monitor_key in each.value.resolved_monitor_keys : aws_ce_anomaly_monitor.this[monitor_key].arn
  ]

  dynamic "subscriber" {
    for_each = toset(each.value.email_subscribers)
    content {
      type    = "EMAIL"
      address = subscriber.value
    }
  }

  dynamic "subscriber" {
    for_each = toset(each.value.sns_topic_arns)
    content {
      type    = "SNS"
      address = subscriber.value
    }
  }

  # AWS requires a threshold expression. One threshold is a bare dimension clause; two are combined
  # with OR or AND.
  threshold_expression {
    dynamic "dimension" {
      for_each = length(each.value.thresholds) == 1 ? each.value.thresholds : []
      content {
        key           = dimension.value.key
        values        = [dimension.value.value]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }

    dynamic "or" {
      for_each = length(each.value.thresholds) > 1 && each.value.threshold_combinator == "OR" ? each.value.thresholds : []
      content {
        dimension {
          key           = or.value.key
          values        = [or.value.value]
          match_options = ["GREATER_THAN_OR_EQUAL"]
        }
      }
    }

    dynamic "and" {
      for_each = length(each.value.thresholds) > 1 && each.value.threshold_combinator == "AND" ? each.value.thresholds : []
      content {
        dimension {
          key           = and.value.key
          values        = [and.value.value]
          match_options = ["GREATER_THAN_OR_EQUAL"]
        }
      }
    }
  }

  tags = var.tags

  lifecycle {
    # Catch a typo in monitor_keys at plan time with a readable message, rather than letting Terraform
    # fail on a missing map element.
    precondition {
      condition = alltrue([
        for monitor_key in local.subscriptions[each.key].resolved_monitor_keys : contains(keys(var.monitors), monitor_key)
      ])
      error_message = "subscription '${each.key}' references a monitor key that is not declared in var.monitors."
    }
  }
}
