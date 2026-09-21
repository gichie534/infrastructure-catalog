# An AWS Data Exports export (CUR 2.0 by default) delivered to an existing S3 bucket.
#
# Why a module for one resource: the resource is the easy half. The half that goes wrong is the bucket
# policy. Data Exports writes as the service principal `bcm-data-exports.amazonaws.com`, conditioned on
# the account that created the export, and AWS refuses to create the export at all if that grant is
# missing — reporting only a generic "Invalid bucket". So this module owns the policy alongside the
# export, which also makes ownership unambiguous (S3 permits one policy per bucket).
#
# It deliberately does not create the bucket. Compose it with `aws/s3-bucket`, which already owns a
# hardened baseline and lifecycle rules; duplicating that here would fork a solved problem.
#
# Note the asymmetry in regions: the Data Exports control plane lives only in us-east-1 (visible in the
# SourceArn below, and the reason the calling unit needs a us-east-1 provider), while the destination
# bucket can live anywhere — hence `s3_region` as an input.

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = var.source_account_id != null ? var.source_account_id : data.aws_caller_identity.current.account_id

  bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.s3_bucket}"

  # Curated starting points. Not the full schema — a narrower export is cheaper to store and query, and
  # every column here is one you would reach for in a first cost investigation: what was charged, to
  # which account, for which resource, in which period, at what rate. Extend via `columns` (e.g. the
  # savings_plan_* / reservation_* families once you have commitments to amortise).
  default_columns = {
    COST_AND_USAGE_REPORT = [
      "identity_line_item_id",
      "identity_time_interval",
      "bill_bill_type",
      "bill_billing_period_start_date",
      "bill_billing_period_end_date",
      "bill_payer_account_id",
      "bill_invoice_id",
      "line_item_usage_account_id",
      "line_item_line_item_type",
      "line_item_usage_start_date",
      "line_item_usage_end_date",
      "line_item_product_code",
      "line_item_usage_type",
      "line_item_operation",
      "line_item_availability_zone",
      "line_item_resource_id",
      "line_item_usage_amount",
      "line_item_unblended_cost",
      "line_item_unblended_rate",
      "line_item_currency_code",
      "line_item_line_item_description",
      "pricing_unit",
      "pricing_term",
      "resource_tags",
    ]
  }

  default_table_configurations = {
    COST_AND_USAGE_REPORT = {
      # Granularity you did not capture cannot be recovered later; an export that is too large is a
      # lifecycle rule away from being fine.
      TIME_GRANULARITY  = "HOURLY"
      INCLUDE_RESOURCES = "TRUE"

      INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE"
      INCLUDE_SPLIT_COST_ALLOCATION_DATA    = "FALSE"
    }
  }

  columns = length(var.columns) > 0 ? var.columns : lookup(local.default_columns, var.table, [])

  query_statement = (
    var.query_statement != null
    ? var.query_statement
    : "SELECT ${join(", ", local.columns)} FROM ${var.table}"
  )

  table_configurations = (
    var.table_configurations != null
    ? var.table_configurations
    : lookup(local.default_table_configurations, var.table, {})
  )
}

# The delivery grant. Scoped to s3:PutObject only — Data Exports never needs to read or delete what it
# has written.
data "aws_iam_policy_document" "delivery" {
  statement {
    sid    = "EnableAWSDataExportsToWriteToS3"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["bcm-data-exports.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${local.bucket_arn}/*"]

    # Confused-deputy protection: only exports created by this account may write here. The us-east-1 in
    # the ARN is a property of the Data Exports service, not of the caller's region.
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:bcm-data-exports:us-east-1:${local.account_id}:export/*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "delivery" {
  count = var.manage_bucket_policy ? 1 : 0

  bucket = var.s3_bucket
  policy = data.aws_iam_policy_document.delivery.json
}

resource "aws_bcmdataexports_export" "this" {
  export {
    name = var.export_name

    data_query {
      query_statement = local.query_statement

      # Omitted entirely when empty: the API rejects an empty configuration object.
      table_configurations = length(local.table_configurations) > 0 ? { (var.table) = local.table_configurations } : null
    }

    destination_configurations {
      s3_destination {
        s3_bucket = var.s3_bucket
        s3_prefix = var.s3_prefix
        s3_region = var.s3_region

        s3_output_configurations {
          format      = var.format
          compression = var.compression
          overwrite   = var.overwrite
          output_type = "CUSTOM"
        }
      }
    }

    refresh_cadence {
      # The only value AWS supports. Data is refreshed at least daily; the first delivery lands within
      # roughly 24 hours of creation.
      frequency = "SYNCHRONOUS"
    }
  }

  tags = var.tags

  # AWS validates the destination bucket when the export is created, so the policy must already be in
  # place. Nothing in the export references the policy resource, so the dependency has to be explicit.
  depends_on = [aws_s3_bucket_policy.delivery]

  lifecycle {
    precondition {
      condition     = var.query_statement != null || length(local.columns) > 0
      error_message = "table '${var.table}' has no curated column list in this module: set `columns` or `query_statement`."
    }

    # AWS pairs format with compression; the wrong combination fails at apply with an opaque error.
    precondition {
      condition = (
        (var.format == "PARQUET" && var.compression == "PARQUET") ||
        (var.format == "TEXT_OR_CSV" && var.compression == "GZIP")
      )
      error_message = "format/compression must be PARQUET+PARQUET or TEXT_OR_CSV+GZIP, got ${var.format}+${var.compression}."
    }
  }
}
