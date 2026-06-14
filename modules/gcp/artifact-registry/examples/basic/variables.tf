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

variable "puller_account_id" {
  description = "account_id of the example image-puller service account granted repo reader."
  type        = string
  default     = "ar-example-puller"
}
