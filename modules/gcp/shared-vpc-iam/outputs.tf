output "gke_service_agent" {
  description = "The service project's GKE service agent (container-engine-robot) that was granted access, as a fully-qualified IAM member."
  value       = local.gke_service_agent
}

output "google_apis_service_agent" {
  description = "The service project's Google APIs service agent (cloudservices) that was granted subnet networkUser, as a fully-qualified IAM member."
  value       = local.google_apis_service_agent
}

output "network_user_members" {
  description = "The IAM members granted roles/compute.networkUser on the host subnetwork."
  value       = tolist(local.network_user_members)
}
