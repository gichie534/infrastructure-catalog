provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the example service, cluster, and task family."
  type        = string
}

# Use the account's default VPC + its subnets so the example is self-contained. Default-VPC subnets
# auto-assign public IPs and route to an internet gateway, so a public-IP task can pull its image
# with no NAT gateway.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# A minimal cluster to place the service in (the example stays independent of the ecs-cluster module).
resource "aws_ecs_cluster" "this" {
  name = var.name
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# A public "hello" image so the example runs without needing a private registry. No load balancer:
# the task just runs. Terraform fully manages the revision here (ignore_task_definition_changes =
# false) so the created service is deterministic for the test.
module "service" {
  source = "../../"

  name             = var.name
  cluster_arn      = aws_ecs_cluster.this.arn
  container_image  = "public.ecr.aws/nginx/nginx:stable"
  container_port   = 80
  vpc_id           = data.aws_vpc.default.id
  subnet_ids       = data.aws_subnets.default.ids
  assign_public_ip = true

  ignore_task_definition_changes = false

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "service_name" {
  description = "Name of the created service."
  value       = module.service.service_name
}

output "task_definition_family" {
  description = "Family of the created task definition."
  value       = module.service.task_definition_family
}

output "log_group_name" {
  description = "Log group receiving container logs."
  value       = module.service.log_group_name
}
