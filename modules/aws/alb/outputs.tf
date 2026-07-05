output "arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "Public DNS name of the ALB — the endpoint clients send requests to."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Route 53 hosted zone ID of the ALB, for aliasing a custom domain to it."
  value       = aws_lb.this.zone_id
}

output "security_group_id" {
  description = "ID of the security group attached to the ALB (the one created by this module, or the first supplied one)."
  value       = try(local.security_group_ids[0], null)
}

output "target_group_arns" {
  description = "Map of target group key to its ARN."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "target_group_names" {
  description = "Map of target group key to its name."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.name }
}

output "listener_arn" {
  description = "ARN of the HTTP listener (a redirect-to-HTTPS listener when certificate_arn is set, otherwise the traffic-serving listener)."
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener, or null when no certificate_arn was supplied."
  value       = local.https_enabled ? aws_lb_listener.https[0].arn : null
}
