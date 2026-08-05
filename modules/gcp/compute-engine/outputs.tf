output "instance_id" {
  description = "The ID of the instance"
  value       = google_compute_instance.this.instance_id
}

output "name" {
  description = "The name of the instance (use with gcloud compute ssh)."
  value       = google_compute_instance.this.name
}

output "zone" {
  description = "The zone the instance runs in."
  value       = google_compute_instance.this.zone
}

output "internal_ip" {
  description = "The internal IP address of the instance"
  value       = google_compute_instance.this.network_interface[0].network_ip
}

output "public_ip" {
  description = "The external IP address of the instance, or null when enable_public_ip is false."
  value       = var.enable_public_ip ? google_compute_instance.this.network_interface[0].access_config[0].nat_ip : null
}
