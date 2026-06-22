output "name" {
  description = "The name of the bucket. Wire this into the workload-iam module's bucket_iam to grant access."
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "The gs:// URL of the bucket."
  value       = google_storage_bucket.this.url
}

output "self_link" {
  description = "The URI (self link) of the bucket."
  value       = google_storage_bucket.this.self_link
}
