output "id" {
  description = "ID of the security group. Attach it to instances, load balancers, Lambda VPC configs, or reference it as a source in another group's rule."
  value       = aws_security_group.this.id
}

output "arn" {
  description = "ARN of the security group."
  value       = aws_security_group.this.arn
}

output "name" {
  description = "Name of the security group."
  value       = aws_security_group.this.name
}
