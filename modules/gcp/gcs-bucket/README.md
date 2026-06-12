# gcp/gcs-bucket

Creates a single Cloud Storage bucket with a secure baseline and exports its name. Nothing else —
this module grants no access. Instantiate it once per bucket.

## Scope

This module owns:

- one `google_storage_bucket` with **uniform bucket-level access** and **enforced public access
  prevention** hardcoded on.

It deliberately does **not** own:

- **access policy** — bucket IAM is granted by the consumer that needs it (see
  [`gcp/workload-iam`](../workload-iam)), so the bucket's access lives with the workload
  rather than with this producer.

## How it fits together

This is a pure producer. A workload's IAM unit takes the `name` output and grants its Google service
account a Cloud Storage role on the bucket. With Terragrunt, the `workload-iam` unit declares a
`dependency` on this unit and reads `name`.

## Usage

```hcl
module "bucket" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/gcs-bucket?ref=vX.Y.Z"

  project_id = "my-project"
  name       = "my-project-app-uploads"
  location   = "US"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.35 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_storage_bucket.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | When true, deleting the bucket also deletes its objects. Keep false for real environments; examples/tests set it true. | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels applied to the bucket. | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Location of the bucket (e.g. US, EU, or a region like us-central1). | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally-unique name of the bucket. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the bucket. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_name"></a> [name](#output\_name) | The name of the bucket. Wire this into the workload-iam module's bucket\_iam to grant access. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | The URI (self link) of the bucket. |
| <a name="output_url"></a> [url](#output\_url) | The gs:// URL of the bucket. |
<!-- END_TF_DOCS -->
