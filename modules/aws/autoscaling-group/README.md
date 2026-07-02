# aws/autoscaling-group

An EC2 Auto Scaling group fronted by a launch template, with a single **target-tracking** scaling
policy on fleet-average CPU. The minimal "elastic compute" building block: the group grows when the
average CPU across its instances rises above a target and shrinks when it falls back.

The consumer supplies the AMI, subnets, security groups, IAM instance profile, and user data as
inputs, so the module stays region- and account-agnostic. It owns **only** the launch template, the
Auto Scaling group, and the CPU scaling policy — compose the network and identity from other
modules or data sources.

Two security defaults are baked into the launch template (not parameterised, since weakening them is
rarely intentional):

- **IMDSv2 required** (`http_tokens = "required"`) — the instance metadata service, and the role
  credentials it vends, can only be reached with a session token, closing off the legacy
  unauthenticated IMDSv1 path.
- **Encrypted root volume** — the `gp3` root EBS volume is encrypted at rest.

Scaling uses a `TargetTrackingScaling` policy on the `ASGAverageCPUUtilization` predefined metric.
AWS creates and manages the underlying CloudWatch alarms; you only set a target. A low target (e.g.
`30`–`40`) makes a synthetic CPU load trip scale-out quickly, which is handy for demos.

## Usage

```hcl
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

module "asg" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/autoscaling-group?ref=aws-autoscaling-group-vX.Y.Z"

  name       = "web"
  ami_id     = data.aws_ssm_parameter.al2023.value
  subnet_ids = var.subnet_ids

  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  target_cpu_utilization = 40

  iam_instance_profile = module.instance_profile.instance_profile_name

  tags = {
    Environment = "dev"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name                                                                      | Version |
| ------------------------------------------------------------------------- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0  |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 5.0  |

## Providers

| Name                                              | Version |
| ------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                         | Type     |
| ---------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_autoscaling_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group)  | resource |
| [aws_autoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template)      | resource |

## Inputs

| Name                                                                                                                      | Description                                                                                                                                                                                           | Type           | Default      | Required |
| ------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ------------ | :------: |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id)                                                                    | AMI ID the launch template uses. The consumer resolves this (e.g. the latest Amazon Linux 2023 via an SSM public parameter) so the module stays region-agnostic.                                      | `string`       | n/a          |   yes    |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Whether launched instances get a public IP. Needed when the group sits in public subnets and reaches the SSM/AWS endpoints over the internet gateway (no NAT). Default true.                          | `bool`         | `true`       |    no    |
| <a name="input_desired_capacity"></a> [desired\_capacity](#input\_desired\_capacity)                                      | Initial desired number of instances. Target tracking adjusts this at runtime, so on subsequent applies avoid fighting the policy by leaving it at the baseline.                                       | `number`       | `1`          |    no    |
| <a name="input_estimated_instance_warmup"></a> [estimated\_instance\_warmup](#input\_estimated\_instance\_warmup)         | Seconds to ignore a newly launched instance's metrics while it warms up, so the group doesn't over-scale before new capacity absorbs load.                                                            | `number`       | `120`        |    no    |
| <a name="input_health_check_grace_period"></a> [health\_check\_grace\_period](#input\_health\_check\_grace\_period)       | Seconds after an instance launches before its health check counts, giving user\_data time to run.                                                                                                     | `number`       | `120`        |    no    |
| <a name="input_health_check_type"></a> [health\_check\_type](#input\_health\_check\_type)                                 | Health check type for the group: EC2 (instance status) or ELB (target group health). Use ELB only when the group is attached to a load balancer.                                                      | `string`       | `"EC2"`      |    no    |
| <a name="input_iam_instance_profile"></a> [iam\_instance\_profile](#input\_iam\_instance\_profile)                        | Name of the IAM instance profile to attach to launched instances. Null (default) launches with no instance profile.                                                                                   | `string`       | `null`       |    no    |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type)                                               | EC2 instance type for launched instances. Default t3.micro — enough for a scaling demo.                                                                                                               | `string`       | `"t3.micro"` |    no    |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size)                                                              | Maximum number of instances the group may scale out to.                                                                                                                                               | `number`       | `3`          |    no    |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size)                                                              | Minimum number of instances the group maintains.                                                                                                                                                      | `number`       | `1`          |    no    |
| <a name="input_name"></a> [name](#input\_name)                                                                            | Name prefix for the launch template, Auto Scaling group, and the Name tag on launched instances.                                                                                                      | `string`       | n/a          |   yes    |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size)                                    | Size of the root EBS volume in GiB for launched instances.                                                                                                                                            | `number`       | `8`          |    no    |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids)                                                        | Subnet IDs the Auto Scaling group launches instances into (its vpc\_zone\_identifier). Spread across AZs for resilience.                                                                              | `list(string)` | n/a          |   yes    |
| <a name="input_target_cpu_utilization"></a> [target\_cpu\_utilization](#input\_target\_cpu\_utilization)                  | Target average CPU utilization (percent) for the target-tracking policy. The group scales out above this and in below it. A low value (e.g. 30) makes a stress load trip scale-out quickly for demos. | `number`       | `40`         |    no    |
| <a name="input_tags"></a> [tags](#input\_tags)                                                                            | Tags applied to the launch template and Auto Scaling group, and propagated to launched instances.                                                                                                     | `map(string)`  | `{}`         |    no    |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data)                                                           | User data script run at first boot (plain text; the module base64-encodes it). Null (default) runs nothing.                                                                                           | `string`       | `null`       |    no    |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids)                | Security group IDs to attach to launched instances. Empty (default) uses the VPC's default security group. For SSM-only access no inbound rules are needed — egress is enough.                        | `list(string)` | `[]`         |    no    |

## Outputs

| Name                                                                                                                                 | Description                                                                                                                                    |
| ------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="output_autoscaling_group_arn"></a> [autoscaling\_group\_arn](#output\_autoscaling\_group\_arn)                              | ARN of the Auto Scaling group.                                                                                                                 |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name)                           | Name of the Auto Scaling group. Use it with the AWS CLI (e.g. aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names <name>). |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id)                                       | ID of the launch template the group uses.                                                                                                      |
| <a name="output_launch_template_latest_version"></a> [launch\_template\_latest\_version](#output\_launch\_template\_latest\_version) | Latest version number of the launch template.                                                                                                  |
| <a name="output_scaling_policy_arn"></a> [scaling\_policy\_arn](#output\_scaling\_policy\_arn)                                       | ARN of the CPU target-tracking scaling policy.                                                                                                 |
<!-- END_TF_DOCS -->
