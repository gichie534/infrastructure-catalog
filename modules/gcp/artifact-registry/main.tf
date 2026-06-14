# A single Artifact Registry repository. The module owns the repository and exports its
# identifiers. It can optionally grant reader/writer IAM to existing members (e.g. a GKE
# node service account that pulls images, or a CI identity that pushes them) — handy when
# the member already exists and isn't created by another module. For an identity a sibling
# module creates (e.g. workload-iam's GSA), prefer wiring that module against the exported
# `name` instead.
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

# Repo-scoped reader grants (roles/artifactregistry.reader) for existing members — e.g. the
# GKE node service account that pulls container images.
resource "google_artifact_registry_repository_iam_member" "reader" {
  for_each = var.reader_members

  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.reader"
  member     = each.value
}

# Repo-scoped writer grants (roles/artifactregistry.writer) for existing members — e.g. a CI
# identity that pushes images.
resource "google_artifact_registry_repository_iam_member" "writer" {
  for_each = var.writer_members

  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.writer"
  member     = each.value
}
