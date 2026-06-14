variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the provider configuration."
  type        = string
  default     = "us-central1"
}

variable "pool_id" {
  description = "ID of the Workload Identity Pool to create."
  type        = string
  default     = "example-ci-pool"
}

variable "github_repository" {
  description = "GitHub repository (OWNER/REPO) allowed to federate into the pool and impersonate the SA."
  type        = string
  default     = "octo-org/example-repo"
}
