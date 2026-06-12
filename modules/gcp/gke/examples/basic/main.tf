provider "google" {
  project = var.project_id
  region  = var.region
}

# Network for the cluster, built from the sibling vpc module. The cluster consumes
# the VPC's outputs (network/subnet self links and secondary range names).
module "vpc" {
  source = "../../../vpc"

  name       = "example-gke"
  project_id = var.project_id

  subnets = [
    {
      name                = "nodes"
      region              = var.region
      ip_cidr_range       = "10.0.0.0/20"
      pods_cidr_range     = "10.16.0.0/14"
      services_cidr_range = "10.20.0.0/20"
      pods_range_name     = "pods"
      services_range_name = "services"
    },
  ]

  # Cloud NAT (default on) gives the private nodes egress; PSA (default on) is fine to keep.
}

module "gke" {
  source = "../../"

  name       = "example-autopilot"
  project_id = var.project_id
  region     = var.region

  network             = module.vpc.network_self_link
  subnetwork          = module.vpc.subnets_self_links["nodes"]
  pods_range_name     = "pods"
  services_range_name = "services"

  # Public control-plane endpoint, locked to the supplied authorized networks.
  enable_private_endpoint    = false
  master_authorized_networks = var.master_authorized_networks

  # Examples/tests must be destroyable.
  deletion_protection = false
}
