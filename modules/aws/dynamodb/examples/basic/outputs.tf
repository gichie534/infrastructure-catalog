output "name" {
  description = "Name of the created table."
  value       = module.table.name
}

output "arn" {
  description = "ARN of the created table."
  value       = module.table.arn
}

output "id" {
  description = "ID of the created table."
  value       = module.table.id
}
