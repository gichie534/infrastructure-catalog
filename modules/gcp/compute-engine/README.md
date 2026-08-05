<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.35 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.39.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_instance.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Attach an ephemeral external IP so the instance can reach the internet directly (e.g. a migration host reaching an external database and installing packages). Default: no public IP. | `bool` | `false` | no |
| <a name="input_image"></a> [image](#input\_image) | Boot disk image | `string` | `"debian-cloud/debian-12"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels applied to the instance. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Machine type for the instance | `string` | `"e2-micro"` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Instance metadata key/value pairs. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the compute instance | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | VPC network for the instance. Used only when subnetwork is not set (auto-mode networks). | `string` | `"default"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the instance | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the service account to attach. Null (default) leaves the instance on the project default compute service account. | `string` | `null` | no |
| <a name="input_service_account_scopes"></a> [service\_account\_scopes](#input\_service\_account\_scopes) | OAuth scopes for the attached service account. Only used when service\_account\_email is set. | `list(string)` | <pre>[<br/>  "cloud-platform"<br/>]</pre> | no |
| <a name="input_startup_script"></a> [startup\_script](#input\_startup\_script) | Shell script run on first boot (e.g. to install packages). Null (default) sets no startup script. | `string` | `null` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | Self link or name of the subnetwork to attach the instance to. Required for custom-mode VPCs; when set it takes precedence over network. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Network tags applied to the instance (targeted by firewall rules). | `list(string)` | `[]` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Zone where the instance will be created | `string` | `"us-central1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | The ID of the instance |
| <a name="output_internal_ip"></a> [internal\_ip](#output\_internal\_ip) | The internal IP address of the instance |
| <a name="output_name"></a> [name](#output\_name) | The name of the instance (use with gcloud compute ssh). |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | The external IP address of the instance, or null when enable\_public\_ip is false. |
| <a name="output_zone"></a> [zone](#output\_zone) | The zone the instance runs in. |
<!-- END_TF_DOCS -->