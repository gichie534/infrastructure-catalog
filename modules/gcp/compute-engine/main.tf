resource "google_compute_instance" "this" {
  name         = var.name
  project      = var.project_id
  machine_type = var.machine_type
  zone         = var.zone

  tags   = var.tags
  labels = var.labels

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    # Use an explicit subnetwork when supplied (required for custom-mode VPCs); otherwise fall back
    # to the named auto-mode network. Setting both when they disagree is an error, so pick one.
    network    = var.subnetwork == null ? var.network : null
    subnetwork = var.subnetwork

    # An external IP is added only when requested (e.g. so a migration host can reach an external
    # database and install packages). Default: no public IP.
    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {}
    }
  }

  metadata = var.metadata

  # Startup script runs on first boot (e.g. install packages). Kept separate from metadata so callers
  # can set both without merging by hand.
  metadata_startup_script = var.startup_script

  dynamic "service_account" {
    for_each = var.service_account_email == null ? [] : [1]
    content {
      email  = var.service_account_email
      scopes = var.service_account_scopes
    }
  }
}
