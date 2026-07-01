provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name tag for the instance."
  type        = string
  default     = "example-ec2-instance"
}

# Resolve the latest Amazon Linux 2023 AMI from the SSM public parameter — keeps the example
# region-portable with no hardcoded AMI ID.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Use the account's default VPC + one of its (public) subnets so the example is self-contained.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "ec2_instance" {
  source = "../../"

  name      = var.name
  ami_id    = data.aws_ssm_parameter.al2023.value
  subnet_id = data.aws_subnets.default.ids[0]

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "instance_id" {
  description = "ID of the created instance."
  value       = module.ec2_instance.id
}

output "public_ip" {
  description = "Public IP of the created instance."
  value       = module.ec2_instance.public_ip
}
