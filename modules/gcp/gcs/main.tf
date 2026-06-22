# A single Cloud Storage bucket. This module owns only the bucket and exports its name; it
# grants no access. A consumer (e.g. the workload-iam module) wires bucket IAM against the
# exported name, keeping the bucket's access policy with the workload that needs it.
#
# Uniform bucket-level access and enforced public access prevention are hardcoded on: they
# are the secure baseline and are required for the IAM-via-workload-iam approach to be clean.
resource "google_storage_bucket" "this" {
  project  = var.project_id
  name     = var.name
  location = var.location
  labels   = var.labels

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  force_destroy = var.force_destroy
}
