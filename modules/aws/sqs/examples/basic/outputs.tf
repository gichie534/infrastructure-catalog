output "arn" {
  description = "ARN of the example queue."
  value       = module.sqs.arn
}

output "url" {
  description = "URL of the example queue."
  value       = module.sqs.url
}

output "name" {
  description = "Name of the example queue."
  value       = module.sqs.name
}
