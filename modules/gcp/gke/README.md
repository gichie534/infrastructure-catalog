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
| <a name="provider_google"></a> [google](#provider\_google) | 7.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_container_cluster.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether the cluster is protected from deletion via Terraform. Keep true for real environments; examples/tests set it false. | `bool` | `true` | no |
| <a name="input_enable_private_endpoint"></a> [enable\_private\_endpoint](#input\_enable\_private\_endpoint) | When true, the control plane is reachable only via its private endpoint. Default false keeps a public endpoint (locked down with master\_authorized\_networks) while nodes stay private. | `bool` | `false` | no |
| <a name="input_master_authorized_networks"></a> [master\_authorized\_networks](#input\_master\_authorized\_networks) | CIDR blocks allowed to reach the control plane endpoint. Each entry is a display name and a CIDR. An empty list allows no external access. | <pre>list(object({<br/>    display_name = string<br/>    cidr_block   = string<br/>  }))</pre> | `[]` | no |
| <a name="input_master_ipv4_cidr_block"></a> [master\_ipv4\_cidr\_block](#input\_master\_ipv4\_cidr\_block) | The /28 CIDR range for the cluster's hosted control plane. Must not overlap with subnet or secondary ranges. | `string` | `"172.16.0.0/28"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the GKE cluster. | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Self link or name of the VPC network to attach the cluster to. Wire this to the vpc module's network\_self\_link output. | `string` | n/a | yes |
| <a name="input_pods_range_name"></a> [pods\_range\_name](#input\_pods\_range\_name) | Name of the subnetwork secondary range to use for Pod IPs (VPC-native alias IPs). Matches the vpc module's pods\_range\_name. | `string` | `"pods"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the cluster. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region for the regional Autopilot cluster (e.g. us-central1). | `string` | n/a | yes |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | GKE release channel that governs cluster version and auto-upgrade cadence. Autopilot clusters must be enrolled in a channel. | `string` | `"REGULAR"` | no |
| <a name="input_resource_labels"></a> [resource\_labels](#input\_resource\_labels) | Labels applied to the GKE cluster and the resources it manages. | `map(string)` | `{}` | no |
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
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | The server-defined URL (self link) of the cluster. |
<!-- END_TF_DOCS -->
