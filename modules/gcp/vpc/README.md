j# gcp/vpc

A GKE-ready VPC network: a custom-mode VPC with one or more subnets, each carrying secondary
ranges for Pods and Services (VPC-native alias IPs), Private Google Access, optional Private
Service Access peering (Cloud SQL and other Google-managed services), and an optional Cloud NAT
for private node egress.

## Usage

```hcl
module "vpc" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/vpc?ref=vX.Y.Z"

  name       = "platform"
  project_id = "my-project"

  subnets = [
    {
      name                = "gke"
      region              = "us-central1"
      ip_cidr_range       = "10.0.0.0/20"
      pods_cidr_range     = "10.16.0.0/14"
      services_cidr_range = "10.20.0.0/20"
    },
  ]
}
```

Wire a VPC-native GKE cluster to the outputs:

```hcl
network    = module.vpc.network_self_link
subnetwork = module.vpc.subnets_self_links["gke"]
# cluster_secondary_range_name  = "pods"
# services_secondary_range_name = "services"
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
| <a name="provider_google"></a> [google](#provider\_google) | 7.39.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_address.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.iap_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_global_address.private_service_access](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_service_networking_connection.private_service_access](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_nat"></a> [create\_nat](#input\_create\_nat) | Create a Cloud Router and Cloud NAT so nodes without external IPs (typical for private GKE) can reach the internet for egress. | `bool` | `true` | no |
| <a name="input_iap_ssh_enabled"></a> [iap\_ssh\_enabled](#input\_iap\_ssh\_enabled) | Create a firewall rule allowing SSH (tcp/22) from Google's IAP TCP-forwarding range (35.235.240.0/20) to instances tagged with iap\_ssh\_target\_tags. Lets an operator reach a host via `gcloud compute ssh --tunnel-through-iap` without any public SSH exposure. | `bool` | `false` | no |
| <a name="input_iap_ssh_target_tags"></a> [iap\_ssh\_target\_tags](#input\_iap\_ssh\_target\_tags) | Network tags the IAP SSH firewall rule targets. Only used when iap\_ssh\_enabled is true; an empty list would target the whole network, so set the tag(s) your host carries. | `list(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | Name applied to the VPC network and used as the prefix for its subnetworks and related resources. | `string` | n/a | yes |
| <a name="input_nat_region"></a> [nat\_region](#input\_nat\_region) | Region for the Cloud Router and Cloud NAT. Defaults to the region of the first subnet when null. | `string` | `null` | no |
| <a name="input_nat_reserve_static_ip"></a> [nat\_reserve\_static\_ip](#input\_nat\_reserve\_static\_ip) | Reserve a static regional external IP for Cloud NAT (MANUAL\_ONLY allocation) instead of dynamic AUTO\_ONLY. Only used when create\_nat is true. Use this when an external system must allowlist a stable egress address for instances that have no public IP of their own (e.g. a migration host reaching a database in another cloud). | `bool` | `false` | no |
| <a name="input_private_service_access"></a> [private\_service\_access](#input\_private\_service\_access) | Enable Private Service Access (VPC peering) for Google-managed services such as Cloud SQL and,<br/>when a GKE control plane uses a private endpoint, services that reach the cluster's VPC. This<br/>reserves a global address range and creates the servicenetworking peering connection. | `bool` | `true` | no |
| <a name="input_private_service_access_cidr"></a> [private\_service\_access\_cidr](#input\_private\_service\_access\_cidr) | CIDR block reserved for Private Service Access peering. Only used when private\_service\_access is true. | `string` | `"10.250.0.0/16"` | no |
| <a name="input_private_service_access_deletion_policy"></a> [private\_service\_access\_deletion\_policy](#input\_private\_service\_access\_deletion\_policy) | Deletion policy for the Private Service Access peering connection. ABANDON (default) removes the<br/>connection from Terraform state on destroy without waiting for Google to release attached producer<br/>services (Cloud SQL, Memorystore), which avoids the common "producer services are still using this<br/>connection" teardown error. Set to null to have Terraform delete the connection and block until it<br/>is released. | `string` | `"ABANDON"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the network and its resources. | `string` | n/a | yes |
| <a name="input_routing_mode"></a> [routing\_mode](#input\_routing\_mode) | Network-wide routing mode for the VPC. REGIONAL keeps routes within a region; GLOBAL shares them across regions. | `string` | `"REGIONAL"` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | GKE-ready subnetworks to create in the VPC. Each subnet has a primary range plus named<br/>secondary ranges for GKE Pods and Services (used by VPC-native clusters as alias IP ranges). | <pre>list(object({<br/>    name                  = string<br/>    region                = string<br/>    ip_cidr_range         = string<br/>    pods_cidr_range       = optional(string)<br/>    services_cidr_range   = optional(string)<br/>    pods_range_name       = optional(string, "pods")<br/>    services_range_name   = optional(string, "services")<br/>    private_google_access = optional(bool, true)<br/>    flow_logs             = optional(bool, false)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_nat_ip_addresses"></a> [nat\_ip\_addresses](#output\_nat\_ip\_addresses) | Reserved static Cloud NAT egress IP address(es), or an empty list when NAT is disabled or using dynamic (AUTO\_ONLY) allocation. Allowlist these on external systems the private instances must reach. |
| <a name="output_nat_router_name"></a> [nat\_router\_name](#output\_nat\_router\_name) | Name of the Cloud Router backing Cloud NAT, or null when NAT is disabled. |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | The ID of the VPC network. |
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | The name of the VPC network. |
| <a name="output_network_self_link"></a> [network\_self\_link](#output\_network\_self\_link) | The URI (self link) of the VPC network, used when wiring GKE clusters and peerings. |
| <a name="output_private_service_access_range"></a> [private\_service\_access\_range](#output\_private\_service\_access\_range) | Name of the reserved global address range used for Private Service Access, or null when disabled. |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Map of subnet name (as supplied in var.subnets) to its key attributes. |
| <a name="output_subnets_secondary_ranges"></a> [subnets\_secondary\_ranges](#output\_subnets\_secondary\_ranges) | Map of subnet name to its secondary range names (Pods/Services) for VPC-native GKE clusters. |
| <a name="output_subnets_self_links"></a> [subnets\_self\_links](#output\_subnets\_self\_links) | Map of subnet name to self link. |
<!-- END_TF_DOCS -->
