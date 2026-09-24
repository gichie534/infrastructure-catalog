# A Redshift Serverless data warehouse: a namespace (the database, its admin credentials, and the IAM
# roles it can assume) and a workgroup (the compute that serves queries, placed in your VPC), plus the
# IAM role Redshift assumes to COPY from S3.
#
# The COPY role is owned by this module rather than the consumer because Redshift requires it to be
# associated with the namespace at creation time, its trust policy is Redshift-specific, and its
# permissions derive entirely from the buckets the consumer names in `s3_read_bucket_arns`. This
# mirrors how `ecs-fargate-service` owns its execution and task roles.
#
# The VPC, subnets, security groups, and source buckets are all the consumer's — this module stays
# account- and region-agnostic.
#
# CREDENTIALS: by default `manage_admin_password` is on, so Redshift creates and rotates the admin
# secret in Secrets Manager. No password passes through Terraform variables or state. Queries are
# expected to run over the Redshift Data API with IAM authentication, which needs no password at all.

locals {
  # Redshift Serverless requires the namespace and workgroup to be named separately, but a consumer
  # thinks of them as one warehouse. Derive both from a single name.
  namespace_name = var.namespace_name != null ? var.namespace_name : var.name
  workgroup_name = var.workgroup_name != null ? var.workgroup_name : var.name

  grant_s3_read = length(var.s3_read_bucket_arns) > 0

  # Object-level ARNs derived from the bucket ARNs the consumer passed.
  s3_object_arns = [for arn in var.s3_read_bucket_arns : "${arn}/*"]
}

# ---------------------------------------------------------------------------------------------------
# IAM — the role Redshift assumes to read S3 during COPY
# ---------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      # Both principals are needed: provisioned Redshift and Redshift Serverless assume the role
      # under different service names depending on the operation.
      identifiers = [
        "redshift.amazonaws.com",
        "redshift-serverless.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "copy" {
  name               = "${var.name}-redshift-copy"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "copy" {
  count = local.grant_s3_read ? 1 : 0

  # COPY reads the objects themselves; it also lists the prefix and resolves the bucket region.
  statement {
    sid       = "ReadSourceObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = local.s3_object_arns
  }

  statement {
    sid    = "ListSourceBuckets"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = var.s3_read_bucket_arns
  }
}

resource "aws_iam_role_policy" "copy" {
  count = local.grant_s3_read ? 1 : 0

  name   = "${var.name}-redshift-copy"
  role   = aws_iam_role.copy.id
  policy = data.aws_iam_policy_document.copy[0].json
}

# ---------------------------------------------------------------------------------------------------
# Namespace — the database and its identity
# ---------------------------------------------------------------------------------------------------
resource "aws_redshiftserverless_namespace" "this" {
  namespace_name = local.namespace_name
  db_name        = var.database_name
  admin_username = var.admin_username

  # Let Redshift own the admin secret in Secrets Manager unless the consumer explicitly supplies a
  # password. Passing null here omits the attribute entirely, which avoids the provider's
  # conflicts-with between the two.
  manage_admin_password = var.admin_user_password == null ? true : null
  admin_user_password   = var.admin_user_password

  # The COPY role must be associated with the namespace for `COPY ... IAM_ROLE` to be able to use it,
  # and being the default means a statement can say `IAM_ROLE default` instead of naming the ARN.
  iam_roles            = [aws_iam_role.copy.arn]
  default_iam_role_arn = aws_iam_role.copy.arn

  log_exports = var.log_exports

  tags = var.tags

  depends_on = [aws_iam_role_policy.copy]
}

# ---------------------------------------------------------------------------------------------------
# Workgroup — the compute that serves queries
# ---------------------------------------------------------------------------------------------------
resource "aws_redshiftserverless_workgroup" "this" {
  namespace_name = aws_redshiftserverless_namespace.this.namespace_name
  workgroup_name = local.workgroup_name

  # Billed per RPU-hour while queries run. 8 is the minimum and the right choice for a warehouse that
  # serves occasional loads and queries rather than sustained analytics.
  base_capacity = var.base_capacity
  max_capacity  = var.max_capacity

  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  # Private by default. With the Data API there is no need to expose the workgroup publicly: requests
  # go to a regional AWS endpoint authenticated with IAM, not to the warehouse over the network.
  publicly_accessible  = var.publicly_accessible
  enhanced_vpc_routing = var.enhanced_vpc_routing

  dynamic "config_parameter" {
    for_each = var.config_parameters
    content {
      parameter_key   = config_parameter.key
      parameter_value = config_parameter.value
    }
  }

  tags = var.tags
}
