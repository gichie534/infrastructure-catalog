# aws/cost-anomaly-detection

**AWS Cost Anomaly Detection**: cost monitors (what is watched) and alert subscriptions (who hears
about it).

Both halves live in one module because neither works alone — a monitor with no subscription detects
anomalies nobody sees, and a subscription must reference a monitor ARN to exist at all. Subscriptions name
monitors by their **key** in `monitors`, or adopt monitors this module does not manage by **ARN**.

## Read this first: you probably should not create a monitor

AWS allows exactly **one** AWS-managed monitor for AWS services
[per account](https://docs.aws.amazon.com/cost-management/latest/userguide/management-limits.html), and it
creates that monitor for you when Cost Anomaly Detection is enabled. On essentially any real account,
creating a `DIMENSIONAL`/`SERVICE` monitor therefore fails:

```
ValidationException: Limit exceeded on dimensional spend monitor creation
```

The fix is not a quota increase. It is to stop creating one and point your subscriptions at the monitor
that already exists, with `monitor_arns`:

```bash
aws ce get-anomaly-monitors --region us-east-1 \
  --query "AnomalyMonitors[?MonitorDimension=='SERVICE'].MonitorArn | [0]" --output text
```

```hcl
module "cost_anomaly_detection" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/cost-anomaly-detection?ref=aws-cost-anomaly-detection-v0.2.0"

  # Nothing to create — AWS already made the monitor.
  monitors = {}

  subscriptions = {
    "immediate" = {
      frequency      = "IMMEDIATE"
      monitor_arns   = [var.aws_services_monitor_arn]
      sns_topic_arns = [module.finops_alerts.arn]

      absolute_impact_threshold   = 10
      percentage_impact_threshold = 50
    }
  }
}
```

That is also the better model conceptually: the managed monitor is account infrastructure AWS owns, while
the subscriptions — who gets told, at what threshold — are yours. `monitor_type` defaults to `CUSTOM` for
the same reason; customer-managed monitors are limited to 500 per account, so they compose freely.

This is the complement to `aws/budget`, not a substitute. A budget compares spend to a number you
chose. Anomaly detection compares spend to a model of *your own history*, so it catches the shape of
problem a limit structurally cannot: a service quietly costing ten times what it did last week while
the monthly total still sits under budget. It is also free, which makes it the cheapest signal in
FinOps.

## Things worth knowing

- **Frequency dictates the channel.** AWS delivers `IMMEDIATE` alerts only via SNS, and `DAILY` /
  `WEEKLY` summaries only by email. The module rejects the wrong pairing at plan time rather than
  letting you create a subscription that can never deliver.
- **One SNS topic and ten email recipients per subscription**, both AWS quotas, both validated here. Fan
  out to more destinations from the topic rather than from the subscription.
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
  Organizations management account**, and only one such managed monitor is allowed there.
- **Cost Explorer is global via its `us-east-1` endpoint** — configure the calling unit's provider for
  `us-east-1`.

## Usage

Two subscriptions on the AWS-managed monitor your account already has — one to react to, one to read.

```hcl
module "cost_anomaly_detection" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/cost-anomaly-detection?ref=aws-cost-anomaly-detection-v0.2.0"

  # AWS owns the "AWS services" monitor; this module owns who hears about it.
  monitors = {}

  subscriptions = {
    # Immediate, machine-readable, for the on-call channel. SNS only — AWS's rule, not ours.
    "immediate" = {
      frequency      = "IMMEDIATE"
      monitor_arns   = [var.aws_services_monitor_arn]
      sns_topic_arns = [module.finops_alerts.arn]

      absolute_impact_threshold   = 10
      percentage_impact_threshold = 50
      threshold_combinator        = "OR"
    }

    # A daily digest for humans, at a higher bar. Email only — likewise.
    "daily-summary" = {
      frequency         = "DAILY"
      monitor_arns      = [var.aws_services_monitor_arn]
      email_subscribers = ["finops@example.com"]

      absolute_impact_threshold = 25
    }
  }
}
```

To create a monitor as well, add it to `monitors` and leave `monitor_arns` off the subscriptions that
should cover everything. Prefer `CUSTOM` unless you are certain the account has no managed monitor yet.

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
| [aws_ce_anomaly_monitor.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_monitor) | resource |
| [aws_ce_anomaly_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_subscription) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_monitors"></a> [monitors](#input\_monitors) | Cost monitors to create, keyed by monitor name (used verbatim). Empty (default) creates none — use<br/>that together with a subscription's `monitor_arns` to attach alerts to a monitor you do not manage.<br/><br/>A monitor defines WHAT is watched; it does not notify anyone on its own — that is a subscription.<br/><br/>  - `monitor_type` — DIMENSIONAL watches every value of one dimension; CUSTOM (default) watches an<br/>    arbitrary Cost Explorer expression.<br/>  - `monitor_dimension` — required for DIMENSIONAL. `SERVICE` is the usual choice.<br/>  - `monitor_specification` — required for CUSTOM: a Cost Explorer `Expression` as a JSON string.<br/><br/>**Read this before creating a DIMENSIONAL monitor.** AWS allows exactly<br/>[one AWS-managed monitor for AWS services per account](https://docs.aws.amazon.com/cost-management/latest/userguide/management-limits.html),<br/>and it creates that monitor for you when Cost Anomaly Detection is enabled. So on essentially any<br/>real account, creating a `DIMENSIONAL`/`SERVICE` monitor fails with<br/>`ValidationException: Limit exceeded on dimensional spend monitor creation`. The fix is not a bigger<br/>quota — it is to stop creating one and point your subscriptions at the monitor that already exists<br/>via `monitor_arns`. The default is CUSTOM for that reason: customer-managed monitors are limited to<br/>500 per account, so they compose freely.<br/><br/>Monitors on linked account, cost allocation tag, or cost category can only be created from an AWS<br/>Organizations management account. | <pre>map(object({<br/>    monitor_type          = optional(string, "CUSTOM")<br/>    monitor_dimension     = optional(string, null)<br/>    monitor_specification = optional(string, null)<br/>  }))</pre> | `{}` | no |
| <a name="input_subscriptions"></a> [subscriptions](#input\_subscriptions) | Alert subscriptions, keyed by subscription name (used verbatim). Every monitor needs at least one<br/>subscription or nothing is ever delivered.<br/><br/>  - `frequency` — IMMEDIATE, DAILY (default), or WEEKLY. AWS ties the channel to the frequency:<br/>    IMMEDIATE is delivered only via SNS, DAILY and WEEKLY only by email. The module rejects the<br/>    wrong pairing rather than letting you create a silent subscription.<br/>  - `monitor_keys` — monitors from this module's `monitors`, by key.<br/>  - `monitor_arns` — monitors this module does NOT manage, by ARN. This is how you attach alerts to<br/>    the AWS-managed "AWS services" monitor that already exists in your account (see `monitors`).<br/>  - When both `monitor_keys` and `monitor_arns` are empty, the subscription covers every monitor in<br/>    `monitors`. Setting either one means "exactly what I listed" — the two are unioned, never<br/>    combined with the implicit all.<br/>  - `email_subscribers` / `sns_topic_arns` — the recipients. AWS permits at most 1 SNS topic and 10<br/>    email recipients per subscription.<br/>  - `absolute_impact_threshold` — alert when the anomaly's dollar impact is at least this much.<br/>  - `percentage_impact_threshold` — alert when actual spend exceeds expected by at least this<br/>    percentage.<br/>  - `threshold_combinator` — OR (default) or AND, when both thresholds are set.<br/><br/>At least one threshold is required: AWS needs a threshold expression, and there is no sensible<br/>default dollar figure a module could pick for you. A percentage alone fires on a $2 anomaly that<br/>tripled; an absolute alone misses a steady 30% overspend. OR-ing a small absolute floor with a<br/>percentage is the usual starting point. | <pre>map(object({<br/>    frequency                   = optional(string, "DAILY")<br/>    monitor_keys                = optional(list(string), [])<br/>    monitor_arns                = optional(list(string), [])<br/>    email_subscribers           = optional(list(string), [])<br/>    sns_topic_arns              = optional(list(string), [])<br/>    absolute_impact_threshold   = optional(number, null)<br/>    percentage_impact_threshold = optional(number, null)<br/>    threshold_combinator        = optional(string, "OR")<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every monitor and subscription. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_monitor_arns"></a> [monitor\_arns](#output\_monitor\_arns) | Map of monitor name to ARN. |
| <a name="output_monitor_names"></a> [monitor\_names](#output\_monitor\_names) | Names of the managed cost monitors. |
| <a name="output_subscription_arns"></a> [subscription\_arns](#output\_subscription\_arns) | Map of subscription name to ARN. |
| <a name="output_subscription_monitor_arns"></a> [subscription\_monitor\_arns](#output\_subscription\_monitor\_arns) | Map of subscription name to every monitor ARN it covers — both the monitors this module manages and any adopted via `monitor_arns`. |
| <a name="output_subscription_monitor_keys"></a> [subscription\_monitor\_keys](#output\_subscription\_monitor\_keys) | Map of subscription name to the module-managed monitor keys it covers, after the 'empty means all monitors' default is resolved. Use it to confirm a subscription actually watches what you think it does. |
| <a name="output_subscription_names"></a> [subscription\_names](#output\_subscription\_names) | Names of the managed alert subscriptions. |
<!-- END_TF_DOCS -->
