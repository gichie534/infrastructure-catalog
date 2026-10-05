# gcp/notification-channels

Cloud Monitoring **email notification channels**, one per address.

The GCP counterpart of the email half of `aws/sns-topic`. Budgets, alerting policies and uptime checks
all reach humans through these channels, so the module is not cost-specific.

## Things worth knowing

- **No confirmation step.** Unlike an SNS email subscription, an email channel is live as soon as it
  exists. The other side of that: nothing proves the address is right, so a typo is a silent channel.
  Send a test notification from the console (Monitoring → Alerting → Edit notification channels) once.
- **A budget takes at most 5 channels.** Fan out from a group address rather than adding people one by one.
- **Deletion is not forced.** If an alerting policy still references a channel, `destroy` fails rather
  than silently orphaning that policy.
- **Email only, for now.** Slack/PagerDuty/webhook channels carry secrets in `sensitive_labels`; they get
  added when a second consumer needs them.

## Usage

```hcl
module "finops_channels" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/notification-channels?ref=gcp-notification-channels-v0.1.0"

  project_id          = "my-project"
  email_addresses     = ["finops@example.com"]
  display_name_prefix = "FinOps"
}

# module.finops_channels.ids -> a budget's notification_channel_ids
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
| [google_monitoring_notification_channel.email](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_description"></a> [description](#input\_description) | Description applied to every channel. | `string` | `null` | no |
| <a name="input_display_name_prefix"></a> [display\_name\_prefix](#input\_display\_name\_prefix) | Prefix for each channel's display name; the address is appended, e.g. `FinOps <you@example.com>`. | `string` | `"Email"` | no |
| <a name="input_email_addresses"></a> [email\_addresses](#input\_email\_addresses) | Email addresses to create a channel for, one channel each. | `list(string)` | n/a | yes |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether the channels deliver. Disabling keeps them (and every reference to them) but silences delivery. | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | User labels applied to every channel. | `map(string)` | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that owns the notification channels. A budget can use channels from any project, but they are usually kept with the rest of the FinOps tooling. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ids"></a> [ids](#output\_ids) | Channel resource names (`projects/<project>/notificationChannels/<id>`), in the order of `email_addresses`. This is what a budget's `notification_channel_ids` takes. |
| <a name="output_ids_by_email"></a> [ids\_by\_email](#output\_ids\_by\_email) | Map of email address to channel resource name. |
| <a name="output_verification_statuses"></a> [verification\_statuses](#output\_verification\_statuses) | Map of email address to verification status. Email channels do not require verification, so this is normally unset; it is exposed so a consumer does not have to assume. |
<!-- END_TF_DOCS -->
