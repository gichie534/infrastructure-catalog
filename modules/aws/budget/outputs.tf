output "arn" {
  description = "ARN of the budget. This is what a budget action or a cross-account policy statement refers to."
  value       = aws_budgets_budget.this.arn
}

output "id" {
  description = "ID of the budget (`<account-id>:<budget-name>`)."
  value       = aws_budgets_budget.this.id
}

output "name" {
  description = "Name of the budget."
  value       = aws_budgets_budget.this.name
}

output "notification_count" {
  description = "How many notification thresholds the budget carries. A zero here would be a budget nobody hears about — the module rejects that, so this is a positive number."
  value       = length(local.notifications)
}
