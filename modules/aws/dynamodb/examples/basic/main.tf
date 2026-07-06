provider "aws" {
  region = var.region
}

# A minimal on-demand table keyed by a single string hash key. Real consumers add a range key or
# switch to PROVISIONED capacity as their access pattern requires, and attach their own IAM policies
# referencing the table ARN.
module "table" {
  source = "../../"

  name          = var.name
  hash_key      = "ImageKey"
  hash_key_type = "S"

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
