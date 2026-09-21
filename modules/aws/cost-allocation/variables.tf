variable "active_cost_allocation_tag_keys" {
  description = <<-EOT
    User-defined tag keys to ACTIVATE as cost allocation tags. Until a key is activated it does not
    appear as a dimension in Cost Explorer, in budgets' `TagKeyValue` filter, or as a column in a cost
    and usage export — the tag is on the resource but invisible to every cost tool.

    Empty (default) activates nothing.

    Two things make this input sharper than it looks:

      - **A key must already be known to billing.** AWS only accepts activation for tag keys it has
        seen on a real resource, and discovery takes up to 24 hours after you first apply the tag —
        then up to another 24 hours for activation to take effect. Listing a brand-new key here makes
        `apply` fail. Tag the resources first, wait, then activate.
      - **Activation is not retroactive by default.** Cost data recorded before activation carries no
        tag columns. AWS offers a backfill, but it is a separate, manual operation — which is why
        activating your allocation keys belongs in a foundation rather than in whichever project first
        needs a chargeback report.

    In an AWS Organizations setup this is a management-account-only action.
  EOT
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = length(distinct(var.active_cost_allocation_tag_keys)) == length(var.active_cost_allocation_tag_keys)
    error_message = "active_cost_allocation_tag_keys must not contain duplicates."
  }

  validation {
    condition     = alltrue([for k in var.active_cost_allocation_tag_keys : length(trimspace(k)) > 0])
    error_message = "tag keys must be non-empty."
  }
}

variable "cost_categories" {
  description = <<-EOT
    Cost categories to define, keyed by category name (used verbatim).

    A cost category is a saved grouping evaluated over your bill: rules map slices of spend to a value,
    and that value then behaves like any other dimension in Cost Explorer, budgets, and anomaly
    detection. It is how you express "team", "environment" or "product" once, centrally, instead of
    re-deriving the same tag logic in every report — and it survives a resource whose tag was never
    applied, because a rule can match on account or service too.

    Per category:
      - `default_value`   — the value assigned to spend no rule matches. Setting it (e.g. "unallocated")
        turns silent gaps into a number you can watch shrink; leaving it null leaves that spend
        uncategorised.
      - `effective_start` — ISO 8601 UTC timestamp on the first of a month, e.g. `2026-01-01T00:00:00Z`.
        Null (default) means the current month.
      - `rules` — evaluated in order; the first match wins. Each rule sets `value` plus exactly one
        matcher:
          * `tag_key` + `tag_values`             — match on a user-defined tag.
          * `dimension_key` + `dimension_values`  — match on a Cost Explorer dimension
            (`LINKED_ACCOUNT`, `SERVICE`, `REGION`, `RECORD_TYPE`, …).
        `match_options` defaults to `["EQUALS"]`; `STARTS_WITH`, `ENDS_WITH` and `CONTAINS` are also
        available for tag rules.

    Empty (default) defines no categories.
  EOT

  type = map(object({
    default_value   = optional(string, null)
    effective_start = optional(string, null)
    rules = list(object({
      value            = string
      tag_key          = optional(string, null)
      tag_values       = optional(list(string), [])
      dimension_key    = optional(string, null)
      dimension_values = optional(list(string), [])
      match_options    = optional(list(string), ["EQUALS"])
    }))
  }))

  nullable = false
  default  = {}

  validation {
    condition     = alltrue([for c in var.cost_categories : length(c.rules) > 0])
    error_message = "each cost category needs at least one rule."
  }

  validation {
    condition = alltrue([
      for c in var.cost_categories : alltrue([
        for r in c.rules :
        (r.tag_key != null && r.dimension_key == null) || (r.tag_key == null && r.dimension_key != null)
      ])
    ])
    error_message = "each cost category rule must set exactly one of tag_key or dimension_key."
  }

  validation {
    condition = alltrue([
      for c in var.cost_categories : alltrue([
        for r in c.rules :
        r.tag_key == null ? true : length(r.tag_values) > 0
      ])
    ])
    error_message = "a tag_key rule needs at least one entry in tag_values."
  }

  validation {
    condition = alltrue([
      for c in var.cost_categories : alltrue([
        for r in c.rules :
        r.dimension_key == null ? true : length(r.dimension_values) > 0
      ])
    ])
    error_message = "a dimension_key rule needs at least one entry in dimension_values."
  }

  validation {
    condition = alltrue([
      for c in var.cost_categories :
      c.effective_start == null || can(regex("^[0-9]{4}-[0-9]{2}-01T00:00:00Z$", c.effective_start))
    ])
    error_message = "effective_start must be an ISO 8601 UTC timestamp on the first of a month, e.g. 2026-01-01T00:00:00Z."
  }
}

variable "tags" {
  description = "Tags applied to every cost category definition. (Cost allocation tag activation is a per-key setting and has nothing to tag.)"
  type        = map(string)
  nullable    = false
  default     = {}
}
