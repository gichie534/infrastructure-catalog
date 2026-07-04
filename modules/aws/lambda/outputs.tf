output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN to be used for invoking the function (e.g. from API Gateway integrations)."
  value       = aws_lambda_function.this.invoke_arn
}

output "role_arn" {
  description = "ARN of the function's execution role. Attach further permissions to it if needed."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the function's execution role."
  value       = aws_iam_role.this.name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group receiving the function's logs."
  value       = aws_cloudwatch_log_group.this.name
}
