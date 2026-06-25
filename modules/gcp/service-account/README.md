# gcp/service-account

A plain Google service account, optionally with project-level role grants and a set of principals
allowed to impersonate it.

This is the general-purpose "create a service account" primitive. Unlike
[`gcp/workload-iam`](../workload-iam) it carries **no** GKE Workload Identity assumptions, so it
suits CI probes, automation identities, and service-account JWT/OIDC flows — for example, an identity
that authenticates to an IAP-secured endpoint by minting a self-signed JWT or an OIDC ID token.

## Scope

This module owns:

- a `google_service_account`;
- the project-level roles in `project_roles`, granted **to** the service account;
- a `roles/iam.serviceAccountTokenCreator` grant **on** the service account for each principal in
  `token_creators`, letting them impersonate it to mint short-lived credentials without an exported
  key.

Resource-scoped grants (a bucket, a secret, IAP access, …) belong on the resource's own module — e.g.
pass this module's `member` output to [`gcp/iap-access`](../iap-access).

## Usage

```hcl
module "iap_probe_sa" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/service-account?ref=vX.Y.Z"

  project_id   = "my-project"
  account_id   = "iap-tester"
  display_name = "IAP connectivity probe"

  # Let the operator impersonate it to mint tokens for testing.
  token_creators = {
    operator = "user:alice@example.com"
  }
}

module "iap_access" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/iap-access?ref=vX.Y.Z"

  project_id = "my-project"
  members    = { probe = module.iap_probe_sa.member }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_project_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.token_creators](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | The account\_id (local part) of the service account. The full email becomes <account\_id>@<project\_id>.iam.gserviceaccount.com. | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Human-readable description for the service account. | `string` | `"Managed by Terraform"` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Human-readable display name for the service account. | `string` | `"Service account"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project that owns the service account. | `string` | n/a | yes |
| <a name="input_project_roles"></a> [project\_roles](#input\_project\_roles) | Project-level IAM roles to grant the service account, as a set of role IDs (each starting with roles/). | `set(string)` | `[]` | no |
| <a name="input_token_creators"></a> [token\_creators](#input\_token\_creators) | IAM principals granted roles/iam.serviceAccountTokenCreator ON this service account, as a map of arbitrary stable label => member (e.g. "user:alice@example.com"). This lets them impersonate the account to mint short-lived credentials (OIDC ID tokens, signed JWTs) without a key. The map keys must be known at plan time. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_email"></a> [email](#output\_email) | Email of the service account (<account\_id>@<project\_id>.iam.gserviceaccount.com). |
| <a name="output_id"></a> [id](#output\_id) | Fully-qualified ID of the service account (projects/<project>/serviceAccounts/<email>). |
| <a name="output_member"></a> [member](#output\_member) | The IAM member string for the service account (serviceAccount:<email>), ready to pass to other IAM grants. |
| <a name="output_name"></a> [name](#output\_name) | The resource name of the service account (projects/<project>/serviceAccounts/<unique\_id>). |
| <a name="output_unique_id"></a> [unique\_id](#output\_unique\_id) | The numeric unique ID of the service account. |
<!-- END_TF_DOCS -->
