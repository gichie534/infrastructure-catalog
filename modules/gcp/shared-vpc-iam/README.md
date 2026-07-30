# gcp/shared-vpc-iam

The IAM unit for a GKE workload that runs in a Shared VPC **service** project on a **host**
project's subnetwork. It is the single home for "the service project may use the host network",
mirroring how [`gcp/workload-iam`](../workload-iam) centralises a workload's permissions.

## Scope

This module owns:

- `roles/compute.networkUser` on the specific host **subnetwork** (least privilege — not the whole
  host project) for the service project's two Google-managed agents:
  - `<number>@cloudservices.gserviceaccount.com` (Google APIs service agent), and
  - `service-<number>@container-engine-robot.iam.gserviceaccount.com` (GKE service agent);
- `roles/container.hostServiceAgentUser` on the host **project** for the GKE service agent, so the
  service project's control plane can manage the cluster's networking (firewall rules, etc.) in the
  host project (toggle with `grant_host_service_agent_user`).

Both agents are derived from the service project **number**, so this module takes
`service_project_number` (from [`gcp/service-project`](../service-project)) rather than the ID.
Producer modules stay pure: [`gcp/vpc`](../vpc) exports the subnetwork name, the project modules
export IDs/numbers, and this unit wires them together.

## Ordering

The `container-engine-robot` agent is created when the Container API is enabled in the service
project. Apply the service project (which activates `container.googleapis.com`) **before** this
unit so the agent exists when these bindings are created — with Terragrunt, declare a `dependency`
on the service project unit.

## Prerequisites

- The caller must be able to set IAM on the host project and its subnetwork.
- The service project must already be attached to the host (see `gcp/service-project`).

## Usage

```hcl
module "shared_vpc_iam" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/gcp/shared-vpc-iam?ref=gcp-shared-vpc-iam-vX.Y.Z"

  host_project_id        = module.host_project.host_project_id
  service_project_number = module.service_project.project_number
  region                 = "us-central1"
  subnetwork             = module.vpc.subnets["gke"].name
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
| [google_compute_subnetwork_iam_member.network_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork_iam_member) | resource |
| [google_project_iam_member.host_service_agent_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_grant_host_service_agent_user"></a> [grant\_host\_service\_agent\_user](#input\_grant\_host\_service\_agent\_user) | Grant the service project's GKE service agent roles/container.hostServiceAgentUser on the host project, so it can manage the cluster's networking (firewall rules, etc.) in the host project. Required for GKE on a Shared VPC; leave on unless the service project runs no GKE. | `bool` | `true` | no |
| <a name="input_host_project_id"></a> [host\_project\_id](#input\_host\_project\_id) | The Shared VPC host project that owns the subnetwork being shared and against which the host-service-agent grant is made. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the host subnetwork being shared (e.g. us-central1). | `string` | n/a | yes |
| <a name="input_service_project_number"></a> [service\_project\_number](#input\_service\_project\_number) | The NUMBER (not ID) of the service project whose GKE service agents are granted access to the<br/>host subnetwork. Two Google-managed accounts are derived from it:<br/><number>@cloudservices.gserviceaccount.com and<br/>service-<number>@container-engine-robot.iam.gserviceaccount.com. Wire from a<br/>gcp/service-project's project\_number output. | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | Name of the host subnetwork the service project may use (its Pods/Services secondary ranges come with it). Wire from a gcp/vpc subnets[*].name output. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_gke_service_agent"></a> [gke\_service\_agent](#output\_gke\_service\_agent) | The service project's GKE service agent (container-engine-robot) that was granted access, as a fully-qualified IAM member. |
| <a name="output_google_apis_service_agent"></a> [google\_apis\_service\_agent](#output\_google\_apis\_service\_agent) | The service project's Google APIs service agent (cloudservices) that was granted subnet networkUser, as a fully-qualified IAM member. |
| <a name="output_network_user_members"></a> [network\_user\_members](#output\_network\_user\_members) | The IAM members granted roles/compute.networkUser on the host subnetwork. |
<!-- END_TF_DOCS -->
