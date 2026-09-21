provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in. AWS Budgets is regionless; this only decides which endpoint is called."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the example budget."
  type        = string
}

variable "subscriber_email" {
  description = "Email address that receives the example notifications."
  type        = string
  default     = "finops@example.com"
}

# A monthly cost budget with early warning, the limit itself, and a forecast tripwire.
#
# The forecast threshold is the only forward-looking one: the ACTUAL thresholds can only ever tell you
# about money already spent, because AWS refreshes billing data at most a few times a day.
module "budget" {
  source = "../../"

  name         = var.name
  limit_amount = "50"
  time_unit    = "MONTHLY"

  subscriber_email_addresses = [var.subscriber_email]

  notifications = [
    { threshold = 80, notification_type = "ACTUAL" },
    { threshold = 100, notification_type = "ACTUAL" },
    { threshold = 100, notification_type = "FORECASTED" },
  ]

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "name" {
  description = "Name of the created budget."
  value       = module.budget.name
}

output "arn" {
  description = "ARN of the created budget."
  value       = module.budget.arn
}

output "notification_count" {
  description = "How many notification thresholds the budget carries."
  value       = module.budget.notification_count
}
