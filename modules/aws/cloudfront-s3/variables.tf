variable "name" {
  description = "Name of the distribution, used to name the origin access control and as the Name tag. Must be 1-64 chars, alphanumeric or hyphens."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}[a-zA-Z0-9]$", var.name))
    error_message = "name must be 1-64 characters, alphanumeric or hyphens, and not start or end with a hyphen."
  }
}

variable "origins" {
  description = <<-EOT
    S3 origins fronted by the distribution, keyed by a logical origin id (referenced by
    `default_origin_key` and the cache behaviors). Each value:
      - domain_name : the bucket's REGIONAL domain name (e.g. `my-bucket.s3.us-east-1.amazonaws.com`),
                      i.e. `aws_s3_bucket.this.bucket_regional_domain_name`. The regional form is
                      required for Origin Access Control (OAC) to sign requests correctly.
      - origin_path : optional path prepended to every request forwarded to this origin (e.g. `/static`).

    Every origin is wired to a single shared OAC (SigV4, always sign), so each bucket only needs a
    policy allowing the `cloudfront.amazonaws.com` service principal for this distribution's ARN.
  EOT
  type = map(object({
    domain_name = string
    origin_path = optional(string)
  }))
  nullable = false

  validation {
    condition     = length(var.origins) > 0
    error_message = "at least one origin must be defined."
  }
}

variable "default_origin_key" {
  description = "Key (from origins) the default cache behavior forwards to — i.e. what serves any request that matches no ordered_cache_behavior path pattern."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.default_origin_key) > 0
    error_message = "default_origin_key must be set to one of the origins keys."
  }
}

variable "ordered_cache_behaviors" {
  description = <<-EOT
    Path-based routing rules, evaluated in list order (first match wins) before the default behavior.
    Each element:
      - path_pattern : CloudFront path pattern, e.g. `*.jpg` or `/images/*`.
      - origin_key   : key (from origins) to forward matching requests to.
    Leave empty to route everything to the default origin.
  EOT
  type = list(object({
    path_pattern = string
    origin_key   = string
  }))
  nullable = false
  default  = []
}

variable "default_root_object" {
  description = "Object CloudFront returns for a request to the distribution root (`/`). Set to \"\" to disable."
  type        = string
  nullable    = false
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFront price class controlling which edge locations serve the distribution. One of PriceClass_100, PriceClass_200, PriceClass_All."
  type        = string
  nullable    = false
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "comment" {
  description = "Comment shown against the distribution in the console/API."
  type        = string
  nullable    = false
  default     = ""
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module."
  type        = map(string)
  nullable    = false
  default     = {}
}
