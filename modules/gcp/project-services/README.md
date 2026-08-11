# gcp/project-services

Enables one or more Google APIs on an **existing** project. This is the pragmatic counterpart to
[`gcp/project`](../project) (which creates a project and activates APIs as part of that): a project
provisioned manually or out-of-band that just needs an additional API turned on later — e.g.
`iap.googleapis.com` before wiring up Identity-Aware Proxy — without importing the whole project
resource into a module's state.

## Scope

This module owns:

- `google_project_service` resources for each entry in `activate_apis`, on an existing project.

It deliberately does **not** own:

- the project resource itself (see [`gcp/project`](../project) for that);
- disabling APIs on destroy (`disable_on_destroy` is hardcoded `false` — removing this module from a
  config never disables a shared project API out from under other consumers).

## Usage

```hcl
module "iap_api" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/project-services?ref=vX.Y.Z"

  project_id    = "my-project"
  activate_apis = ["iap.googleapis.com"]
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
| <a name="provider_google"></a> [google](#provider\_google) | 7.44.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_activate_apis"></a> [activate\_apis](#input\_activate\_apis) | Set of Google API service names to enable on the project, e.g. ["iap.googleapis.com"]. | `set(string)` | n/a | yes |
| <a name="input_disable_dependent_services"></a> [disable\_dependent\_services](#input\_disable\_dependent\_services) | Whether to also disable services that depend on a service being disabled (only takes effect on disable, which this module never does since disable\_on\_destroy is hardcoded false; kept as a passthrough for forward compatibility). | `bool` | `true` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the EXISTING project to enable APIs on. This module never creates or manages the project resource itself. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_enabled_apis"></a> [enabled\_apis](#output\_enabled\_apis) | The set of API service names this module enabled on the project. |
<!-- END_TF_DOCS -->
