output "repository_id" {
  description = "The short repository ID (name)."
  value       = google_artifact_registry_repository.this.repository_id
}

output "name" {
  description = "The fully-qualified repository name (projects/<project>/locations/<location>/repositories/<id>). Wire this into the workload-iam module (for a GSA it creates) to grant reader/writer IAM, or use this module's reader_members/writer_members for existing identities."
  value       = google_artifact_registry_repository.this.name
}

output "location" {
  description = "The location the repository lives in."
  value       = google_artifact_registry_repository.this.location
}

output "registry_url" {
  description = "The host/path prefix for artifact references, e.g. <location>-docker.pkg.dev/<project>/<repo> for DOCKER. The host segment reflects the repository format."
  value       = "${var.location}-${lower(var.format)}.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
