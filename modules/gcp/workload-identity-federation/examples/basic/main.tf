provider "google" {
  project = var.project_id
  region  = var.region
}

# Federate GitHub Actions OIDC tokens to the pool and grant the configured repository a project
# role *directly* — no intermediary service account (Google's preferred direct-WIF pattern). GitHub
# is used here only as a concrete example of the IdP-neutral interface.
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

  project_iam_bindings = {
    github_repo = {
      # Every workflow run in the named repository gets this role directly.
      principal_set = "attribute.repository/${var.github_repository}"
      roles         = ["roles/artifactregistry.reader"]
    }
  }
}
