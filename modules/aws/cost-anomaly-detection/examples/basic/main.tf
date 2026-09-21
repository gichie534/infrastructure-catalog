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

# One monitor over every AWS service, and a daily email summary of anomalies that are either worth at
# least $10 or represent a 50% overshoot of expected spend.
#
# The OR is the point: a percentage threshold alone fires on a $2 service that tripled, and an absolute
# threshold alone sleeps through a steady 30% overspend on a large bill.
module "cost_anomaly_detection" {
  source = "../../"

  monitors = {
    "${var.name_prefix}-services" = {
      monitor_type      = "DIMENSIONAL"
      monitor_dimension = "SERVICE"
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
  description = "Which monitors each subscription resolved to."
  value       = module.cost_anomaly_detection.subscription_monitor_keys
}
