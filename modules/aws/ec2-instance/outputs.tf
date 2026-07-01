output "id" {
  description = "ID of the EC2 instance. Use it with the AWS CLI / SSM (e.g. aws ssm start-session --target <id>)."
  value       = aws_instance.this.id
}

output "arn" {
  description = "ARN of the EC2 instance."
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "Private IPv4 address of the instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IPv4 address of the instance, if one was assigned (else empty)."
  value       = aws_instance.this.public_ip
}
