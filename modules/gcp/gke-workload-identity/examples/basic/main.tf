provider "google" {
  project = var.project_id
  region  = var.region
}

# A bucket to grant the KSA read access to (a producer; grants nothing itself).
module "bucket" {
  source = "../../../gcs"

  project_id    = var.project_id
  name          = var.bucket_name
  location      = var.region
  force_destroy = true
}

# Direct WIF: grant the KSA principal object-viewer on the bucket. No GSA is created.
module "workload_identity" {
  source = "../../"

  project_id     = var.project_id
  project_number = var.project_number

  kubernetes_namespace       = "demo"
  kubernetes_service_account = "reader"

  bucket_iam = {
    allowed = {
      bucket = module.bucket.name
      role   = "roles/storage.objectViewer"
    }
  }
}
