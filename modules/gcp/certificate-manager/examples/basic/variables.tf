variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the provider configuration."
  type        = string
  default     = "us-central1"
}

variable "base_domain" {
  description = <<-EOT
    Apex domain for the example zone and the per-host certificates (api.<base_domain>,
    app.<base_domain>). Without a trailing dot. Defaults to example.com for static validation, but
    GCP refuses to create a PUBLIC zone for reserved domains like example.com — the test injects a
    unique, creatable domain instead.
  EOT
  type        = string
  default     = "example.com"
}
