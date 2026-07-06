# A single, hardened-by-default S3 bucket. The module owns a secure baseline so consumers can't
# accidentally ship a public or unencrypted bucket:
#   - all public access blocked
#   - server-side encryption on (SSE-S3 / AES256)
#   - object ownership set to BucketOwnerEnforced (ACLs disabled — ownership is by the bucket owner)
#
# Access control is expressed purely through IAM and an optional bucket policy. The module owns only
# the bucket + its baseline; the policy is the consumer's concern (raw JSON passthrough), which keeps
# the module reusable — e.g. pass an ABAC policy matching aws:PrincipalTag/* from a lab.

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = var.tags
}

# Block every avenue of public access. This is the baseline the module refuses to compromise on.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Disable ACLs entirely: the bucket owner owns every object, and access is governed by policies only.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Encrypt objects at rest with SSE-S3 (AES256) by default — no consumer input required.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Optional CORS configuration. Only created when cors_rules is non-empty. Needed when a browser makes
# cross-origin requests directly to the bucket — e.g. a PUT to a presigned upload URL from a web page
# served on a different origin.
resource "aws_s3_bucket_cors_configuration" "this" {
  count = length(var.cors_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# Optional raw bucket policy (e.g. an ABAC policy). Only created when a policy string is supplied.
# Depends on the public access block so BlockPublicPolicy is in force before the policy is evaluated.
resource "aws_s3_bucket_policy" "this" {
  count = var.bucket_policy != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy

  depends_on = [aws_s3_bucket_public_access_block.this]
}
