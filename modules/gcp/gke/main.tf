# Regional GKE Autopilot cluster.
#
# Autopilot fully manages node pools, so this module declares no machine types or
# node counts. Nodes are private (no public IPs) and rely on the VPC's Cloud NAT for
# egress; the control plane keeps a public endpoint locked down with authorized
# networks unless enable_private_endpoint is set.
resource "google_container_cluster" "this" {
  name     = var.name
  project  = var.project_id
  location = var.region

  enable_autopilot    = true
  deletion_protection = var.deletion_protection
  network             = var.network
  subnetwork          = var.subnetwork

  release_channel {
    channel = var.release_channel
  }

  # VPC-native cluster using the subnetwork's secondary ranges for Pods and Services.
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private nodes; control-plane endpoint visibility controlled by var.enable_private_endpoint.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        display_name = cidr_blocks.value.display_name
        cidr_block   = cidr_blocks.value.cidr_block
      }
    }
  }

  # Enable the GKE-managed Secret Manager add-on (the Google-managed Secrets Store CSI Driver +
  # GCP provider) when requested.
  dynamic "secret_manager_config" {
    for_each = var.enable_secret_manager_addon ? [1] : []
    content {
      enabled = true
    }
  }

  # The SecretSync controller materializes Secret Manager secrets as Kubernetes Secrets so they
  # can be referenced through standard valueFrom.secretKeyRef / envFrom. Independent from the
  # CSI-based add-on above — either or both may be enabled.
  dynamic "secret_sync_config" {
    for_each = var.enable_secret_sync ? [1] : []
    content {
      enabled = true
    }
  }

  resource_labels = var.resource_labels
}
