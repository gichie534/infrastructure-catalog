# aws/budget

A single **AWS Budget** and the notification thresholds attached to it.

One module instance is one budget. A budget is a self-contained decision — *this* limit, over *this*
period, on *this* slice of spend, telling *these* people — which also makes it the right unit to plan,
version and destroy on its own. A consumer that wants several budgets instantiates the module several
times, and each one then keeps its own diff, state and blast radius.

`notifications` is required and must be non-empty. A budget without one is invisible, and AWS will create
it happily. Subscribers fall back to the budget-level `subscriber_email_addresses` /
`subscriber_sns_topic_arns`, so the channel is declared once rather than on every threshold; a threshold
that still ends up with **no** subscriber fails at plan time, because that is a guardrail you would only
discover was mute when the alert never arrived.

## What this module does not do

**Budget actions** (`aws_budgets_budget_action`). An action needs an IAM role plus either an IAM policy
target or an SCP, and the SCP variant only exists with AWS Organizations. Enforcement is a different
concern from measurement, and folding it in here would hide a resource with real blast radius behind an
innocuous-looking input.

## Things worth knowing

- **Budgets are not real time.** AWS refreshes billing data
  [at least once a day](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-best-practices.html),
  so a budget is a guardrail, not a circuit breaker. Pair it with Cost Anomaly Detection for the class of
  problem a daily aggregate cannot catch: a 10x jump on day three that still lands under the limit.
- **Two budgets per account are free.** Beyond that AWS meters them per budget per day. Instantiating this
  module a dozen times is cheap but not free.
- **`FORECASTED` needs history.** AWS cannot project a period it has no baseline for, so a forecast
  threshold on a brand-new account stays quiet until there is enough data to model.
- **SNS delivery needs a topic policy.** The topic must allow `budgets.amazonaws.com` to `SNS:Publish` or
  the publish is denied silently. The `aws/sns-topic` module handles that grant.
- **`cost_types` changes what you are measuring.** The AWS defaults track your net invoice, credits
  included — so a credit-funded account can sit at $0 while consuming real resources. Set
  `include_credit = false` when you want the budget to track consumption instead.

## Usage

```hcl
# The limit you chose.
module "monthly_budget" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/budget?ref=aws-budget-v0.1.0"

  name         = "account-monthly"
  limit_amount = "50"
  time_unit    = "MONTHLY"

  subscriber_sns_topic_arns = [module.finops_alerts.arn]

  notifications = [
    { threshold = 50, notification_type = "ACTUAL" },
    { threshold = 80, notification_type = "ACTUAL" },
    { threshold = 100, notification_type = "ACTUAL" },
    { threshold = 100, notification_type = "FORECASTED" },
  ]
}

# A second, unrelated decision: one team's slice of the same account.
module "platform_team_budget" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/budget?ref=aws-budget-v0.1.0"

  name         = "platform-team-monthly"
  limit_amount = "20"
  cost_filters = { TagKeyValue = ["user:team$platform"] }

  subscriber_sns_topic_arns = [module.finops_alerts.arn]

  notifications = [
    { threshold = 100, notification_type = "ACTUAL" },
  ]
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
| [aws_budgets_budget.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_budget_type"></a> [budget\_type](#input\_budget\_type) | What the budget measures: COST (default), USAGE, or an RI / Savings Plans utilisation or coverage type. | `string` | `"COST"` | no |
| <a name="input_cost_filters"></a> [cost\_filters](#input\_cost\_filters) | Map of AWS Budgets filter dimension to values, scoping the budget to a slice of spend. Empty<br/>(default) covers the whole account.<br/><br/>Examples: `{ Service = ["Amazon Elastic Compute Cloud - Compute"] }`,<br/>`{ TagKeyValue = ["user:team$platform"] }`, `{ LinkedAccount = ["123456789012"] }`,<br/>`{ CostCategories = ["team$platform"] }`. | `map(list(string))` | `{}` | no |
| <a name="input_cost_types"></a> [cost\_types](#input\_cost\_types) | Which charge classes count toward the limit. Null (default) uses the AWS defaults.<br/><br/>Worth setting deliberately: the AWS defaults track your net invoice with credits included, so a<br/>credit-funded account can sit at $0 while consuming real resources. `include_credit = false` makes the<br/>budget track consumption instead. `use_amortized = true` spreads upfront RI / Savings Plans payments<br/>across the term rather than charging them to the month they were bought. | <pre>object({<br/>    include_credit             = optional(bool, null)<br/>    include_discount           = optional(bool, null)<br/>    include_other_subscription = optional(bool, null)<br/>    include_recurring          = optional(bool, null)<br/>    include_refund             = optional(bool, null)<br/>    include_subscription       = optional(bool, null)<br/>    include_support            = optional(bool, null)<br/>    include_tax                = optional(bool, null)<br/>    include_upfront            = optional(bool, null)<br/>    use_amortized              = optional(bool, null)<br/>    use_blended                = optional(bool, null)<br/>  })</pre> | `null` | no |
| <a name="input_limit_amount"></a> [limit\_amount](#input\_limit\_amount) | The budget limit, as a string (e.g. "50"). AWS takes this as a decimal string, not a number. | `string` | n/a | yes |
| <a name="input_limit_unit"></a> [limit\_unit](#input\_limit\_unit) | Unit for `limit_amount`: a currency code such as USD (default) for a COST budget, or the usage unit (e.g. GB) for a USAGE budget. | `string` | `"USD"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the budget. Unique per account, and used verbatim. | `string` | n/a | yes |
| <a name="input_notifications"></a> [notifications](#input\_notifications) | The thresholds to alert on. A budget with no notifications is invisible, and AWS will happily create<br/>one, so this input is required and must be non-empty.<br/><br/>  - `threshold` + `threshold_type` — PERCENTAGE (default) of the limit, or ABSOLUTE\_VALUE in the<br/>    budget's unit.<br/>  - `notification_type` — ACTUAL (default) fires on spend already incurred; FORECASTED fires on AWS's<br/>    projection for the period, and is the only forward-looking signal budgets offer.<br/>  - `comparison_operator` — GREATER\_THAN (default), LESS\_THAN, EQUAL\_TO.<br/>  - subscribers — fall back to the module-level `subscriber_email_addresses` /<br/>    `subscriber_sns_topic_arns` when left empty, so the channel is declared once per budget rather<br/>    than once per threshold. | <pre>list(object({<br/>    threshold                  = number<br/>    threshold_type             = optional(string, "PERCENTAGE")<br/>    notification_type          = optional(string, "ACTUAL")<br/>    comparison_operator        = optional(string, "GREATER_THAN")<br/>    subscriber_email_addresses = optional(list(string), [])<br/>    subscriber_sns_topic_arns  = optional(list(string), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_subscriber_email_addresses"></a> [subscriber\_email\_addresses](#input\_subscriber\_email\_addresses) | Email addresses notified for any threshold that does not list its own subscribers. Lets the channel be declared once per budget. | `list(string)` | `[]` | no |
| <a name="input_subscriber_sns_topic_arns"></a> [subscriber\_sns\_topic\_arns](#input\_subscriber\_sns\_topic\_arns) | SNS topic ARNs notified for any threshold that does not list its own subscribers.<br/><br/>The topic's resource policy must allow `budgets.amazonaws.com` to `SNS:Publish`, otherwise the publish<br/>is denied silently and nothing is delivered. The `aws/sns-topic` module handles that grant. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the budget. | `map(string)` | `{}` | no |
| <a name="input_time_period_end"></a> [time\_period\_end](#input\_time\_period\_end) | When the budget stops tracking, formatted `YYYY-MM-DD_HH:MM`. Null (default) means it never expires. | `string` | `null` | no |
| <a name="input_time_period_start"></a> [time\_period\_start](#input\_time\_period\_start) | When the budget starts tracking, formatted `YYYY-MM-DD_HH:MM`. Null (default) lets AWS use the start of the chosen period, which is what a recurring budget wants. | `string` | `null` | no |
| <a name="input_time_unit"></a> [time\_unit](#input\_time\_unit) | The period the limit applies to: DAILY, MONTHLY (default), QUARTERLY, or ANNUALLY. | `string` | `"MONTHLY"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the budget. This is what a budget action or a cross-account policy statement refers to. |
| <a name="output_id"></a> [id](#output\_id) | ID of the budget (`<account-id>:<budget-name>`). |
| <a name="output_name"></a> [name](#output\_name) | Name of the budget. |
| <a name="output_notification_count"></a> [notification\_count](#output\_notification\_count) | How many notification thresholds the budget carries. A zero here would be a budget nobody hears about — the module rejects that, so this is a positive number. |
<!-- END_TF_DOCS -->
