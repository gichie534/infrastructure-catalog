provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create the buckets in. CloudFront itself is global."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Globally-unique prefix for the three example buckets and the distribution name."
  type        = string
}

# Three private origins: a static site, a jpg store, and a pdf store. Each bucket keeps the hardened
# baseline (all public access blocked); CloudFront reaches them only through OAC.
locals {
  buckets = toset(["site", "jpg", "pdf"])
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket        = "${var.name_prefix}-${each.key}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Fixtures the routing test reads back through CloudFront.
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.this["site"].id
  key          = "index.html"
  content      = "<html><body>hello from site<br><a href=\"/photo.jpg\">jpg</a> <a href=\"/report.pdf\">pdf</a></body></html>"
  content_type = "text/html"
}

resource "aws_s3_object" "jpg" {
  bucket       = aws_s3_bucket.this["jpg"].id
  key          = "photo.jpg"
  content      = "fake-jpeg-bytes-for-the-routing-test"
  content_type = "image/jpeg"
}

resource "aws_s3_object" "pdf" {
  bucket       = aws_s3_bucket.this["pdf"].id
  key          = "report.pdf"
  content      = "fake-pdf-bytes-for-the-routing-test"
  content_type = "application/pdf"
}

module "cdn" {
  source = "../../"

  name    = var.name_prefix
  comment = "cloudfront-s3 module example"

  origins = {
    site = { domain_name = aws_s3_bucket.this["site"].bucket_regional_domain_name }
    jpg  = { domain_name = aws_s3_bucket.this["jpg"].bucket_regional_domain_name }
    pdf  = { domain_name = aws_s3_bucket.this["pdf"].bucket_regional_domain_name }
  }

  default_origin_key = "site"

  ordered_cache_behaviors = [
    { path_pattern = "*.jpg", origin_key = "jpg" },
    { path_pattern = "*.pdf", origin_key = "pdf" },
  ]

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

# Each origin bucket trusts ONLY the CloudFront service principal, and only for this distribution
# (AWS:SourceArn). This is the OAC access recipe — the buckets stay fully private otherwise.
data "aws_iam_policy_document" "oac" {
  for_each = aws_s3_bucket.this

  statement {
    sid     = "AllowCloudFrontOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    resources = ["${each.value.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cdn.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "oac" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id
  policy = data.aws_iam_policy_document.oac[each.key].json
}

output "domain_name" {
  description = "CloudFront domain name to fetch objects through."
  value       = module.cdn.domain_name
}

output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = module.cdn.distribution_id
}
