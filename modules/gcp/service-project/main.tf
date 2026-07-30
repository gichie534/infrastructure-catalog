# A GCP project that is attached to a Shared VPC HOST as a SERVICE project: workloads in it
# (e.g. a GKE cluster) run on subnets owned by the host project. This is the plain project
# (from the base gcp/project module) plus the one resource that attaches it to a host — kept as
# its own module so a service project is expressed without a conditional (see gcp/host-project
# for the other side).
#
# The project attaches ITSELF to the host, so the dependency graph stays acyclic: the host knows
# nothing about its service projects. Attaching requires the caller to hold roles/compute.xpnAdmin
# at the org/folder and the Compute API to be active on both projects.

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

# Attach this project to the Shared VPC host. Requires the Compute API (above) first.
resource "google_compute_shared_vpc_service_project" "this" {
  host_project    = var.shared_vpc_host_project_id
  service_project = google_project.this.project_id

  depends_on = [google_project_service.apis]
}
