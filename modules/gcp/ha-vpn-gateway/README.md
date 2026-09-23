# gcp/ha-vpn-gateway

A Cloud **HA VPN gateway** — two interfaces, each with its own Google-assigned external IPv4
address. It creates the gateway and nothing else, so the addresses a peer must be configured with
become available before any tunnel exists.

## Why this is separate from `gcp/ha-vpn-tunnels`

Peering HA VPN with a non-Google peer (an AWS Site-to-Site VPN, an on-prem router) is inherently
**two-phase**: each side needs an address the other side only produces once it exists.

```
phase 1   gcp/ha-vpn-gateway   ->  Google assigns interface 0 / interface 1 IP addresses
phase 2   the peer (e.g. AWS)  ->  configured with those IPs; returns its own tunnel outside
                                   addresses, inside (BGP) addresses and pre-shared keys
phase 3   gcp/ha-vpn-tunnels   ->  external gateway + tunnels + BGP, built from phase-2 values
```

Keeping the gateway in its own module lets a consumer express that ordering with ordinary dependency
wiring rather than a targeted apply or a two-pass workaround.

The gateway itself is not billed — only tunnels are — so applying this module alone is free.

## Usage

```hcl
module "ha_vpn_gateway" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/gcp/ha-vpn-gateway?ref=gcp-ha-vpn-gateway-vX.Y.Z"

  name       = "xcloud"
  project_id = var.project_id
  region     = "us-central1"
  network    = module.vpc.network_self_link
}

# Feed the peer with the interface addresses, in interface order.
module "aws_vpn" {
  source = ".../modules/aws/site-to-site-vpn?ref=..."

  peer_gateway_ip_addresses = module.ha_vpn_gateway.interface_ip_addresses
  # ...
}
```

## Notes

- `stack_type` defaults to `IPV4_ONLY`, the only stack an AWS Site-to-Site VPN peer supports.
- The gateway's `region` must match the region of the Cloud Router that terminates its tunnels.

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
| [google_compute_ha_vpn_gateway.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ha_vpn_gateway) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name of the HA VPN gateway. | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Self link or name of the VPC network the gateway attaches to. Wire this to the vpc module's network\_self\_link output. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project to create the gateway in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region for the HA VPN gateway. Must match the region of the Cloud Router that terminates its tunnels. | `string` | n/a | yes |
| <a name="input_stack_type"></a> [stack\_type](#input\_stack\_type) | IP stack for the gateway interfaces. IPV4\_ONLY is the only stack an AWS Site-to-Site VPN peer supports today. | `string` | `"IPV4_ONLY"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | The ID of the HA VPN gateway. |
| <a name="output_interface_ip_addresses"></a> [interface\_ip\_addresses](#output\_interface\_ip\_addresses) | External IPv4 address of each gateway interface, ordered by interface ID (index 0 = interface 0). Configure the PEER with these — e.g. one AWS customer gateway per address. |
| <a name="output_name"></a> [name](#output\_name) | The name of the HA VPN gateway. |
| <a name="output_region"></a> [region](#output\_region) | The region the gateway was created in. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | The server-defined URL (self link) of the HA VPN gateway. Wire this to the ha-vpn-tunnels module's ha\_vpn\_gateway input. |
<!-- END_TF_DOCS -->
