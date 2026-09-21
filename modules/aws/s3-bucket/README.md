# aws/s3-bucket

A single, **hardened-by-default** S3 bucket. The module owns a secure baseline so a consumer can't
accidentally ship a public or unencrypted bucket:

- **All public access blocked** (`aws_s3_bucket_public_access_block`, every flag on).
- **Server-side encryption** on by default (SSE-S3 / `AES256`).
- **Object ownership `BucketOwnerEnforced`** — ACLs disabled; access is governed by IAM and bucket
  policy only.

Access control is expressed through an **optional raw `bucket_policy`** (a JSON string). When
provided, the module attaches it via `aws_s3_bucket_policy`; when omitted, no policy is created and
the bucket is reachable only by IAM principals the account already grants. This passthrough mirrors
how `iam-instance-profile` takes inline policies — the module stays policy-agnostic, so a lab can
pass an ABAC policy (e.g. one matching `aws:PrincipalTag/*`) without the module knowing anything
about it.

Optional **`lifecycle_rules`** manage object expiry, storage-class transitions, and cleanup of
incomplete multipart uploads. Omitted by default, so no lifecycle configuration resource is created
at all. Reach for it on any bucket that accumulates data on a schedule — cost/usage exports, logs,
build artefacts — where "keep everything forever" is a cost decision nobody made deliberately. Note
that incomplete multipart uploads are billed but invisible in the console, so
`abort_incomplete_multipart_upload_days` is worth setting on any bucket receiving large objects.

This module owns **only the bucket and its baseline**. Keeping it single-purpose keeps it reusable
across labs.

## Usage

```hcl
locals {
  # Derive the ARN from the bucket name so the policy is known at plan time. Referencing
  # module.s3_bucket.arn here would make the policy unknown until apply and break the module's
  # count on bucket_policy.
  bucket_arn = "arn:aws:s3:::my-lab-bucket-demo"
}

data "aws_iam_policy_document" "abac" {
  statement {
    sid     = "ABACProjectMatch"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]

    resources = [
      local.bucket_arn,
      "${local.bucket_arn}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::123456789012:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/Project"
      values   = ["demo"]
    }
  }
}

module "s3_bucket" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/s3-bucket?ref=aws-s3-bucket-v0.1.0"

  bucket_name   = "my-lab-bucket-demo"
  force_destroy = true # throwaway lab: destroy cleanly without emptying first
  bucket_policy = data.aws_iam_policy_document.abac.json

  tags = {
    Project = "demo"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.53.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the S3 bucket. Must be globally unique and DNS-compliant (3-63 chars, lowercase letters, numbers, dots, and hyphens; start/end alphanumeric). | `string` | n/a | yes |
| <a name="input_bucket_policy"></a> [bucket\_policy](#input\_bucket\_policy) | Optional bucket policy as a JSON string. When set, the module attaches it via an<br/>`aws_s3_bucket_policy` — the raw passthrough mirrors how `iam-instance-profile` takes inline<br/>policies. Typically produced from an `aws_iam_policy_document` data source (e.g. an ABAC policy<br/>matching `aws:PrincipalTag/*`). When null (the default) no bucket policy is created. | `string` | `null` | no |
| <a name="input_cors_rules"></a> [cors\_rules](#input\_cors\_rules) | Optional CORS rules for the bucket. Empty (default) creates no CORS configuration. Each rule sets<br/>the allowed methods and origins (required) plus optional allowed/exposed headers and a max age.<br/>Typically needed so a browser can PUT directly to a presigned upload URL from a web page served on<br/>a different origin. | <pre>list(object({<br/>    allowed_headers = optional(list(string), [])<br/>    allowed_methods = list(string)<br/>    allowed_origins = list(string)<br/>    expose_headers  = optional(list(string), [])<br/>    max_age_seconds = optional(number, 3600)<br/>  }))</pre> | `[]` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Whether to allow Terraform to delete the bucket even when it still contains objects. Leave `false`<br/>for anything you care about; set `true` in throwaway lab environments so `terraform destroy`<br/>tears down cleanly without a manual empty step. | `bool` | `false` | no |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | Optional object-lifecycle rules. Empty (default) creates no lifecycle configuration at all, so<br/>existing consumers are unaffected. Each rule needs a unique `id`; every other field is optional,<br/>and a rule that sets none of the expiry/transition fields is rejected (it would be a no-op).<br/><br/>`prefix` scopes the rule to a key prefix — null or "" applies it to every object in the bucket.<br/>`transitions` moves objects to a cheaper storage class after N days (e.g. STANDARD\_IA at 30,<br/>GLACIER\_IR at 90); `expiration_days` deletes them outright.<br/>`abort_incomplete_multipart_upload_days` cleans up failed multipart uploads, which are invisible<br/>in the console but still billed — worth setting on any bucket that receives large objects.<br/><br/>Typical use: keep a cost/usage export or log bucket from growing without bound. | <pre>list(object({<br/>    id                                     = string<br/>    enabled                                = optional(bool, true)<br/>    prefix                                 = optional(string, null)<br/>    expiration_days                        = optional(number, null)<br/>    noncurrent_version_expiration_days     = optional(number, null)<br/>    abort_incomplete_multipart_upload_days = optional(number, null)<br/>    transitions = optional(list(object({<br/>      days          = number<br/>      storage_class = string<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the S3 bucket. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the S3 bucket. Use it to scope IAM/bucket policy resources (e.g. arn and arn/*). |
| <a name="output_bucket"></a> [bucket](#output\_bucket) | Name (id) of the S3 bucket. |
| <a name="output_lifecycle_rule_ids"></a> [lifecycle\_rule\_ids](#output\_lifecycle\_rule\_ids) | IDs of the lifecycle rules managed on this bucket, in declaration order. Empty when no lifecycle configuration is managed. |
<!-- END_TF_DOCS -->
