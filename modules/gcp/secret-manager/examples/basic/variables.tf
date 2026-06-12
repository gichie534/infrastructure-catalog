variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the provider configuration."
  type        = string
  default     = "us-central1"
}
