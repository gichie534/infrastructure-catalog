output "instance_id" {
  description = "The ID of the instance"
  value       = google_compute_instance.this.instance_id
}

output "internal_ip" {
  description = "The internal IP address of the instance"
  value       = google_compute_instance.this.network_interface[0].network_ip
}
