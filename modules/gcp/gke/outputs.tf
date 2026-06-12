output "cluster_id" {
  description = "The ID of the GKE cluster."
  value       = google_container_cluster.this.id
}

output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = google_container_cluster.this.name
}

output "location" {
  description = "The region the cluster runs in."
  value       = google_container_cluster.this.location
}

output "endpoint" {
  description = "The IP address of the cluster's Kubernetes API server."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded public CA certificate of the cluster, used to authenticate kubectl/provider clients."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "self_link" {
  description = "The server-defined URL (self link) of the cluster."
  value       = google_container_cluster.this.self_link
}
