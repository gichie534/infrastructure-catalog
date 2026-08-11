# Enables one or more Google APIs on an EXISTING project. Unlike gcp/project (which creates the
# project itself and activates APIs on it as part of that), this module takes over no project
# lifecycle at all — it is the pragmatic choice for a project that already exists (created manually
# or out-of-band) and just needs an additional API turned on, without importing/adopting the whole
# project resource into this module's state.

resource "google_project_service" "apis" {
  for_each = var.activate_apis

  project = var.project_id
  service = each.value

  disable_dependent_services = var.disable_dependent_services
  disable_on_destroy         = false
}
