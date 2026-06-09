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
