output "function_name" {
  description = "Name of the Lambda function."
  value       = local.function.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = local.function.arn
}

output "invoke_arn" {
  description = "ARN to be used for invoking the function (e.g. from API Gateway integrations)."
  value       = local.function.invoke_arn
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

output "function_url" {
  description = "HTTPS Function URL endpoint (with a trailing slash), or null when create_function_url is false."
  value       = var.create_function_url ? aws_lambda_function_url.this[0].function_url : null
}
