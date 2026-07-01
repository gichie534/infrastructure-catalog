provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally-unique name for the example bucket."
  type        = string
}

data "aws_caller_identity" "current" {}

# Build the bucket ARN from the (plan-known) bucket name rather than the module's output. An S3 ARN
# is fully derivable from the name, and referencing module.s3_bucket.arn here would make the policy —
# and thus the module's `count` on bucket_policy — unknown until apply (Terraform rejects a count
# that depends on an apply-time value). It also avoids feeding a module output back into its input.
locals {
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"
}

# An ABAC bucket policy: allow S3 access to principals in this account only when their
# `aws:PrincipalTag/Project` matches the bucket's `Project` tag ("demo"). This is the raw JSON the
# module attaches via aws_s3_bucket_policy — the module itself stays policy-agnostic.
data "aws_iam_policy_document" "abac" {
  statement {
    sid     = "ABACProjectMatch"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]

    resources = [
      local.bucket_arn,
      "${local.bucket_arn}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/Project"
      values   = ["demo"]
    }
  }
}

# Minimal call: an explicit bucket name, clean teardown for the lab, and the ABAC policy above.
module "s3_bucket" {
  source = "../../"

  bucket_name   = var.bucket_name
  force_destroy = true
  bucket_policy = data.aws_iam_policy_document.abac.json

  tags = {
    Project     = "demo"
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "bucket" {
  description = "Name of the created bucket."
  value       = module.s3_bucket.bucket
}

output "arn" {
  description = "ARN of the created bucket."
  value       = module.s3_bucket.arn
}
