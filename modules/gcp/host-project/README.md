# gcp/host-project

A GCP project that is nominated as a **Shared VPC host** — it owns the VPC network(s) that
attached *service* projects consume. It is the base [`gcp/project`](../project) (project +
API enablement) plus a single `google_compute_shared_vpc_host_project` resource, packaged as its
own module so "this project is a host" is expressed without a conditional. The counterpart is
[`gcp/service-project`](../service-project), which attaches itself to a host.

## Scope

This module owns:

- a `google_project` in the given folder, with the supplied billing account and labels;
- `google_project_service` for each API in `activate_apis` (must include `compute.googleapis.com`);
- the `google_compute_shared_vpc_host_project` that nominates the project as a Shared VPC host.

It does **not** own the VPC network itself (use [`gcp/vpc`](../vpc) in the host project) nor the
per-subnet IAM that lets a service project use the network (use [`gcp/shared-vpc-iam`](../shared-vpc-iam)).

## Prerequisites

- The caller must hold `roles/compute.xpnAdmin` at the organization or folder to nominate a host.
- Project creation requires folder + billing permissions.

## Usage

```hcl
module "host_project" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/gcp/host-project?ref=gcp-host-project-vX.Y.Z"

  name            = "shared-vpc-host"
  project_id      = "my-shared-vpc-host"
  folder_id       = "folders/123456789012"
  billing_account = "0X0X0X-0X0X0X-0X0X0X"
  activate_apis   = ["compute.googleapis.com"]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.40.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_shared_vpc_host_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_host_project) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_activate_apis"></a> [activate\_apis](#input\_activate\_apis) | List of Google APIs to activate on the project. Must include compute.googleapis.com — enabling Shared VPC on a host requires the Compute API. | `list(string)` | <pre>[<br/>  "compute.googleapis.com"<br/>]</pre> | no |
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | The billing account ID to associate with this project. | `string` | `null` | no |
| <a name="input_deletion_policy"></a> [deletion\_policy](#input\_deletion\_policy) | The deletion policy for the project. One of PREVENT, ABANDON, or DELETE. | `string` | `"PREVENT"` | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | The parent folder ID (e.g. folders/123456). | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the project. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The display name of the project. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The unique project ID. Must be globally unique across GCP. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_host_project_id"></a> [host\_project\_id](#output\_host\_project\_id) | The ID of this Shared VPC host project. Wire this into a gcp/service-project's shared\_vpc\_host\_project\_id. |
| <a name="output_name"></a> [name](#output\_name) | The display name of the project. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The project ID, consumed by resource units (vpc, etc.) created in the host project and by service projects attaching to this host. |
| <a name="output_project_number"></a> [project\_number](#output\_project\_number) | The numeric project number. |
<!-- END_TF_DOCS -->
