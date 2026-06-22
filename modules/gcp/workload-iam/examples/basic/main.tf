provider "google" {
  project = var.project_id
  region  = var.region
}

# Producers: each Secret Manager instance owns one secret and exports its ID. Instantiate
# the module once per secret.
module "db_password" {
  source = "../../../secret-manager"

  project_id = var.project_id
  secret_id  = "app-db-password"
}

module "api_key" {
  source = "../../../secret-manager"

  project_id = var.project_id
  secret_id  = "app-api-key"
}

# Producer: a GCS bucket. Stays pure — just creates the bucket and exports its name.
module "uploads" {
  source = "../../../gcs"

  project_id = var.project_id
  name       = var.bucket_name
  location   = var.region

  force_destroy = true
}

# Producer: an Artifact Registry repository. Stays pure — exports its name.
module "images" {
  source = "../../../artifact-registry"

  project_id    = var.project_id
  repository_id = var.repository_id
  location      = var.region
  format        = "DOCKER"
}

# Consumer / IAM unit: creates the workload GSA, binds the Kubernetes SA via Workload
# Identity, and grants the GSA read access to the secrets produced above. This mirrors how
# the Terragrunt workload-iam unit takes each secret-manager unit's secret_id as a
# dependency output.
module "workload_identity" {
  source = "../../"

  project_id = var.project_id
  account_id = "example-wi-app"

  kubernetes_namespace       = var.k8s_namespace
  kubernetes_service_account = var.k8s_service_account

  secret_ids = {
    db-password = module.db_password.secret_id
    api-key     = module.api_key.secret_id
  }

  bucket_iam = {
    uploads = { bucket = module.uploads.name, role = "roles/storage.objectUser" }
  }

  artifact_registry_repositories = {
    images = module.images.name
  }
}
