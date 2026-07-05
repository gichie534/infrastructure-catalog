# aws/ecr

A single **ECR repository** to store an application's container images — the AWS analogue of a
`gcp/artifact-registry` repo. Hardened by default: images are **encrypted at rest** (AES256) and
**scanned on push**. The module owns only the repository and an optional lifecycle policy; **who may
push/pull is an IAM concern** left to the consumer (typically a CI role from the `oidc-federation`
module scoped to this repo's ARN).

- **Tag mutability** is configurable (`MUTABLE` by default so a rolling tag like `dev` can be
  re-pushed; `IMMUTABLE` to forbid overwriting a tag).
- **`untagged_image_expiry_days`** optionally attaches a lifecycle policy that expires orphaned
  (untagged) images after a retention window.
- **`force_delete`** lets a throwaway lab repo be destroyed without emptying it first.

## Usage

```hcl
module "ecr" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/aws/ecr?ref=aws-ecr-v0.1.0"

  name                       = "my-app"
  force_delete               = true # throwaway lab
  untagged_image_expiry_days = 7

  tags = {
    Environment = "lab"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.53.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_force_delete"></a> [force\_delete](#input\_force\_delete) | Allow Terraform to delete the repository even when it still contains images. Set true in throwaway lab environments so `terraform destroy` tears down cleanly. | `bool` | `false` | no |
| <a name="input_image_tag_mutability"></a> [image\_tag\_mutability](#input\_image\_tag\_mutability) | Whether image tags can be overwritten. MUTABLE lets a tag (e.g. "dev") be re-pushed; IMMUTABLE forbids overwriting an existing tag. | `string` | `"MUTABLE"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the ECR repository (e.g. "my-app"). Lowercase; may contain slashes for namespacing (e.g. "team/my-app"). | `string` | n/a | yes |
| <a name="input_scan_on_push"></a> [scan\_on\_push](#input\_scan\_on\_push) | Run a basic vulnerability scan automatically when an image is pushed. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the repository. | `map(string)` | `{}` | no |
| <a name="input_untagged_image_expiry_days"></a> [untagged\_image\_expiry\_days](#input\_untagged\_image\_expiry\_days) | When set, attach a lifecycle policy that expires untagged images older than this many days — keeps a repo from accumulating orphaned layers. Leave null (default) for no lifecycle policy. | `number` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the repository. Use it to scope an IAM policy granting push/pull to a CI role. |
| <a name="output_name"></a> [name](#output\_name) | Name of the repository. |
| <a name="output_registry_id"></a> [registry\_id](#output\_registry\_id) | The account ID of the registry holding the repository. |
| <a name="output_repository_url"></a> [repository\_url](#output\_repository\_url) | URL of the repository (<account>.dkr.ecr.<region>.amazonaws.com/<name>). Tag and push images here, and reference it as the container image (with a tag) in a task definition. |
<!-- END_TF_DOCS -->
