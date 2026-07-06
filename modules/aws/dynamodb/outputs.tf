output "name" {
  description = "Name of the DynamoDB table. Pass this to clients as the table name."
  value       = aws_dynamodb_table.this.name
}

output "arn" {
  description = "ARN of the table. Use it to scope IAM policy resource statements granting item access."
  value       = aws_dynamodb_table.this.arn
}

output "id" {
  description = "ID of the table (equal to its name)."
  value       = aws_dynamodb_table.this.id
}

output "stream_arn" {
  description = "ARN of the table's stream if enabled, otherwise an empty string. Wire this to a stream consumer (e.g. a Lambda event source mapping)."
  value       = aws_dynamodb_table.this.stream_arn
}
