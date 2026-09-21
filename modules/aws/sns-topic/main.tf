# An SNS topic that AWS services can publish to, plus optional email subscribers.
#
# The module exists for the resource-policy half of the problem. Creating a topic is trivial; the part
# that reliably goes wrong is that a service publishing to it (AWS Budgets, Cost Anomaly Detection,
# CloudWatch, EventBridge) acts as the SERVICE, not as your IAM identity, so it needs an explicit
# statement in the topic's resource policy. Without it the publish is denied and nothing arrives —
# no error surfaces on your side.
#
# The module owns the topic, its policy, and email subscriptions. It deliberately does not create KMS
# keys or chat integrations: those are the consumer's composition concern.

data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "this" {
  name         = var.name
  display_name = var.display_name

  kms_master_key_id = var.kms_master_key_id

  tags = var.tags
}

locals {
  # Whether to manage a topic policy at all. Derived purely from inputs so the `count` below stays
  # known at plan time (the policy body itself references the topic ARN, which is not).
  manage_policy = var.topic_policy != null || var.include_default_owner_statement || length(var.allowed_service_principals) > 0
}

# Generated topic policy: the account-owner statement AWS would have attached by default, plus one
# publish statement per allowed service principal.
data "aws_iam_policy_document" "generated" {
  # Mirrors the default policy AWS attaches to a new topic. Attaching any policy replaces that
  # default, so without this statement the owning account would lose resource-policy access.
  dynamic "statement" {
    for_each = var.include_default_owner_statement ? [1] : []
    content {
      sid    = "DefaultOwnerStatement"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      actions = [
        "SNS:GetTopicAttributes",
        "SNS:SetTopicAttributes",
        "SNS:AddPermission",
        "SNS:RemovePermission",
        "SNS:DeleteTopic",
        "SNS:Subscribe",
        "SNS:ListSubscriptionsByTopic",
        "SNS:Publish",
      ]

      resources = [aws_sns_topic.this.arn]

      condition {
        test     = "StringEquals"
        variable = "AWS:SourceOwner"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = toset(var.allowed_service_principals)
    content {
      sid    = "AllowPublishFrom${replace(replace(statement.value, ".amazonaws.com", ""), ".", "")}"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = [statement.value]
      }

      actions   = ["SNS:Publish"]
      resources = [aws_sns_topic.this.arn]

      # Opt-in: denies a same-service publisher in another account. Off by default because a service
      # that does not set aws:SourceAccount would be silently denied.
      dynamic "condition" {
        for_each = var.restrict_service_publish_to_source_account ? [1] : []
        content {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        }
      }
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  count = local.manage_policy ? 1 : 0

  arn    = aws_sns_topic.this.arn
  policy = var.topic_policy != null ? var.topic_policy : data.aws_iam_policy_document.generated.json
}

# Email subscriptions. These apply immediately but sit at PendingConfirmation until the recipient
# clicks the link in the AWS confirmation email — Terraform cannot confirm them on their behalf.
resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.email_subscribers)

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}
