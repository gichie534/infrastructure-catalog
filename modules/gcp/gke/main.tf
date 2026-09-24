# Regional GKE Autopilot cluster.
#
# Autopilot fully manages node pools, so this module declares no machine types or
# node counts. Nodes are private (no public IPs) and rely on the VPC's Cloud NAT for
# egress; the control plane keeps a public endpoint locked down with authorized
# networks unless enable_private_endpoint is set.

locals {
  # account_id is capped at 30 characters while a cluster name may be up to 40, so derive and
  # truncate rather than assume it fits. trimsuffix keeps a truncation from ending in a hyphen,
  # which account_id rejects.
  node_service_account_id = coalesce(
    var.node_service_account_id,
    trimsuffix(substr("${var.name}-nodes", 0, 30), "-"),
  )

  # null means "say nothing about the node identity", and GKE falls back to the project's Compute
  # Engine default service account. See var.create_node_service_account for why that default is a
  # trap on newer projects.
  node_service_account_email = (
    var.create_node_service_account
    ? google_service_account.node[0].email
    : var.node_service_account
  )
}

# A dedicated, least-privilege identity for the cluster's nodes, replacing the project's Compute
# Engine default service account. Its lifecycle is the cluster's lifecycle, which is why it lives
# here rather than in a separate module: it has no reason to exist without this cluster.
resource "google_service_account" "node" {
  count = var.create_node_service_account ? 1 : 0

  project      = var.project_id
  account_id   = local.node_service_account_id
  display_name = "GKE node identity for ${var.name}"
  description  = "Least-privilege node service account for the ${var.name} GKE cluster. Managed by the gcp/gke module."
}

# Without this grant nodes boot, fail to register, and are then deleted by the control plane — so
# the cluster reports RUNNING with zero nodes and every pod sits Pending. The binding is additive
# (google_project_iam_member, not _binding), so it never disturbs other members of the same role.
resource "google_project_iam_member" "node" {
  for_each = var.create_node_service_account ? toset(var.node_service_account_roles) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node[0].email}"
}

resource "google_container_cluster" "this" {
  # The grant must land before the first node boots, or that node fails to register and the cluster
  # spends a while recovering from a self-inflicted outage.
  depends_on = [google_project_iam_member.node]

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

  # Autopilot has no node pools to attach a service account to, so the node identity is set through
  # the autoprovisioning defaults. Omitted entirely when unset, because an empty cluster_autoscaling
  # block conflicts with enable_autopilot.
  dynamic "cluster_autoscaling" {
    for_each = local.node_service_account_email == null ? [] : [1]
    content {
      auto_provisioning_defaults {
        service_account = local.node_service_account_email
      }
    }
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
  # GCP provider) when requested. Optional rotation_config re-fetches mounted secret values on an
  # interval so files pick up a new secret version without a pod restart.
  dynamic "secret_manager_config" {
    for_each = var.enable_secret_manager_addon ? [1] : []
    content {
      enabled = true

      dynamic "rotation_config" {
        for_each = var.secret_manager_addon_rotation.enabled ? [1] : []
        content {
          enabled           = true
          rotation_interval = var.secret_manager_addon_rotation.rotation_interval
        }
      }
    }
  }

  # The SecretSync controller materializes Secret Manager secrets as Kubernetes Secrets so they
  # can be referenced through standard valueFrom.secretKeyRef / envFrom. Independent from the
  # CSI-based add-on above — either or both may be enabled. Optional rotation_config periodically
  # checks Secret Manager for a new version and updates the Kubernetes Secret's data; consumers
  # must detect and reload the value themselves (no pod restart).
  dynamic "secret_sync_config" {
    for_each = var.enable_secret_sync ? [1] : []
    content {
      enabled = true

      dynamic "rotation_config" {
        for_each = var.secret_sync_rotation.enabled ? [1] : []
        content {
          enabled           = true
          rotation_interval = var.secret_sync_rotation.rotation_interval
        }
      }
    }
  }

  resource_labels = var.resource_labels
}
