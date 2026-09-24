# gcp/gke

A basic regional **GKE Autopilot** cluster. Autopilot fully manages node pools, so this module
declares no machine types or node counts. Nodes are private (no public IPs) and rely on the VPC's
Cloud NAT for egress; the control plane keeps a public endpoint locked down with authorized
networks by default, or can be made fully private.

The module is network-agnostic: pass in a `network`, `subnetwork`, and the Pods/Services secondary
range names. It pairs naturally with the sibling [`gcp/vpc`](../vpc) module, whose outputs wire
straight into these inputs (see `examples/basic`).

## Usage

```hcl
module "gke" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/gke?ref=vX.Y.Z"

  name       = "platform"
  project_id = "my-project"
  region     = "us-central1"

  network             = module.vpc.network_self_link
  subnetwork          = module.vpc.subnets_self_links["nodes"]
  pods_range_name     = "pods"
  services_range_name = "services"

  master_authorized_networks = [
    { display_name = "office", cidr_block = "203.0.113.0/24" },
  ]
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
| <a name="provider_google"></a> [google](#provider\_google) | 8.4.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_container_cluster.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_project_iam_member.node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_node_service_account"></a> [create\_node\_service\_account](#input\_create\_node\_service\_account) | Create a dedicated, least-privilege service account for the cluster's nodes and grant it<br/>node\_service\_account\_roles on project\_id. When false (the default, which preserves the behaviour<br/>of earlier versions of this module) GKE falls back to the project's Compute Engine default<br/>service account.<br/><br/>That fallback is a trap on projects created after Google stopped automatically granting<br/>roles/editor to the Compute Engine default service account (and on any project where the<br/>iam.automaticIamGrantsForDefaultServiceAccounts org policy is enforced): the default account then<br/>holds no roles at all, nodes boot but cannot register, the control plane deletes them, and the<br/>cluster sits RUNNING with zero nodes while every pod stays Pending. The console surfaces this<br/>only as an advisory to "grant roles/container.defaultNodeServiceAccount to the Node service<br/>account".<br/><br/>Set this true to make the node identity explicit and owned by Terraform. Takes precedence over<br/>node\_service\_account. | `bool` | `false` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether the cluster is protected from deletion via Terraform. Keep true for real environments; examples/tests set it false. | `bool` | `true` | no |
| <a name="input_enable_private_endpoint"></a> [enable\_private\_endpoint](#input\_enable\_private\_endpoint) | When true, the control plane is reachable only via its private endpoint. Default false keeps a public endpoint (locked down with master\_authorized\_networks) while nodes stay private. | `bool` | `false` | no |
| <a name="input_enable_secret_manager_addon"></a> [enable\_secret\_manager\_addon](#input\_enable\_secret\_manager\_addon) | Enable the GKE-managed Secret Manager add-on (the Google-managed build of the Secrets Store CSI Driver and its GCP provider). When true, pods may mount Secret Manager secrets as files via a SecretProviderClass referencing the secrets-store-gke.csi.k8s.io driver. Disabled by default to keep the cluster minimal. | `bool` | `false` | no |
| <a name="input_enable_secret_sync"></a> [enable\_secret\_sync](#input\_enable\_secret\_sync) | Enable the SecretSync controller (secret\_sync\_config) on the cluster. The controller materializes a Secret Manager secret as a Kubernetes Secret (referenced via valueFrom.secretKeyRef / envFrom) given a SecretProviderClass. This is an independent feature from enable\_secret\_manager\_addon — either, both, or neither may be enabled, depending on whether the workload needs file mounts, env-var consumption, or both. Requires a GKE control plane version that supports the feature (1.33+ at the time of writing). | `bool` | `false` | no |
| <a name="input_master_authorized_networks"></a> [master\_authorized\_networks](#input\_master\_authorized\_networks) | CIDR blocks allowed to reach the control plane endpoint. Each entry is a display name and a CIDR. An empty list allows no external access. | <pre>list(object({<br/>    display_name = string<br/>    cidr_block   = string<br/>  }))</pre> | `[]` | no |
| <a name="input_master_ipv4_cidr_block"></a> [master\_ipv4\_cidr\_block](#input\_master\_ipv4\_cidr\_block) | The /28 CIDR range for the cluster's hosted control plane. Must not overlap with subnet or secondary ranges. | `string` | `"172.16.0.0/28"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the GKE cluster. | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Self link or name of the VPC network to attach the cluster to. Wire this to the vpc module's network\_self\_link output. | `string` | n/a | yes |
| <a name="input_node_service_account"></a> [node\_service\_account](#input\_node\_service\_account) | Email of an existing service account to run the cluster's nodes as. It must already hold roles/container.defaultNodeServiceAccount on the project. Ignored when create\_node\_service\_account is true. Leave null to let GKE use the Compute Engine default service account. | `string` | `null` | no |
| <a name="input_node_service_account_id"></a> [node\_service\_account\_id](#input\_node\_service\_account\_id) | Account ID (the local part of the email) for the service account created when create\_node\_service\_account is true. Defaults to "<name>-nodes", truncated to the 30-character limit. | `string` | `null` | no |
| <a name="input_node_service_account_roles"></a> [node\_service\_account\_roles](#input\_node\_service\_account\_roles) | Project-level roles granted to the service account created when create\_node\_service\_account is true. The default is the minimum GKE requires for nodes to register and run system tasks such as logging, monitoring and image pulls; add to it for workloads that need more (e.g. roles/artifactregistry.reader for a private registry in another project). | `list(string)` | <pre>[<br/>  "roles/container.defaultNodeServiceAccount"<br/>]</pre> | no |
| <a name="input_pods_range_name"></a> [pods\_range\_name](#input\_pods\_range\_name) | Name of the subnetwork secondary range to use for Pod IPs (VPC-native alias IPs). Matches the vpc module's pods\_range\_name. | `string` | `"pods"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the cluster. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region for the regional Autopilot cluster (e.g. us-central1). | `string` | n/a | yes |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | GKE release channel that governs cluster version and auto-upgrade cadence. Autopilot clusters must be enrolled in a channel. | `string` | `"REGULAR"` | no |
| <a name="input_resource_labels"></a> [resource\_labels](#input\_resource\_labels) | Labels applied to the GKE cluster and the resources it manages. | `map(string)` | `{}` | no |
| <a name="input_secret_manager_addon_rotation"></a> [secret\_manager\_addon\_rotation](#input\_secret\_manager\_addon\_rotation) | Automatic rotation for the Secret Manager add-on's mounted volumes: periodically re-fetches secret values so mounted files pick up a new version without a pod restart. Ignored unless enable\_secret\_manager\_addon is true. enabled defaults to true (rotation on); rotation\_interval is a duration string (e.g. "120s") and defaults to the API's own default (2 minutes) when null. | <pre>object({<br/>    enabled           = optional(bool, true)<br/>    rotation_interval = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_secret_sync_rotation"></a> [secret\_sync\_rotation](#input\_secret\_sync\_rotation) | Automatic rotation for SecretSync-materialized Kubernetes Secrets: periodically checks Secret Manager for a new secret version and updates the Kubernetes Secret's data (consumers must detect and reload it themselves — this does not restart pods). Ignored unless enable\_secret\_sync is true. enabled defaults to true (rotation on); rotation\_interval is a duration string (e.g. "120s") and defaults to the API's own default (2 minutes) when null. | <pre>object({<br/>    enabled           = optional(bool, true)<br/>    rotation_interval = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_services_range_name"></a> [services\_range\_name](#input\_services\_range\_name) | Name of the subnetwork secondary range to use for Service IPs. Matches the vpc module's services\_range\_name. | `string` | `"services"` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | Self link or name of the subnetwork for the cluster nodes. Wire this to the vpc module's subnets\_self\_links output. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Base64-encoded public CA certificate of the cluster, used to authenticate kubectl/provider clients. |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | The ID of the GKE cluster. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the GKE cluster. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | The IP address of the cluster's Kubernetes API server. |
| <a name="output_location"></a> [location](#output\_location) | The region the cluster runs in. |
| <a name="output_node_service_account_email"></a> [node\_service\_account\_email](#output\_node\_service\_account\_email) | Email of the service account the cluster's nodes run as. Null when the cluster falls back to the project's Compute Engine default service account (create\_node\_service\_account false and node\_service\_account unset). |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | The server-defined URL (self link) of the cluster. |
<!-- END_TF_DOCS -->
