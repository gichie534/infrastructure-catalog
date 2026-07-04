# aws/security-group

A single VPC security group with consumer-supplied ingress/egress rules — the minimal network
access-control building block. Beyond wrapping the raw resource, it gives first-class support for
**security-group-to-security-group** rules: point one rule at another group via
`source_security_group_id` to express "allow this SG from that SG" without hand-writing the AWS
resource.

The module owns **only** the security group and its inline rules. The VPC is passed in as `vpc_id`,
so the module stays region- and account-agnostic.

Defaults chosen for the common case:

- **No ingress** — `ingress_rules` defaults to empty (deny all inbound), the right posture for an
  egress-only workload such as a VPC-attached Lambda.
- **Allow-all egress** — `egress_rules` defaults to a single `0.0.0.0/0` all-protocol rule.

Each rule sets **exactly one** of `cidr_blocks` or `source_security_group_id` (validated).

## Usage

```hcl
module "ec2_sg" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/security-group?ref=aws-security-group-vX.Y.Z"

  name        = "app-server"
  vpc_id      = module.vpc.vpc_id
  description = "App server: HTTP from the Lambda SG only, all egress."

  ingress_rules = [{
    description              = "HTTP from the Lambda function"
    from_port                = 8080
    to_port                  = 8080
    source_security_group_id = module.lambda_sg.id
  }]

  # egress_rules defaults to allow-all.

  tags = {
    Environment = "dev"
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
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_description"></a> [description](#input\_description) | Description for the security group. Defaults to a generic label derived from the name. | `string` | `"Managed by Terraform"` | no |
| <a name="input_egress_rules"></a> [egress\_rules](#input\_egress\_rules) | Outbound rules. Defaults to a single allow-all egress rule (the common case: let the workload<br/>reach anything). Override to constrain egress. | <pre>list(object({<br/>    description              = optional(string, "")<br/>    from_port                = number<br/>    to_port                  = number<br/>    protocol                 = optional(string, "tcp")<br/>    cidr_blocks              = optional(list(string), [])<br/>    source_security_group_id = optional(string)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "cidr_blocks": [<br/>      "0.0.0.0/0"<br/>    ],<br/>    "description": "Allow all outbound",<br/>    "from_port": 0,<br/>    "protocol": "-1",<br/>    "to_port": 0<br/>  }<br/>]</pre> | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | Inbound rules. Each rule opens a port range for either CIDR blocks or another security group<br/>(source\_security\_group\_id) — set exactly one of the two per rule. Empty by default (no inbound),<br/>which is the right posture for egress-only workloads like a VPC-attached Lambda. | <pre>list(object({<br/>    description              = optional(string, "")<br/>    from_port                = number<br/>    to_port                  = number<br/>    protocol                 = optional(string, "tcp")<br/>    cidr_blocks              = optional(list(string), [])<br/>    source_security_group_id = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | Name for the security group. Also applied as the Name tag. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the security group. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC the security group belongs to. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the security group. |
| <a name="output_id"></a> [id](#output\_id) | ID of the security group. Attach it to instances, load balancers, Lambda VPC configs, or reference it as a source in another group's rule. |
| <a name="output_name"></a> [name](#output\_name) | Name of the security group. |
<!-- END_TF_DOCS -->
