locals {
  service = var.ignore_task_definition_changes ? aws_ecs_service.ignore_taskdef[0] : aws_ecs_service.managed[0]
}

output "service_name" {
  description = "Name of the ECS service."
  value       = local.service.name
}

output "service_id" {
  description = "ID (ARN) of the ECS service."
  value       = local.service.id
}

output "task_definition_arn" {
  description = "ARN of the (bootstrap) task definition revision created by this module."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Family name of the task definition. A CI deployer describes this family, swaps the image, and registers a new revision."
  value       = aws_ecs_task_definition.this.family
}

output "container_name" {
  description = "Name of the container in the task definition (the load-balancer target and the CI image-swap target)."
  value       = var.container_name
}

output "container_port" {
  description = "Port the container listens on."
  value       = var.container_port
}

output "execution_role_arn" {
  description = "ARN of the task execution role (used by the ECS agent). Grant a CI deployer iam:PassRole on this."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the task role (assumed by the application). Grant a CI deployer iam:PassRole on this."
  value       = aws_iam_role.task.arn
}

output "security_group_id" {
  description = "ID of the task security group created by this module, or null when one was supplied instead."
  value       = local.create_sg ? aws_security_group.this[0].id : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group receiving the container logs."
  value       = aws_cloudwatch_log_group.this.name
}
