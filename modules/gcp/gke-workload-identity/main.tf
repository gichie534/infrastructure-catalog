# Direct Workload Identity Federation for GKE.
#
# This module implements the Google-recommended pattern where the Kubernetes service account (KSA)
# is itself an IAM principal: IAM roles are granted straight to the KSA's federated principal
# string, with NO intermediary Google service account to create, annotate, or impersonate.
# See https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authn-to-gcp.
#
# The principal for a KSA on a GKE cluster in this project is:
#   principal://iam.googleapis.com/projects/<project_number>/locations/global/workloadIdentityPools/<project_id>.svc.id.goog/subject/ns/<namespace>/sa/<ksa>
#
# A pod running under that KSA (no annotation needed — that annotation is only for the older GSA
# impersonation pattern) gets short-lived credentials for whatever this module grants the principal.

locals {
  # The federated principal of the Kubernetes service account. GKE's fixed pool for a project is
  # always <project_id>.svc.id.goog.
  ksa_principal = "principal://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.kubernetes_namespace}/sa/${var.kubernetes_service_account}"
}

# Grant the KSA principal access to each supplied bucket/role pair, scoped to the bucket.
resource "google_storage_bucket_iam_member" "this" {
  for_each = var.bucket_iam

  bucket = each.value.bucket
  role   = each.value.role
  member = local.ksa_principal
}

# Grant the KSA principal access to each supplied Secret Manager secret/role pair, scoped to the
# individual secret. secret_id must be the fully-qualified projects/<project>/secrets/<name>
# resource ID (the secret-manager module's secret_id output).
resource "google_secret_manager_secret_iam_member" "this" {
  for_each = var.secret_iam

  secret_id = each.value.secret_id
  role      = each.value.role
  member    = local.ksa_principal
}

# Grant the KSA principal project-level roles.
resource "google_project_iam_member" "this" {
  for_each = var.project_roles

  project = var.project_id
  role    = each.value
  member  = local.ksa_principal
}
