variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the instance and its VPC subnet."
  type        = string
  default     = "us-central1"
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
