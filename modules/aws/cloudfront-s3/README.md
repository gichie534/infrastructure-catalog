# aws/cloudfront-s3

A CloudFront distribution that fronts one or more **private** S3 buckets and routes requests to them
by **path pattern**. Buckets stay fully private (all public access blocked); CloudFront reaches them
through **Origin Access Control (OAC)** — it signs every origin request with SigV4, so each bucket
only needs a policy trusting the `cloudfront.amazonaws.com` service principal for this distribution.

- **Multi-origin** — pass a map of S3 origins (keyed by a logical id), each pointing at a bucket's
  **regional** domain name (`bucket_regional_domain_name`, required for OAC signing).
- **Path routing** — `ordered_cache_behaviors` map path patterns (e.g. `*.jpg`, `*.pdf`) to origins;
  the first match wins, and anything unmatched is served by `default_origin_key`.
- **Shared OAC** — one Origin Access Control (`always` sign, `sigv4`) is wired to every origin.
- **HTTPS by default** — viewer requests are redirected to HTTPS on the default `*.cloudfront.net`
  certificate; only `GET`/`HEAD` are allowed (static content). Caching uses the managed
  CachingOptimized policy by default; set `cache_policy_id` to override (e.g. the managed
  CachingDisabled policy so viewers always fetch from the origin).

The module owns **only the distribution and its OAC**. It does not create the buckets or their bucket
policies — the consumer creates each bucket and attaches a policy that allows `s3:GetObject` to the
CloudFront service principal, scoped by `AWS:SourceArn = output.distribution_arn`. Keeping it
single-purpose keeps it reusable across labs.

## Usage

```hcl
module "cdn" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/cloudfront-s3?ref=aws-cloudfront-s3-v0.1.0"

  name = "my-lab-cdn"

  origins = {
    site = { domain_name = aws_s3_bucket.site.bucket_regional_domain_name }
    jpg  = { domain_name = aws_s3_bucket.jpg.bucket_regional_domain_name }
    pdf  = { domain_name = aws_s3_bucket.pdf.bucket_regional_domain_name }
  }

  default_origin_key = "site"

  ordered_cache_behaviors = [
    { path_pattern = "*.jpg", origin_key = "jpg" },
    { path_pattern = "*.pdf", origin_key = "pdf" },
  ]
}

# Each origin bucket grants read to ONLY this distribution via OAC.
data "aws_iam_policy_document" "oac" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cdn.distribution_arn]
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name                                                                      | Version |
| ------------------------------------------------------------------------- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0  |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 5.0  |

## Providers

| Name                                              | Version |
| ------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.53.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                                                      | Type     |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution)                   | resource |
| [aws_cloudfront_origin_access_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |

## Inputs

| Name                                                                                                        | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Type                                                                                                  | Default            | Required |
| ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------ | :------: |
| <a name="input_comment"></a> [comment](#input\_comment)                                                     | Comment shown against the distribution in the console/API.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `string`                                                                                              | `""`               |    no    |
| <a name="input_default_origin_key"></a> [default\_origin\_key](#input\_default\_origin\_key)                | Key (from origins) the default cache behavior forwards to — i.e. what serves any request that matches no ordered\_cache\_behavior path pattern.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `string`                                                                                              | n/a                |   yes    |
| <a name="input_default_root_object"></a> [default\_root\_object](#input\_default\_root\_object)             | Object CloudFront returns for a request to the distribution root (`/`). Set to "" to disable.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | `string`                                                                                              | `"index.html"`     |    no    |
| <a name="input_name"></a> [name](#input\_name)                                                              | Name of the distribution, used to name the origin access control and as the Name tag. Must be 1-64 chars, alphanumeric or hyphens.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `string`                                                                                              | n/a                |   yes    |
| <a name="input_ordered_cache_behaviors"></a> [ordered\_cache\_behaviors](#input\_ordered\_cache\_behaviors) | Path-based routing rules, evaluated in list order (first match wins) before the default behavior.<br/>Each element:<br/>  - path\_pattern : CloudFront path pattern, e.g. `*.jpg` or `/images/*`.<br/>  - origin\_key   : key (from origins) to forward matching requests to.<br/>Leave empty to route everything to the default origin.                                                                                                                                                                                                                                                                                                                                                                                                                                     | <pre>list(object({<br/>    path_pattern = string<br/>    origin_key   = string<br/>  }))</pre>        | `[]`               |    no    |
| <a name="input_origins"></a> [origins](#input\_origins)                                                     | S3 origins fronted by the distribution, keyed by a logical origin id (referenced by<br/>`default_origin_key` and the cache behaviors). Each value:<br/>  - domain\_name : the bucket's REGIONAL domain name (e.g. `my-bucket.s3.us-east-1.amazonaws.com`),<br/>                  i.e. `aws_s3_bucket.this.bucket_regional_domain_name`. The regional form is<br/>                  required for Origin Access Control (OAC) to sign requests correctly.<br/>  - origin\_path : optional path prepended to every request forwarded to this origin (e.g. `/static`).<br/><br/>Every origin is wired to a single shared OAC (SigV4, always sign), so each bucket only needs a<br/>policy allowing the `cloudfront.amazonaws.com` service principal for this distribution's ARN. | <pre>map(object({<br/>    domain_name = string<br/>    origin_path = optional(string)<br/>  }))</pre> | n/a                |   yes    |
| <a name="input_price_class"></a> [price\_class](#input\_price\_class)                                       | CloudFront price class controlling which edge locations serve the distribution. One of PriceClass\_100, PriceClass\_200, PriceClass\_All.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | `string`                                                                                              | `"PriceClass_100"` |    no    |
| <a name="input_tags"></a> [tags](#input\_tags)                                                              | Tags applied to every taggable resource created by this module.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `map(string)`                                                                                         | `{}`               |    no    |

## Outputs

| Name                                                                                                               | Description                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="output_distribution_arn"></a> [distribution\_arn](#output\_distribution\_arn)                             | ARN of the CloudFront distribution. Use it in each origin bucket's policy condition (AWS:SourceArn) to grant only this distribution access via OAC. |
| <a name="output_distribution_id"></a> [distribution\_id](#output\_distribution\_id)                                | ID of the CloudFront distribution.                                                                                                                  |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name)                                            | Distribution domain name (e.g. d111111abcdef8.cloudfront.net). This is the DNS you open in a browser.                                               |
| <a name="output_hosted_zone_id"></a> [hosted\_zone\_id](#output\_hosted\_zone\_id)                                 | CloudFront's hosted zone ID, for aliasing a custom domain to the distribution with a Route 53 alias record.                                         |
| <a name="output_origin_access_control_id"></a> [origin\_access\_control\_id](#output\_origin\_access\_control\_id) | ID of the Origin Access Control shared by all S3 origins.                                                                                           |
<!-- END_TF_DOCS -->
