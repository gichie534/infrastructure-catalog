# A Pub/Sub topic that other principals — typically Google-owned service accounts — may publish to, plus
# optional pull subscriptions.
#
# The GCP counterpart of aws/sns-topic, and for the same reason: creating a topic is trivial, the publish
# grant is what goes wrong. Cloud Billing publishes budget messages as
# `billing-budget-alert@system.gserviceaccount.com`; without roles/pubsub.publisher on the topic for that
# account, publishes are refused and nothing tells you.
#
# The grants use google_pubsub_topic_iam_member (additive), never _policy/_binding (authoritative), so this
# module cannot strip grants that Google adds to the topic by itself when you wire it up in the console.
#
# Subscriptions are here, not in a separate module, because a topic with no subscription drops every
# message on the floor. Pull only, for now.

resource "google_pubsub_topic" "this" {
  project = var.project_id
  name    = var.name
  labels  = var.labels

  kms_key_name               = var.kms_key_name
  message_retention_duration = var.message_retention_duration
}

resource "google_pubsub_topic_iam_member" "publisher" {
  for_each = toset(var.publisher_members)

  project = var.project_id
  topic   = google_pubsub_topic.this.name
  role    = "roles/pubsub.publisher"
  member  = each.value
}

resource "google_pubsub_subscription" "pull" {
  for_each = var.pull_subscriptions

  project = var.project_id
  name    = each.key
  topic   = google_pubsub_topic.this.id
  labels  = var.labels

  ack_deadline_seconds       = each.value.ack_deadline_seconds
  message_retention_duration = each.value.message_retention_duration
  retain_acked_messages      = each.value.retain_acked_messages

  # A subscription with no activity for 31 days is deleted by default — which is exactly what an alert
  # feed nobody has needed yet looks like. Never expire unless the consumer says otherwise.
  expiration_policy {
    ttl = each.value.expiration_ttl
  }
}
