# gcp/secret-manager

Creates a single Secret Manager **secret container** and exports its ID. Nothing else — this module
grants no access and stores no value. Instantiate it once per secret.

## Scope

This module owns:

- one `google_secret_manager_secret`, with automatic replication.

It deliberately does **not** own:

- **the secret value (version)** — added out-of-band by apps/CI;
- **access policy** — accessor IAM is granted by the consumer that needs it (see
  [`gcp/workload-iam`](../workload-iam)), so the secret's access lives with the workload
  rather than with this producer.

## How it fits together

This is a pure producer. A workload's IAM unit takes the `secret_id` output and grants its Google
service account `roles/secretmanager.secretAccessor` on the secret. With Terragrunt, the
`workload-iam` unit declares a `dependency` on this unit and reads `secret_id`.

## Usage

```hcl
module "secret" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/secret-manager?ref=vX.Y.Z"

  project_id = "my-project"
  secret_id  = "app-db-password"
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
| [google_secret_manager_secret.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels applied to the secret. | `map(string)` | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the secret. | `string` | n/a | yes |
| <a name="input_secret_id"></a> [secret\_id](#input\_secret\_id) | The secret ID (name) to create. The module creates one empty secret container; the value (version) is added out-of-band by apps/CI, not by this module. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_secret_id"></a> [secret\_id](#output\_secret\_id) | The fully-qualified resource ID of the secret (projects/<project>/secrets/<name>). Wire this into the workload-iam module to grant accessor IAM. |
| <a name="output_secret_name"></a> [secret\_name](#output\_secret\_name) | The short secret\_id, as referenced by application code at access time. |
<!-- END_TF_DOCS -->
