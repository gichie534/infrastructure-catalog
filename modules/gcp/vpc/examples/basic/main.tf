provider "google" {
  project = var.project_id
  region  = var.region
}

module "vpc" {
  source = "../../"

  name       = "example-gke-vpc"
  project_id = var.project_id

  subnets = [
    {
      name                = "gke"
      region              = var.region
      ip_cidr_range       = "10.0.0.0/20"
      pods_cidr_range     = "10.16.0.0/14"
      services_cidr_range = "10.20.0.0/20"
    },
  ]

  # Private Google services access (servicenetworking peering) and Cloud NAT
  # for private node egress are enabled by default.
}
