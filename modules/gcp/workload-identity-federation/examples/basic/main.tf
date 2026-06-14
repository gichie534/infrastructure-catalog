provider "google" {
  project = var.project_id
  region  = var.region
}

# A service account the federated identity will impersonate. In a real setup this is the
# deploy/CI identity (granted whatever it needs to push images, reach a cluster, etc.).
resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = "WIF example CI service account"
}

# Federate GitHub Actions OIDC tokens to the pool and let the configured repository
# impersonate the service account above. GitHub is used here only as a concrete example of
# the IdP-neutral interface.
module "wif" {
  source = "../../"

  project_id        = var.project_id
  pool_id           = var.pool_id
  pool_display_name = "WIF example pool"

  oidc_providers = {
    github = {
      issuer_uri = "https://token.actions.githubusercontent.com"
      attribute_mapping = {
        "google.subject"       = "assertion.sub"
        "attribute.repository" = "assertion.repository"
        "attribute.ref"        = "assertion.ref"
      }
      # Only tokens whose repository claim matches are accepted by this provider.
      attribute_condition = "assertion.repository == \"${var.github_repository}\""
      display_name        = "GitHub Actions"
    }
  }

  service_account_bindings = {
    github_repo = {
      service_account_id = google_service_account.ci.id
      # Every workflow run in the named repository may impersonate the SA.
      principal_set = "attribute.repository/${var.github_repository}"
    }
  }
}
