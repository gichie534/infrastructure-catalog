# aws/dynamodb

A single Amazon DynamoDB table — the minimal key/value + document store a consumer wires its
application and IAM to. On-demand (`PAY_PER_REQUEST`) by default so a lab costs nothing when idle;
switch to `PROVISIONED` with explicit read/write capacity for steady traffic. The key schema (a
required hash key and an optional range key) and their attribute types are inputs.

This module owns **only the table**. It deliberately does not create IAM policies granting item
access — that is the consumer's composition concern. A consumer grants `GetItem`/`PutItem`/`Query`
to specific principals (e.g. Lambda execution roles) using the table ARN this module outputs.
Keeping the module single-purpose keeps it reusable across labs.

## Usage

```hcl
module "table" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/dynamodb?ref=aws-dynamodb-vX.Y.Z"

  name          = "ImageMetadata"
  hash_key      = "ImageKey"
  hash_key_type = "S"

  tags = {
    Environment = "dev"
  }
}
```

Grant a consumer item access by referencing the table ARN in its IAM policy:

```hcl
{
  Effect   = "Allow"
  Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query", "dynamodb:UpdateItem"]
  Resource = module.table.arn
}
```

## Provisioned capacity

For steady, predictable traffic set `billing_mode = "PROVISIONED"` and supply `read_capacity` and
`write_capacity`; the module validates that pairing at plan time. On-demand is simpler and cheaper
for spiky or lab workloads.

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
| [aws_dynamodb_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_billing_mode"></a> [billing\_mode](#input\_billing\_mode) | Capacity mode: PAY\_PER\_REQUEST (on-demand, default — costs nothing when idle) or PROVISIONED (fixed read/write capacity). | `string` | `"PAY_PER_REQUEST"` | no |
| <a name="input_deletion_protection_enabled"></a> [deletion\_protection\_enabled](#input\_deletion\_protection\_enabled) | Block table deletion until disabled. Default false so a lab tears down cleanly; enable for tables you care about. | `bool` | `false` | no |
| <a name="input_hash_key"></a> [hash\_key](#input\_hash\_key) | Name of the partition (hash) key attribute. Required. | `string` | n/a | yes |
| <a name="input_hash_key_type"></a> [hash\_key\_type](#input\_hash\_key\_type) | Attribute type of the hash key: S (string), N (number), or B (binary). | `string` | `"S"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the DynamoDB table. | `string` | n/a | yes |
| <a name="input_point_in_time_recovery_enabled"></a> [point\_in\_time\_recovery\_enabled](#input\_point\_in\_time\_recovery\_enabled) | Enable point-in-time recovery (continuous backups). Default false to keep lab tables cheap; enable for anything you'd need to restore. | `bool` | `false` | no |
| <a name="input_range_key"></a> [range\_key](#input\_range\_key) | Name of the sort (range) key attribute. Null (default) creates a table keyed only by the hash key. | `string` | `null` | no |
| <a name="input_range_key_type"></a> [range\_key\_type](#input\_range\_key\_type) | Attribute type of the range key when range\_key is set: S (string), N (number), or B (binary). | `string` | `"S"` | no |
| <a name="input_read_capacity"></a> [read\_capacity](#input\_read\_capacity) | Provisioned read capacity units. Required (and only used) when billing\_mode is PROVISIONED; leave null for on-demand. | `number` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the table (the one taggable resource this module creates). | `map(string)` | `{}` | no |
| <a name="input_write_capacity"></a> [write\_capacity](#input\_write\_capacity) | Provisioned write capacity units. Required (and only used) when billing\_mode is PROVISIONED; leave null for on-demand. | `number` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the table. Use it to scope IAM policy resource statements granting item access. |
| <a name="output_id"></a> [id](#output\_id) | ID of the table (equal to its name). |
| <a name="output_name"></a> [name](#output\_name) | Name of the DynamoDB table. Pass this to clients as the table name. |
| <a name="output_stream_arn"></a> [stream\_arn](#output\_stream\_arn) | ARN of the table's stream if enabled, otherwise an empty string. Wire this to a stream consumer (e.g. a Lambda event source mapping). |
<!-- END_TF_DOCS -->
