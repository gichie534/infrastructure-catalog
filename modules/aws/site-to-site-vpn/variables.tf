variable "name" {
  description = "Name prefix for the virtual private gateway, customer gateways, and VPN connections."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,99}$", var.name))
    error_message = "name must be 1-100 characters, start with a letter or digit, and contain only alphanumeric characters, dots, underscores, or hyphens."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the virtual private gateway attaches to. Wire this to the vpc module's vpc_id output."
  type        = string
  nullable    = false
}

variable "peer_gateway_ip_addresses" {
  description = <<-EOT
    Public IPv4 address of each peer VPN gateway interface. ONE customer gateway and ONE VPN
    connection is created per address, in list order.

    For a Google Cloud HA VPN peer, pass the ha-vpn-gateway module's interface_ip_addresses output
    verbatim: each HA VPN interface sources traffic from its own address, so a single AWS connection
    cannot serve both (AWS accepts traffic only from the address its customer gateway names).
  EOT
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.peer_gateway_ip_addresses) >= 1 && length(var.peer_gateway_ip_addresses) <= 4
    error_message = "peer_gateway_ip_addresses must contain between 1 and 4 addresses."
  }

  validation {
    condition = alltrue([
      for ip in var.peer_gateway_ip_addresses :
      can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$", ip))
    ])
    error_message = "every entry in peer_gateway_ip_addresses must be a valid IPv4 address."
  }

  validation {
    condition     = length(distinct(var.peer_gateway_ip_addresses)) == length(var.peer_gateway_ip_addresses)
    error_message = "peer_gateway_ip_addresses must not contain duplicates — each connection needs a distinct peer interface."
  }
}

variable "peer_bgp_asn" {
  description = "BGP Autonomous System Number of the PEER side (for a Google Cloud peer, the Cloud Router's ASN). Changing this replaces the customer gateways."
  type        = number
  nullable    = false
  default     = 65001

  validation {
    condition     = var.peer_bgp_asn >= 1 && var.peer_bgp_asn <= 2147483647
    error_message = "peer_bgp_asn must be between 1 and 2147483647."
  }
}

variable "amazon_side_asn" {
  description = "BGP Autonomous System Number of the AMAZON side of the virtual private gateway. Set explicitly (rather than letting AWS default it) so the peer's BGP configuration can reference it deterministically. Changing this replaces the gateway."
  type        = number
  nullable    = false
  default     = 64512

  validation {
    condition     = (var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534) || (var.amazon_side_asn >= 4200000000 && var.amazon_side_asn <= 4294967294)
    error_message = "amazon_side_asn must be in a private ASN range: 64512-65534 (16-bit) or 4200000000-4294967294 (32-bit)."
  }
}

variable "route_table_ids" {
  description = "Route tables that should learn routes from the VPN via BGP (route propagation). Without this, BGP sessions come up but VPC instances have no route back to the peer. Wire this to the vpc module's private_route_table_ids."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "static_routes_only" {
  description = "Use static routing instead of BGP. Leave false: the peer_bgp_asn/amazon_side_asn contract and the tunnels output exist to support dynamic routing, and a Google Cloud HA VPN peer requires BGP."
  type        = bool
  nullable    = false
  default     = false
}

variable "ike_versions" {
  description = "Permitted IKE versions for every tunnel. Google Cloud HA VPN uses IKEv2, so the default pins it rather than letting AWS negotiate either version."
  type        = list(string)
  nullable    = false
  default     = ["ikev2"]

  validation {
    condition     = length(var.ike_versions) > 0 && alltrue([for v in var.ike_versions : contains(["ikev1", "ikev2"], v)])
    error_message = "ike_versions must be a non-empty subset of [\"ikev1\", \"ikev2\"]."
  }
}

variable "tunnel_startup_action" {
  description = "Which side initiates the IKE negotiation: 'add' waits for the peer to start it, 'start' makes AWS initiate too. 'start' shortens the time to first establishment when both ends are cloud gateways."
  type        = string
  nullable    = false
  default     = "start"

  validation {
    condition     = contains(["add", "start"], var.tunnel_startup_action)
    error_message = "tunnel_startup_action must be either add or start."
  }
}

variable "tunnel_inside_cidrs" {
  description = <<-EOT
    Optional override for the link-local /30 inside each tunnel, one entry per connection
    (index-aligned with peer_gateway_ip_addresses). Each entry supplies tunnel1 and/or tunnel2.
    Leave empty to let AWS allocate from 169.254.0.0/16 — override only when those allocations
    would collide with ranges already in use on the peer side.
  EOT
  type = list(object({
    tunnel1 = optional(string)
    tunnel2 = optional(string)
  }))
  nullable = false
  default  = []

  validation {
    condition     = length(var.tunnel_inside_cidrs) == 0 || length(var.tunnel_inside_cidrs) == length(var.peer_gateway_ip_addresses)
    error_message = "tunnel_inside_cidrs must either be empty or have exactly one entry per peer_gateway_ip_addresses entry."
  }

  validation {
    condition = alltrue(flatten([
      for e in var.tunnel_inside_cidrs : [
        for c in compact([e.tunnel1, e.tunnel2]) :
        can(cidrhost(c, 0)) && tonumber(split("/", c)[1]) == 30
      ]
    ]))
    error_message = "every supplied tunnel inside CIDR must be a valid /30 (e.g. 169.254.10.0/30)."
  }
}

variable "tunnel_preshared_keys" {
  description = <<-EOT
    Optional override for the IKE pre-shared keys, one entry per connection (index-aligned with
    peer_gateway_ip_addresses). Leave empty to let AWS generate them — the generated values are
    returned in the tunnels output, so the peer can be configured from it either way.
  EOT
  type = list(object({
    tunnel1 = optional(string)
    tunnel2 = optional(string)
  }))
  nullable  = false
  default   = []
  sensitive = true

  validation {
    condition     = length(var.tunnel_preshared_keys) == 0 || length(var.tunnel_preshared_keys) == length(var.peer_gateway_ip_addresses)
    error_message = "tunnel_preshared_keys must either be empty or have exactly one entry per peer_gateway_ip_addresses entry."
  }
}

variable "local_ipv4_network_cidr" {
  description = "IPv4 CIDR on the AWS side allowed over the tunnels. Null uses AWS's default of 0.0.0.0/0, which is correct for BGP."
  type        = string
  nullable    = true
  default     = null
}

variable "remote_ipv4_network_cidr" {
  description = "IPv4 CIDR on the peer side allowed over the tunnels. Null uses AWS's default of 0.0.0.0/0, which is correct for BGP."
  type        = string
  nullable    = true
  default     = null
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module."
  type        = map(string)
  nullable    = false
  default     = {}
}
