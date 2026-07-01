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

| Name                                                                                                                                                                                  | Type     |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)                                                                           | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls)                                     | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy)                                                             | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)                                   | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |

## Inputs

| Name                                                                        | Description                                                                                                                                                                                                                                                                                                                                                                    | Type          | Default | Required |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------- | ------- | :------: |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name)       | Name of the S3 bucket. Must be globally unique and DNS-compliant (3-63 chars, lowercase letters, numbers, dots, and hyphens; start/end alphanumeric).                                                                                                                                                                                                                          | `string`      | n/a     |   yes    |
| <a name="input_bucket_policy"></a> [bucket\_policy](#input\_bucket\_policy) | Optional bucket policy as a JSON string. When set, the module attaches it via an<br/>`aws_s3_bucket_policy` — the raw passthrough mirrors how `iam-instance-profile` takes inline<br/>policies. Typically produced from an `aws_iam_policy_document` data source (e.g. an ABAC policy<br/>matching `aws:PrincipalTag/*`). When null (the default) no bucket policy is created. | `string`      | `null`  |    no    |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Whether to allow Terraform to delete the bucket even when it still contains objects. Leave `false`<br/>for anything you care about; set `true` in throwaway lab environments so `terraform destroy`<br/>tears down cleanly without a manual empty step.                                                                                                                        | `bool`        | `false` |    no    |
| <a name="input_tags"></a> [tags](#input\_tags)                              | Tags applied to the S3 bucket.                                                                                                                                                                                                                                                                                                                                                 | `map(string)` | `{}`    |    no    |

## Outputs

| Name                                                   | Description                                                                             |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| <a name="output_arn"></a> [arn](#output\_arn)          | ARN of the S3 bucket. Use it to scope IAM/bucket policy resources (e.g. arn and arn/*). |
| <a name="output_bucket"></a> [bucket](#output\_bucket) | Name (id) of the S3 bucket.                                                             |
<!-- END_TF_DOCS -->
