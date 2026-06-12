variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Location for the bucket and provider configuration."
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Globally-unique bucket name. Override per run to avoid collisions."
  type        = string
}
