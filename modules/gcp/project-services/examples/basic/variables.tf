variable "project_id" {
  description = "GCP project ID to enable APIs on."
  type        = string
}

variable "region" {
  description = "Region for the provider configuration (this module's resources are project-scoped, not regional, but the provider block requires one)."
  type        = string
  default     = "us-central1"
}
