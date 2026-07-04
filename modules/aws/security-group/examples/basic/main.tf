provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the security group."
  type        = string
  default     = "example-security-group"
}

# Use the account's default VPC so the example is self-contained.
data "aws_vpc" "default" {
  default = true
}

module "security_group" {
  source = "../../"

  name        = var.name
  vpc_id      = data.aws_vpc.default.id
  description = "Example security group: HTTP from within the VPC, all egress."

  ingress_rules = [{
    description = "HTTP from within the VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }]

  # egress_rules defaults to allow-all.

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "security_group_id" {
  description = "ID of the created security group."
  value       = module.security_group.id
}

output "security_group_arn" {
  description = "ARN of the created security group."
  value       = module.security_group.arn
}
