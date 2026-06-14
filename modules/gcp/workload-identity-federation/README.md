# gcp/workload-identity-federation

Workload Identity Federation (WIF): lets **external OIDC identities** act as Google service
accounts **without exporting long-lived service-account keys**. An external workload (GitHub
Actions, GitLab CI, Terraform Cloud, another cloud) presents a short-lived OIDC token; GCP's
Security Token Service validates it against a pool provider and returns a federated credential that
can impersonate a bound service account.

This module is deliberately **IdP-neutral**. It owns the *mechanism* — the pool, its OIDC
providers, the attribute mapping/condition, and the `workloadIdentityUser` bindings — while the
*policy* (which issuer, which claims to gate on, which GSA to bind) is supplied as inputs. GitHub
is just one possible provider entry. It does **not** create the service account; pair it with the
[`gcp/workload-iam`](../workload-iam) module (or any GSA) and wire that account's ID into
`service_account_bindings`.

## Usage

```hcl
module "wif" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/workload-identity-federation?ref=gcp-workload-identity-federation-vX.Y.Z"

  project_id        = "my-project"
  pool_id           = "github-ci"
  pool_display_name = "GitHub CI"

  oidc_providers = {
    github = {
      issuer_uri = "https://token.actions.githubusercontent.com"
      attribute_mapping = {
        "google.subject"       = "assertion.sub"
        "attribute.repository" = "assertion.repository"
      }
      attribute_condition = "assertion.repository == \"octo-org/my-repo\""
    }
  }

  service_account_bindings = {
    deployer = {
      service_account_id = module.workload_iam.service_account_id
      principal_set      = "attribute.repository/octo-org/my-repo"
    }
  }
}
```

The consuming CI then federates with `provider_names["github"]` and impersonates the bound service
account — no JSON key anywhere.

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
| [google_iam_workload_identity_pool.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_service_account_iam_member.workload_identity_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_oidc_providers"></a> [oidc\_providers](#input\_oidc\_providers) | OIDC providers to attach to the pool, keyed by provider ID. The module is IdP-neutral: each entry<br/>describes one external issuer (GitHub Actions, GitLab CI, Terraform Cloud, another cloud, ...).<br/><br/>- issuer\_uri:          the provider's OIDC issuer URL (e.g. https://token.actions.githubusercontent.com).<br/>- attribute\_mapping:   map of Google STS attributes to assertion expressions. Must map google.subject.<br/>                       Add attribute.<name> entries for any claim you want to gate on later.<br/>- attribute\_condition: optional CEL expression that an incoming token must satisfy to be accepted<br/>                       (the security gate, e.g. restrict to one repo/owner). Strongly recommended.<br/>- allowed\_audiences:   optional list of accepted audiences. Empty means GCP accepts the provider's<br/>                       default audience (the full provider resource URL), which suits most setups. | <pre>map(object({<br/>    issuer_uri          = string<br/>    attribute_mapping   = map(string)<br/>    attribute_condition = optional(string)<br/>    allowed_audiences   = optional(list(string), [])<br/>    display_name        = optional(string)<br/>    description         = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_pool_description"></a> [pool\_description](#input\_pool\_description) | Description of the Workload Identity Pool. | `string` | `"Federates external OIDC identities to Google service accounts."` | no |
| <a name="input_pool_display_name"></a> [pool\_display\_name](#input\_pool\_display\_name) | Human-readable display name for the Workload Identity Pool. | `string` | `"Workload Identity Pool"` | no |
| <a name="input_pool_id"></a> [pool\_id](#input\_pool\_id) | ID of the Workload Identity Pool to create (the last path segment of its resource name). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project that owns the Workload Identity Pool and its providers. | `string` | n/a | yes |
| <a name="input_service_account_bindings"></a> [service\_account\_bindings](#input\_service\_account\_bindings) | Grants federated identities permission to impersonate Google service accounts via<br/>roles/iam.workloadIdentityUser, keyed by an arbitrary stable label.<br/><br/>- service\_account\_id: fully-qualified GSA resource ID (projects/<p>/serviceAccounts/<email>).<br/>                      Wire this from the workload-iam module's service\_account\_id output.<br/>- principal\_set:      the member suffix appended to the pool resource name. Use an attribute<br/>                      selector to scope to matching identities, e.g.<br/>                      "attribute.repository/OWNER/REPO" (all tokens whose repository attribute<br/>                      equals OWNER/REPO), or "*" for every identity in the pool.<br/><br/>The module assembles the full principalSet:// member from the pool name and this suffix, so<br/>callers never hardcode the project number. | <pre>map(object({<br/>    service_account_id = string<br/>    principal_set      = string<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_pool_id"></a> [pool\_id](#output\_pool\_id) | The short ID of the Workload Identity Pool. |
| <a name="output_pool_name"></a> [pool\_name](#output\_pool\_name) | The full resource name of the Workload Identity Pool (projects/<num>/locations/global/workloadIdentityPools/<id>). Used to build principalSet members and the audience. |
| <a name="output_provider_ids"></a> [provider\_ids](#output\_provider\_ids) | Map of provider ID to its short workload\_identity\_pool\_provider\_id. |
| <a name="output_provider_names"></a> [provider\_names](#output\_provider\_names) | Map of provider ID to its full resource name. The provider name is what external CI passes as the federation provider (e.g. GitHub's workload\_identity\_provider input). |
<!-- END_TF_DOCS -->
