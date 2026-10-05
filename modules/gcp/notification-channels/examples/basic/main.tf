terraform {
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

variable "project_id" {
  description = "GCP project to create the channels in (monitoring.googleapis.com must be enabled)."
  type        = string
}

variable "email" {
  description = "Address for the example channel."
  type        = string
  default     = "finops@example.com"
}

variable "display_name_prefix" {
  description = "Display name prefix; override per run to keep parallel runs distinguishable."
  type        = string
  default     = "Example"
}

module "channels" {
  source = "../../"

  project_id          = var.project_id
  email_addresses     = [var.email]
  display_name_prefix = var.display_name_prefix

  labels = {
    managed-by = "terraform"
    example    = "basic"
  }
}

output "ids" {
  description = "Channel resource names."
  value       = module.channels.ids
}
