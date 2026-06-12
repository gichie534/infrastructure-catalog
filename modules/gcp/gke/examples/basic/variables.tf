variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "Region for the cluster and its VPC subnet."
  type        = string
  default     = "us-central1"
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to reach the control plane endpoint."
  type = list(object({
    display_name = string
    cidr_block   = string
  }))
  default = [
    {
      display_name = "all"
      cidr_block   = "0.0.0.0/0"
    },
  ]
}
