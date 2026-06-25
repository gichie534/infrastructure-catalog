# Grants the IAP "who may pass through" permission — roles/iap.httpsResourceAccessor — to a set of
# principals on an IAP-protected web resource. This is the access-control half of IAP: enabling IAP
# on a backend (e.g. via a GKE BackendConfig) turns the gate ON; this module says who gets through.
#
# Two scopes:
#   - project-wide  (backend_service = null): the grant applies to every IAP-protected backend in
#     the project (google_iap_web_iam_member). GKE Ingress names its backend services dynamically,
#     so project-wide is the pragmatic default for a GKE workload.
#   - per-backend   (backend_service set): the grant is scoped to one named Compute backend service
#     (google_iap_web_backend_service_iam_member) for tighter, least-privilege control.
#
# Members can be users, groups, service accounts, or domains. Service-account principals are what
# enable programmatic (non-browser) access to the IAP-secured app.

locals {
  role = "roles/iap.httpsResourceAccessor"
}

# Project-wide IAP web access (all IAP-protected backends in the project).
resource "google_iap_web_iam_member" "this" {
  for_each = var.backend_service == null ? var.members : {}

  project = var.project_id
  role    = local.role
  member  = each.value
}

# Access scoped to a single named backend service.
resource "google_iap_web_backend_service_iam_member" "this" {
  for_each = var.backend_service == null ? {} : var.members

  project             = var.project_id
  web_backend_service = var.backend_service
  role                = local.role
  member              = each.value
}
