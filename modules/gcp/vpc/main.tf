locals {
  # Region used for the Cloud Router / NAT: explicit override, else the first subnet's region.
  nat_region = coalesce(var.nat_region, var.subnets[0].region)

  # Subnets that should advertise Private Google Access.
  subnets_by_name = { for s in var.subnets : s.name => s }
}

# VPC network. Subnets are created explicitly (no auto subnetworks) so ranges are deterministic.
resource "google_compute_network" "this" {
  name                            = var.name
  project                         = var.project_id
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = false
}

# GKE-ready subnets, each with secondary ranges for Pods and Services (VPC-native alias IPs).
resource "google_compute_subnetwork" "this" {
  for_each = local.subnets_by_name

  name                     = "${var.name}-${each.value.name}"
  project                  = var.project_id
  region                   = each.value.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = each.value.ip_cidr_range
  private_ip_google_access = each.value.private_google_access

  dynamic "secondary_ip_range" {
    for_each = each.value.pods_cidr_range == null ? [] : [each.value.pods_cidr_range]
    content {
      range_name    = each.value.pods_range_name
      ip_cidr_range = secondary_ip_range.value
    }
  }

  dynamic "secondary_ip_range" {
    for_each = each.value.services_cidr_range == null ? [] : [each.value.services_cidr_range]
    content {
      range_name    = each.value.services_range_name
      ip_cidr_range = secondary_ip_range.value
    }
  }

  dynamic "log_config" {
    for_each = each.value.flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# --- Private Service Access (servicenetworking peering) --------------------
# Reserves a range and peers the VPC with Google-managed services (Cloud SQL, etc.).
resource "google_compute_global_address" "private_service_access" {
  count = var.private_service_access ? 1 : 0

  name          = "${var.name}-psa"
  project       = var.project_id
  network       = google_compute_network.this.id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = cidrhost(var.private_service_access_cidr, 0)
  prefix_length = tonumber(split("/", var.private_service_access_cidr)[1])
}

resource "google_service_networking_connection" "private_service_access" {
  count = var.private_service_access ? 1 : 0

  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access[0].name]

  # On destroy, producer services (Cloud SQL, Memorystore, ...) are released
  # asynchronously, so the API often still reports the connection as in use right
  # after the instance is deleted. ABANDON drops the peering from state instead of
  # blocking the destroy on that eventual-consistency lag.
  deletion_policy = var.private_service_access_deletion_policy
}

# --- Cloud NAT for private node egress -------------------------------------
resource "google_compute_router" "this" {
  count = var.create_nat ? 1 : 0

  name    = "${var.name}-router"
  project = var.project_id
  region  = local.nat_region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  count = var.create_nat ? 1 : 0

  name                               = "${var.name}-nat"
  project                            = var.project_id
  region                             = local.nat_region
  router                             = google_compute_router.this[0].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
