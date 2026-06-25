# A plain Google service account, optionally with project-level role grants and a set of principals
# allowed to impersonate it (Service Account Token Creator). Unlike gcp/workload-iam this carries no
# GKE Workload Identity assumptions — it is the general-purpose "create a service account" primitive,
# useful for CI probes, automation identities, and service-account JWT/OIDC flows (e.g. authenticating
# to an IAP-secured endpoint).

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
  description  = var.description
}

# Project-level roles granted TO this service account.
resource "google_project_iam_member" "this" {
  for_each = var.project_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

# Principals allowed to impersonate this service account to mint short-lived credentials
# (roles/iam.serviceAccountTokenCreator on the SA resource — no exported keys needed).
resource "google_service_account_iam_member" "token_creators" {
  for_each = var.token_creators

  service_account_id = google_service_account.this.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value
}
