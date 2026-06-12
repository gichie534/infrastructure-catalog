provider "google" {
  project = var.project_id
  region  = var.region
}

module "secret" {
  source = "../../"

  project_id = var.project_id
  secret_id  = "app-db-password"

  labels = {
    managed-by = "terraform"
    example    = "basic"
  }
}
