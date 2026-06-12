# gcp/workload-iam

The IAM unit for a GKE workload. It is the single home for everything that expresses "this workload
is allowed to do X": the workload's Google service account, the Workload Identity binding that lets
a Kubernetes service account impersonate it, and the resource grants it needs.

## Scope

This module owns:

- a `google_service_account` (the GSA the pod runs as);
- the `roles/iam.workloadIdentityUser` binding from `<project>.svc.id.goog[<namespace>/<ksa>]` to that GSA;
- a `roles/secretmanager.secretAccessor` grant on each secret in `secret_ids`, scoped to the secret;
- the project-level roles in `project_roles` (e.g. `roles/cloudsql.client`, `roles/cloudsql.instanceUser`);
- a bucket-scoped Cloud Storage grant for each `{ bucket, role }` pair in `bucket_iam`;
- a `roles/artifactregistry.reader` grant on each repository in `artifact_registry_repositories`, scoped to the repo.

Producer modules stay pure: [`gcp/secret-manager`](../secret-manager) exports a secret ID,
[`gcp/gcs-bucket`](../gcs-bucket) exports a bucket name, [`gcp/artifact-registry`](../artifact-registry)
exports a repository name, and [`gcp/gke`](../gke) exports cluster facts. This unit collects their
identifiers and centralises the workload's cross-service permissions. As the workload gains access to
more resources, add those grants here.

## How a pod authenticates

1. The pod runs under a Kubernetes SA annotated with `iam.gke.io/gcp-service-account = <service_account_email>`.
2. The Workload Identity binding lets that KSA impersonate the GSA — no exported keys.
3. The GSA's grants (e.g. secret accessor) authorise the pod's calls to Google APIs.

## How it fits together

With Terragrunt, this unit declares `dependency` blocks on the producer units and feeds their
outputs in — e.g. `secret_ids = dependency.secret_manager.outputs.secret_ids`.

## Usage

```hcl
module "workload_identity" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/workload-iam?ref=vX.Y.Z"

  project_id = "my-project"
  account_id = "platform-app"

  kubernetes_namespace       = "default"
  kubernetes_service_account = "app"

  secret_ids = values(module.secrets.secret_ids)
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.35 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_artifact_registry_repository_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_project_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_secret_manager_secret_iam_member.accessor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_bucket_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | The account\_id (local part) of the workload Google service account to create. The full email becomes <account\_id>@<project\_id>.iam.gserviceaccount.com. | `string` | n/a | yes |
| <a name="input_artifact_registry_repositories"></a> [artifact\_registry\_repositories](#input\_artifact\_registry\_repositories) | Artifact Registry repositories the workload may pull from, as a map of arbitrary stable label => fully-qualified repository name (projects/<p>/locations/<loc>/repositories/<id>). Wire each value from an artifact-registry module's name output. The map keys must be known at plan time. The GSA is granted roles/artifactregistry.reader on each. Note: GKE image pulls usually authenticate as the node service account, not the workload GSA. | `map(string)` | `{}` | no |
| <a name="input_bucket_iam"></a> [bucket\_iam](#input\_bucket\_iam) | GCS bucket access to grant the workload GSA, as a map of arbitrary stable label => { bucket, role } (e.g. role roles/storage.objectViewer or roles/storage.objectUser). Wire bucket from the gcs-bucket module's name output. The map keys must be known at plan time. Each entry becomes a bucket-scoped IAM member. | <pre>map(object({<br/>    bucket = string<br/>    role   = string<br/>  }))</pre> | `{}` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Human-readable display name for the workload service account. | `string` | `"Workload identity service account"` | no |
| <a name="input_kubernetes_namespace"></a> [kubernetes\_namespace](#input\_kubernetes\_namespace) | Kubernetes namespace of the service account that impersonates the GSA via Workload Identity. | `string` | n/a | yes |
| <a name="input_kubernetes_service_account"></a> [kubernetes\_service\_account](#input\_kubernetes\_service\_account) | Kubernetes service account name (within kubernetes\_namespace) that the pod runs as and that impersonates the GSA. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project that owns the workload's Google service account and the secrets it accesses. | `string` | n/a | yes |
| <a name="input_project_roles"></a> [project\_roles](#input\_project\_roles) | Project-level IAM roles to grant the workload GSA (e.g. roles/cloudsql.client and roles/cloudsql.instanceUser for Cloud SQL IAM auth). Resource-scoped access (like secret access) is handled by its own input, not here. | `set(string)` | `[]` | no |
| <a name="input_secret_ids"></a> [secret\_ids](#input\_secret\_ids) | Secret Manager secrets the workload may read, as a map of arbitrary stable label => fully-qualified secret ID (projects/<project>/secrets/<name>). Wire each value from a secret-manager module's secret\_id output. The map keys must be known at plan time (don't derive them from resource attributes). The GSA is granted roles/secretmanager.secretAccessor on each. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the workload Google service account. Annotate the Kubernetes service account with this (iam.gke.io/gcp-service-account) to complete Workload Identity. |
| <a name="output_service_account_id"></a> [service\_account\_id](#output\_service\_account\_id) | Fully-qualified ID of the workload Google service account (projects/<project>/serviceAccounts/<email>). |
<!-- END_TF_DOCS -->
