output "project_id" {
  description = "The project ID, consumed by resource units (vpc, gke, gcs, etc.) under this project"
  value       = google_project.this.project_id
}

output "project_number" {
  description = "The numeric project number"
  value       = google_project.this.number
}

output "name" {
  description = "The display name of the project"
  value       = google_project.this.name
}
