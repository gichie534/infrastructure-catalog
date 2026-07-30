variable "host_project_id" {
  description = "The Shared VPC host project that owns the subnetwork being shared and against which the host-service-agent grant is made."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.host_project_id))
    error_message = "host_project_id must be 6 to 30 characters, contain only lowercase letters, numbers, and hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "service_project_number" {
  description = <<-EOT
    The NUMBER (not ID) of the service project whose GKE service agents are granted access to the
    host subnetwork. Two Google-managed accounts are derived from it:
    <number>@cloudservices.gserviceaccount.com and
    service-<number>@container-engine-robot.iam.gserviceaccount.com. Wire from a
    gcp/service-project's project_number output.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+$", var.service_project_number))
    error_message = "service_project_number must be the numeric project number (digits only), not the project ID."
  }
}

variable "region" {
  description = "Region of the host subnetwork being shared (e.g. us-central1)."
  type        = string
  nullable    = false
}

variable "subnetwork" {
  description = "Name of the host subnetwork the service project may use (its Pods/Services secondary ranges come with it). Wire from a gcp/vpc subnets[*].name output."
  type        = string
  nullable    = false
}

variable "grant_host_service_agent_user" {
  description = "Grant the service project's GKE service agent roles/container.hostServiceAgentUser on the host project, so it can manage the cluster's networking (firewall rules, etc.) in the host project. Required for GKE on a Shared VPC; leave on unless the service project runs no GKE."
  type        = bool
  nullable    = false
  default     = true
}
