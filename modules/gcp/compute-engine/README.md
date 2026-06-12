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
| [google_compute_instance.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_image"></a> [image](#input\_image) | Boot disk image | `string` | `"debian-cloud/debian-12"` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Machine type for the instance | `string` | `"e2-micro"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the compute instance | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | VPC network for the instance | `string` | `"default"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the instance | `string` | n/a | yes |
| <a name="input_zone"></a> [zone](#input\_zone) | Zone where the instance will be created | `string` | `"us-central1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | The ID of the instance |
| <a name="output_internal_ip"></a> [internal\_ip](#output\_internal\_ip) | The internal IP address of the instance |
<!-- END_TF_DOCS -->