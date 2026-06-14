provider "google" {
  project = var.project_id
  region  = var.region
}

# A throwaway service account to demonstrate (and test) repo-scoped reader grants on an
# existing member — stands in for, e.g., a GKE node service account that pulls images.
resource "google_service_account" "puller" {
  project      = var.project_id
  account_id   = var.puller_account_id
  display_name = "AR example image puller"
}

module "repository" {
  source = "../../"

  project_id    = var.project_id
  repository_id = var.repository_id
  location      = var.region
  format        = "DOCKER"
  description   = "Example container image repository"

  # Grant the existing puller SA read access, scoped to this repo.
  reader_members = {
    puller = "serviceAccount:${google_service_account.puller.email}"
  }

  labels = {
    managed-by = "terraform"
    example    = "basic"
  }
}
