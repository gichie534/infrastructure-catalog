# Public, Google-managed HTTPS certificates for GKE Ingress (external Application Load Balancer),
# validated by DNS authorization — the GCP analogue of "ACM cert + Route53 validation". Certificate
# Manager provisions and auto-renews each cert as long as its DNS-authorization CNAME stays published
# in the zone; GKE Ingress attaches the certs by referencing this module's certificate MAP via the
# `networking.gke.io/certmap` annotation (the annotation takes a map name, not a cert name).
#
# ALL-IN-ONE: this module owns the whole bundle — one certificate (via the private ./modules/certificate
# submodule) per domain, one certificate map, and one map entry per domain (SNI-routed by hostname).
# Per-host only: wildcard domains are rejected (see variables.tf).
#
# DNS records are NOT written here (by design). The module OUTPUTS the validation CNAME each domain
# needs; wire those into your zone via the gcp/cloud-dns module. Nothing validates until they resolve.

locals {
  # Resource names are derived as "<name>-<label>". Certificate Manager resource names must match
  # [a-zA-Z][a-zA-Z0-9_-]* and be <= 64 chars, which is why the map is keyed by a caller-chosen label
  # rather than the (dotted) domain.
  resource_names = { for k in keys(var.certificates) : k => "${var.name}-${k}" }
}

# --- Certificates ----------------------------------------------------------
# One DNS-authorized, auto-renewing managed certificate per domain, via the private submodule.
module "certificate" {
  source   = "./modules/certificate"
  for_each = var.certificates

  project_id = var.project_id
  name       = local.resource_names[each.key]
  location   = var.location
  domain     = each.value.domain
  labels     = var.labels
}

# --- Certificate map -------------------------------------------------------
# The single object a GKE Ingress references via `networking.gke.io/certmap: <name>`.
resource "google_certificate_manager_certificate_map" "this" {
  project     = var.project_id
  name        = var.name
  description = "Managed by Terraform"
  labels      = var.labels
}

# --- Map entries -----------------------------------------------------------
# One entry per domain, selected by SNI hostname. A client whose SNI matches no entry is rejected
# (there is deliberately no PRIMARY fallback entry — keep it explicit and per-host).
resource "google_certificate_manager_certificate_map_entry" "this" {
  for_each = var.certificates

  project      = var.project_id
  name         = local.resource_names[each.key]
  map          = google_certificate_manager_certificate_map.this.name
  hostname     = each.value.domain
  certificates = [module.certificate[each.key].certificate_id]
  description  = "Managed by Terraform"
  labels       = var.labels
}
