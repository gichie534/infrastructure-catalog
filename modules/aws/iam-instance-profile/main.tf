# An EC2 instance role + instance profile — the minimal IAM wiring that lets an EC2 instance assume
# a role and receive temporary credentials via the instance metadata service (IMDS).
#
# The chain this module builds:
#   EC2 service --assume--> IAM role --(managed + inline policies)--> permissions
#   the role is exposed to the instance through an instance profile (the EC2-shaped wrapper).
#
# This module owns ONLY the identity (role + profile + policy wiring). It does not create the EC2
# instance, and the permissions themselves are the consumer's concern: pass AWS-managed policy ARNs
# (e.g. AmazonSSMManagedInstanceCore) via managed_policy_arns and narrow least-privilege grants via
# inline_policies. Keeping it single-purpose keeps it reusable across labs.

# Trust policy: only the EC2 service may assume this role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowEC2AssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

# Attach pre-existing managed policies (e.g. AmazonSSMManagedInstanceCore for Session Manager).
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# Embed narrow, workload-specific least-privilege policies inline on the role.
resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}

# The instance profile is the container EC2 uses to hand the role to an instance.
resource "aws_iam_instance_profile" "this" {
  name = var.name
  role = aws_iam_role.this.name

  tags = var.tags
}
