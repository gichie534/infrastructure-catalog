# The Data Exports control plane lives only in us-east-1.
provider "aws" {
  region = "us-east-1"
}

variable "export_name" {
  description = "Name for the example export."
  type        = string
}

variable "bucket_name" {
  description = "Globally-unique name for the destination bucket."
  type        = string
}

# A dedicated destination bucket. The export module owns this bucket's policy, so no bucket_policy is
# set here — S3 allows only one policy per bucket.
module "export_bucket" {
  source = "../../../s3-bucket"

  bucket_name   = var.bucket_name
  force_destroy = true # example/lab: tear down without emptying first

  # Hourly, resource-level cost data accumulates. Expire it rather than paying to keep it forever.
  lifecycle_rules = [
    {
      id                                     = "expire-exports"
      expiration_days                        = 90
      abort_incomplete_multipart_upload_days = 7
    },
  ]

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

# CUR 2.0, hourly, with resource IDs — the most granular the table offers, and the reason the export
# exists: budgets and anomaly alerts tell you THAT spend moved, this tells you which resource moved it.
module "cost_data_export" {
  source = "../../"

  export_name = var.export_name

  s3_bucket = module.export_bucket.bucket
  s3_prefix = "cur2"
  s3_region = "us-east-1"

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "export_arn" {
  description = "ARN of the created export."
  value       = module.cost_data_export.export_arn
}

output "s3_uri" {
  description = "Where the export is delivered."
  value       = module.cost_data_export.s3_uri
}

output "query_statement" {
  description = "The resolved SQL statement."
  value       = module.cost_data_export.query_statement
}

output "bucket" {
  description = "Destination bucket name."
  value       = module.export_bucket.bucket
}
