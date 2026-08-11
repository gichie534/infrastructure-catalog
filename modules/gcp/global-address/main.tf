# A single reserved global external IPv4 address, for a classic GKE Ingress (external Application
# Load Balancer). Reserving the address up front means the Ingress can reference it by name
# (kubernetes.io/ingress.global-static-ip-name) and the IP is stable across Ingress
# delete/recreate — unlike GKE's default ephemeral-IP behavior, which allocates a new address
# every time the Ingress object is recreated.
resource "google_compute_global_address" "this" {
  project      = var.project_id
  name         = var.name
  description  = var.description
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}
