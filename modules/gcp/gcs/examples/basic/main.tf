provider "google" {
  project = var.project_id
  region  = var.region
}

module "bucket" {
  source = "../../"

  project_id = var.project_id
  name       = var.bucket_name
  location   = var.region

  # Examples/tests must be destroyable.
  force_destroy = true

  labels = {
    managed-by = "terraform"
    example    = "basic"
  }
}
