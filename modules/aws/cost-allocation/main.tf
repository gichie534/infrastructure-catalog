# The allocation layer: cost allocation tag activation and cost category definitions.
#
# Both answer the same question — "whose spend is this?" — which is why they sit in one module. Budgets
# and anomaly detection can only ever tell you an ACCOUNT spent too much; allocation metadata is what
# turns that into a team, an environment, or a product. Without it every cost conversation ends at the
# account boundary.
#
# Neither of these creates billable infrastructure. Both are one-way in an important sense: cost data
# already recorded does not gain a tag column retroactively, and a cost category's rules apply from its
# effective month onward. That is the argument for putting them in a foundation rather than adding them
# the first time somebody asks for a chargeback report.
#
# Cost Explorer is a global service reachable only through its us-east-1 endpoint — configure the
# provider for us-east-1 in the calling unit.

# Activate a discovered tag key so it becomes a usable cost dimension. AWS rejects keys it has not yet
# seen on a real resource (discovery takes up to 24h), so this input is intentionally opt-in.
resource "aws_ce_cost_allocation_tag" "this" {
  for_each = toset(var.active_cost_allocation_tag_keys)

  tag_key = each.value
  status  = "Active"
}

resource "aws_ce_cost_category" "this" {
  for_each = var.cost_categories

  name         = each.key
  rule_version = "CostCategoryExpression.v1"

  # Spend that matches no rule. Naming it (e.g. "unallocated") turns a silent gap into a number you can
  # watch shrink.
  default_value   = each.value.default_value
  effective_start = each.value.effective_start

  # Rules are evaluated in order and the first match wins, so declaration order is meaningful.
  dynamic "rule" {
    for_each = each.value.rules
    content {
      value = rule.value.value
      type  = "REGULAR"

      rule {
        dynamic "tags" {
          for_each = rule.value.tag_key == null ? [] : [rule.value]
          content {
            key           = tags.value.tag_key
            values        = tags.value.tag_values
            match_options = tags.value.match_options
          }
        }

        dynamic "dimension" {
          for_each = rule.value.dimension_key == null ? [] : [rule.value]
          content {
            key           = dimension.value.dimension_key
            values        = dimension.value.dimension_values
            match_options = dimension.value.match_options
          }
        }
      }
    }
  }

  tags = var.tags
}
