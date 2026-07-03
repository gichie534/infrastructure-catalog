# An Application Load Balancer with an HTTP listener, one or more target groups, and path/host-based
# routing rules — the minimal building block for fronting several backends behind one entry point.
#
# The module owns ONLY the load balancer, its target groups, listener, and rules (plus an optional
# security group). It does not create the VPC/subnets or the targets themselves — those are the
# consumer's composition concern, passed in as inputs (vpc_id, subnet_ids, target_ids). That keeps
# the module region- and account-agnostic and reusable across labs.

locals {
  # Create a security group only when the consumer didn't supply their own and asked us to.
  create_sg = var.create_security_group && length(var.security_group_ids) == 0

  security_group_ids = local.create_sg ? [aws_security_group.this[0].id] : var.security_group_ids
}

resource "aws_security_group" "this" {
  count = local.create_sg ? 1 : 0

  name        = "${var.name}-alb"
  description = "Ingress on ${var.listener_port} for the ${var.name} ALB; all egress."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP listener"
    from_port   = var.listener_port
    to_port     = var.listener_port
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  egress {
    description = "All egress (reach the targets)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_lb" "this" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = local.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name        = "${var.name}-${each.key}"
  port        = each.value.port
  protocol    = each.value.protocol
  target_type = each.value.target_type
  vpc_id      = var.vpc_id

  health_check {
    path                = each.value.health_check_path
    matcher             = each.value.health_check_matcher
    interval            = each.value.health_check_interval
    healthy_threshold   = each.value.healthy_threshold
    unhealthy_threshold = each.value.unhealthy_threshold
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

# Register the supplied targets. Flatten target_groups -> (group, target) pairs so each registration
# is its own resource instance keyed by "<group>:<target>".
resource "aws_lb_target_group_attachment" "this" {
  for_each = {
    for pair in flatten([
      for tg_key, tg in var.target_groups : [
        for target_id in tg.target_ids : {
          key       = "${tg_key}:${target_id}"
          tg_key    = tg_key
          target_id = target_id
          port      = tg.port
        }
      ]
    ]) : pair.key => pair
  }

  target_group_arn = aws_lb_target_group.this[each.value.tg_key].arn
  target_id        = each.value.target_id
  port             = each.value.port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  # Default action: forward to the chosen default target group, else return a fixed 404 so unmatched
  # requests fail loud and cheap instead of hitting an arbitrary backend.
  dynamic "default_action" {
    for_each = var.default_target_group_key != null ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this[var.default_target_group_key].arn
    }
  }

  dynamic "default_action" {
    for_each = var.default_target_group_key == null ? [1] : []
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "text/plain"
        message_body = "No matching rule"
        status_code  = "404"
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-http" })
}

resource "aws_lb_listener_rule" "this" {
  for_each = var.listener_rules

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group_key].arn
  }

  dynamic "condition" {
    for_each = each.value.path_patterns != null && length(each.value.path_patterns) > 0 ? [1] : []
    content {
      path_pattern {
        values = each.value.path_patterns
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.host_headers != null && length(each.value.host_headers) > 0 ? [1] : []
    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}
