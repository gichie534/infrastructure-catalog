output "ids" {
  description = "Channel resource names (`projects/<project>/notificationChannels/<id>`), in the order of `email_addresses`. This is what a budget's `notification_channel_ids` takes."
  value       = [for e in var.email_addresses : google_monitoring_notification_channel.email[e].name]
}

output "ids_by_email" {
  description = "Map of email address to channel resource name."
  value       = { for e, c in google_monitoring_notification_channel.email : e => c.name }
}

output "verification_statuses" {
  description = "Map of email address to verification status. Email channels do not require verification, so this is normally unset; it is exposed so a consumer does not have to assume."
  value       = { for e, c in google_monitoring_notification_channel.email : e => c.verification_status }
}
