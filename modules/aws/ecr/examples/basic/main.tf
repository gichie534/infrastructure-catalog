provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the example ECR repository."
  type        = string
}

# Minimal call: a mutable, scan-on-push repository that tears down cleanly (force_delete) and expires
# untagged images after a week.
module "ecr" {
  source = "../../"

  name                       = var.name
  force_delete               = true
  untagged_image_expiry_days = 7

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "repository_url" {
  description = "URL of the created repository."
  value       = module.ecr.repository_url
}

output "arn" {
  description = "ARN of the created repository."
  value       = module.ecr.arn
}

output "name" {
  description = "Name of the created repository."
  value       = module.ecr.name
}
