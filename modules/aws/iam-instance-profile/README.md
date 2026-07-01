# aws/iam-instance-profile

The minimal IAM identity for an EC2 instance: an IAM role that the **EC2 service** can assume, plus
the **instance profile** that hands that role to a running instance. Attach capabilities two ways:

- `managed_policy_arns` — existing AWS-managed or customer-managed policies (e.g.
  `AmazonSSMManagedInstanceCore` so the instance is reachable via SSM Session Manager).
- `inline_policies` — narrow, workload-specific least-privilege JSON documents embedded on the role
  (e.g. a single `s3:ListAllMyBuckets` grant).

This module owns **only the identity** (role + instance profile + policy wiring). It does not create
the EC2 instance and bakes in no permissions of its own — the consumer decides exactly what the role
can do. Keeping it single-purpose keeps it reusable across labs.

## Usage

```hcl
data "aws_iam_policy_document" "s3_list" {
  statement {
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }
}

module "instance_profile" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/iam-instance-profile?ref=aws-iam-instance-profile-vX.Y.Z"

  name = "app-server"

  # SSM Session Manager access (no SSH key, no inbound port 22).
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  # Least-privilege workload grant.
  inline_policies = {
    s3-list = data.aws_iam_policy_document.s3_list.json
  }

  tags = {
    Environment = "dev"
  }
}
```

Then attach it to an instance via `iam_instance_profile = module.instance_profile.instance_profile_name`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.52.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_inline_policies"></a> [inline\_policies](#input\_inline\_policies) | Map of inline least-privilege policies to embed in the role, keyed by policy name. Each value is<br/>a JSON IAM policy document (typically from an `aws_iam_policy_document` data source). Use this for<br/>the narrow, workload-specific grants that don't warrant a standalone managed policy — e.g. a<br/>single `s3:ListAllMyBuckets` statement. Empty by default. | `map(string)` | `{}` | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | ARNs of existing (AWS-managed or customer-managed) IAM policies to attach to the role. Use this<br/>for capabilities that AWS already ships a policy for — e.g. `AmazonSSMManagedInstanceCore` to let<br/>the instance be reached via SSM Session Manager. Empty by default. | `list(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the IAM role and instance profile. Both resources share this name. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the IAM role (the taggable resource this module creates). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_instance_profile_arn"></a> [instance\_profile\_arn](#output\_instance\_profile\_arn) | ARN of the instance profile. |
| <a name="output_instance_profile_name"></a> [instance\_profile\_name](#output\_instance\_profile\_name) | Name of the instance profile. Pass this to an EC2 instance's iam\_instance\_profile. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the IAM role. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the IAM role. Use it to attach further policies from a consumer if needed. |
<!-- END_TF_DOCS -->
