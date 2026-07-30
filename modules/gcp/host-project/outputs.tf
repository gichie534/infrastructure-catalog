output "project_id" {
  description = "The project ID, consumed by resource units (vpc, etc.) created in the host project and by service projects attaching to this host."
  value       = google_project.this.project_id
}

output "project_number" {
  description = "The numeric project number."
  value       = google_project.this.number
}

output "name" {
  description = "The display name of the project."
  value       = google_project.this.name
}

output "host_project_id" {
  description = "The ID of this Shared VPC host project. Wire this into a gcp/service-project's shared_vpc_host_project_id."
  value       = google_compute_shared_vpc_host_project.this.project
}
