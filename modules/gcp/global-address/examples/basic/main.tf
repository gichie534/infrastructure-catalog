provider "google" {
  project = var.project_id
  region  = var.region
}

module "global_address" {
  source = "../../"

  project_id  = var.project_id
  name        = "example-ingress-ip"
  description = "Example reserved global IP for a GKE classic Ingress"
}
