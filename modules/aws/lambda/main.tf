# A Lambda function plus its execution role — the minimal serverless-compute building block. The
# consumer supplies the deployment package (a zip), handler, and runtime; the module wires the
# execution role, optional VPC attachment, and a log group.
#
# The module owns the function, its IAM execution role, and (optionally) its CloudWatch log group.
# It does not build the zip or create the VPC/subnets/security groups — those are the consumer's
# concern, passed in as inputs. That keeps the module region- and account-agnostic and reusable.
#
# When vpc_config is set, the module attaches the AWS-managed AWSLambdaVPCAccessExecutionRole policy
# so the function can create the ENIs it needs in the given subnets; otherwise it attaches only the
# basic AWSLambdaBasicExecutionRole (CloudWatch Logs). Extra permissions go through
# additional_policy_arns / inline_policies.

locals {
  in_vpc = var.vpc_config != null

  # Basic execution (Logs) always; VPC access only when attached to a VPC.
  base_policy_arns = local.in_vpc ? [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    ] : [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ]

  managed_policy_arns = toset(concat(local.base_policy_arns, var.additional_policy_arns))
}

# Trust policy: only the Lambda service may assume this role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowLambdaAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = local.managed_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}

# Explicit log group so retention is controlled (and destroyed with the module) rather than an
# implicit, never-expiring group created lazily on first invocation.
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = aws_iam_role.this.arn

  filename         = var.filename
  source_code_hash = filebase64sha256(var.filename)

  handler       = var.handler
  runtime       = var.runtime
  architectures = [var.architecture]

  memory_size = var.memory_size
  timeout     = var.timeout

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = local.in_vpc ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = var.tags

  # The role's policy attachments (esp. VPC access) must exist before the function is created, or
  # ENI setup fails; and the log group before it, so logs land in the retention-managed group.
  depends_on = [
    aws_iam_role_policy_attachment.managed,
    aws_cloudwatch_log_group.this,
  ]
}
