provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the role and instance profile."
  type        = string
  default     = "example-instance-profile"
}

# A minimal least-privilege grant: list bucket names only (what `aws s3 ls` needs).
data "aws_iam_policy_document" "s3_list" {
  statement {
    sid       = "ListAllMyBuckets"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }
}

# The instance role + profile: reachable via SSM Session Manager (managed policy) and able to list
# bucket names (inline policy). This is the exact shape a consumer uses for a minimal EC2 identity.
module "iam_instance_profile" {
  source = "../../"

  name = var.name

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  inline_policies = {
    s3-list = data.aws_iam_policy_document.s3_list.json
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "instance_profile_name" {
  description = "Instance profile name to attach to an EC2 instance."
  value       = module.iam_instance_profile.instance_profile_name
}

output "role_arn" {
  description = "ARN of the created role."
  value       = module.iam_instance_profile.role_arn
}
