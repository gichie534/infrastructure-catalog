# aws/cost-allocation

The **allocation layer**: cost allocation tag activation and cost category definitions.

Both answer the same question — *whose spend is this?* — which is why they sit in one module. Budgets
and anomaly detection can only ever tell you that an **account** spent too much. Allocation metadata is
what turns that into a team, an environment, or a product. Without it every cost conversation ends at
the account boundary.

Neither resource is billable.

## Why this belongs in a foundation

Both halves are effectively one-way:

- **Tag activation is not retroactive.** Cost data already recorded carries no tag columns. AWS offers a
  backfill, but it is a separate manual operation.
- **A cost category applies from its effective month onward.** Earlier spend is not categorised.

So the cost of adding this late is not effort — it is a permanent hole in your history, right across
the period you most want to explain. That is the argument for turning it on before anyone needs it.

## Things that bite

- **You cannot activate a tag key AWS has not seen.** Discovery takes up to 24 hours after the key first
  appears on a real resource, then up to another 24 hours for activation to take effect. Listing a
  brand-new key in `active_cost_allocation_tag_keys` makes `apply` fail. Tag first, wait, then activate
  — which is why the input defaults to empty rather than to something helpful-looking.
- **In an organization this is management-account-only.** A member account cannot activate cost
  allocation tags for the org.
- **Tag rules are only as good as your tagging discipline.** A dimension rule (`LINKED_ACCOUNT`,
  `SERVICE`, `RECORD_TYPE`) matches whether or not anybody remembered to tag, so it is the right tool
  for untaggable charges — support, tax, refunds — that would otherwise fall through.
- **Set `default_value`.** Unmatched spend with no default is invisible; unmatched spend labelled
  `unallocated` is a number you can watch shrink.
- **Rule order matters.** Rules are evaluated in declaration order and the first match wins.
- **Cost Explorer is global via its `us-east-1` endpoint** — configure the calling unit's provider for
  `us-east-1`.

## Usage

```hcl
module "cost_allocation" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/cost-allocation?ref=aws-cost-allocation-v0.1.0"

  # Only keys AWS has already discovered on a real resource.
  active_cost_allocation_tag_keys = ["team", "environment"]

  cost_categories = {
    "team" = {
      default_value = "unallocated"

      rules = [
        { value = "platform", tag_key = "team", tag_values = ["platform"] },
        { value = "data", tag_key = "team", tag_values = ["data"] },
        { value = "shared-charges", dimension_key = "RECORD_TYPE", dimension_values = ["Tax", "Support"] },
      ]
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.65.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ce_cost_allocation_tag.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_cost_allocation_tag) | resource |
| [aws_ce_cost_category.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_cost_category) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_active_cost_allocation_tag_keys"></a> [active\_cost\_allocation\_tag\_keys](#input\_active\_cost\_allocation\_tag\_keys) | User-defined tag keys to ACTIVATE as cost allocation tags. Until a key is activated it does not<br/>appear as a dimension in Cost Explorer, in budgets' `TagKeyValue` filter, or as a column in a cost<br/>and usage export — the tag is on the resource but invisible to every cost tool.<br/><br/>Empty (default) activates nothing.<br/><br/>Two things make this input sharper than it looks:<br/><br/>  - **A key must already be known to billing.** AWS only accepts activation for tag keys it has<br/>    seen on a real resource, and discovery takes up to 24 hours after you first apply the tag —<br/>    then up to another 24 hours for activation to take effect. Listing a brand-new key here makes<br/>    `apply` fail. Tag the resources first, wait, then activate.<br/>  - **Activation is not retroactive by default.** Cost data recorded before activation carries no<br/>    tag columns. AWS offers a backfill, but it is a separate, manual operation — which is why<br/>    activating your allocation keys belongs in a foundation rather than in whichever project first<br/>    needs a chargeback report.<br/><br/>In an AWS Organizations setup this is a management-account-only action. | `list(string)` | `[]` | no |
| <a name="input_cost_categories"></a> [cost\_categories](#input\_cost\_categories) | Cost categories to define, keyed by category name (used verbatim).<br/><br/>A cost category is a saved grouping evaluated over your bill: rules map slices of spend to a value,<br/>and that value then behaves like any other dimension in Cost Explorer, budgets, and anomaly<br/>detection. It is how you express "team", "environment" or "product" once, centrally, instead of<br/>re-deriving the same tag logic in every report — and it survives a resource whose tag was never<br/>applied, because a rule can match on account or service too.<br/><br/>Per category:<br/>  - `default_value`   — the value assigned to spend no rule matches. Setting it (e.g. "unallocated")<br/>    turns silent gaps into a number you can watch shrink; leaving it null leaves that spend<br/>    uncategorised.<br/>  - `effective_start` — ISO 8601 UTC timestamp on the first of a month, e.g. `2026-01-01T00:00:00Z`.<br/>    Null (default) means the current month.<br/>  - `rules` — evaluated in order; the first match wins. Each rule sets `value` plus exactly one<br/>    matcher:<br/>      * `tag_key` + `tag_values`             — match on a user-defined tag.<br/>      * `dimension_key` + `dimension_values`  — match on a Cost Explorer dimension<br/>        (`LINKED_ACCOUNT`, `SERVICE`, `REGION`, `RECORD_TYPE`, …).<br/>    `match_options` defaults to `["EQUALS"]`; `STARTS_WITH`, `ENDS_WITH` and `CONTAINS` are also<br/>    available for tag rules.<br/><br/>Empty (default) defines no categories. | <pre>map(object({<br/>    default_value   = optional(string, null)<br/>    effective_start = optional(string, null)<br/>    rules = list(object({<br/>      value            = string<br/>      tag_key          = optional(string, null)<br/>      tag_values       = optional(list(string), [])<br/>      dimension_key    = optional(string, null)<br/>      dimension_values = optional(list(string), [])<br/>      match_options    = optional(list(string), ["EQUALS"])<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every cost category definition. (Cost allocation tag activation is a per-key setting and has nothing to tag.) | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_active_cost_allocation_tag_keys"></a> [active\_cost\_allocation\_tag\_keys](#output\_active\_cost\_allocation\_tag\_keys) | Tag keys this module has activated as cost allocation tags. Activation can take a further 24 hours to show up in cost data. |
| <a name="output_cost_category_arns"></a> [cost\_category\_arns](#output\_cost\_category\_arns) | Map of cost category name to ARN. Use it as a `CostCategories` filter value in a budget or an anomaly monitor. |
| <a name="output_cost_category_effective_starts"></a> [cost\_category\_effective\_starts](#output\_cost\_category\_effective\_starts) | Map of cost category name to the month its rules take effect from. Spend before that month is not categorised. |
| <a name="output_cost_category_names"></a> [cost\_category\_names](#output\_cost\_category\_names) | Names of the managed cost categories. |
<!-- END_TF_DOCS -->
