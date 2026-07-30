# The IAM unit for a GKE workload running in a Shared VPC SERVICE project on a HOST project's
# subnetwork. It is the single home for "the service project may use the host network": the
# per-subnet networkUser grants for the service project's Google-managed agents, plus the
# host-service-agent grant that lets its GKE control plane manage networking in the host project.
#
# Producer modules stay pure: gcp/host-project / gcp/service-project export project IDs and numbers,
# gcp/vpc exports the subnetwork name; this unit collects them and centralises the cross-project
# network permissions. Mirrors the gcp/workload-iam pattern.
#
# Two Google-managed service accounts in the service project need access (both derived from the
# service project NUMBER, which is why this module takes the number, not the ID):
#   - <number>@cloudservices.gserviceaccount.com          (Google APIs service agent)
#   - service-<number>@container-engine-robot.iam.gserviceaccount.com (GKE service agent)
#
# NOTE ON ORDERING: the container-engine-robot agent is created when the Container API is enabled
# in the service project. Ensure the service project (which activates container.googleapis.com) is
# applied before this unit — the lab wires that with a dependency — so the agent exists when these
# bindings are created.

locals {
  google_apis_service_agent = "serviceAccount:${var.service_project_number}@cloudservices.gserviceaccount.com"
  gke_service_agent         = "serviceAccount:service-${var.service_project_number}@container-engine-robot.iam.gserviceaccount.com"

  # Both agents need networkUser on the shared subnet (which also covers its secondary ranges).
  network_user_members = toset([
    local.google_apis_service_agent,
    local.gke_service_agent,
  ])
}

# Scope networkUser to the specific subnet (least privilege), not the whole host project — the
# service project can use only this subnetwork of the host VPC.
resource "google_compute_subnetwork_iam_member" "network_user" {
  for_each = local.network_user_members

  project    = var.host_project_id
  region     = var.region
  subnetwork = var.subnetwork
  role       = "roles/compute.networkUser"
  member     = each.value
}

# Let the service project's GKE service agent manage the cluster's networking resources in the host
# project (firewall rules for the control plane, etc.).
resource "google_project_iam_member" "host_service_agent_user" {
  count = var.grant_host_service_agent_user ? 1 : 0

  project = var.host_project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = local.gke_service_agent
}
