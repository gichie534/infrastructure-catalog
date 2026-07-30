# A GCP project that is a Shared VPC HOST: it owns the VPC network(s) that attached
# service projects consume. This is the plain project (from the base gcp/project module)
# plus the one resource that nominates it as a host — kept as its own module so a host is
# expressed without a conditional (see also gcp/service-project for the other side).
#
# Enabling a host requires the caller to hold roles/compute.xpnAdmin at the org/folder and
# the Compute API to be active on the project (enforced by the activate_apis validation).

resource "google_project" "this" {
  name       = var.name
  project_id = var.project_id
  folder_id  = var.folder_id

  billing_account = var.billing_account
  labels          = var.labels

  deletion_policy = var.deletion_policy
}

resource "google_project_service" "apis" {
  for_each = toset(var.activate_apis)

  project = google_project.this.project_id
  service = each.value

  disable_dependent_services = true
  disable_on_destroy         = false
}

# Nominate the project as a Shared VPC host. Requires the Compute API (above) first.
resource "google_compute_shared_vpc_host_project" "this" {
  project = google_project.this.project_id

  depends_on = [google_project_service.apis]
}
