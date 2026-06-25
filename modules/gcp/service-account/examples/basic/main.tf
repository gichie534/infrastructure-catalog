provider "google" {
  project = var.project_id
  region  = var.region
}

module "service_account" {
  source = "../../"

  project_id   = var.project_id
  account_id   = var.account_id
  display_name = "Example service account"

  # A harmless, broadly-available viewer role to exercise project_roles.
  project_roles = ["roles/viewer"]
}
