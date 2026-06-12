provider "google" {
  project = var.project_id
  region  = var.region
}

# A VPC for the private zone to attach to. Private zones resolve only on their networks.
module "vpc" {
  source = "../../../vpc"

  name       = "example-dns"
  project_id = var.project_id

  subnets = [
    {
      name                = "nodes"
      region              = var.region
      ip_cidr_range       = "10.0.0.0/20"
      pods_cidr_range     = "10.16.0.0/14"
      services_cidr_range = "10.20.0.0/20"
    },
  ]
}

# A private zone for internal GKE service discovery, with a couple of records.
module "dns" {
  source = "../../"

  project_id = var.project_id
  name       = "example-internal"
  dns_name   = "internal.example.com."
  visibility = "private"
  networks   = [module.vpc.network_self_link]

  records = {
    "api" = { type = "A", rrdatas = ["10.0.0.10"] }
    "db"  = { type = "CNAME", ttl = 600, rrdatas = ["api.internal.example.com."] }
  }
}
