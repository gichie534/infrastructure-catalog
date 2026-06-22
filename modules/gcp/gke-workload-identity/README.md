# gcp/gke-workload-identity

Grants Google Cloud IAM roles **directly to a GKE Kubernetes service account (KSA)** using Workload
Identity Federation — the [Google-recommended pattern](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authn-to-gcp)
where the KSA *is* the IAM principal. No Google service account is created, annotated, or
impersonated.

This is the direct-binding alternative to [`gcp/workload-iam`](../workload-iam), which uses the older
GSA-impersonation pattern (the pod runs as a KSA annotated with `iam.gke.io/gcp-service-account` that
impersonates a GSA). Prefer this module for new workloads.

## How a pod authenticates

1. A pod runs under a Kubernetes service account `<namespace>/<ksa>` — no annotation required.
2. GKE Workload Identity exposes that KSA to IAM as a federated principal:

   ```
   principal://iam.googleapis.com/projects/<project_number>/locations/global/workloadIdentityPools/<project_id>.svc.id.goog/subject/ns/<namespace>/sa/<ksa>
   ```

3. IAM roles granted to that principal (this module's job) authorise the pod's calls to Google APIs,
   with short-lived credentials and no exported keys.

The workload identity pool `<project_id>.svc.id.goog` is fixed per project and always present on a
GKE cluster in that project, so this module never references the cluster resource — only
`project_id`, `project_number`, the namespace, and the KSA name.

## Scope

This module owns the IAM grants to the KSA principal:

- a bucket-scoped Cloud Storage grant for each `{ bucket, role }` pair in `bucket_iam`;
- the project-level roles in `project_roles` (this is also how Cloud SQL access is granted —
  `roles/cloudsql.client` / `roles/cloudsql.instanceUser` — since Cloud SQL has no per-instance IAM
  resource).

It is intentionally minimal. **To support another resource kind** (Secret Manager secrets, Cloud DNS
zones, Artifact Registry repos, KMS keys, …) add one typed map input and one matching
`google_<service>_iam_member` resource that sets `member = local.ksa_principal`. The principal string
is computed once in `main.tf` and reused, so each new resource kind is a localized addition.

## How it fits together

Producer modules stay pure: [`gcp/gcs`](../gcs) exports a bucket name. This unit takes
those identifiers and grants the KSA principal access. With Terragrunt, declare `dependency` blocks
on the producer units and feed their outputs in (e.g. `bucket_iam = { allowed = { bucket =
dependency.bucket.outputs.name, role = "roles/storage.objectViewer" } }`).

## Usage

```hcl
module "workload_identity" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/gke-workload-identity?ref=vX.Y.Z"

  project_id     = "my-project"
  project_number = "123456789012"

  kubernetes_namespace       = "default"
  kubernetes_service_account = "app"

  bucket_iam = {
    uploads = {
      bucket = module.bucket.name
      role   = "roles/storage.objectViewer"
    }
  }
}
```
