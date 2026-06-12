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
| [google_folder.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/folder) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether to prevent the folder from being deleted while this value is true | `bool` | `true` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Display name of the folder | `string` | n/a | yes |
| <a name="input_parent"></a> [parent](#input\_parent) | Parent resource: organizations/<org\_id> or folders/<folder\_id> | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_display_name"></a> [display\_name](#output\_display\_name) | The display name of the folder |
| <a name="output_id"></a> [id](#output\_id) | The folder ID (e.g. folders/123456), used as the parent for child folders/projects |
| <a name="output_parent"></a> [parent](#output\_parent) | The parent resource of the folder |
<!-- END_TF_DOCS -->