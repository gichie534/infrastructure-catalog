variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Location for the repository and provider configuration."
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Repository ID (name). Override per run to avoid collisions."
  type        = string
}
