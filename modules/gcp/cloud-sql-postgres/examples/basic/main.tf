provider "google" {
  project = var.project_id
  region  = var.region
}

# Network with Private Service Access so Cloud SQL can get a private IP.
module "vpc" {
  source = "../../../vpc"

  name       = "example-sql"
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

# --- Workload IAM: GSA + project roles + Workload Identity binding ----------
# The workload-iam module owns the workload's identity and all its grants: it creates the
# GSA, binds the Kubernetes SA to it via Workload Identity, and grants the project roles
# Cloud SQL IAM auth needs (cloudsql.client + cloudsql.instanceUser). The cloud-sql module
# below just registers that GSA as an IAM database user.
module "workload_iam" {
  source = "../../../workload-iam"

  project_id = var.project_id
  account_id = "example-sql-app"

  kubernetes_namespace       = var.k8s_namespace
  kubernetes_service_account = var.k8s_service_account

  project_roles = ["roles/cloudsql.client", "roles/cloudsql.instanceUser"]
}

module "cloud_sql" {
  source = "../../"

  name       = "example-pg"
  project_id = var.project_id
  region     = var.region
  network    = module.vpc.network_self_link

  iam_service_account_emails = [module.workload_iam.service_account_email]

  # Examples/tests must be destroyable.
  deletion_protection = false

  # A private-IP instance can only be created once the VPC's Private Service Access
  # peering exists. The module only receives the network self link, so it can't see
  # the peering connection — sequence it here at the composition level.
  depends_on = [module.vpc]
}
