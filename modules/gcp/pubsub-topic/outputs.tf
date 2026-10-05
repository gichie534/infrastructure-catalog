output "id" {
  description = "Full resource name of the topic (`projects/<project>/topics/<name>`). This is what a budget's `pubsub_topic` takes."
  value       = google_pubsub_topic.this.id
}

output "name" {
  description = "Short name of the topic."
  value       = google_pubsub_topic.this.name
}

output "publisher_members" {
  description = "Members granted roles/pubsub.publisher by this module."
  value       = sort([for m in google_pubsub_topic_iam_member.publisher : m.member])
}

output "subscription_ids" {
  description = "Map of subscription name to full resource name (`projects/<project>/subscriptions/<name>`)."
  value       = { for k, s in google_pubsub_subscription.pull : k => s.id }
}
