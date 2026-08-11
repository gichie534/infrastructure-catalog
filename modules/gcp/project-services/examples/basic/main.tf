provider "google" {
  project = var.project_id
  region  = var.region
}

module "project_services" {
  source = "../../"

  project_id = var.project_id

  # iap.googleapis.com is harmless to enable repeatedly (idempotent) and free to keep enabled, so it
  # doubles as a safe example/test fixture.
  activate_apis = ["iap.googleapis.com"]
}
