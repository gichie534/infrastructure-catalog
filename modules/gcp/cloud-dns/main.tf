# A single Cloud DNS managed zone (public or private) plus a set of record sets. Designed
# for GKE service discovery: a private zone on the cluster's VPC lets workloads resolve
# internal names, while a public zone serves external names.
#
# Record names are given relative to the zone (e.g. "api"); "" denotes the zone apex. The
# module expands them to FQDNs against dns_name.
#
# A separate `validation_records` input handles records whose NAME is computed at apply time
# (ACME / Certificate Manager DNS-authorization CNAMEs): it is keyed by a stable caller label rather
# than the record name, so for_each stays plan-time-known.

locals {
  # Map each relative record name to its fully-qualified name. "" is the apex (dns_name).
  record_fqdns = {
    for rel, r in var.records :
    rel => rel == "" ? var.dns_name : "${rel}.${var.dns_name}"
  }
}

resource "google_dns_managed_zone" "this" {
  project     = var.project_id
  name        = var.name
  dns_name    = var.dns_name
  description = "Managed by Terraform"
  labels      = var.labels
  visibility  = var.visibility

  dynamic "private_visibility_config" {
    for_each = var.visibility == "private" ? [1] : []
    content {
      dynamic "networks" {
        for_each = var.networks
        content {
          network_url = networks.value
        }
      }
    }
  }
}

resource "google_dns_record_set" "this" {
  for_each = var.records

  project      = var.project_id
  managed_zone = google_dns_managed_zone.this.name
  name         = local.record_fqdns[each.key]
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}

# Records with computed names (ACME / Certificate Manager DNS-authorization CNAMEs). Keyed by a
# stable caller label so for_each stays plan-time-known; the absolute name comes from the value and
# is written verbatim (no expansion against dns_name).
resource "google_dns_record_set" "validation" {
  for_each = var.validation_records

  project      = var.project_id
  managed_zone = google_dns_managed_zone.this.name
  name         = each.value.name
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}
