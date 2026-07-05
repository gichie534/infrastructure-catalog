provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the example ECS cluster."
  type        = string
}

# Minimal call: a Fargate cluster with FARGATE + FARGATE_SPOT capacity providers.
module "ecs_cluster" {
  source = "../../"

  name = var.name

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "cluster_arn" {
  description = "ARN of the created cluster."
  value       = module.ecs_cluster.cluster_arn
}

output "cluster_name" {
  description = "Name of the created cluster."
  value       = module.ecs_cluster.cluster_name
}
