# gcp/iap-access

Grants the "who may pass through IAP" permission — `roles/iap.httpsResourceAccessor` — to a set of
principals on an [Identity-Aware Proxy](https://cloud.google.com/iap/docs/concepts-overview)-protected
web resource.

IAP has two halves. **Enabling** IAP on a backend (for GKE, via a `BackendConfig` with
`iap.enabled: true`; for Compute/Cloud Run, on the backend service) turns the authentication gate
**on**. **This module is the other half**: it says *who gets through the gate*. Both are required —
an IAP-enabled backend with no accessor grants rejects everyone.

## Scope

This module grants the role at one of two scopes:

- **Project-wide** (`backend_service = null`, the default) — the grant applies to every
  IAP-protected backend in the project (`google_iap_web_iam_member`). GKE Ingress names its backend
  services dynamically, so project-wide is the pragmatic default for a GKE workload.
- **Per-backend** (`backend_service` set) — the grant is scoped to a single named Compute backend
  service (`google_iap_web_backend_service_iam_member`) for tighter least-privilege control.

## Members

`members` accepts any standard IAM principals: `user:`, `group:`, `serviceAccount:`, `domain:`,
`principal:`, `principalSet:`. A **service account** principal is what enables **programmatic**
(non-browser) access: the caller mints an OIDC token or a self-signed service-account JWT and sends
it as `Authorization: Bearer <token>`. Human/group principals get the interactive browser sign-in
flow.

## Usage

```hcl
module "iap_access" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/iap-access?ref=vX.Y.Z"

  project_id = "my-project"

  members = {
    operator = "user:alice@example.com"
    ci_probe = "serviceAccount:iap-tester@my-project.iam.gserviceaccount.com"
  }
}
```

> Enabling IAP itself is done where the backend lives (a GKE `BackendConfig`, or the backend service
> for Compute/Cloud Run). This module only manages the accessor IAM bindings.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.39.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_iap_settings.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_settings) | resource |
| [google_iap_web_backend_service_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_web_backend_service_iam_member) | resource |
| [google_iap_web_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_web_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_backend_service"></a> [backend\_service](#input\_backend\_service) | Optional name of a specific Compute backend service to scope the grant to. When null (default), access is granted at the project-wide IAP web level (all IAP-protected backends in the project). GKE Ingress creates backend services with generated names, so the project-wide default is usually what a GKE lab wants. | `string` | `null` | no |
| <a name="input_cors_allow_http_options"></a> [cors\_allow\_http\_options](#input\_cors\_allow\_http\_options) | When set, manages IAP settings for this scope so cross-origin preflight requests can reach the backend: true lets HTTP OPTIONS calls skip IAP authorization, false makes IAP apply its normal authorization to them. Leave null (default) to not manage IAP settings at all, which leaves any existing configuration untouched. Set this to true when a browser app on one origin calls an IAP-protected API on another: the preflight OPTIONS request carries no credentials, so IAP would otherwise reject it and the actual request never gets sent. | `bool` | `null` | no |
| <a name="input_members"></a> [members](#input\_members) | IAM members granted access THROUGH IAP (role roles/iap.httpsResourceAccessor), as a map of arbitrary stable label => member. Each value is a standard IAM principal, e.g. "user:alice@example.com", "group:eng@example.com", or "serviceAccount:svc@<project>.iam.gserviceaccount.com". The map keys must be known at plan time. | `map(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project that owns the IAP-protected web resource. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cors_allow_http_options"></a> [cors\_allow\_http\_options](#output\_cors\_allow\_http\_options) | Whether HTTP OPTIONS calls skip IAP authorization for this scope, or null when IAP settings are not managed by this module. |
| <a name="output_members"></a> [members](#output\_members) | The set of IAM principals granted access through IAP. |
| <a name="output_role"></a> [role](#output\_role) | The IAM role granted to every member (roles/iap.httpsResourceAccessor). |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope of the grant: "project" (all IAP-protected backends in the project) or "backend-service" (a single named backend service). |
| <a name="output_settings_resource_name"></a> [settings\_resource\_name](#output\_settings\_resource\_name) | The IAP resource name that IAP settings are managed on, or null when cors\_allow\_http\_options is unset (no settings managed). |
<!-- END_TF_DOCS -->
