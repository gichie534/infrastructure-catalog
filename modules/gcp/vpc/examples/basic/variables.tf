variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the example subnet and Cloud NAT."
  type        = string
  default     = "us-central1"
}
