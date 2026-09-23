# gcp/ha-vpn-tunnels

Phase 3 of peering Cloud **HA VPN** with a non-Google gateway: the **external VPN gateway** that
describes the peer, a **dedicated Cloud Router** for BGP, and one **tunnel + router interface + BGP
peer** per tunnel.

Consumes an existing HA VPN gateway (see [`gcp/ha-vpn-gateway`](../ha-vpn-gateway)) rather than
creating one, so the two-phase ordering a real peering requires stays visible in the dependency graph
instead of hiding inside a module that cannot be applied in a single pass.

## Why pre-shared keys are a separate input

`tunnels` carries the addressing; `tunnel_shared_secrets` carries the keys, index-aligned. That split
is not cosmetic — Terraform **cannot evaluate `for_each` over a sensitive value**, so the per-tunnel
map has to be built from non-sensitive data and the secret looked up positionally.

## Usage

Wired to an [`aws/site-to-site-vpn`](../../aws/site-to-site-vpn) peer:

```hcl
locals {
  # HA VPN pairs one interface with one AWS connection, so take tunnel 1 of each connection.
  aws_tunnels = [for t in module.aws_vpn.tunnels : t if t.tunnel_index == 1]
}

module "ha_vpn_tunnels" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/gcp/ha-vpn-tunnels?ref=gcp-ha-vpn-tunnels-vX.Y.Z"

  name       = "xcloud"
  project_id = var.project_id
  region     = "us-central1"
  network    = module.vpc.network_self_link

  ha_vpn_gateway          = module.ha_vpn_gateway.self_link
  peer_gateway_interfaces = [for t in local.aws_tunnels : t.outside_address]

  tunnels = [
    for i, t in local.aws_tunnels : {
      vpn_gateway_interface           = i
      peer_external_gateway_interface = i
      router_interface_ip_range       = t.cgw_inside_address_cidr # this side, with prefix
      peer_ip_address                 = t.vgw_inside_address      # the BGP neighbour
      peer_asn                        = t.amazon_side_asn
    }
  ]

  tunnel_shared_secrets = [for t in local.aws_tunnels : t.preshared_key]

  bgp_asn = 65001 # must equal the peer's peer_bgp_asn

  # GKE Pods live in a subnet SECONDARY range, which advertise_all_subnets never covers.
  advertised_ip_ranges = [
    { range = "10.31.0.0/16", description = "GKE Pod range" },
  ]
}
```

## The GKE Pod range trap

GKE Pods get addresses from a subnet **secondary** range. That is not a subnet in its own right, so
`advertise_all_subnets` does not advertise it. GKE also does **not** masquerade Pod traffic to
RFC 1918 destinations, so a Pod reaching the peer arrives with its **Pod** address — and with the Pod
range unadvertised, the peer has no return route. The symptom is a connection that hangs rather than
one that is refused.

Advertising both the node subnet (automatic) and the Pod range via `advertised_ip_ranges` makes the
path work regardless of masquerade behaviour. On Autopilot, where the `ip-masq-agent` ConfigMap is not
editable, this is the only in-Terraform fix.

## Notes

- `peer_gateway_interfaces` accepts **1, 2, or 4** addresses; the count sets the gateway's redundancy
  type (`SINGLE_IP_INTERNALLY_REDUNDANT` / `TWO_IPS_REDUNDANCY` / `FOUR_IPS_REDUNDANCY`).
- `router_interface_ip_range` is this side's address **with** prefix (`169.254.10.2/30`), while
  `peer_ip_address` is a bare address. The `aws/site-to-site-vpn` module emits both forms, so no
  string surgery is needed.
- A **dedicated** Cloud Router is created rather than reusing one that runs Cloud NAT — sharing works,
  but it couples an egress concern to a connectivity one and makes either harder to remove.
- `bgp_asn` here and the peer's `peer_bgp_asn` must match, as must the peer's `amazon_side_asn` and
  each tunnel's `peer_asn`. Mismatches leave the tunnel up with BGP stuck in `Connect`.
- Check state with `gcloud compute vpn-tunnels describe <name> --region <region>` and
  `gcloud compute routers get-status <router> --region <region>`.
- **Cost:** Cloud VPN tunnels are billed hourly from creation, whether or not they establish.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.35 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 8.3.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_external_vpn_gateway.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_external_vpn_gateway) | resource |
| [google_compute_router.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_interface.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_interface) | resource |
| [google_compute_router_peer.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_peer) | resource |
| [google_compute_vpn_tunnel.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_vpn_tunnel) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_advertise_all_subnets"></a> [advertise\_all\_subnets](#input\_advertise\_all\_subnets) | Advertise every subnet of the VPC to the peer. Leave true unless the peer should only see specific ranges. | `bool` | `true` | no |
| <a name="input_advertised_ip_ranges"></a> [advertised\_ip\_ranges](#input\_advertised\_ip\_ranges) | Extra IP ranges to advertise to the peer beyond the VPC's own subnets.<br/><br/>The case that needs this: GKE Pods get addresses from a subnet SECONDARY range, which is not a<br/>subnet in its own right and so is never covered by advertise\_all\_subnets. GKE does not masquerade<br/>Pod traffic to RFC 1918 destinations, so a Pod reaching the peer arrives with its POD address —<br/>and without that range advertised, the peer has no return route. Advertising both the Pod range<br/>and the node subnet makes the path work regardless of masquerade behaviour. | <pre>list(object({<br/>    range       = string<br/>    description = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_bgp_asn"></a> [bgp\_asn](#input\_bgp\_asn) | BGP ASN for THIS side's Cloud Router. The peer must be configured with this as its neighbour ASN (e.g. the aws/site-to-site-vpn module's peer\_bgp\_asn). | `number` | `65001` | no |
| <a name="input_ha_vpn_gateway"></a> [ha\_vpn\_gateway](#input\_ha\_vpn\_gateway) | Self link or ID of the HA VPN gateway the tunnels originate from. Wire this to the ha-vpn-gateway module's self\_link output. | `string` | n/a | yes |
| <a name="input_ike_version"></a> [ike\_version](#input\_ike\_version) | IKE version for every tunnel. AWS Site-to-Site VPN supports both; 2 is the default on both sides. | `number` | `2` | no |
| <a name="input_keepalive_interval"></a> [keepalive\_interval](#input\_keepalive\_interval) | BGP keepalive interval in seconds. Null uses Google's default (20). | `number` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for the external VPN gateway, Cloud Router, tunnels, router interfaces, and BGP peers. | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Self link or name of the VPC network the Cloud Router attaches to. Wire this to the vpc module's network\_self\_link output. | `string` | n/a | yes |
| <a name="input_peer_gateway_interfaces"></a> [peer\_gateway\_interfaces](#input\_peer\_gateway\_interfaces) | Public IPv4 address of each PEER tunnel endpoint, in interface order — index 0 becomes external<br/>gateway interface 0. These describe the peer to Google Cloud.<br/><br/>For an AWS Site-to-Site VPN peer, pass the outside address of the AWS tunnels you intend to use<br/>(one per AWS connection, since each HA VPN interface pairs with one connection).<br/><br/>Google only accepts 1, 2, or 4 interfaces, which sets the gateway's redundancy type. | `list(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project to create the tunnels and Cloud Router in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region for the Cloud Router and tunnels. Must match the region of the HA VPN gateway. | `string` | n/a | yes |
| <a name="input_router_name"></a> [router\_name](#input\_router\_name) | Name for the Cloud Router. Defaults to "<name>-router". A dedicated router keeps BGP separate from a router used for Cloud NAT. | `string` | `null` | no |
| <a name="input_tunnel_shared_secrets"></a> [tunnel\_shared\_secrets](#input\_tunnel\_shared\_secrets) | IKE pre-shared key for each tunnel, index-aligned with the tunnels list. Separate from tunnels because Terraform forbids a sensitive value in for\_each. | `list(string)` | n/a | yes |
| <a name="input_tunnels"></a> [tunnels](#input\_tunnels) | One entry per tunnel to build. Each pairs an HA VPN gateway interface with a peer interface and<br/>carries the BGP addressing for that tunnel's link-local /30:<br/><br/>  vpn\_gateway\_interface           - HA VPN gateway interface (0 or 1) the tunnel leaves from.<br/>  peer\_external\_gateway\_interface - index into peer\_gateway\_interfaces it connects to.<br/>  router\_interface\_ip\_range       - THIS side's address inside the /30, WITH prefix<br/>                                    (e.g. "169.254.10.2/30").<br/>  peer\_ip\_address                 - the PEER's address inside the same /30, the BGP neighbour.<br/>  peer\_asn                        - the peer's BGP ASN.<br/>  advertised\_route\_priority       - optional MED for routes learned over this tunnel; lower wins.<br/><br/>From an aws/site-to-site-vpn peer these map to cgw\_inside\_address\_cidr, vgw\_inside\_address, and<br/>amazon\_side\_asn respectively.<br/><br/>Pre-shared keys are NOT here: they go in tunnel\_shared\_secrets, because Terraform cannot use a<br/>sensitive value in for\_each. | <pre>list(object({<br/>    vpn_gateway_interface           = number<br/>    peer_external_gateway_interface = number<br/>    router_interface_ip_range       = string<br/>    peer_ip_address                 = string<br/>    peer_asn                        = number<br/>    advertised_route_priority       = optional(number)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_advertised_ip_ranges"></a> [advertised\_ip\_ranges](#output\_advertised\_ip\_ranges) | Extra IP ranges advertised to the peer beyond the VPC's own subnets (e.g. a GKE Pod secondary range). |
| <a name="output_bgp_asn"></a> [bgp\_asn](#output\_bgp\_asn) | BGP ASN of this side's Cloud Router. The peer must use this as its neighbour ASN. |
| <a name="output_bgp_peer_names"></a> [bgp\_peer\_names](#output\_bgp\_peer\_names) | Map of tunnel index (as a string) to the Cloud Router BGP peer name. |
| <a name="output_external_gateway_id"></a> [external\_gateway\_id](#output\_external\_gateway\_id) | ID of the external VPN gateway describing the peer. |
| <a name="output_external_gateway_name"></a> [external\_gateway\_name](#output\_external\_gateway\_name) | Name of the external VPN gateway describing the peer. |
| <a name="output_redundancy_type"></a> [redundancy\_type](#output\_redundancy\_type) | Redundancy type Google derived from the number of peer interfaces supplied. |
| <a name="output_router_id"></a> [router\_id](#output\_router\_id) | ID of the Cloud Router running BGP for this peering. |
| <a name="output_router_name"></a> [router\_name](#output\_router\_name) | Name of the Cloud Router running BGP for this peering. Use it with `gcloud compute routers get-status` to read learned routes. |
| <a name="output_tunnel_names"></a> [tunnel\_names](#output\_tunnel\_names) | Map of tunnel index (as a string) to the VPN tunnel name. Use with `gcloud compute vpn-tunnels describe` to check establishment. |
| <a name="output_tunnel_self_links"></a> [tunnel\_self\_links](#output\_tunnel\_self\_links) | Map of tunnel index (as a string) to the VPN tunnel self link. |
<!-- END_TF_DOCS -->
