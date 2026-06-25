variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the provider configuration."
  type        = string
  default     = "us-central1"
}

variable "account_id" {
  description = "account_id (local part) of the throwaway service account created as the example IAP principal."
  type        = string
  default     = "iap-access-example"
}
