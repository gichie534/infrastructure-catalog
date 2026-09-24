provider "aws" {
  region = var.region
}

# Fixture dependencies. These are plain resources rather than sibling modules so the example stays
# independent of other modules' versions — it is a test fixture, not a reference composition.
resource "aws_s3_bucket" "destination" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Environment = "example"
  }
}

resource "aws_kinesis_stream" "source" {
  name        = var.stream_name
  shard_count = 1

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  enforce_consumer_deletion = true

  tags = {
    Environment = "example"
  }
}

# A Kinesis-sourced delivery stream flushing to S3 on a 60s interval — the lowest practical latency,
# and what a low-freshness-lag pipeline would use.
module "firehose" {
  source = "../../"

  name                      = var.name
  source_kinesis_stream_arn = aws_kinesis_stream.source.arn
  destination_bucket_arn    = aws_s3_bucket.destination.arn

  prefix              = "stream/"
  error_output_prefix = "errors/"

  buffering_interval_seconds = 60
  buffering_size_mb          = 1

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
