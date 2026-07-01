# aws/ec2-instance

A single EC2 instance — the minimal compute building block. The consumer supplies the AMI, subnet,
security groups, IAM instance profile, and user data as inputs, so the module stays region- and
account-agnostic.

Two security defaults are baked in (not parameterised, since weakening them is rarely intentional):

- **IMDSv2 required** (`http_tokens = "required"`) — the instance metadata service, and the role
  credentials it vends, can only be reached with a session token, closing off the legacy
  unauthenticated IMDSv1 path.
- **Encrypted root volume** — the `gp3` root EBS volume is encrypted at rest.

This module owns **only the instance**. It does not resolve the AMI, create the VPC/subnet/security
group, or define the IAM profile — compose those from other modules or data sources.

## Usage

```hcl
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

module "instance" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/ec2-instance?ref=aws-ec2-instance-vX.Y.Z"

  name      = "app-server"
  ami_id    = data.aws_ssm_parameter.al2023.value
  subnet_id = var.subnet_id

  iam_instance_profile = module.instance_profile.instance_profile_name

  user_data = <<-EOF
    #!/bin/bash
    aws s3 ls
  EOF

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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.52.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID to launch. The consumer resolves this (e.g. the latest Amazon Linux 2023 via an SSM public parameter) so the module stays region-agnostic. | `string` | n/a | yes |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Whether to assign a public IP. Needed when the instance sits in a public subnet and reaches the SSM/AWS endpoints over the internet gateway (no NAT). Default true. | `bool` | `true` | no |
| <a name="input_iam_instance_profile"></a> [iam\_instance\_profile](#input\_iam\_instance\_profile) | Name of the IAM instance profile to attach, granting the instance its role. Null (default) launches with no instance profile. | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type. Default t3.micro — enough for a demo instance. | `string` | `"t3.micro"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name tag for the instance and its root volume. | `string` | n/a | yes |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Size of the root EBS volume in GiB. | `number` | `8` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | ID of the subnet to launch the instance in. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the instance and root volume. | `map(string)` | `{}` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | User data script run at first boot (plain text; the provider base64-encodes it). Null (default) runs nothing. | `string` | `null` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | Security group IDs to attach. Empty (default) uses the VPC's default security group. For SSM-only access no inbound rules are needed — egress is enough. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the EC2 instance. |
| <a name="output_id"></a> [id](#output\_id) | ID of the EC2 instance. Use it with the AWS CLI / SSM (e.g. aws ssm start-session --target <id>). |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Private IPv4 address of the instance. |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Public IPv4 address of the instance, if one was assigned (else empty). |
<!-- END_TF_DOCS -->
