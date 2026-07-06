# A single DynamoDB table — the minimal key/value + document store building block a consumer wires
# its application and IAM to.
#
# The module owns only the table. It deliberately does NOT create IAM policies granting access:
# that is the consumer's composition concern (a lab grants GetItem/PutItem/Query to specific Lambda
# execution roles using the table ARN this module outputs). Keeping the module single-purpose keeps
# it reusable.
#
# On-demand (PAY_PER_REQUEST) by default so a lab costs nothing when idle; switch to PROVISIONED with
# explicit capacities for steady, predictable traffic. The key schema (a required hash key and an
# optional range key) and their attribute types are inputs.

locals {
  # DynamoDB requires an `attribute` block only for attributes used in the key schema (and indexes).
  # Build that set from the hash key plus the optional range key.
  key_attributes = concat(
    [{ name = var.hash_key, type = var.hash_key_type }],
    var.range_key != null ? [{ name = var.range_key, type = var.range_key_type }] : [],
  )
}

resource "aws_dynamodb_table" "this" {
  name         = var.name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key
  range_key    = var.range_key

  # Only meaningful for PROVISIONED; null (ignored) for PAY_PER_REQUEST.
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  dynamic "attribute" {
    for_each = local.key_attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  deletion_protection_enabled = var.deletion_protection_enabled

  tags = var.tags
}
