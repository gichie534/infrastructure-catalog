output "project_id" {
  description = "The project ID, consumed by resource units (gke, etc.) created in the service project."
  value       = google_project.this.project_id
}

output "project_number" {
  description = "The numeric project number. Needed to build the Google-managed service-agent emails granted access to the host network (see gcp/shared-vpc-iam)."
  value       = google_project.this.number
}

output "name" {
  description = "The display name of the project."
  value       = google_project.this.name
}

output "host_project_id" {
  description = "The Shared VPC host project this service project is attached to."
  value       = google_compute_shared_vpc_service_project.this.host_project
}
