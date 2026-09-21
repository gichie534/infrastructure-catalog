# aws/sns-topic

An SNS topic that **AWS services can publish to**, plus optional email subscribers.

Creating a topic is trivial. The part that reliably goes wrong — and the reason this is a module — is
the resource policy. When AWS Budgets or Cost Anomaly Detection sends a notification it publishes as
the **service principal**, not as your IAM identity, so it needs an explicit statement in the topic's
resource policy. An IAM policy on your side cannot substitute for it, and when the grant is missing
the publish is denied *silently*: no error surfaces anywhere on your side, the alert simply never
arrives.

The module owns the topic, its policy, and email subscriptions. It does not create KMS keys or chat
integrations — those are the consumer's composition concern.

## Things that bite

- **Attaching any topic policy replaces the AWS default.** `include_default_owner_statement` (default
  `true`) re-adds the equivalent of what AWS attaches to a new topic, so the owning account keeps
  resource-policy access. Turning it off while granting a service principal leaves a topic whose
  policy grants the service but not you.
- **Email subscriptions require human confirmation.** Each address gets a confirmation email and must
  click through. Terraform applies the subscription successfully and it sits at
  `PendingConfirmation`, so "applied" does not mean "will deliver".
- **`alias/aws/sns` breaks service publishers.** If you set `kms_master_key_id`, use a
  customer-managed key whose policy grants the publishing service `kms:GenerateDataKey*` and
  `kms:Decrypt`. The AWS-managed key's policy cannot be edited to do that, and messages are dropped
  without an error.
- **`restrict_service_publish_to_source_account` is off by default.** It is the safer policy, but a
  service that does not populate `aws:SourceAccount` gets silently denied. AWS Budgets documents
  support for the condition; Cost Anomaly Detection does not. Turn it on only after confirming alerts
  still arrive.

## Usage

```hcl
module "finops_alerts" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/sns-topic?ref=aws-sns-topic-v0.1.0"

  name         = "finops-alerts"
  display_name = "FinOps alerts"

  # Both billing services publish as themselves and need this grant.
  allowed_service_principals = [
    "budgets.amazonaws.com",
    "costalerts.amazonaws.com",
  ]

  email_subscribers = ["finops@example.com"]

  tags = {
    Environment = "lab"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
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
| [aws_sns_topic.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.generated](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_service_principals"></a> [allowed\_service\_principals](#input\_allowed\_service\_principals) | AWS service principals allowed to publish to this topic, e.g.<br/>`["budgets.amazonaws.com", "costalerts.amazonaws.com"]`. Empty (default) adds no service<br/>statements.<br/><br/>A service publishing to SNS is doing so as the service, not as your IAM identity, so it needs an<br/>explicit resource-policy grant — an IAM policy on your side cannot substitute for it. This is the<br/>single most common reason a budget or anomaly alert never arrives. | `list(string)` | `[]` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Optional friendly name for the topic. It is what recipients see as the sender label on email notifications, so a readable value ('FinOps alerts') is worth setting. Default null leaves it unset. | `string` | `null` | no |
| <a name="input_email_subscribers"></a> [email\_subscribers](#input\_email\_subscribers) | Email addresses subscribed to the topic. Empty (default) creates no subscriptions.<br/><br/>Each address receives an AWS confirmation email and must click through before any notification is<br/>delivered. Terraform cannot do that for you: the subscription applies successfully and sits at<br/>`PendingConfirmation`, so a silent alert channel is the expected state until someone confirms. | `list(string)` | `[]` | no |
| <a name="input_include_default_owner_statement"></a> [include\_default\_owner\_statement](#input\_include\_default\_owner\_statement) | When true (default), the generated topic policy includes the equivalent of the policy AWS attaches<br/>to a new topic: the owning account may manage and publish to the topic, conditioned on<br/>`AWS:SourceOwner`.<br/><br/>Attaching any topic policy REPLACES the AWS default, so leaving this off while setting<br/>`allowed_service_principals` produces a topic whose resource policy grants the service but not<br/>you. Only set false if you intend that. | `bool` | `true` | no |
| <a name="input_kms_master_key_id"></a> [kms\_master\_key\_id](#input\_kms\_master\_key\_id) | Optional KMS key id/alias/ARN for server-side encryption of messages at rest. Default null = no<br/>encryption.<br/><br/>Important when AWS services publish to this topic (see `allowed_service_principals`): the<br/>AWS-managed key `alias/aws/sns` will NOT work, because its key policy cannot be edited to grant<br/>a service principal `kms:GenerateDataKey*`/`kms:Decrypt`. Messages are silently dropped. Use a<br/>customer-managed key whose policy grants those actions to the same principals, or leave<br/>encryption off. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the SNS topic. Must be unique per account and region. | `string` | n/a | yes |
| <a name="input_restrict_service_publish_to_source_account"></a> [restrict\_service\_publish\_to\_source\_account](#input\_restrict\_service\_publish\_to\_source\_account) | When true, service-principal publish statements are conditioned on<br/>`aws:SourceAccount` matching this account, so another account's copy of the same service cannot<br/>publish here. Default false.<br/><br/>Off by default deliberately: a service that does not populate `aws:SourceAccount` on its publish<br/>call is silently denied, and not every billing service documents that it does. Turn it on only<br/>after confirming alerts still arrive. AWS Budgets documents support for it; Cost Anomaly<br/>Detection does not. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the SNS topic. | `map(string)` | `{}` | no |
| <a name="input_topic_policy"></a> [topic\_policy](#input\_topic\_policy) | Optional raw topic policy as a JSON string. When set it is attached verbatim and every generated<br/>statement (`allowed_service_principals`, `include_default_owner_statement`) is ignored — the<br/>escape hatch for a policy this module's inputs cannot express. Default null uses the generated<br/>policy. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the SNS topic. This is what you hand to a publisher (budget notification, anomaly subscription, CloudWatch alarm action). |
| <a name="output_email_subscription_arns"></a> [email\_subscription\_arns](#output\_email\_subscription\_arns) | Map of subscribed email address to subscription ARN. A subscription is inert until the recipient confirms it, so presence here does not prove deliverability. |
| <a name="output_id"></a> [id](#output\_id) | ID of the SNS topic (equal to its ARN for SNS). |
| <a name="output_name"></a> [name](#output\_name) | Name of the SNS topic. |
| <a name="output_policy_managed"></a> [policy\_managed](#output\_policy\_managed) | Whether the module manages a topic policy. False means the topic keeps whatever policy AWS attached by default. |
<!-- END_TF_DOCS -->
