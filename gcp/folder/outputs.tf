# `id` is the canonical handle a child folder/project depends on (folders/<id>).
output "id" {
  description = "The folder ID (e.g. folders/123456), used as the parent for child folders/projects"
  value       = google_folder.this.name
}

output "display_name" {
  description = "The display name of the folder"
  value       = google_folder.this.display_name
}

output "parent" {
  description = "The parent resource of the folder"
  value       = google_folder.this.parent
}
