# gcp/artifact-registry

Creates a single Artifact Registry repository and exports its identifiers. Nothing else — this
module grants no access. Instantiate it once per repository.

## Scope

This module owns:

- one `google_artifact_registry_repository`. For `DOCKER` repositories, **immutable tags** are
  hardcoded on so a pushed tag can't be silently overwritten.

It deliberately does **not** own:

- **access policy** — reader/writer IAM is granted by the consumer that needs it (see
  [`gcp/workload-iam`](../workload-iam)), so the repo's access lives with the workload
  rather than with this producer.

## How it fits together

This is a pure producer. A workload's IAM unit takes the `name` output and grants its Google service
account `roles/artifactregistry.reader` on the repo. With Terragrunt, the `workload-iam` unit
declares a `dependency` on this unit and reads `name`.

> Note: GKE image pulls usually authenticate as the cluster's **node** service account, not the
> pod's Workload Identity GSA. Granting the reader role to the workload GSA covers in-pod API access
> to the registry; node-level pull access is a separate, node-SA concern.

## Usage

```hcl
module "repository" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/artifact-registry?ref=vX.Y.Z"

  project_id    = "my-project"
  repository_id = "app-images"
  location      = "us-central1"
  format        = "DOCKER"
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
| [google_artifact_registry_repository.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_description"></a> [description](#input\_description) | Human-readable description of the repository. | `string` | `""` | no |
| <a name="input_format"></a> [format](#input\_format) | Artifact format of the repository (e.g. DOCKER, MAVEN, NPM, PYTHON). Immutable tags are enforced for DOCKER repositories. | `string` | `"DOCKER"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels applied to the repository. | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Location of the repository (e.g. us-central1). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the repository. | `string` | n/a | yes |
| <a name="input_repository_id"></a> [repository\_id](#input\_repository\_id) | The ID (name) of the repository. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_location"></a> [location](#output\_location) | The location the repository lives in. |
| <a name="output_name"></a> [name](#output\_name) | The fully-qualified repository name (projects/<project>/locations/<location>/repositories/<id>). Wire this into the workload-iam module to grant reader/writer IAM. |
| <a name="output_registry_url"></a> [registry\_url](#output\_registry\_url) | The host/path prefix for artifact references, e.g. <location>-docker.pkg.dev/<project>/<repo> for DOCKER. The host segment reflects the repository format. |
| <a name="output_repository_id"></a> [repository\_id](#output\_repository\_id) | The short repository ID (name). |
<!-- END_TF_DOCS -->
