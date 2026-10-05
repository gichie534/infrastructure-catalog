output "id" {
  description = "Terraform ID of the budget (`billingAccounts/<account>/budgets/<budget-id>`)."
  value       = google_billing_budget.this.id
}

output "name" {
  description = "Full resource name of the budget (`billingAccounts/<account>/budgets/<budget-id>`). This is what gcloud and the API take."
  value       = google_billing_budget.this.name
}

output "budget_id" {
  description = "The generated budget ID alone — the last path segment of `name`."
  value       = element(split("/", google_billing_budget.this.name), length(split("/", google_billing_budget.this.name)) - 1)
}

output "display_name" {
  description = "Display name of the budget."
  value       = google_billing_budget.this.display_name
}

output "billing_account" {
  description = "Billing account the budget belongs to."
  value       = google_billing_budget.this.billing_account
}

output "threshold_count" {
  description = "How many threshold rules the budget carries. Always positive — the module rejects an empty list."
  value       = length(var.threshold_rules)
}
