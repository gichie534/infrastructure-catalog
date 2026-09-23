variable "name" {
  description = "Name prefix for the external VPN gateway, Cloud Router, tunnels, router interfaces, and BGP peers."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,48}[a-z0-9])?$", var.name))
    error_message = "name must be 1-50 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen (room is left for per-tunnel suffixes)."
  }
}

variable "project_id" {
  description = "The ID of the project to create the tunnels and Cloud Router in."
  type        = string
  nullable    = false
}

variable "region" {
  description = "Region for the Cloud Router and tunnels. Must match the region of the HA VPN gateway."
  type        = string
  nullable    = false
}

variable "network" {
  description = "Self link or name of the VPC network the Cloud Router attaches to. Wire this to the vpc module's network_self_link output."
  type        = string
  nullable    = false
}

variable "ha_vpn_gateway" {
  description = "Self link or ID of the HA VPN gateway the tunnels originate from. Wire this to the ha-vpn-gateway module's self_link output."
  type        = string
  nullable    = false
}

variable "peer_gateway_interfaces" {
  description = <<-EOT
    Public IPv4 address of each PEER tunnel endpoint, in interface order — index 0 becomes external
    gateway interface 0. These describe the peer to Google Cloud.

    For an AWS Site-to-Site VPN peer, pass the outside address of the AWS tunnels you intend to use
    (one per AWS connection, since each HA VPN interface pairs with one connection).

    Google only accepts 1, 2, or 4 interfaces, which sets the gateway's redundancy type.
  EOT
  type        = list(string)
  nullable    = false

  validation {
    condition     = contains([1, 2, 4], length(var.peer_gateway_interfaces))
    error_message = "peer_gateway_interfaces must contain exactly 1, 2, or 4 addresses (Google's supported redundancy types)."
  }

  validation {
    condition = alltrue([
      for ip in var.peer_gateway_interfaces :
      can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$", ip))
    ])
    error_message = "every entry in peer_gateway_interfaces must be a valid IPv4 address."
  }

  validation {
    condition     = length(distinct(var.peer_gateway_interfaces)) == length(var.peer_gateway_interfaces)
    error_message = "peer_gateway_interfaces must not contain duplicates."
  }
}

variable "tunnels" {
  description = <<-EOT
    One entry per tunnel to build. Each pairs an HA VPN gateway interface with a peer interface and
    carries the BGP addressing for that tunnel's link-local /30:

      vpn_gateway_interface           - HA VPN gateway interface (0 or 1) the tunnel leaves from.
      peer_external_gateway_interface - index into peer_gateway_interfaces it connects to.
      router_interface_ip_range       - THIS side's address inside the /30, WITH prefix
                                        (e.g. "169.254.10.2/30").
      peer_ip_address                 - the PEER's address inside the same /30, the BGP neighbour.
      peer_asn                        - the peer's BGP ASN.
      advertised_route_priority       - optional MED for routes learned over this tunnel; lower wins.

    From an aws/site-to-site-vpn peer these map to cgw_inside_address_cidr, vgw_inside_address, and
    amazon_side_asn respectively.

    Pre-shared keys are NOT here: they go in tunnel_shared_secrets, because Terraform cannot use a
    sensitive value in for_each.
  EOT
  type = list(object({
    vpn_gateway_interface           = number
    peer_external_gateway_interface = number
    router_interface_ip_range       = string
    peer_ip_address                 = string
    peer_asn                        = number
    advertised_route_priority       = optional(number)
  }))
  nullable = false

  validation {
    condition     = length(var.tunnels) >= 1
    error_message = "at least one tunnel must be defined."
  }

  validation {
    condition     = alltrue([for t in var.tunnels : contains([0, 1], t.vpn_gateway_interface)])
    error_message = "each tunnel's vpn_gateway_interface must be 0 or 1 (an HA VPN gateway has two interfaces)."
  }

  validation {
    condition = alltrue([
      for t in var.tunnels :
      t.peer_external_gateway_interface >= 0 && t.peer_external_gateway_interface < length(var.peer_gateway_interfaces)
    ])
    error_message = "each tunnel's peer_external_gateway_interface must index an entry in peer_gateway_interfaces."
  }

  validation {
    condition = alltrue([
      for t in var.tunnels :
      can(cidrhost(t.router_interface_ip_range, 0)) && can(regex("/[0-9]+$", t.router_interface_ip_range))
    ])
    error_message = "each tunnel's router_interface_ip_range must be an address WITH a prefix (e.g. 169.254.10.2/30)."
  }

  validation {
    condition = alltrue([
      for t in var.tunnels :
      can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$", t.peer_ip_address))
    ])
    error_message = "each tunnel's peer_ip_address must be a valid IPv4 address."
  }

  validation {
    condition     = alltrue([for t in var.tunnels : t.peer_asn >= 1 && t.peer_asn <= 4294967294])
    error_message = "each tunnel's peer_asn must be between 1 and 4294967294."
  }
}

variable "tunnel_shared_secrets" {
  description = "IKE pre-shared key for each tunnel, index-aligned with the tunnels list. Separate from tunnels because Terraform forbids a sensitive value in for_each."
  type        = list(string)
  nullable    = false
  sensitive   = true

  validation {
    condition     = length(var.tunnel_shared_secrets) == length(var.tunnels)
    error_message = "tunnel_shared_secrets must have exactly one entry per tunnels entry, in the same order."
  }

  validation {
    condition     = alltrue([for s in var.tunnel_shared_secrets : length(s) > 0])
    error_message = "every tunnel shared secret must be non-empty."
  }
}

variable "bgp_asn" {
  description = "BGP ASN for THIS side's Cloud Router. The peer must be configured with this as its neighbour ASN (e.g. the aws/site-to-site-vpn module's peer_bgp_asn)."
  type        = number
  nullable    = false
  default     = 65001

  validation {
    condition     = (var.bgp_asn >= 64512 && var.bgp_asn <= 65534) || (var.bgp_asn >= 4200000000 && var.bgp_asn <= 4294967294)
    error_message = "bgp_asn must be in a private ASN range: 64512-65534 (16-bit) or 4200000000-4294967294 (32-bit)."
  }
}

variable "advertise_all_subnets" {
  description = "Advertise every subnet of the VPC to the peer. Leave true unless the peer should only see specific ranges."
  type        = bool
  nullable    = false
  default     = true
}

variable "advertised_ip_ranges" {
  description = <<-EOT
    Extra IP ranges to advertise to the peer beyond the VPC's own subnets.

    The case that needs this: GKE Pods get addresses from a subnet SECONDARY range, which is not a
    subnet in its own right and so is never covered by advertise_all_subnets. GKE does not masquerade
    Pod traffic to RFC 1918 destinations, so a Pod reaching the peer arrives with its POD address —
    and without that range advertised, the peer has no return route. Advertising both the Pod range
    and the node subnet makes the path work regardless of masquerade behaviour.
  EOT
  type = list(object({
    range       = string
    description = optional(string)
  }))
  nullable = false
  default  = []

  validation {
    condition     = alltrue([for r in var.advertised_ip_ranges : can(cidrhost(r.range, 0))])
    error_message = "every advertised_ip_ranges range must be a valid CIDR."
  }
}

variable "ike_version" {
  description = "IKE version for every tunnel. AWS Site-to-Site VPN supports both; 2 is the default on both sides."
  type        = number
  nullable    = false
  default     = 2

  validation {
    condition     = contains([1, 2], var.ike_version)
    error_message = "ike_version must be 1 or 2."
  }
}

variable "router_name" {
  description = "Name for the Cloud Router. Defaults to \"<name>-router\". A dedicated router keeps BGP separate from a router used for Cloud NAT."
  type        = string
  nullable    = true
  default     = null
}

variable "keepalive_interval" {
  description = "BGP keepalive interval in seconds. Null uses Google's default (20)."
  type        = number
  nullable    = true
  default     = null

  validation {
    condition     = var.keepalive_interval == null || (var.keepalive_interval >= 20 && var.keepalive_interval <= 60)
    error_message = "keepalive_interval must be between 20 and 60 seconds."
  }
}
