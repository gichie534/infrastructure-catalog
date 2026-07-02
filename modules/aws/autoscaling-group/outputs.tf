output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group. Use it with the AWS CLI (e.g. aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <name>)."
  value       = aws_autoscaling_group.this.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling group."
  value       = aws_autoscaling_group.this.arn
}

output "launch_template_id" {
  description = "ID of the launch template the group uses."
  value       = aws_launch_template.this.id
}

output "launch_template_latest_version" {
  description = "Latest version number of the launch template."
  value       = aws_launch_template.this.latest_version
}

output "scaling_policy_arn" {
  description = "ARN of the CPU target-tracking scaling policy."
  value       = aws_autoscaling_policy.cpu.arn
}
