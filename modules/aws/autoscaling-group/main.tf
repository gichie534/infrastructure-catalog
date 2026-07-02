# An EC2 Auto Scaling group fronted by a launch template, with a single target-tracking scaling
# policy on average CPU. The minimal "elastic compute" building block: a fleet that grows when the
# fleet-average CPU rises above a target and shrinks when it falls back.
#
# This module owns ONLY the launch template, the ASG, and the CPU scaling policy. It does not
# resolve the AMI, create the VPC/subnets/security groups, or define the IAM instance profile —
# those are the consumer's composition concern, passed in as inputs, so the module stays region-
# and account-agnostic.
#
# Security posture baked into the launch template (not parameterised — weakening it is rarely
# intentional):
#   - IMDSv2 required (http_tokens = "required") so the metadata service, and the role credentials
#     it vends, can't be reached via the legacy unauthenticated IMDSv1 path.
#   - Root EBS volume encrypted at rest.

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  # Attach the instance profile only when the consumer supplies one.
  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile != null ? [var.iam_instance_profile] : []
    content {
      name = iam_instance_profile.value
    }
  }

  # Require IMDSv2 — token-authenticated metadata access only.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.root_volume_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  # Public IP + security groups are configured on the interface (mutually exclusive with the
  # top-level security_group_ids attribute, so everything network-related lives here).
  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = length(var.vpc_security_group_ids) > 0 ? var.vpc_security_group_ids : null
    delete_on_termination       = true
  }

  user_data = var.user_data != null ? base64encode(var.user_data) : null

  # Name/tag the instances the group launches.
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = var.name })
  }

  tags = var.tags
}

resource "aws_autoscaling_group" "this" {
  name_prefix         = "${var.name}-"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.subnet_ids

  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # Propagate the module's tags (plus Name) to every launched instance.
  dynamic "tag" {
    for_each = merge(var.tags, { Name = var.name })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Replace the group cleanly when the launch template changes.
  lifecycle {
    create_before_destroy = true
  }
}

# Target-tracking on fleet-average CPU: AWS creates and manages the underlying CloudWatch alarms,
# adding capacity when the average rises above target_cpu_utilization and removing it when it drops.
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  # How long a freshly launched instance's metrics are ignored while it warms up, so the group
  # doesn't over-scale before the new capacity starts absorbing load.
  estimated_instance_warmup = var.estimated_instance_warmup

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}
