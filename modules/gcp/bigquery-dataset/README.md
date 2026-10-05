# gcp/bigquery-dataset

A single **BigQuery dataset**: location, expiration defaults, encryption, deletion behaviour, and
additive dataset-level grants. Tables and views are the consumer's concern.

## Things worth knowing

- **Access is additive only.** Services such as the Cloud Billing export add their own service account
  as a dataset OWNER. An authoritative `access` block would remove it on the next apply and the export
  would stop writing silently. So the module ignores drift on `access` and grants via
  `google_bigquery_dataset_iam_member`.
- **Location is immutable**, and for a billing export it matters: only a multi-region (`US`/`EU`) dataset
  gets the current and previous month backfilled when the export is first enabled.
- **`delete_contents_on_destroy` defaults to false.** For data you cannot recreate, a routine `destroy`
  should fail loudly rather than succeed.
- **No table expiration by default.** Google warns that an expired billing-export table cannot be
  backfilled. Use `default_partition_expiration_ms` to bound retention instead of deleting whole tables.
- **Dataset IDs take underscores, not hyphens.**

## Usage

```hcl
module "billing_export_dataset" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/bigquery-dataset?ref=gcp-bigquery-dataset-v0.1.0"

  project_id = "my-finops-project"
  dataset_id = "billing_export"
  location   = "US"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.46.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_bigquery_dataset.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset) | resource |
| [google_bigquery_dataset_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dataset_id"></a> [dataset\_id](#input\_dataset\_id) | Dataset ID: letters, digits and underscores only (no hyphens — a common trip-up coming from other GCP resource names). | `string` | n/a | yes |
| <a name="input_default_partition_expiration_ms"></a> [default\_partition\_expiration\_ms](#input\_default\_partition\_expiration\_ms) | Default lifetime of partitions in NEW partitioned tables, in ms. Null (default) = partitions never expire. This is how retention is bounded on a time-partitioned table without deleting the table. | `number` | `null` | no |
| <a name="input_default_table_expiration_ms"></a> [default\_table\_expiration\_ms](#input\_default\_table\_expiration\_ms) | Default lifetime of NEW tables, in ms. Null (default) = tables never expire. Leave null for a billing export: Google warns that an expired export table cannot be backfilled. | `number` | `null` | no |
| <a name="input_delete_contents_on_destroy"></a> [delete\_contents\_on\_destroy](#input\_delete\_contents\_on\_destroy) | Whether `destroy` deletes the dataset even if it contains tables. Default false, because for data that cannot be recreated (a billing export) losing it to a routine teardown is the worst outcome. | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | Dataset description. | `string` | `null` | no |
| <a name="input_friendly_name"></a> [friendly\_name](#input\_friendly\_name) | Human-readable name shown in the console. | `string` | `null` | no |
| <a name="input_iam_members"></a> [iam\_members](#input\_iam\_members) | Additive dataset-level grants, e.g. `{ role = "roles/bigquery.dataViewer", member = "group:finops@example.com" }`. Never authoritative — see main.tf for why. | <pre>list(object({<br/>    role   = string<br/>    member = string<br/>  }))</pre> | `[]` | no |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | CMEK key for the dataset default. Null (default) = Google-managed encryption. Immutable in practice: changing it later does not re-encrypt existing tables. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels applied to the dataset. | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Dataset location: a multi-region (`US`, `EU`) or a region (`us-central1`). Immutable after creation.<br/><br/>For a Cloud Billing export this choice is not cosmetic: only a multi-region dataset receives the<br/>current and previous month retroactively when the export is first enabled. A regional dataset gets<br/>data from the day of enablement only. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project to create the dataset in. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dataset_id"></a> [dataset\_id](#output\_dataset\_id) | Dataset ID. |
| <a name="output_fully_qualified_name"></a> [fully\_qualified\_name](#output\_fully\_qualified\_name) | `<project>.<dataset_id>` — the prefix used in SQL and by `bq`. |
| <a name="output_id"></a> [id](#output\_id) | Terraform ID of the dataset (`projects/<project>/datasets/<dataset_id>`). |
| <a name="output_location"></a> [location](#output\_location) | Dataset location. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Project the dataset lives in. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | API self link of the dataset. |
<!-- END_TF_DOCS -->
