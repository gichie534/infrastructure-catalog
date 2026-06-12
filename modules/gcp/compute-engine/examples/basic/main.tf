provider "google" {
  project = var.project_id
  region  = "us-central1"
}

module "vm" {
  source = "../../"

  name       = "example-instance"
  project_id = var.project_id
}
