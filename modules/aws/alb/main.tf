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

  # When a certificate is supplied, terminate TLS on an HTTPS listener and redirect plain HTTP to it.
  https_enabled = var.certificate_arn != null

  # Listener rules (and the default forward/404) attach to the HTTPS listener when it exists,
  # otherwise to the HTTP listener.
  primary_listener_arn = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn

  # Lambda target groups register a single function (the ARN) and need an invoke permission before
  # the registration; instance/ip groups register by id and don't. Split them out here so each path
  # gets the right resources. Keyed by target-group key -> function ARN.
  lambda_targets = {
    for tg_key, tg in var.target_groups : tg_key => tg.target_ids[0]
    if tg.target_type == "lambda" && length(tg.target_ids) > 0
  }
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

  # Open the HTTPS port too when TLS is terminated here.
  dynamic "ingress" {
    for_each = local.https_enabled ? [1] : []
    content {
      description = "HTTPS listener"
      from_port   = var.https_listener_port
      to_port     = var.https_listener_port
      protocol    = "tcp"
      cidr_blocks = var.ingress_cidr_blocks
    }
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
  target_type = each.value.target_type

  # port/protocol/vpc_id are invalid on a lambda target group — the ALB invokes the function through
  # the Lambda service, not over the network — so they are set only for instance/ip groups.
  port     = each.value.target_type == "lambda" ? null : each.value.port
  protocol = each.value.target_type == "lambda" ? null : each.value.protocol
  vpc_id   = each.value.target_type == "lambda" ? null : var.vpc_id

  # Only meaningful for lambda targets; leave unset otherwise.
  lambda_multi_value_headers_enabled = each.value.target_type == "lambda" ? each.value.lambda_multi_value_headers_enabled : null

  # HTTP-style health checks apply to instance/ip groups. Lambda target groups have them disabled
  # (the default), so the function is considered healthy without a probe path.
  dynamic "health_check" {
    for_each = each.value.target_type == "lambda" ? [] : [1]
    content {
      path                = each.value.health_check_path
      matcher             = each.value.health_check_matcher
      interval            = each.value.health_check_interval
      healthy_threshold   = each.value.healthy_threshold
      unhealthy_threshold = each.value.unhealthy_threshold
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

# Register instance/ip targets. Flatten target_groups -> (group, target) pairs so each registration
# is its own resource instance keyed by "<group>:<target>". Lambda groups are handled separately
# (they need an invoke permission first).
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
      ] if tg.target_type != "lambda"
    ]) : pair.key => pair
  }

  target_group_arn = aws_lb_target_group.this[each.value.tg_key].arn
  target_id        = each.value.target_id
  port             = each.value.port
}

# Allow Elastic Load Balancing to invoke each lambda target. The registration below depends on this
# so the permission exists before the function is attached to the target group.
resource "aws_lambda_permission" "alb" {
  for_each = local.lambda_targets

  statement_id  = "AllowInvokeFromALB-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.this[each.key].arn
}

# Register the lambda function (by ARN) with its target group.
resource "aws_lb_target_group_attachment" "lambda" {
  for_each = local.lambda_targets

  target_group_arn = aws_lb_target_group.this[each.key].arn
  target_id        = each.value

  depends_on = [aws_lambda_permission.alb]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  # When HTTPS is enabled, the HTTP listener does nothing but redirect (301) to HTTPS.
  dynamic "default_action" {
    for_each = local.https_enabled ? [1] : []
    content {
      type = "redirect"
      redirect {
        protocol    = "HTTPS"
        port        = tostring(var.https_listener_port)
        status_code = "HTTP_301"
      }
    }
  }

  # Plain-HTTP mode: forward to the chosen default target group, else return a fixed 404 so unmatched
  # requests fail loud and cheap instead of hitting an arbitrary backend.
  dynamic "default_action" {
    for_each = !local.https_enabled && var.default_target_group_key != null ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this[var.default_target_group_key].arn
    }
  }

  dynamic "default_action" {
    for_each = !local.https_enabled && var.default_target_group_key == null ? [1] : []
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

# HTTPS listener — created only when a certificate is supplied. Terminates TLS and carries the
# routing rules; its default action mirrors the plain-HTTP behaviour (forward to default or 404).
resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = var.https_listener_port
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

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

  tags = merge(var.tags, { Name = "${var.name}-https" })
}

resource "aws_lb_listener_rule" "this" {
  for_each = var.listener_rules

  listener_arn = local.primary_listener_arn
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
