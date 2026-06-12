# A single Secret Manager secret container. This module owns only the secret itself and
# exports its ID; it grants no access. A consumer (e.g. the workload-iam module) wires
# accessor IAM against the exported secret_id, keeping the secret's access policy with the
# workload that needs it rather than with this producer.
#
# The secret value (version) is added out-of-band by apps/CI — this module creates an empty
# container only.
resource "google_secret_manager_secret" "this" {
  project   = var.project_id
  secret_id = var.secret_id
  labels    = var.labels

  replication {
    auto {}
  }
}
