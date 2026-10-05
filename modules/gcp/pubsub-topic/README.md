# gcp/pubsub-topic

A **Pub/Sub topic** that other principals — typically Google-owned service accounts — may publish to,
plus optional pull subscriptions.

The GCP counterpart of `aws/sns-topic`, for the same reason: the topic is trivial, the publish grant is
what goes wrong. Cloud Billing publishes budget messages as
`billing-budget-alert@system.gserviceaccount.com`, and without `roles/pubsub.publisher` for that account
nothing is delivered and nothing tells you.

## Things worth knowing

- **Grants are additive** (`google_pubsub_topic_iam_member`). The module never overwrites the topic
  policy, so it cannot remove a grant Google adds itself when you connect the topic in the console.
- **A topic with no subscription drops messages.** Hence `pull_subscriptions` lives here.
- **Subscriptions never expire by default.** Google's own default deletes a subscription after 31 days of
  inactivity — which is exactly what a quiet alert feed looks like.
- **Domain-restricted sharing blocks Google service accounts.** If the organization enforces
  `iam.allowedPolicyMemberDomains`, the project needs an exemption before the publisher grant applies.
- **Pull only, for now.** Push subscriptions add an endpoint and an auth story; they get added when a
  second consumer needs them.

## Usage

```hcl
module "finops_topic" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/pubsub-topic?ref=gcp-pubsub-topic-v0.1.0"

  project_id = "my-project"
  name       = "finops-budget-updates"

  publisher_members = ["serviceAccount:billing-budget-alert@system.gserviceaccount.com"]

  pull_subscriptions = {
    "finops-budget-updates-pull" = {}
  }
}

# module.finops_topic.id -> a budget's pubsub_topic
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
| [google_pubsub_subscription.pull](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_pubsub_topic.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_member.publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | CMEK key for the topic. Null (default) = Google-managed encryption. A CMEK key also needs the Pub/Sub service agent granted on it, which is the consumer's job. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels applied to the topic and its subscriptions. | `map(string)` | `{}` | no |
| <a name="input_message_retention_duration"></a> [message\_retention\_duration](#input\_message\_retention\_duration) | How long the TOPIC retains messages (so a subscription created later can seek back). Null (default) = no topic-level retention, which is free. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Topic name (the short ID, not the full resource name). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project to create the topic (and subscriptions) in. | `string` | n/a | yes |
| <a name="input_publisher_members"></a> [publisher\_members](#input\_publisher\_members) | IAM members granted roles/pubsub.publisher on the topic, e.g.<br/>`serviceAccount:billing-budget-alert@system.gserviceaccount.com` for Cloud Billing budget messages.<br/><br/>Additive grants: anything already on the topic is left alone. On an organization that enforces<br/>`iam.allowedPolicyMemberDomains`, a Google-owned service account is outside your domain and the grant<br/>is rejected — the project needs an exemption. | `list(string)` | `[]` | no |
| <a name="input_pull_subscriptions"></a> [pull\_subscriptions](#input\_pull\_subscriptions) | Pull subscriptions to create, keyed by subscription name. Without at least one subscription the topic<br/>discards every message published to it.<br/><br/>  - `ack_deadline_seconds` (default 60)<br/>  - `message_retention_duration` (default "604800s", 7 days — the maximum)<br/>  - `retain_acked_messages` (default false)<br/>  - `expiration_ttl` (default "" = never expire). Google's own default deletes a subscription after<br/>    31 days without activity, which is what a quiet alert feed looks like. | <pre>map(object({<br/>    ack_deadline_seconds       = optional(number, 60)<br/>    message_retention_duration = optional(string, "604800s")<br/>    retain_acked_messages      = optional(bool, false)<br/>    expiration_ttl             = optional(string, "")<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | Full resource name of the topic (`projects/<project>/topics/<name>`). This is what a budget's `pubsub_topic` takes. |
| <a name="output_name"></a> [name](#output\_name) | Short name of the topic. |
| <a name="output_publisher_members"></a> [publisher\_members](#output\_publisher\_members) | Members granted roles/pubsub.publisher by this module. |
| <a name="output_subscription_ids"></a> [subscription\_ids](#output\_subscription\_ids) | Map of subscription name to full resource name (`projects/<project>/subscriptions/<name>`). |
<!-- END_TF_DOCS -->
