# A Fargate ECS service: a task definition, the service that keeps N copies running, the IAM roles
# the task needs, a CloudWatch log group, and (optionally) a security group for the task ENIs. Wire
# it to an ALB by passing a target_group_arn. The cluster, load balancer, subnets, and image come
# from the consumer — keeping the module region/account-agnostic and reusable.
#
# DEPLOYMENT OWNERSHIP: by default (ignore_task_definition_changes = true) Terraform creates the
# service with a BOOTSTRAP task definition and then stops managing which revision runs. A CI pipeline
# registers new task-definition revisions (new image tags) and updates the service; Terraform will
# not revert them on the next apply. Set the flag false to have Terraform fully own the revision.

locals {
  create_sg          = var.create_security_group && length(var.security_group_ids) == 0
  security_group_ids = local.create_sg ? [aws_security_group.this[0].id] : var.security_group_ids
  log_group_name     = "/ecs/${var.name}"
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------------------------------
# Logs
# ---------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

# ---------------------------------------------------------------------------------------------------
# IAM — an execution role (ECS agent: pull image, write logs) and a task role (the app itself)
# ---------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "execution_extra" {
  for_each   = toset(var.execution_policy_arns)
  role       = aws_iam_role.execution.name
  policy_arn = each.value
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "task_extra" {
  for_each   = toset(var.task_policy_arns)
  role       = aws_iam_role.task.name
  policy_arn = each.value
}

# ---------------------------------------------------------------------------------------------------
# Task security group (optional)
# ---------------------------------------------------------------------------------------------------
resource "aws_security_group" "this" {
  count = local.create_sg ? 1 : 0

  name        = "${var.name}-task"
  description = "Ingress on ${var.container_port} from allowed SGs for the ${var.name} tasks; all egress."
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = toset(var.ingress_security_group_ids)
    content {
      description     = "App traffic from ${ingress.value}"
      from_port       = var.container_port
      to_port         = var.container_port
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    description = "All egress (pull image, reach AWS APIs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-task" })
}

# ---------------------------------------------------------------------------------------------------
# Task definition
# ---------------------------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [for k, v in var.environment : { name = k, value = v }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = var.container_name
        }
      }
    }
  ])

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------
# Service — two variants so lifecycle.ignore_changes can be toggled by a variable (lifecycle blocks
# can't be dynamic). Exactly one is created, selected by ignore_task_definition_changes.
# ---------------------------------------------------------------------------------------------------
resource "aws_ecs_service" "ignore_taskdef" {
  count = var.ignore_task_definition_changes ? 1 : 0

  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  enable_execute_command = var.enable_execute_command
  propagate_tags         = "SERVICE"

  health_check_grace_period_seconds = var.target_group_arn != null ? var.health_check_grace_period_seconds : null

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = local.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  # CI owns the running revision and scale. Ignore both so Terraform doesn't revert deployments.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = var.tags
}

resource "aws_ecs_service" "managed" {
  count = var.ignore_task_definition_changes ? 0 : 1

  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  enable_execute_command = var.enable_execute_command
  propagate_tags         = "SERVICE"

  health_check_grace_period_seconds = var.target_group_arn != null ? var.health_check_grace_period_seconds : null

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = local.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  tags = var.tags
}
