# A Kinesis Data Firehose delivery stream that buffers records and writes them to S3, plus the IAM
# role Firehose assumes to do it and (optionally) the CloudWatch log group it reports delivery errors
# to.
#
# The delivery role is owned by this module rather than the consumer: it exists solely to serve this
# delivery stream, its permissions are fully derived from the source stream and destination bucket,
# and a consumer could not construct it without duplicating Firehose's exact requirements. This
# mirrors how `ecs-fargate-service` owns its execution and task roles.
#
# The destination bucket is NOT created here — pass the ARN of a bucket the consumer owns (e.g. from
# the `aws/s3-bucket` module). Same for the source Kinesis stream.
#
# SOURCE: set `source_kinesis_stream_arn` to read from a Kinesis data stream (Firehose polls it and
# the role is granted read on it). Leave it null for a Direct PUT stream that producers write to with
# the Firehose PutRecord API instead.

locals {
  # Firehose's own convention for its log group, kept predictable so a consumer can find it.
  log_group_name = "/aws/kinesisfirehose/${var.name}"

  read_from_kinesis = var.source_kinesis_stream_arn != null

  # ARN of the destination bucket's contents, derived from the bucket ARN the consumer passed.
  destination_objects_arn = "${var.destination_bucket_arn}/*"
}

# ---------------------------------------------------------------------------------------------------
# Delivery logs (optional) — where Firehose reports delivery failures. Without this, a stream that
# cannot write to S3 fails silently.
# ---------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  count = var.enable_cloudwatch_logging ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_stream" "s3_delivery" {
  count = var.enable_cloudwatch_logging ? 1 : 0

  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.this[0].name
}

# ---------------------------------------------------------------------------------------------------
# IAM — the role Firehose assumes to read the source stream and write to the destination bucket
# ---------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "delivery" {
  name               = "${var.name}-firehose-delivery"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "delivery" {
  # Writing buffered objects to the destination bucket. Firehose uploads multipart, so it needs the
  # multipart actions alongside PutObject, and GetBucketLocation/ListBucket to resolve the target.
  statement {
    sid    = "WriteDestinationObjects"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [
      var.destination_bucket_arn,
      local.destination_objects_arn,
    ]
  }

  # Reading the source stream, only when this is a Kinesis-sourced delivery stream.
  dynamic "statement" {
    for_each = local.read_from_kinesis ? [1] : []
    content {
      sid    = "ReadSourceStream"
      effect = "Allow"
      actions = [
        "kinesis:DescribeStream",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords",
        "kinesis:ListShards",
      ]
      resources = [var.source_kinesis_stream_arn]
    }
  }

  # Reporting delivery errors, only when logging is enabled.
  dynamic "statement" {
    for_each = var.enable_cloudwatch_logging ? [1] : []
    content {
      sid       = "WriteDeliveryLogs"
      effect    = "Allow"
      actions   = ["logs:PutLogEvents"]
      resources = ["${aws_cloudwatch_log_group.this[0].arn}:*"]
    }
  }
}

resource "aws_iam_role_policy" "delivery" {
  name   = "${var.name}-firehose-delivery"
  role   = aws_iam_role.delivery.id
  policy = data.aws_iam_policy_document.delivery.json
}

# ---------------------------------------------------------------------------------------------------
# The delivery stream
# ---------------------------------------------------------------------------------------------------
resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = var.name
  destination = "extended_s3"

  # Reading from a Kinesis data stream. Omitted entirely for a Direct PUT stream.
  dynamic "kinesis_source_configuration" {
    for_each = local.read_from_kinesis ? [1] : []
    content {
      kinesis_stream_arn = var.source_kinesis_stream_arn
      role_arn           = aws_iam_role.delivery.arn
    }
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.delivery.arn
    bucket_arn = var.destination_bucket_arn

    prefix              = var.prefix
    error_output_prefix = var.error_output_prefix

    # Firehose flushes when EITHER threshold is hit. The interval is the floor on end-to-end latency
    # for anything reading the delivered objects — the dominant term in streaming freshness.
    buffering_size     = var.buffering_size_mb
    buffering_interval = var.buffering_interval_seconds

    compression_format = var.compression_format

    dynamic "cloudwatch_logging_options" {
      for_each = var.enable_cloudwatch_logging ? [1] : []
      content {
        enabled         = true
        log_group_name  = aws_cloudwatch_log_group.this[0].name
        log_stream_name = aws_cloudwatch_log_stream.s3_delivery[0].name
      }
    }
  }

  tags = var.tags

  # The inline policy must exist before Firehose validates that it can reach the source/destination.
  depends_on = [aws_iam_role_policy.delivery]
}
