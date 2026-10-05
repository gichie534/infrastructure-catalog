output "id" {
  description = "Terraform ID of the dataset (`projects/<project>/datasets/<dataset_id>`)."
  value       = google_bigquery_dataset.this.id
}

output "dataset_id" {
  description = "Dataset ID."
  value       = google_bigquery_dataset.this.dataset_id
}

output "project_id" {
  description = "Project the dataset lives in."
  value       = google_bigquery_dataset.this.project
}

output "location" {
  description = "Dataset location."
  value       = google_bigquery_dataset.this.location
}

output "fully_qualified_name" {
  description = "`<project>.<dataset_id>` — the prefix used in SQL and by `bq`."
  value       = "${google_bigquery_dataset.this.project}.${google_bigquery_dataset.this.dataset_id}"
}

output "self_link" {
  description = "API self link of the dataset."
  value       = google_bigquery_dataset.this.self_link
}
