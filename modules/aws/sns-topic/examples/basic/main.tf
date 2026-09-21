provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the example topic."
  type        = string
}

variable "email_subscribers" {
  description = "Optional email addresses to subscribe. Left empty by default so the example applies without sending confirmation mail."
  type        = list(string)
  default     = []
}

# A notification topic for AWS Budgets and Cost Anomaly Detection — the two billing services that
# publish as themselves and therefore need an explicit resource-policy grant.
module "sns_topic" {
  source = "../../"

  name         = var.name
  display_name = "FinOps alerts"

  allowed_service_principals = [
    "budgets.amazonaws.com",
    "costalerts.amazonaws.com",
  ]

  email_subscribers = var.email_subscribers

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "arn" {
  description = "ARN of the created topic."
  value       = module.sns_topic.arn
}

output "name" {
  description = "Name of the created topic."
  value       = module.sns_topic.name
}

output "policy_managed" {
  description = "Whether a topic policy is managed."
  value       = module.sns_topic.policy_managed
}
