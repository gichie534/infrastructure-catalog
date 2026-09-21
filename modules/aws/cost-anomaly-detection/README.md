# aws/cost-anomaly-detection

**AWS Cost Anomaly Detection**: cost monitors (what is watched) and alert subscriptions (who hears
about it).

Both halves live in one module because neither works alone — a monitor with no subscription detects
anomalies nobody sees, and a subscription must reference a monitor ARN to exist at all. Subscriptions
name monitors by their **key** in `monitors`, so a consumer never handles ARNs.

This is the complement to `aws/budget`, not a substitute. A budget compares spend to a number you
chose. Anomaly detection compares spend to a model of *your own history*, so it catches the shape of
problem a limit structurally cannot: a service quietly costing ten times what it did last week while
the monthly total still sits under budget. It is also free, which makes it the cheapest signal in
FinOps.

## Things worth knowing

- **Frequency dictates the channel.** AWS delivers `IMMEDIATE` alerts only via SNS, and `DAILY` /
  `WEEKLY` summaries only by email. The module rejects the wrong pairing at plan time rather than
  letting you create a subscription that can never deliver.
- **SNS delivery needs a topic policy** allowing `costalerts.amazonaws.com` to `SNS:Publish`, or the
  publish is denied silently. The `aws/sns-topic` module handles that grant. Note that Cost Anomaly
  Detection does not document sending `aws:SourceAccount`, so do not condition the grant on it.
- **A threshold is required and has no sensible default.** Pick deliberately: a percentage alone fires
  on a $2 service that tripled; an absolute alone sleeps through a steady 30% overspend on a large
  bill. OR-ing a small absolute floor with a percentage is the usual starting point.
- **Every anomaly is still recorded.** The threshold only controls *notification*. Anomalies below it
  remain visible in the console, so a high threshold costs you alerts, not data.
- **The model needs history.** Detection is relative to a learned baseline, so a brand-new account sees
  little until it has a pattern to deviate from.
- **Monitors on linked account, cost allocation tag, or cost category can only be created from an
  Organizations management account.** A standalone account gets the `SERVICE` dimension, which is the
  right default anyway: it tracks every service you use, including ones you did not know were on.
- **Cost Explorer is global via its `us-east-1` endpoint** — configure the calling unit's provider for
  `us-east-1`.

## Usage

```hcl
module "cost_anomaly_detection" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/cost-anomaly-detection?ref=aws-cost-anomaly-detection-v0.1.0"

  monitors = {
    "all-services" = {
      monitor_type      = "DIMENSIONAL"
      monitor_dimension = "SERVICE"
    }
  }

  subscriptions = {
    # Immediate, machine-readable, for the on-call channel.
    "immediate" = {
      frequency      = "IMMEDIATE"
      sns_topic_arns = [module.finops_alerts.arn]

      absolute_impact_threshold   = 10
      percentage_impact_threshold = 50
      threshold_combinator        = "OR"
    }

    # A daily digest for humans, at a higher bar.
    "daily-summary" = {
      frequency         = "DAILY"
      email_subscribers = ["finops@example.com"]

      absolute_impact_threshold = 25
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name                                                                      | Version |
| ------------------------------------------------------------------------- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3  |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 5.0  |

## Providers

| Name                                              | Version |
| ------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.65.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                                    | Type     |
| --------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_ce_anomaly_monitor.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_monitor)           | resource |
| [aws_ce_anomaly_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_subscription) | resource |

## Inputs

| Name                                                                      | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Type                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Default | Required |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | :------: |
| <a name="input_monitors"></a> [monitors](#input\_monitors)                | Cost monitors to create, keyed by monitor name (used verbatim).<br/><br/>A monitor defines WHAT is watched; it does not notify anyone on its own — that is a subscription.<br/><br/>  - `monitor_type` — DIMENSIONAL (default) watches every value of one dimension; CUSTOM watches an<br/>    arbitrary Cost Explorer expression.<br/>  - `monitor_dimension` — required for DIMENSIONAL. `SERVICE` (default) is the one the API<br/>    documents for a standalone account, and it is the right default: it tracks every service you<br/>    use, including ones you did not know you had turned on.<br/>  - `monitor_specification` — required for CUSTOM: a Cost Explorer `Expression` as a JSON string.<br/><br/>Note that monitors on linked account, cost allocation tag, or cost category can only be created<br/>from an AWS Organizations management account.                                                                                                                                                                                                                                                                                                                                                                                                                                                         | <pre>map(object({<br/>    monitor_type          = optional(string, "DIMENSIONAL")<br/>    monitor_dimension     = optional(string, "SERVICE")<br/>    monitor_specification = optional(string, null)<br/>  }))</pre>                                                                                                                                                                                                                                                                        | n/a     |   yes    |
| <a name="input_subscriptions"></a> [subscriptions](#input\_subscriptions) | Alert subscriptions, keyed by subscription name (used verbatim). Every monitor needs at least one<br/>subscription or nothing is ever delivered.<br/><br/>  - `frequency` — IMMEDIATE, DAILY (default), or WEEKLY. AWS ties the channel to the frequency:<br/>    IMMEDIATE is delivered only via SNS, DAILY and WEEKLY only by email. The module rejects the<br/>    wrong pairing rather than letting you create a silent subscription.<br/>  - `monitor_keys` — which monitors this subscribes to, by their key in `monitors`. Empty (default)<br/>    subscribes to all of them.<br/>  - `email_subscribers` / `sns_topic_arns` — the recipients.<br/>  - `absolute_impact_threshold` — alert when the anomaly's dollar impact is at least this much.<br/>  - `percentage_impact_threshold` — alert when actual spend exceeds expected by at least this<br/>    percentage.<br/>  - `threshold_combinator` — OR (default) or AND, when both thresholds are set.<br/><br/>At least one threshold is required: AWS needs a threshold expression, and there is no sensible<br/>default dollar figure a module could pick for you. A percentage alone fires on a $2 anomaly that<br/>tripled; an absolute alone misses a steady 30% overspend. OR-ing a small absolute floor with a<br/>percentage is the usual starting point. | <pre>map(object({<br/>    frequency                   = optional(string, "DAILY")<br/>    monitor_keys                = optional(list(string), [])<br/>    email_subscribers           = optional(list(string), [])<br/>    sns_topic_arns              = optional(list(string), [])<br/>    absolute_impact_threshold   = optional(number, null)<br/>    percentage_impact_threshold = optional(number, null)<br/>    threshold_combinator        = optional(string, "OR")<br/>  }))</pre> | n/a     |   yes    |
| <a name="input_tags"></a> [tags](#input\_tags)                            | Tags applied to every monitor and subscription.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | `map(string)`                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `{}`    |    no    |

## Outputs

| Name                                                                                                                | Description                                                                                                                                                                                 |
| ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="output_monitor_arns"></a> [monitor\_arns](#output\_monitor\_arns)                                          | Map of monitor name to ARN.                                                                                                                                                                 |
| <a name="output_monitor_names"></a> [monitor\_names](#output\_monitor\_names)                                       | Names of the managed cost monitors.                                                                                                                                                         |
| <a name="output_subscription_arns"></a> [subscription\_arns](#output\_subscription\_arns)                           | Map of subscription name to ARN.                                                                                                                                                            |
| <a name="output_subscription_monitor_keys"></a> [subscription\_monitor\_keys](#output\_subscription\_monitor\_keys) | Map of subscription name to the monitor keys it covers, after the 'empty means all monitors' default is resolved. Use it to confirm a subscription actually watches what you think it does. |
| <a name="output_subscription_names"></a> [subscription\_names](#output\_subscription\_names)                        | Names of the managed alert subscriptions.                                                                                                                                                   |
<!-- END_TF_DOCS -->
