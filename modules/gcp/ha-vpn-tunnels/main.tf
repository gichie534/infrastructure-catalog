# gcp/ha-vpn-tunnels module.
#
# Phase 3 of peering Cloud HA VPN with a non-Google gateway: the external gateway that describes the
# peer, a dedicated Cloud Router for BGP, and one tunnel + router interface + BGP peer per tunnel.
#
# Consumes an existing HA VPN gateway (see gcp/ha-vpn-gateway) and the peer's addressing. It owns no
# gateway of its own, so the two-phase ordering a real peering requires stays visible in the
# dependency graph instead of hiding inside one module that cannot be applied in a single pass.

locals {
  router_name = coalesce(var.router_name, "${var.name}-router")

  # Google derives redundancy from how many peer endpoints it is told about. The variable's
  # validation already restricts the length to these three cases.
  redundancy_type = {
    1 = "SINGLE_IP_INTERNALLY_REDUNDANT"
    2 = "TWO_IPS_REDUNDANCY"
    4 = "FOUR_IPS_REDUNDANCY"
  }[length(var.peer_gateway_interfaces)]

  # Keyed by stringified index so resource addresses are stable and each tunnel's shared secret can
  # be looked up positionally (the secrets live in a separate, sensitive list because Terraform
  # refuses to evaluate for_each over a sensitive value).
  tunnels = { for idx, t in var.tunnels : tostring(idx) => t }

  # A router advertising only its subnets uses DEFAULT mode; anything more must be spelled out, and
  # in CUSTOM mode the subnet groups stop being implicit — so they are restated explicitly.
  advertise_custom = length(var.advertised_ip_ranges) > 0
  advertise_mode   = local.advertise_custom ? "CUSTOM" : "DEFAULT"
  advertised_groups = (
    local.advertise_custom && var.advertise_all_subnets ? ["ALL_SUBNETS"] : null
  )
}

# --- The peer, as Google Cloud sees it --------------------------------------
resource "google_compute_external_vpn_gateway" "this" {
  name            = "${var.name}-peer"
  project         = var.project_id
  description     = "Peer VPN gateway for ${var.name}"
  redundancy_type = local.redundancy_type

  dynamic "interface" {
    for_each = { for idx, ip in var.peer_gateway_interfaces : idx => ip }

    content {
      id         = interface.key
      ip_address = interface.value
    }
  }
}

# --- BGP ---------------------------------------------------------------------
# A router dedicated to this peering. Sharing the Cloud NAT router would work, but it couples an
# egress concern to a connectivity one and makes either harder to remove.
resource "google_compute_router" "this" {
  name    = local.router_name
  project = var.project_id
  region  = var.region
  network = var.network

  bgp {
    asn                = var.bgp_asn
    advertise_mode     = local.advertise_mode
    advertised_groups  = local.advertised_groups
    keepalive_interval = var.keepalive_interval

    dynamic "advertised_ip_ranges" {
      for_each = var.advertised_ip_ranges

      content {
        range       = advertised_ip_ranges.value.range
        description = advertised_ip_ranges.value.description
      }
    }
  }
}

# --- Tunnels ----------------------------------------------------------------
resource "google_compute_vpn_tunnel" "this" {
  for_each = local.tunnels

  name    = "${var.name}-${each.key}"
  project = var.project_id
  region  = var.region

  vpn_gateway           = var.ha_vpn_gateway
  vpn_gateway_interface = each.value.vpn_gateway_interface

  peer_external_gateway           = google_compute_external_vpn_gateway.this.id
  peer_external_gateway_interface = each.value.peer_external_gateway_interface

  shared_secret = var.tunnel_shared_secrets[tonumber(each.key)]
  ike_version   = var.ike_version
  router        = google_compute_router.this.id
}

# This side's address within the tunnel's link-local /30.
resource "google_compute_router_interface" "this" {
  for_each = local.tunnels

  name    = "${var.name}-${each.key}"
  project = var.project_id
  region  = var.region
  router  = google_compute_router.this.name

  ip_range   = each.value.router_interface_ip_range
  vpn_tunnel = google_compute_vpn_tunnel.this[each.key].name
}

# The peer's address within the same /30, and its ASN.
resource "google_compute_router_peer" "this" {
  for_each = local.tunnels

  name    = "${var.name}-${each.key}"
  project = var.project_id
  region  = var.region
  router  = google_compute_router.this.name

  interface                 = google_compute_router_interface.this[each.key].name
  peer_ip_address           = each.value.peer_ip_address
  peer_asn                  = each.value.peer_asn
  advertised_route_priority = each.value.advertised_route_priority
}
