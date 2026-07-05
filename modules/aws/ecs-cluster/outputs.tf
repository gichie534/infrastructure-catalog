output "cluster_arn" {
  description = "ARN of the ECS cluster. Pass it to a service module to place the service in this cluster."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "cluster_id" {
  description = "ID of the ECS cluster (same value as the ARN)."
  value       = aws_ecs_cluster.this.id
}
