# A serverless (Fargate) ECS cluster: the logical grouping that services and tasks run in. The module
# owns the cluster and its Fargate capacity providers only — services, task definitions, load
# balancers, and networking are separate concerns supplied by other modules (e.g. ecs-fargate-service
# behind an alb). Keeping the cluster its own module lets several services share one cluster.

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = var.tags
}

# Make the Fargate capacity providers available and pick the default one, so a service that only
# specifies FARGATE (or nothing) schedules correctly.
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = var.capacity_providers

  default_capacity_provider_strategy {
    capacity_provider = var.default_capacity_provider
    weight            = 1
    base              = 1
  }
}
