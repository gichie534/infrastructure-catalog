# aws/cost-data-export

An **AWS Data Exports** export — CUR 2.0 by default — delivered to an existing S3 bucket.

## Why this exists

Budgets and anomaly detection alert on aggregates. They tell you *that* spend moved. Neither can tell
you which resource, tag, or team moved it, and that is always the next question. This export is the
line-item record that answers it: hourly, resource-level, in your own bucket, queryable with Athena.

The decisive property is that it is **not retroactive**. Turn on a budget today and it works today.
Turn on an export today and you get data from today forward — the past is simply gone. That is what
makes it a foundation concern rather than something to add when a report is requested.

## Why a module for one resource

The resource is the easy half. The half that goes wrong is the **bucket policy**: Data Exports writes as
the service principal `bcm-data-exports.amazonaws.com`, conditioned on the account that created the
export, and AWS refuses to create the export at all when that grant is missing — surfacing only a
generic *"Invalid bucket"*. This module owns the policy alongside the export, which also makes ownership
unambiguous, since S3 permits exactly one policy per bucket.

It does **not** create the bucket. Compose it with `aws/s3-bucket`, which already owns a hardened
baseline and lifecycle rules.

## Things worth knowing

- **The destination bucket must be dedicated to exports.** This module manages its policy; something
  else managing a policy on the same bucket will fight it. Set `manage_bucket_policy = false` and take
  `required_bucket_policy_json` from the outputs if you need to own it elsewhere.
- **Regions are asymmetric.** The Data Exports control plane exists only in `us-east-1`, so the calling
  unit needs a `us-east-1` provider. The bucket can live anywhere, hence `s3_region` as an input.
- **Nothing arrives immediately.** The first delivery lands within roughly 24 hours; refreshes follow at
  least daily. An empty bucket an hour after apply is expected, not broken.
- **Defaults are hourly with resource IDs** — the most granular, therefore largest, form of the table.
  That is deliberate: granularity you did not capture cannot be recovered, whereas an export that is too
  big is one lifecycle rule away from being fine. Drop to `DAILY` / `INCLUDE_RESOURCES = "FALSE"` if size
  matters more than answerability.
- **`OVERWRITE_REPORT` is the default.** `CREATE_NEW_REPORT` keeps every version, and refreshes happen
  several times a day, so storage grows accordingly.
- **The curated column list is a starting point, not the schema.** See the
  [Data Exports table dictionary](https://docs.aws.amazon.com/cur/latest/userguide/dataexports-table-dictionary.html)
  and extend `columns` — the `savings_plan_*` and `reservation_*` families become relevant once you hold
  commitments to amortise.
- **The export itself is free.** You pay standard S3 rates for what it delivers, which is why the
  companion bucket should carry a lifecycle rule.
- **Legacy CUR is a different thing.** It uses the `billingreports.amazonaws.com` principal and the `cur`
  API. This module targets Data Exports (CUR 2.0), the recommended path.

## Usage

```hcl
module "export_bucket" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/s3-bucket?ref=aws-s3-bucket-v0.3.0"

  bucket_name = "my-cost-exports-123456789012"

  lifecycle_rules = [
    { id = "expire-exports", expiration_days = 365, abort_incomplete_multipart_upload_days = 7 },
  ]
}

module "cost_data_export" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/cost-data-export?ref=aws-cost-data-export-v0.1.0"

  export_name = "cur2-hourly"

  s3_bucket = module.export_bucket.bucket
  s3_prefix = "cur2"
  s3_region = "us-east-1"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.40 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.65.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_bcmdataexports_export.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bcmdataexports_export) | resource |
| [aws_s3_bucket_policy.delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_columns"></a> [columns](#input\_columns) | Columns to select from the table. Empty (default) uses the module's curated column list for the<br/>chosen table; tables with no curated list require either this input or `query_statement`.<br/><br/>Selecting columns rather than everything is the point of Data Exports: a narrower export is cheaper<br/>to store and query, and it lets you leave sensitive cost detail out of a dataset you intend to share<br/>more widely. | `list(string)` | `[]` | no |
| <a name="input_compression"></a> [compression](#input\_compression) | Compression: PARQUET (default) or GZIP. AWS pairs these with the format — PARQUET format requires PARQUET compression, TEXT\_OR\_CSV requires GZIP. The module validates the pairing. | `string` | `"PARQUET"` | no |
| <a name="input_export_name"></a> [export\_name](#input\_export\_name) | Name of the data export. Unique per account. | `string` | n/a | yes |
| <a name="input_format"></a> [format](#input\_format) | Output format: PARQUET (default) or TEXT\_OR\_CSV. Parquet is columnar and typed, so it is both smaller and far cheaper to query with Athena — prefer it unless something downstream can only read CSV. | `string` | `"PARQUET"` | no |
| <a name="input_manage_bucket_policy"></a> [manage\_bucket\_policy](#input\_manage\_bucket\_policy) | When true (default), the module attaches the bucket policy Data Exports requires in order to deliver<br/>at all. AWS refuses to create the export without it, and the console reports only a generic "Invalid<br/>bucket".<br/><br/>Set false if something else owns the bucket's policy — then take `required_bucket_policy_json` from<br/>the outputs and attach it yourself, and make sure it exists before this module runs. | `bool` | `true` | no |
| <a name="input_overwrite"></a> [overwrite](#input\_overwrite) | How each refresh is written:<br/><br/>  - `OVERWRITE_REPORT` (default) replaces the current period's file in place, so the bucket holds one<br/>    copy per period. Cheaper, and what you want unless you need an audit trail.<br/>  - `CREATE_NEW_REPORT` keeps every version, so storage grows with each refresh (several times a day). | `string` | `"OVERWRITE_REPORT"` | no |
| <a name="input_query_statement"></a> [query\_statement](#input\_query\_statement) | Full SQL SELECT statement, overriding `columns`. Null (default) builds `SELECT <columns> FROM <table>`. Use this when you need row filters (a `WHERE` clause) or renamed columns. | `string` | `null` | no |
| <a name="input_s3_bucket"></a> [s3\_bucket](#input\_s3\_bucket) | Name of the destination S3 bucket. The bucket must already exist — compose this module with<br/>`aws/s3-bucket` rather than having it create one.<br/><br/>The bucket should be DEDICATED to exports, because this module manages its bucket policy (see<br/>`manage_bucket_policy`) and S3 allows only one policy per bucket. | `string` | n/a | yes |
| <a name="input_s3_prefix"></a> [s3\_prefix](#input\_s3\_prefix) | Key prefix within the bucket to deliver under, e.g. `cur2`. Default empty writes to the bucket root. A prefix is worth setting so a lifecycle rule can target the export without touching anything else. | `string` | `""` | no |
| <a name="input_s3_region"></a> [s3\_region](#input\_s3\_region) | Region of the destination bucket. Taken as an input rather than inferred, because the export's control plane always lives in us-east-1 while the bucket can live anywhere. | `string` | n/a | yes |
| <a name="input_source_account_id"></a> [source\_account\_id](#input\_source\_account\_id) | Account that owns the export, used in the bucket policy's `aws:SourceArn` / `aws:SourceAccount` conditions. Null (default) uses the calling account. | `string` | `null` | no |
| <a name="input_table"></a> [table](#input\_table) | Which export table to deliver.<br/><br/>  - `COST_AND_USAGE_REPORT` (default) — CUR 2.0, the recommended detailed cost and usage dataset.<br/>  - `FOCUS_1_0_AWS` / `FOCUS_1_2_AWS` — the FinOps Open Cost and Usage Specification with AWS<br/>    columns. Worth choosing if you intend to compare AWS spend against another cloud on the same<br/>    schema.<br/>  - `COST_OPTIMIZATION_RECOMMENDATIONS` — Cost Optimization Hub recommendations.<br/>  - `CARBON_EMISSIONS` — carbon footprint data. | `string` | `"COST_AND_USAGE_REPORT"` | no |
| <a name="input_table_configurations"></a> [table\_configurations](#input\_table\_configurations) | Table configuration overrides for the chosen table, as a flat map of string to string. Null (default)<br/>applies the module's defaults, which for CUR 2.0 are hourly granularity with resource IDs included.<br/><br/>Hourly + resource IDs is the most granular the table offers and therefore the largest. It is the<br/>right default for a foundation: granularity you did not capture cannot be recovered later, whereas<br/>an export that is too big is a lifecycle rule away from being fine. Drop to `DAILY` and<br/>`INCLUDE_RESOURCES = "FALSE"` if size matters more than answerability.<br/><br/>Recognised keys for CUR 2.0: `TIME_GRANULARITY` (HOURLY/DAILY/MONTHLY), `INCLUDE_RESOURCES`,<br/>`INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY`, `INCLUDE_SPLIT_COST_ALLOCATION_DATA` (all "TRUE"/"FALSE").<br/>Pass `{}` to send no configuration at all. | `map(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the export. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_policy_managed"></a> [bucket\_policy\_managed](#output\_bucket\_policy\_managed) | Whether this module attached the delivery bucket policy. |
| <a name="output_export_arn"></a> [export\_arn](#output\_export\_arn) | ARN of the data export. |
| <a name="output_export_name"></a> [export\_name](#output\_export\_name) | Name of the data export. |
| <a name="output_query_statement"></a> [query\_statement](#output\_query\_statement) | The SQL statement actually sent to Data Exports, after column defaults are resolved. Useful when an export delivers a different schema than you expected. |
| <a name="output_required_bucket_policy_json"></a> [required\_bucket\_policy\_json](#output\_required\_bucket\_policy\_json) | The bucket policy Data Exports requires. Attach this yourself when `manage_bucket_policy` is false — without it AWS refuses to create the export. |
| <a name="output_s3_uri"></a> [s3\_uri](#output\_s3\_uri) | S3 URI the export is delivered to. The first objects appear within roughly 24 hours of creation, not immediately. |
| <a name="output_table_configurations"></a> [table\_configurations](#output\_table\_configurations) | The table configuration actually applied (granularity, resource inclusion, …), after defaults are resolved. |
<!-- END_TF_DOCS -->
