# A CloudFront distribution that fronts one or more PRIVATE S3 buckets and routes requests to them by
# path pattern. Access to the buckets is via Origin Access Control (OAC): CloudFront signs each
# origin request with SigV4, so the buckets can keep all public access blocked and only trust the
# CloudFront service principal for this distribution.
#
# The module owns ONLY the distribution and its shared OAC. It does not create the buckets or their
# bucket policies — those are the consumer's composition concern (the consumer wires each bucket's
# policy to `output.distribution_arn`). That keeps the module region/account-agnostic and reusable.
#
# All origins share one OAC and one managed cache policy (CachingOptimized). Viewer requests are
# redirected to HTTPS; only GET/HEAD are allowed (a static content distribution).

locals {
  # Managed CachingOptimized policy id — the same well-known id in every account/region.
  caching_optimized_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

# One Origin Access Control shared by every S3 origin. always sign + sigv4 is the S3 OAC recipe.
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.name
  description                       = "OAC for the ${var.name} distribution."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = var.comment
  default_root_object = var.default_root_object != "" ? var.default_root_object : null
  price_class         = var.price_class

  dynamic "origin" {
    for_each = var.origins
    content {
      origin_id                = origin.key
      domain_name              = origin.value.domain_name
      origin_path              = origin.value.origin_path
      origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    }
  }

  # Default behavior: everything that matches no ordered behavior below is served by this origin.
  default_cache_behavior {
    target_origin_id       = var.default_origin_key
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = local.caching_optimized_policy_id
    compress               = true
  }

  # Path-based routing: first matching path_pattern (in list order) wins over the default.
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.origin_key
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      cache_policy_id        = local.caching_optimized_policy_id
      compress               = true
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # No custom domain/ACM in this module — use the default *.cloudfront.net certificate.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, { Name = var.name })
}
