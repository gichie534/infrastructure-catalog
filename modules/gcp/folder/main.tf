resource "google_folder" "this" {
  display_name = var.display_name
  parent       = var.parent
}
