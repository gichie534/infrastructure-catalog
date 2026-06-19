# Private submodule: instantiates exactly ONE DNS-authorized, Google-managed certificate — one DNS
# authorization plus one managed certificate for a single domain. The parent certificate-manager
# module calls this once per domain (for_each). Not intended to be consumed directly from outside the
# parent module; input validation lives in the parent.

resource "google_certificate_manager_dns_authorization" "this" {
  project     = var.project_id
  name        = var.name
  location    = var.location
  domain      = var.domain
  description = "Managed by Terraform"
  labels      = var.labels
}

resource "google_certificate_manager_certificate" "this" {
  project     = var.project_id
  name        = var.name
  location    = var.location
  description = "Managed by Terraform"
  labels      = var.labels

  managed {
    domains            = [var.domain]
    dns_authorizations = [google_certificate_manager_dns_authorization.this.id]
  }
}
