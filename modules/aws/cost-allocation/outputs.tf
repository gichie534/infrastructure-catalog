output "active_cost_allocation_tag_keys" {
  description = "Tag keys this module has activated as cost allocation tags. Activation can take a further 24 hours to show up in cost data."
  value       = [for tag in aws_ce_cost_allocation_tag.this : tag.tag_key]
}

output "cost_category_arns" {
  description = "Map of cost category name to ARN. Use it as a `CostCategories` filter value in a budget or an anomaly monitor."
  value       = { for key, category in aws_ce_cost_category.this : key => category.arn }
}

output "cost_category_names" {
  description = "Names of the managed cost categories."
  value       = keys(aws_ce_cost_category.this)
}

output "cost_category_effective_starts" {
  description = "Map of cost category name to the month its rules take effect from. Spend before that month is not categorised."
  value       = { for key, category in aws_ce_cost_category.this : key => category.effective_start }
}
