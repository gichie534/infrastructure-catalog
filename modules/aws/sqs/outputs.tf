output "arn" {
  description = "ARN of the queue. Use this in IAM policy resource statements that grant send/receive on this queue."
  value       = aws_sqs_queue.this.arn
}

output "url" {
  description = "URL (queue endpoint) of the queue. This is what producers/consumers pass to the SQS API as QueueUrl."
  value       = aws_sqs_queue.this.url
}

output "name" {
  description = "Name of the queue."
  value       = aws_sqs_queue.this.name
}
