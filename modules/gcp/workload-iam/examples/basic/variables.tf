variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the provider configuration and bucket location."
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Globally-unique bucket name. Override per run to avoid collisions."
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository ID. Override per run to avoid collisions."
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace of the workload's service account (for the Workload Identity binding)."
  type        = string
  default     = "default"
}

variable "k8s_service_account" {
  description = "Kubernetes service account name the pod runs as (for the Workload Identity binding)."
  type        = string
  default     = "app"
}
