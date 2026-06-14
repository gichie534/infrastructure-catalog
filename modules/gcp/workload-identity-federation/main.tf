# Workload Identity Federation: let external OIDC identities act as Google service accounts
# without exporting long-lived service-account keys.
#
# This module is deliberately IdP-neutral. It owns the *mechanism* — the pool, its OIDC
# providers, the attribute mapping/condition, and the workloadIdentityUser bindings — while
# the *policy* (which issuer, which claims to gate on, which GSA to bind) is supplied as
# inputs. GitHub Actions is just one possible provider; GitLab CI, Terraform Cloud, or any
# generic OIDC issuer plug into the same shape.
resource "google_iam_workload_identity_pool" "this" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = var.pool_display_name
  description               = var.pool_description
}

resource "google_iam_workload_identity_pool_provider" "this" {
  for_each = var.oidc_providers

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = each.key
  display_name                       = each.value.display_name
  description                        = each.value.description
  attribute_mapping                  = each.value.attribute_mapping
  attribute_condition                = each.value.attribute_condition

  oidc {
    issuer_uri        = each.value.issuer_uri
    allowed_audiences = each.value.allowed_audiences
  }
}

# Bind each federated principalSet to a Google service account. The full member string is
# assembled from the pool's server-assigned resource name so callers never need the project
# number: principalSet://iam.googleapis.com/<pool_name>/<principal_set_suffix>.
#
# This is the impersonation fallback — prefer the direct grants below.
resource "google_service_account_iam_member" "workload_identity_user" {
  for_each = var.service_account_bindings

  service_account_id = each.value.service_account_id
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.this.name}/${each.value.principal_set}"
}

# Direct WIF (preferred): grant project-level roles straight to the federated principalSet, with no
# intermediary service account. Flatten {label -> {principal_set, roles}} into one binding per
# (label, role) pair so each grant is its own resource.
locals {
  project_iam_grants = merge([
    for label, b in var.project_iam_bindings : {
      for role in b.roles : "${label}/${role}" => {
        principal_set = b.principal_set
        role          = role
      }
    }
  ]...)
}

resource "google_project_iam_member" "direct" {
  for_each = local.project_iam_grants

  project = var.project_id
  role    = each.value.role
  member  = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.this.name}/${each.value.principal_set}"
}
