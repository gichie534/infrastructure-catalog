provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for the Auto Scaling group and its resources."
  type        = string
  default     = "example-asg"
}

# Resolve the latest Amazon Linux 2023 AMI from the SSM public parameter — keeps the example
# region-portable with no hardcoded AMI ID.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Use the account's default VPC + its (public) subnets so the example is self-contained.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "asg" {
  source = "../../"

  name       = var.name
  ami_id     = data.aws_ssm_parameter.al2023.value
  subnet_ids = data.aws_subnets.default.ids

  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  target_cpu_utilization = 40

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "autoscaling_group_name" {
  description = "Name of the created Auto Scaling group."
  value       = module.asg.autoscaling_group_name
}

output "launch_template_id" {
  description = "ID of the created launch template."
  value       = module.asg.launch_template_id
}
