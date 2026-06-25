provider "google" {
  project = var.project_id
  region  = var.region
}

# A throwaway service account to use as a concrete, side-effect-free IAP principal. Granting it
# roles/iap.httpsResourceAccessor exercises the module without needing a real user/group to exist.
resource "google_service_account" "example" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = "iap-access example principal"
}

# Grant the service account access through IAP at the project-wide web scope.
module "iap_access" {
  source = "../../"

  project_id = var.project_id

  members = {
    example_sa = "serviceAccount:${google_service_account.example.email}"
  }
}
