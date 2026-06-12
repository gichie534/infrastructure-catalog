# The workload's IAM unit. It owns everything that says "this workload is allowed to do X":
#
#   - the Google service account (GSA) the pod runs as;
#   - the Workload Identity binding that lets the Kubernetes SA impersonate that GSA;
#   - the per-secret accessor grants on the secret IDs it is handed.
#
# Producer modules (gke, secret-manager, ...) stay pure and just export identifiers; this
# unit collects them and is the single home for the workload's cross-service permissions.
# As the workload accrues access to more resources (buckets, registries, ...), add the
# corresponding grants here.

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
}

# Let the Kubernetes SA <namespace>/<name> impersonate the GSA. The pod then authenticates
# to Google APIs as the GSA with no exported key.
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${var.kubernetes_service_account}]"
}

# Grant the GSA read access to each supplied secret, scoped to the secret itself.
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = var.secret_ids

  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.this.email}"
}

# Grant the GSA project-level roles (e.g. Cloud SQL client/instanceUser for IAM DB auth).
resource "google_project_iam_member" "this" {
  for_each = var.project_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

# Grant the GSA access to each supplied bucket/role pair, scoped to the bucket itself.
resource "google_storage_bucket_iam_member" "this" {
  for_each = var.bucket_iam

  bucket = each.value.bucket
  role   = each.value.role
  member = "serviceAccount:${google_service_account.this.email}"
}

# Grant the GSA read access to each supplied Artifact Registry repo, scoped to the repo.
resource "google_artifact_registry_repository_iam_member" "this" {
  for_each = var.artifact_registry_repositories

  repository = each.value
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.this.email}"
}
