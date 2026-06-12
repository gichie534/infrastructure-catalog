# A single Artifact Registry repository. This module owns only the repository and exports
# its identifiers; it grants no access. A consumer (e.g. the workload-iam module) wires
# reader/writer IAM against the exported name, keeping the repo's access policy with the
# workload that needs it.
#
# For DOCKER repositories, immutable tags are hardcoded on so a pushed tag can't be
# silently overwritten — the secure baseline for image provenance.
resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  format        = var.format
  description   = var.description
  labels        = var.labels

  dynamic "docker_config" {
    for_each = var.format == "DOCKER" ? [1] : []
    content {
      immutable_tags = true
    }
  }
}
