output "cluster_id" {
  description = "The ID of the created cluster."
  value       = module.gke.cluster_id
}

output "cluster_name" {
  description = "The name of the created cluster."
  value       = module.gke.cluster_name
}

output "location" {
  description = "The region the cluster runs in."
  value       = module.gke.location
}

output "endpoint" {
  description = "The API server endpoint of the created cluster."
  value       = module.gke.endpoint
  sensitive   = true
}

output "network_self_link" {
  description = "Self link of the VPC the cluster runs in."
  value       = module.vpc.network_self_link
}

output "node_service_account_email" {
  description = "Email of the dedicated service account the cluster's nodes run as."
  value       = module.gke.node_service_account_email
}
