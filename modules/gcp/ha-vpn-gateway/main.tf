# gcp/ha-vpn-gateway module.
#
# A Cloud HA VPN gateway: two interfaces, each assigned its own Google-owned external IPv4 address.
#
# WHY THIS IS A MODULE OF ITS OWN, separate from gcp/ha-vpn-tunnels: peering HA VPN with a
# non-Google peer (an AWS Site-to-Site VPN, an on-prem router) is inherently a TWO-PHASE operation,
# because each side needs an address the other side only has once it exists:
#
#   phase 1  this module          -> Google assigns the two interface IP addresses
#   phase 2  the peer (e.g. AWS)  -> configure it with those IPs; it returns its own tunnel
#                                    outside addresses, inside addresses and pre-shared keys
#   phase 3  gcp/ha-vpn-tunnels   -> external gateway + tunnels + BGP, using the phase-2 values
#
# Splitting the gateway from its tunnels lets a consumer express that ordering with ordinary
# dependency wiring instead of a targeted apply or a two-pass hack.
resource "google_compute_ha_vpn_gateway" "this" {
  name    = var.name
  project = var.project_id
  region  = var.region
  network = var.network

  stack_type = var.stack_type
}
