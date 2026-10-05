terraform {
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

# The Budgets API needs a quota project when called with user ADC. Without these two lines every call
# fails with a 403 that talks about end-user credentials rather than the missing setting.
provider "google" {
  project               = var.project_id
  billing_project       = var.project_id
  user_project_override = true
}

variable "project_id" {
  description = "Project used as the quota project, and whose spend the example budget watches."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID the budget is created on (needs roles/billing.costsManager or roles/billing.admin)."
  type        = string
}

variable "display_name" {
  description = "Display name for the example budget."
  type        = string
}

data "google_project" "this" {
  project_id = var.project_id
}

# A monthly budget on one project with early warning, the limit itself, and a forecast tripwire. Default
# IAM recipients (the billing admins) are kept on, so the example needs no notification channel.
module "budget" {
  source = "../../"

  billing_account = var.billing_account
  display_name    = var.display_name
  amount          = 50

  projects = ["projects/${data.google_project.this.number}"]

  threshold_rules = [
    { threshold_percent = 0.8 },
    { threshold_percent = 1.0 },
    { threshold_percent = 1.0, spend_basis = "FORECASTED_SPEND" },
  ]
}

output "name" {
  description = "Resource name of the created budget."
  value       = module.budget.name
}

output "display_name" {
  description = "Display name of the created budget."
  value       = module.budget.display_name
}

output "threshold_count" {
  description = "How many threshold rules the budget carries."
  value       = module.budget.threshold_count
}
