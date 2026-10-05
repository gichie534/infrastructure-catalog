# Cloud Monitoring email notification channels — one per address.
#
# The GCP counterpart of the email half of aws/sns-topic. Budgets, alerting policies and uptime checks all
# deliver to humans through these channels, so they are reusable well beyond cost alerts.
#
# Unlike an SNS email subscription, an email channel needs no confirmation click: it is live as soon as it
# exists. The flip side is that nothing proves the address is right — a typo is a silent channel. The
# `verify`-style check a consumer can do is send a test notification from the console.
#
# Email only, for now. Other channel types (Slack, PagerDuty, webhooks) carry secrets in
# `sensitive_labels` and get added when a second consumer needs them (rule of three).

resource "google_monitoring_notification_channel" "email" {
  for_each = toset(var.email_addresses)

  project      = var.project_id
  display_name = "${var.display_name_prefix} <${each.value}>"
  description  = var.description
  type         = "email"
  enabled      = var.enabled

  labels = {
    email_address = each.value
  }

  user_labels = var.labels

  # Deleting a channel that an alerting policy still references fails unless forced. This module does not
  # know who references it, so it does not force.
  force_delete = false
}
