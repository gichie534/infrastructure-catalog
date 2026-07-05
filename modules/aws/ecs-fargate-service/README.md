# aws/ecs-fargate-service

A **Fargate ECS service** and everything a single containerised workload needs around it: a task
definition, the service that keeps N copies running, the two IAM roles a task uses (execution + task
role), a CloudWatch log group, and — optionally — a security group for the task ENIs. Wire it behind
a load balancer by passing a `target_group_arn` (use `target_type = ip` on the target group, which
awsvpc/Fargate requires). The cluster, load balancer, subnets, and image are supplied by the
consumer, keeping the module region/account-agnostic.

## Deployment ownership (important)

By default (`ignore_task_definition_changes = true`) the module creates the service with a
**bootstrap** task definition and then **stops managing which revision runs**. A CI pipeline is
expected to register new task-definition revisions (new image tags) and update the service; because
Terraform ignores `task_definition` and `desired_count`, it won't revert those deployments on the
next `apply`. This is the clean split between *infrastructure* (Terraform) and *the app rollout* (CI)
— analogous to Terraform standing up a cluster while Helm owns the deployment.

Set `ignore_task_definition_changes = false` to have Terraform fully own the running revision (handy
for tests or purely-Terraform workflows).

## Networking

`awsvpc` mode gives every task its own ENI. Run tasks in **public subnets with
`assign_public_ip = true`** to pull images and reach AWS APIs over the internet gateway (no NAT
gateway — cheapest for a lab), or in **private subnets** with a NAT gateway / VPC endpoints. Lock the
task security group down to just the load balancer via `ingress_security_group_ids`.

## Usage

```hcl
module "service" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/aws/ecs-fargate-service?ref=aws-ecs-fargate-service-v0.1.0"

  name        = "hello"
  cluster_arn = module.ecs_cluster.cluster_arn

  container_image = "${module.ecr.repository_url}:bootstrap" # CI ships real tags later
  container_port  = 8080

  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.public_subnet_ids
  assign_public_ip           = true
  ingress_security_group_ids = [module.alb.security_group_id]

  target_group_arn = module.alb.target_group_arns["app"]

  tags = { Environment = "lab" }
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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.ignore_taskdef](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_service.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.execution_extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.execution_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Give each task ENI a public IP. Required when tasks run in public subnets so they can pull the image and reach AWS APIs over the internet gateway (avoids a NAT gateway). | `bool` | `false` | no |
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | ARN of the ECS cluster to run the service in. | `string` | n/a | yes |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | Container image reference the task runs, including a tag or digest (e.g. <account>.dkr.ecr.<region>.amazonaws.com/my-app:dev). When ignore\_task\_definition\_changes is true this is only the BOOTSTRAP image — the CI pipeline registers new revisions with new tags afterwards. | `string` | n/a | yes |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the container in the task definition. Referenced by the load balancer target and by CI when rendering new task-definition revisions. | `string` | `"app"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | Port the container listens on and the load balancer forwards to. | `number` | `8080` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Fargate task CPU units (256 = 0.25 vCPU). Must be a valid Fargate CPU/memory combination. | `number` | `256` | no |
| <a name="input_cpu_architecture"></a> [cpu\_architecture](#input\_cpu\_architecture) | CPU architecture of the task's runtime platform: X86\_64 or ARM64. Must match the architecture the image was built for. | `string` | `"X86_64"` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Create a task security group (inbound on container\_port from ingress\_security\_group\_ids, all egress). Ignored when security\_group\_ids is non-empty. | `bool` | `true` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of task copies to run. | `number` | `1` | no |
| <a name="input_enable_execute_command"></a> [enable\_execute\_command](#input\_enable\_execute\_command) | Enable ECS Exec (aws ecs execute-command) for interactive debugging into running tasks. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment variables passed to the container, as a name -> value map. | `map(string)` | `{}` | no |
| <a name="input_execution_policy_arns"></a> [execution\_policy\_arns](#input\_execution\_policy\_arns) | Extra IAM policy ARNs attached to the task EXECUTION role (used by the ECS agent to pull images and write logs). AmazonECSTaskExecutionRolePolicy is always attached; add more here (e.g. to read secrets). | `list(string)` | `[]` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Grace period before the load balancer health check can mark a task unhealthy and the scheduler replaces it — gives the app time to start. Only applied when target\_group\_arn is set. | `number` | `60` | no |
| <a name="input_ignore_task_definition_changes"></a> [ignore\_task\_definition\_changes](#input\_ignore\_task\_definition\_changes) | Ignore changes to the service's task\_definition and desired\_count so an external deployer (CI registering new task-def revisions) owns rolling deployments without Terraform reverting the image on the next apply. Set false to let Terraform fully manage the running revision. | `bool` | `true` | no |
| <a name="input_ingress_security_group_ids"></a> [ingress\_security\_group\_ids](#input\_ingress\_security\_group\_ids) | Security group IDs allowed to reach the tasks on container\_port — typically the ALB's security group. Only used when the module creates its own security group. Empty = no inbound (tasks reachable only from within their own SG). | `list(string)` | `[]` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | Retention for the task's CloudWatch log group. | `number` | `14` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Fargate task memory in MiB. Must be a valid Fargate CPU/memory combination for the chosen cpu. | `number` | `512` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the service. Also used as the task-definition family and the prefix for the log group, IAM roles, and (optional) security group. | `string` | n/a | yes |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security groups to attach to the task ENIs. When empty (default) and create\_security\_group is true, the module creates one allowing inbound on container\_port from ingress\_security\_group\_ids. | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnets the tasks' elastic network interfaces are placed in. Use public subnets with assign\_public\_ip = true (no NAT needed) or private subnets with NAT/VPC endpoints. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource created by this module. | `map(string)` | `{}` | no |
| <a name="input_target_group_arn"></a> [target\_group\_arn](#input\_target\_group\_arn) | ARN of an ALB/NLB target group (target\_type = ip) to register the tasks with. When null (default) the service runs without a load balancer. | `string` | `null` | no |
| <a name="input_task_policy_arns"></a> [task\_policy\_arns](#input\_task\_policy\_arns) | IAM policy ARNs attached to the TASK role (assumed by the application code itself to call AWS APIs). Empty by default. | `list(string)` | `[]` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC to create the task security group in. Required only when the module creates its own security group (create\_security\_group = true and no security\_group\_ids supplied). | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_container_name"></a> [container\_name](#output\_container\_name) | Name of the container in the task definition (the load-balancer target and the CI image-swap target). |
| <a name="output_container_port"></a> [container\_port](#output\_container\_port) | Port the container listens on. |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | ARN of the task execution role (used by the ECS agent). Grant a CI deployer iam:PassRole on this. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the CloudWatch log group receiving the container logs. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the task security group created by this module, or null when one was supplied instead. |
| <a name="output_service_id"></a> [service\_id](#output\_service\_id) | ID (ARN) of the ECS service. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Name of the ECS service. |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | ARN of the (bootstrap) task definition revision created by this module. |
| <a name="output_task_definition_family"></a> [task\_definition\_family](#output\_task\_definition\_family) | Family name of the task definition. A CI deployer describes this family, swaps the image, and registers a new revision. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ARN of the task role (assumed by the application). Grant a CI deployer iam:PassRole on this. |
<!-- END_TF_DOCS -->
