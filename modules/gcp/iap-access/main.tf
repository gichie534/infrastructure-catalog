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

  # Resource name for the IAP settings below, kept on the SAME scope as the IAM grant above so the
  # two never disagree: project-wide IAP web, or the single named backend service.
  settings_name = (
    var.backend_service == null
    ? "projects/${var.project_id}/iap_web"
    : "projects/${var.project_id}/iap_web/compute/services/${var.backend_service}"
  )
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

# IAP settings for this scope. Separate from the IAM grants above: those decide WHO may pass through
# the gate, this decides HOW the gate behaves. Created only when cors_allow_http_options is set, so a
# consumer that only wants IAM grants gets no settings resource and any pre-existing IAP
# configuration is left alone.
#
# allow_http_options exempts HTTP OPTIONS from IAP authorization. A browser sends the CORS preflight
# OPTIONS WITHOUT credentials by design, so without this a cross-origin call to an IAP-protected API
# fails at the preflight and the real request is never issued — which surfaces as a hang rather than
# a 401. IAP still authorizes the actual (non-OPTIONS) request, so the gate is not bypassed.
resource "google_iap_settings" "this" {
  count = var.cors_allow_http_options == null ? 0 : 1

  name = local.settings_name

  access_settings {
    cors_settings {
      allow_http_options = var.cors_allow_http_options
    }
  }
}
