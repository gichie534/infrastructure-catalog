variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the provider configuration (global addresses are region-agnostic, but the provider block requires one)."
  type        = string
  default     = "us-central1"
}
