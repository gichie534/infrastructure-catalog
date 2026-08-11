output "address" {
  description = "The reserved IPv4 address (dotted-decimal string). Wire this into a DNS A record and/or read it for reference; the Ingress consumes the address by name, not by value."
  value       = google_compute_global_address.this.address
}

output "name" {
  description = "The name of the reserved address, for the Ingress's kubernetes.io/ingress.global-static-ip-name annotation."
  value       = google_compute_global_address.this.name
}

output "self_link" {
  description = "The self link of the reserved address resource."
  value       = google_compute_global_address.this.self_link
}
