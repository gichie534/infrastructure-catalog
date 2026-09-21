output "arn" {
  description = "ARN of the SNS topic. This is what you hand to a publisher (budget notification, anomaly subscription, CloudWatch alarm action)."
  value       = aws_sns_topic.this.arn
}

output "name" {
  description = "Name of the SNS topic."
  value       = aws_sns_topic.this.name
}

output "id" {
  description = "ID of the SNS topic (equal to its ARN for SNS)."
  value       = aws_sns_topic.this.id
}

output "policy_managed" {
  description = "Whether the module manages a topic policy. False means the topic keeps whatever policy AWS attached by default."
  value       = local.manage_policy
}

output "email_subscription_arns" {
  description = "Map of subscribed email address to subscription ARN. A subscription is inert until the recipient confirms it, so presence here does not prove deliverability."
  value       = { for email, sub in aws_sns_topic_subscription.email : email => sub.arn }
}
