<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_activate_apis"></a> [activate\_apis](#input\_activate\_apis) | List of Google APIs to activate on the project | `list(string)` | `[]` | no |
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | The billing account ID to associate with this project | `string` | `null` | no |
| <a name="input_deletion_policy"></a> [deletion\_policy](#input\_deletion\_policy) | The deletion policy for the project. One of PREVENT, ABANDON, or DELETE | `string` | `"PREVENT"` | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | The parent folder ID (e.g. folders/123456) | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the project | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The display name of the project | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The unique project ID. Must be globally unique across GCP | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_name"></a> [name](#output\_name) | The display name of the project |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The project ID, consumed by resource units (vpc, gke, gcs, etc.) under this project |
| <a name="output_project_number"></a> [project\_number](#output\_project\_number) | The numeric project number |
<!-- END_TF_DOCS -->