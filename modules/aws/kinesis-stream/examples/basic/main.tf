provider "aws" {
  region = var.region
}

# A minimal single-shard provisioned stream with the default 24h replay window and SSE via the
# AWS-managed Kinesis key. Shard-level metrics are enabled here because they are the two a real
# consumer watches first: producer throttling and consumer lag.
module "kinesis_stream" {
  source = "../../"

  name        = var.name
  shard_count = 1

  shard_level_metrics = [
    "WriteProvisionedThroughputExceeded",
    "IteratorAgeMilliseconds",
  ]

  # Throwaway example — let destroy remove the stream even if a consumer is registered.
  enforce_consumer_deletion = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
