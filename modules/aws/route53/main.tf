# A single Route 53 hosted zone (public or private) plus a set of records. The AWS analogue of the
# gcp/cloud-dns module: a private zone associated with one or more VPCs lets workloads resolve
# internal names, while a public zone serves external names and is delegated to at a registrar.
#
# Record names are given relative to the zone (e.g. "api"); "" denotes the zone apex. The module
# expands them to FQDNs against the zone name.
#
# A separate `validation_records` input handles records whose NAME is computed at apply time
# (ACM certificate DNS-validation CNAMEs): it is keyed by a stable caller label rather than the
# record name, so for_each stays plan-time-known.
#
# When `delegate_to_parent_zone` is set, the module also writes an NS record for THIS zone's name
# into an existing parent hosted zone, using this zone's own authoritative name servers. That makes
# a delegated subdomain reproducible: Route 53 assigns fresh name servers each time the zone is
# recreated, and the delegation is rewritten in lock-step, so teardown/recreate never leaves a stale
# NS record.

locals {
  # Zone apex without a trailing dot, so relative names expand cleanly.
  zone_fqdn = trimsuffix(var.name, ".")

  # Map each relative record name to its fully-qualified name. "" is the apex.
  record_fqdns = {
    for rel, r in var.records :
    rel => rel == "" ? local.zone_fqdn : "${rel}.${local.zone_fqdn}"
  }
}

resource "aws_route53_zone" "this" {
  name          = var.name
  comment       = var.comment
  force_destroy = var.force_destroy
  tags          = var.tags

  # Present only for private zones; a public zone must have no vpc association.
  dynamic "vpc" {
    for_each = var.visibility == "private" ? var.vpc_associations : []
    content {
      vpc_id     = vpc.value.vpc_id
      vpc_region = vpc.value.vpc_region
    }
  }
}

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = aws_route53_zone.this.zone_id
  name    = local.record_fqdns[each.key]
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}

# Records with computed names (ACM certificate DNS-validation CNAMEs). Keyed by a stable caller
# label so for_each stays plan-time-known; the absolute name comes from the value and is written
# verbatim (no expansion against the zone name).
resource "aws_route53_record" "validation" {
  for_each = var.validation_records

  zone_id = aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}

# Subdomain delegation: write an NS record for this zone's name into an existing PARENT hosted zone,
# pointing at this zone's authoritative name servers. Created only when delegate_to_parent_zone is
# set. The records come from the zone resource itself, so the delegation always tracks the current
# name servers (reproducible across destroy/recreate).
resource "aws_route53_record" "delegation" {
  count = var.delegate_to_parent_zone == null ? 0 : 1

  zone_id = var.delegate_to_parent_zone.zone_id
  name    = local.zone_fqdn
  type    = "NS"
  ttl     = var.delegate_to_parent_zone.ttl
  records = aws_route53_zone.this.name_servers
}
