provider "google" {
  project = var.project_id
  region  = var.region
}

module "repository" {
  source = "../../"

  project_id    = var.project_id
  repository_id = var.repository_id
  location      = var.region
  format        = "DOCKER"
  description   = "Example container image repository"

  labels = {
    managed-by = "terraform"
    example    = "basic"
  }
}
