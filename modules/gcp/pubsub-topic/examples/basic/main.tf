terraform {
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

variable "project_id" {
  description = "GCP project to create the topic in (pubsub.googleapis.com must be enabled)."
  type        = string
}

variable "name" {
  description = "Topic name; override per run to avoid collisions."
  type        = string
  default     = "example-budget-alerts"
}

# A topic Cloud Billing budgets can publish to, with one pull subscription so the messages are kept.
module "topic" {
  source = "../../"

  project_id = var.project_id
  name       = var.name

  publisher_members = [
    "serviceAccount:billing-budget-alert@system.gserviceaccount.com",
  ]

  pull_subscriptions = {
    "${var.name}-pull" = {}
  }

  labels = {
    managed-by = "terraform"
    example    = "basic"
  }
}

output "id" {
  description = "Topic resource name."
  value       = module.topic.id
}

output "publisher_members" {
  description = "Members granted publish."
  value       = module.topic.publisher_members
}

output "subscription_ids" {
  description = "Subscription resource names."
  value       = module.topic.subscription_ids
}
