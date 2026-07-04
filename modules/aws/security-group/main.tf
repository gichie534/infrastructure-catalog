# A single VPC security group with consumer-supplied ingress/egress rules — the minimal network
# access-control building block. Its main reason to exist beyond the raw resource: first-class
# support for security-group-to-security-group rules (source_security_group_id), so a consumer can
# say "allow this SG from that SG" without hand-writing the AWS resources each time.
#
# The module owns ONLY the security group and its rules. It does not create the VPC — that's passed
# in as vpc_id — which keeps it region- and account-agnostic and reusable across labs.
#
# Rules are managed with the current best-practice aws_vpc_security_group_(in|e)gress_rule resources
# (one CIDR or one referenced SG per rule) rather than the legacy inline ingress/egress blocks on
# aws_security_group, which don't give each rule its own id/description and mishandle multiple CIDRs.
# A rule with several cidr_blocks is expanded to one rule resource per CIDR.

locals {
  # Expand each ingress rule into one entry per CIDR block, plus one entry for a referenced SG.
  # Keyed by a stable string so plans are deterministic.
  ingress_expanded = merge([
    for idx, r in var.ingress_rules : merge(
      {
        for cidr in r.cidr_blocks : "${idx}-cidr-${cidr}" => {
          description                  = r.description
          from_port                    = r.from_port
          to_port                      = r.to_port
          ip_protocol                  = r.protocol
          cidr_ipv4                    = cidr
          referenced_security_group_id = null
        }
      },
      r.source_security_group_id != null ? {
        "${idx}-sg-${r.source_security_group_id}" = {
          description                  = r.description
          from_port                    = r.from_port
          to_port                      = r.to_port
          ip_protocol                  = r.protocol
          cidr_ipv4                    = null
          referenced_security_group_id = r.source_security_group_id
        }
      } : {}
    )
  ]...)

  egress_expanded = merge([
    for idx, r in var.egress_rules : merge(
      {
        for cidr in r.cidr_blocks : "${idx}-cidr-${cidr}" => {
          description                  = r.description
          from_port                    = r.from_port
          to_port                      = r.to_port
          ip_protocol                  = r.protocol
          cidr_ipv4                    = cidr
          referenced_security_group_id = null
        }
      },
      r.source_security_group_id != null ? {
        "${idx}-sg-${r.source_security_group_id}" = {
          description                  = r.description
          from_port                    = r.from_port
          to_port                      = r.to_port
          ip_protocol                  = r.protocol
          cidr_ipv4                    = null
          referenced_security_group_id = r.source_security_group_id
        }
      } : {}
    )
  ]...)
}

resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress_expanded

  security_group_id = aws_security_group.this.id
  description       = each.value.description != "" ? each.value.description : null

  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id

  # Port range is unset for all-protocol (-1) rules; the API rejects ports there.
  from_port = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port   = each.value.ip_protocol == "-1" ? null : each.value.to_port

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = local.egress_expanded

  security_group_id = aws_security_group.this.id
  description       = each.value.description != "" ? each.value.description : null

  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id

  from_port = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port   = each.value.ip_protocol == "-1" ? null : each.value.to_port

  tags = var.tags
}
