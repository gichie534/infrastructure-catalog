# gcp/service-project

A GCP project attached to a **Shared VPC host** as a *service* project — workloads in it (e.g. a
GKE cluster) run on subnets owned by the host project. It is the base [`gcp/project`](../project)
(project + API enablement) plus a single `google_compute_shared_vpc_service_project` resource,
packaged as its own module so "this project is a service project" is expressed without a
conditional. The counterpart is [`gcp/host-project`](../host-project).

## Scope

This module owns:

- a `google_project` in the given folder, with the supplied billing account and labels;
- `google_project_service` for each API in `activate_apis` (must include `compute.googleapis.com`;
  add `container.googleapis.com` for a GKE service project);
- the `google_compute_shared_vpc_service_project` that attaches this project to the host.

The project attaches **itself** to the host (via `shared_vpc_host_project_id`), so the host stays
unaware of its service projects and the dependency graph is acyclic. This module does **not** grant
the per-subnet network access a workload needs — use [`gcp/shared-vpc-iam`](../shared-vpc-iam),
which consumes this module's `project_number`.

## Prerequisites

- The caller must hold `roles/compute.xpnAdmin` at the organization or folder to attach a service
  project, and the host must already be a Shared VPC host.
- Project creation requires folder + billing permissions.

## Usage

```hcl
module "service_project" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/gcp/service-project?ref=gcp-service-project-vX.Y.Z"

  name                       = "gke-service"
  project_id                 = "my-gke-service"
  folder_id                  = "folders/123456789012"
  billing_account            = "0X0X0X-0X0X0X-0X0X0X"
  shared_vpc_host_project_id = module.host_project.host_project_id
  activate_apis              = ["compute.googleapis.com", "container.googleapis.com"]
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
| [google_compute_shared_vpc_service_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_service_project) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project) | resource |
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_activate_apis"></a> [activate\_apis](#input\_activate\_apis) | List of Google APIs to activate on the project. Must include compute.googleapis.com — attaching to a Shared VPC host requires the Compute API. | `list(string)` | <pre>[<br/>  "compute.googleapis.com"<br/>]</pre> | no |
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | The billing account ID to associate with this project. | `string` | `null` | no |
| <a name="input_deletion_policy"></a> [deletion\_policy](#input\_deletion\_policy) | The deletion policy for the project. One of PREVENT, ABANDON, or DELETE. | `string` | `"PREVENT"` | no |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | The parent folder ID (e.g. folders/123456). | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the project. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The display name of the project. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The unique project ID. Must be globally unique across GCP. | `string` | n/a | yes |
| <a name="input_shared_vpc_host_project_id"></a> [shared\_vpc\_host\_project\_id](#input\_shared\_vpc\_host\_project\_id) | The ID of the Shared VPC host project to attach this project to as a service project. Wire this from a gcp/host-project's host\_project\_id output. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_host_project_id"></a> [host\_project\_id](#output\_host\_project\_id) | The Shared VPC host project this service project is attached to. |
| <a name="output_name"></a> [name](#output\_name) | The display name of the project. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The project ID, consumed by resource units (gke, etc.) created in the service project. |
| <a name="output_project_number"></a> [project\_number](#output\_project\_number) | The numeric project number. Needed to build the Google-managed service-agent emails granted access to the host network (see gcp/shared-vpc-iam). |
<!-- END_TF_DOCS -->
