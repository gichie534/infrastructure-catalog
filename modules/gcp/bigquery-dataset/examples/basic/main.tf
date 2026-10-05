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
  description = "GCP project to create the dataset in (bigquery.googleapis.com must be enabled)."
  type        = string
}

variable "dataset_id" {
  description = "Dataset ID; override per run to avoid collisions."
  type        = string
  default     = "example_dataset"
}

# An empty multi-region dataset of the shape a billing export wants. An empty dataset costs nothing.
module "dataset" {
  source = "../../"

  project_id  = var.project_id
  dataset_id  = var.dataset_id
  location    = "US"
  description = "Example dataset (gcp/bigquery-dataset examples/basic)."

  # Example only: lets the test tear down cleanly. Keep the default (false) for real data.
  delete_contents_on_destroy = true

  labels = {
    managed-by = "terraform"
    example    = "basic"
  }
}

output "dataset_id" {
  description = "Dataset ID."
  value       = module.dataset.dataset_id
}

output "location" {
  description = "Dataset location."
  value       = module.dataset.location
}

output "fully_qualified_name" {
  description = "<project>.<dataset_id>."
  value       = module.dataset.fully_qualified_name
}
