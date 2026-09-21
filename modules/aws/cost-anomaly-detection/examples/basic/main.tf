# Cost Explorer is a global service reachable only through its us-east-1 endpoint.
provider "aws" {
  region = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for the example monitor and subscription names, so repeat runs do not collide."
  type        = string
}

variable "subscriber_email" {
  description = "Email address that receives the daily anomaly summary."
  type        = string
  default     = "finops@example.com"
}

data "aws_caller_identity" "current" {}

# A CUSTOM monitor over this account's own spend, and a daily email summary of anomalies that are either
# worth at least $10 or represent a 50% overshoot of expected spend.
#
# The OR is the point: a percentage threshold alone fires on a $2 service that tripled, and an absolute
# threshold alone sleeps through a steady 30% overspend on a large bill.
#
# Why CUSTOM rather than the more obvious DIMENSIONAL/SERVICE monitor: AWS allows exactly ONE AWS-managed
# monitor for AWS services per account and creates it for you, so a second one fails with "Limit exceeded
# on dimensional spend monitor creation" — which would make this example unrunnable on any real account.
# Customer-managed monitors are limited to 500, so they compose. On a real account you would usually skip
# creating a monitor entirely and point `monitor_arns` at the managed one; see the module README.
module "cost_anomaly_detection" {
  source = "../../"

  monitors = {
    "${var.name_prefix}-account" = {
      monitor_type = "CUSTOM"
      monitor_specification = jsonencode({
        Dimensions = {
          Key          = "LINKED_ACCOUNT"
          Values       = [data.aws_caller_identity.current.account_id]
          MatchOptions = ["EQUALS"]
        }
      })
    }
  }

  subscriptions = {
    "${var.name_prefix}-daily" = {
      frequency         = "DAILY"
      email_subscribers = [var.subscriber_email]

      absolute_impact_threshold   = 10
      percentage_impact_threshold = 50
      threshold_combinator        = "OR"
    }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "monitor_names" {
  description = "Names of the created monitors."
  value       = module.cost_anomaly_detection.monitor_names
}

output "monitor_arns" {
  description = "Map of monitor name to ARN."
  value       = module.cost_anomaly_detection.monitor_arns
}

output "subscription_names" {
  description = "Names of the created subscriptions."
  value       = module.cost_anomaly_detection.subscription_names
}

output "subscription_monitor_keys" {
  description = "Which module-managed monitors each subscription resolved to."
  value       = module.cost_anomaly_detection.subscription_monitor_keys
}
