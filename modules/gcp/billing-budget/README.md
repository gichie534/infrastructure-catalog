# gcp/billing-budget

A single **Cloud Billing budget** and the threshold rules attached to it.

One module instance is one budget — the same shape as `aws/budget`. A budget is a self-contained
decision (*this* amount, over *this* period, on *this* slice of spend, telling *these* people), so it is
also the right unit to plan, version and destroy on its own.

`threshold_rules` is required and must be non-empty, and a budget whose only human recipients are switched
off fails at plan time. Both are guardrails you would otherwise only discover were mute when the alert
never arrived.

## Things worth knowing

- **A budget lives on the billing account, not the project.** The project is only a filter. The caller
  needs `roles/billing.costsManager` (or `roles/billing.admin`) on the billing account; project Owner is
  not enough.
- **With user ADC the provider needs a quota project.** Set `billing_project = <project>` and
  `user_project_override = true` on the `google` provider, and enable `billingbudgets.googleapis.com` on
  that project. Otherwise every call is a 403 about end-user credentials.
- **`projects` takes project numbers, not IDs** (`projects/123456789012`). Validated, because the API's
  own error does not say so.
- **Credits hide spend.** The default `INCLUDE_ALL_CREDITS` tracks your invoice, so on a Free Trial or
  promotional-credit account the budget sits at $0 while real resources run. `EXCLUDE_ALL_CREDITS` tracks
  consumption instead.
- **Pub/Sub is a feed, not an alert.** Billing publishes the current spend to `pubsub_topic` several times
  a day regardless of thresholds. The topic must allow
  `serviceAccount:billing-budget-alert@system.gserviceaccount.com` to publish (`gcp/pubsub-topic` handles
  that).
- **Budgets are not real time.** Billing data lags usage by hours, sometimes a day. A budget is a
  guardrail, not a circuit breaker, and it never stops spend.
- **Periods start at midnight US Pacific**, not UTC.

## Usage

```hcl
module "monthly_budget" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/billing-budget?ref=gcp-billing-budget-v0.1.0"

  billing_account = "012345-6789AB-CDEF01"
  display_name    = "project-monthly"
  amount          = 50
  projects        = ["projects/123456789012"]

  notification_channel_ids = module.finops_channels.ids
  pubsub_topic             = module.finops_topic.id

  threshold_rules = [
    { threshold_percent = 0.5 },
    { threshold_percent = 0.8 },
    { threshold_percent = 1.0 },
    { threshold_percent = 1.0, spend_basis = "FORECASTED_SPEND" },
  ]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.46.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_billing_budget.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_amount"></a> [amount](#input\_amount) | The budget amount per period, in the billing account's currency (e.g. 50 or 12.5). Set this OR `use_last_period_amount`, not both. | `number` | `null` | no |
| <a name="input_billing_account"></a> [billing\_account](#input\_billing\_account) | ID of the Cloud Billing account the budget belongs to, e.g. `012345-6789AB-CDEF01`. The bare ID, not `billingAccounts/<id>`. | `string` | n/a | yes |
| <a name="input_calendar_period"></a> [calendar\_period](#input\_calendar\_period) | Recurring period the amount applies to: MONTH (default), QUARTER, or YEAR. Periods start at 12 AM US Pacific time, not UTC. Ignored when `custom_period` is set. | `string` | `"MONTH"` | no |
| <a name="input_credit_types"></a> [credit\_types](#input\_credit\_types) | Credit types subtracted from gross cost when `credit_types_treatment = INCLUDE_SPECIFIED_CREDITS`, e.g. ["PROMOTION", "FREE\_TIER"]. Must be empty otherwise. | `list(string)` | `[]` | no |
| <a name="input_credit_types_treatment"></a> [credit\_types\_treatment](#input\_credit\_types\_treatment) | How credits affect the spend compared against thresholds.<br/><br/>  - INCLUDE\_ALL\_CREDITS (default) — net spend: what you are invoiced.<br/>  - EXCLUDE\_ALL\_CREDITS — gross spend: what you consumed. Use this on a Free Trial or<br/>    promotional-credit account, where net spend sits at $0 while real resources run.<br/>  - INCLUDE\_SPECIFIED\_CREDITS — subtract only the types listed in `credit_types`. | `string` | `"INCLUDE_ALL_CREDITS"` | no |
| <a name="input_currency_code"></a> [currency\_code](#input\_currency\_code) | ISO 4217 currency code for `amount`. Null (default) uses the billing account's currency. If set it MUST match the billing account's currency, otherwise the API rejects the budget. | `string` | `null` | no |
| <a name="input_custom_period"></a> [custom\_period](#input\_custom\_period) | A one-off, non-recurring period instead of `calendar_period`. Dates are `YYYY-MM-DD`; `end_date` null means "from start\_date onward". | <pre>object({<br/>    start_date = string<br/>    end_date   = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_disable_default_iam_recipients"></a> [disable\_default\_iam\_recipients](#input\_disable\_default\_iam\_recipients) | Stop emailing Billing Account Administrators and Billing Account Users on threshold crossings. Default false: on a personal account those people are you, and a second copy of an alert is cheap. | `bool` | `false` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Display name of the budget. Unlike an AWS budget name it is not unique — Google identifies budgets by a generated ID — so pick something you can find in the console. | `string` | n/a | yes |
| <a name="input_enable_project_level_recipients"></a> [enable\_project\_level\_recipients](#input\_enable\_project\_level\_recipients) | Also email the project's Owners. Only takes effect when `projects` lists exactly one project. | `bool` | `false` | no |
| <a name="input_label_filter"></a> [label\_filter](#input\_label\_filter) | Scope the budget to resources carrying ONE label key/value pair, e.g. `{ team = "platform" }`. The API supports a single pair only. Empty (default) = no label filter. | `map(string)` | `{}` | no |
| <a name="input_notification_channel_ids"></a> [notification\_channel\_ids](#input\_notification\_channel\_ids) | Cloud Monitoring notification channels (`projects/<project>/notificationChannels/<id>`) told when a threshold is crossed. At most 5 (an API limit). The `gcp/notification-channels` module produces these. | `list(string)` | `[]` | no |
| <a name="input_ownership_scope"></a> [ownership\_scope](#input\_ownership\_scope) | Who may see the budget: ALL\_USERS or BILLING\_ACCOUNT (only billing-account-level users). Null (default) leaves Google's default. | `string` | `null` | no |
| <a name="input_projects"></a> [projects](#input\_projects) | Projects whose usage counts toward the budget, as `projects/<PROJECT_NUMBER>`. Empty (default) means<br/>every project on the billing account.<br/><br/>The project NUMBER, not the project ID. The API accepts only numbers here, and passing an ID fails<br/>with an error that does not say so — hence the validation. | `list(string)` | `[]` | no |
| <a name="input_pubsub_topic"></a> [pubsub\_topic](#input\_pubsub\_topic) | Pub/Sub topic (`projects/<project>/topics/<topic>`) that receives budget status messages. Null<br/>(default) = none.<br/><br/>Not an alert channel: Billing publishes the current spend to it several times a day whether or not a<br/>threshold was crossed. It is the hook for automation (chat, enforcement), and the topic must let<br/>`serviceAccount:billing-budget-alert@system.gserviceaccount.com` publish — the `gcp/pubsub-topic`<br/>module can make that grant. | `string` | `null` | no |
| <a name="input_resource_ancestors"></a> [resource\_ancestors](#input\_resource\_ancestors) | Folders or organizations (`folders/<id>`, `organizations/<id>`) whose projects count toward the budget. Empty (default) = no ancestor filter. | `list(string)` | `[]` | no |
| <a name="input_services"></a> [services](#input\_services) | Billing services (`services/<SERVICE_ID>`, e.g. `services/24E6-581D-38E5` for BigQuery) to scope the budget to. Empty (default) = every service. | `list(string)` | `[]` | no |
| <a name="input_threshold_rules"></a> [threshold\_rules](#input\_threshold\_rules) | Thresholds that trigger an alert, as 1.0-based fractions of the amount (0.5 = 50%).<br/><br/>  - `spend_basis` — CURRENT\_SPEND (default) fires on spend already incurred; FORECASTED\_SPEND fires<br/>    on Google's projection for the period and is the only forward-looking signal a budget offers.<br/><br/>Required and non-empty: without a threshold the email recipients are never told anything (Pub/Sub<br/>still receives periodic status updates, but those are a feed, not an alert). | <pre>list(object({<br/>    threshold_percent = number<br/>    spend_basis       = optional(string, "CURRENT_SPEND")<br/>  }))</pre> | n/a | yes |
| <a name="input_use_last_period_amount"></a> [use\_last\_period\_amount](#input\_use\_last\_period\_amount) | Set the budget to 100% of last period's spend instead of a fixed `amount`. Useful as a "did anything change" tripwire; useless on a new billing account with no last period. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_billing_account"></a> [billing\_account](#output\_billing\_account) | Billing account the budget belongs to. |
| <a name="output_budget_id"></a> [budget\_id](#output\_budget\_id) | The generated budget ID alone — the last path segment of `name`. |
| <a name="output_display_name"></a> [display\_name](#output\_display\_name) | Display name of the budget. |
| <a name="output_id"></a> [id](#output\_id) | Terraform ID of the budget (`billingAccounts/<account>/budgets/<budget-id>`). |
| <a name="output_name"></a> [name](#output\_name) | Full resource name of the budget (`billingAccounts/<account>/budgets/<budget-id>`). This is what gcloud and the API take. |
| <a name="output_threshold_count"></a> [threshold\_count](#output\_threshold\_count) | How many threshold rules the budget carries. Always positive — the module rejects an empty list. |
<!-- END_TF_DOCS -->
