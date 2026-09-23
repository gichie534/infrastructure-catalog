# aws/site-to-site-vpn

The **AWS half** of a BGP-routed IPsec VPN to a peer gateway in another network — typically another
cloud. Creates the virtual private gateway, **one customer gateway and one VPN connection per peer
interface**, and the route propagation that makes learned routes usable.

## The contract

A VPN can't be configured in one pass: each side needs an address the other only has once it exists.
So this module takes the peer's addresses in and hands back everything the peer needs:

```
in    peer_gateway_ip_addresses   the peer's public interface addresses
out   tunnels                     per tunnel: outside address, the link-local /30, both inside
                                  addresses, both ASNs, and the pre-shared key
```

`tunnels` is marked **sensitive** as a whole because it carries the pre-shared keys — consume it from
another module rather than printing it. `tunnel_outside_addresses` is non-sensitive for diagnostics.

## One connection per peer interface

A Google Cloud HA VPN gateway has two interfaces, and **each sources traffic from its own address**.
AWS only accepts traffic from the address its customer gateway names, so a single AWS connection
cannot serve both interfaces. Hence one customer gateway plus one connection per address.

AWS then builds **two tunnels per connection**. An HA VPN peer pairs one interface with one
connection, so it consumes only `tunnel_index == 1` of each and the second tunnel of each connection
stays `DOWN`. That is expected, not a fault.

## Usage

```hcl
# Phase 1: the peer gateway exists first, so its addresses are known.
module "ha_vpn_gateway" {
  source = ".../modules/gcp/ha-vpn-gateway?ref=..."
  # ...
}

# Phase 2: the AWS side, configured from the peer's addresses.
module "aws_vpn" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/aws/site-to-site-vpn?ref=aws-site-to-site-vpn-vX.Y.Z"

  name   = "xcloud"
  vpc_id = module.vpc.vpc_id

  peer_gateway_ip_addresses = module.ha_vpn_gateway.interface_ip_addresses

  peer_bgp_asn    = 65001 # the peer's Cloud Router ASN
  amazon_side_asn = 64512

  # Without this, BGP comes up but nothing in the VPC has a route back to the peer.
  route_table_ids = values(module.vpc.private_route_table_ids)
}

# Phase 3: the peer's tunnels, built from this module's output.
module "ha_vpn_tunnels" {
  source = ".../modules/gcp/ha-vpn-tunnels?ref=..."

  # HA VPN pairs one interface per AWS connection, so take tunnel 1 of each.
  tunnels = [for t in module.aws_vpn.tunnels : t if t.tunnel_index == 1]
  # ...
}
```

## Notes

- **`route_table_ids` is the step that is easy to miss.** Omit it and the tunnels establish, BGP
  exchanges routes, and traffic still fails — presenting as a one-way network rather than a missing
  route.
- `amazon_side_asn` defaults to `64512` and is set explicitly rather than left to AWS, so the peer's
  BGP neighbour ASN is deterministic.
- `ike_versions` pins IKEv2 by default, which is what Google Cloud HA VPN speaks.
- `tunnel_startup_action` defaults to `start` so AWS also initiates negotiation, shortening time to
  first establishment when both ends are cloud gateways.
- Inside `/30`s and pre-shared keys are allocated by AWS unless overridden via `tunnel_inside_cidrs`
  / `tunnel_preshared_keys`. Override the CIDRs only when AWS's `169.254.0.0/16` allocations would
  collide with ranges already used on the peer side.
- **Cost:** a VPN connection is billed hourly from creation, whether or not its tunnels are up.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.66.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_customer_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/customer_gateway) | resource |
| [aws_vpn_connection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection) | resource |
| [aws_vpn_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_gateway) | resource |
| [aws_vpn_gateway_route_propagation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_gateway_route_propagation) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | BGP Autonomous System Number of the AMAZON side of the virtual private gateway. Set explicitly (rather than letting AWS default it) so the peer's BGP configuration can reference it deterministically. Changing this replaces the gateway. | `number` | `64512` | no |
| <a name="input_ike_versions"></a> [ike\_versions](#input\_ike\_versions) | Permitted IKE versions for every tunnel. Google Cloud HA VPN uses IKEv2, so the default pins it rather than letting AWS negotiate either version. | `list(string)` | <pre>[<br/>  "ikev2"<br/>]</pre> | no |
| <a name="input_local_ipv4_network_cidr"></a> [local\_ipv4\_network\_cidr](#input\_local\_ipv4\_network\_cidr) | IPv4 CIDR on the AWS side allowed over the tunnels. Null uses AWS's default of 0.0.0.0/0, which is correct for BGP. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for the virtual private gateway, customer gateways, and VPN connections. | `string` | n/a | yes |
| <a name="input_peer_bgp_asn"></a> [peer\_bgp\_asn](#input\_peer\_bgp\_asn) | BGP Autonomous System Number of the PEER side (for a Google Cloud peer, the Cloud Router's ASN). Changing this replaces the customer gateways. | `number` | `65001` | no |
| <a name="input_peer_gateway_ip_addresses"></a> [peer\_gateway\_ip\_addresses](#input\_peer\_gateway\_ip\_addresses) | Public IPv4 address of each peer VPN gateway interface. ONE customer gateway and ONE VPN<br/>connection is created per address, in list order.<br/><br/>For a Google Cloud HA VPN peer, pass the ha-vpn-gateway module's interface\_ip\_addresses output<br/>verbatim: each HA VPN interface sources traffic from its own address, so a single AWS connection<br/>cannot serve both (AWS accepts traffic only from the address its customer gateway names). | `list(string)` | n/a | yes |
| <a name="input_remote_ipv4_network_cidr"></a> [remote\_ipv4\_network\_cidr](#input\_remote\_ipv4\_network\_cidr) | IPv4 CIDR on the peer side allowed over the tunnels. Null uses AWS's default of 0.0.0.0/0, which is correct for BGP. | `string` | `null` | no |
| <a name="input_route_table_ids"></a> [route\_table\_ids](#input\_route\_table\_ids) | Route tables that should learn routes from the VPN via BGP (route propagation). Without this, BGP sessions come up but VPC instances have no route back to the peer. Wire this to the vpc module's private\_route\_table\_ids. | `list(string)` | `[]` | no |
| <a name="input_static_routes_only"></a> [static\_routes\_only](#input\_static\_routes\_only) | Use static routing instead of BGP. Leave false: the peer\_bgp\_asn/amazon\_side\_asn contract and the tunnels output exist to support dynamic routing, and a Google Cloud HA VPN peer requires BGP. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource created by this module. | `map(string)` | `{}` | no |
| <a name="input_tunnel_inside_cidrs"></a> [tunnel\_inside\_cidrs](#input\_tunnel\_inside\_cidrs) | Optional override for the link-local /30 inside each tunnel, one entry per connection<br/>(index-aligned with peer\_gateway\_ip\_addresses). Each entry supplies tunnel1 and/or tunnel2.<br/>Leave empty to let AWS allocate from 169.254.0.0/16 — override only when those allocations<br/>would collide with ranges already in use on the peer side. | <pre>list(object({<br/>    tunnel1 = optional(string)<br/>    tunnel2 = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_tunnel_preshared_keys"></a> [tunnel\_preshared\_keys](#input\_tunnel\_preshared\_keys) | Optional override for the IKE pre-shared keys, one entry per connection (index-aligned with<br/>peer\_gateway\_ip\_addresses). Leave empty to let AWS generate them — the generated values are<br/>returned in the tunnels output, so the peer can be configured from it either way. | <pre>list(object({<br/>    tunnel1 = optional(string)<br/>    tunnel2 = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_tunnel_startup_action"></a> [tunnel\_startup\_action](#input\_tunnel\_startup\_action) | Which side initiates the IKE negotiation: 'add' waits for the peer to start it, 'start' makes AWS initiate too. 'start' shortens the time to first establishment when both ends are cloud gateways. | `string` | `"start"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC the virtual private gateway attaches to. Wire this to the vpc module's vpc\_id output. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_amazon_side_asn"></a> [amazon\_side\_asn](#output\_amazon\_side\_asn) | BGP ASN of the Amazon side. The peer configures this as its BGP neighbour's ASN. |
| <a name="output_customer_gateway_ids"></a> [customer\_gateway\_ids](#output\_customer\_gateway\_ids) | Map of peer-interface index (as a string) to the customer gateway ID created for it. |
| <a name="output_tunnel_outside_addresses"></a> [tunnel\_outside\_addresses](#output\_tunnel\_outside\_addresses) | Public address of every AWS tunnel endpoint, ordered by connection then tunnel. Use these as the peer's external gateway interfaces. Non-sensitive, so it is safe to print while diagnosing connectivity. |
| <a name="output_tunnels"></a> [tunnels](#output\_tunnels) | Everything the peer side needs, one entry per tunnel (two per connection), ordered by connection<br/>then tunnel: connection\_index, tunnel\_index, connection\_id, peer\_gateway\_ip, outside\_address,<br/>inside\_cidr, vgw\_inside\_address (the peer's BGP neighbour), cgw\_inside\_address and<br/>cgw\_inside\_address\_cidr (the address the peer's own router interface must hold),<br/>amazon\_side\_asn, peer\_bgp\_asn, and preshared\_key.<br/><br/>Marked sensitive as a whole because it carries the pre-shared keys; consume it from another<br/>module rather than printing it. Use tunnel\_outside\_addresses for anything you need to read. |
| <a name="output_vpn_connection_ids"></a> [vpn\_connection\_ids](#output\_vpn\_connection\_ids) | Map of peer-interface index (as a string) to the VPN connection ID created for it. |
| <a name="output_vpn_gateway_id"></a> [vpn\_gateway\_id](#output\_vpn\_gateway\_id) | ID of the virtual private gateway attached to the VPC. |
<!-- END_TF_DOCS -->
