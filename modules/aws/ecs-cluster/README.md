# aws/ecs-cluster

A **serverless (Fargate) ECS cluster** — the logical grouping that services and tasks run in. The
module owns the cluster and its **Fargate capacity providers** only; services, task definitions,
load balancers, and networking are separate concerns supplied by other modules (pair it with
`ecs-fargate-service` behind an `alb`). Keeping the cluster its own module lets several services
share one cluster.

- **Capacity providers** default to `FARGATE` + `FARGATE_SPOT`, with `FARGATE` as the default
  strategy — so a service that only asks for Fargate schedules correctly.
- **Container Insights** is off by default (it adds CloudWatch cost); flip
  `enable_container_insights` on when you want per-task metrics.

## Usage

```hcl
module "ecs_cluster" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/aws/ecs-cluster?ref=aws-ecs-cluster-v0.1.0"

  name = "my-lab"

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
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_capacity_providers"></a> [capacity\_providers](#input\_capacity\_providers) | Fargate capacity providers available to services in this cluster. | `list(string)` | <pre>[<br/>  "FARGATE",<br/>  "FARGATE_SPOT"<br/>]</pre> | no |
| <a name="input_default_capacity_provider"></a> [default\_capacity\_provider](#input\_default\_capacity\_provider) | Capacity provider used by default when a service in this cluster does not specify a launch type or strategy. Must be one of capacity\_providers. | `string` | `"FARGATE"` | no |
| <a name="input_enable_container_insights"></a> [enable\_container\_insights](#input\_enable\_container\_insights) | Enable CloudWatch Container Insights for the cluster (extra per-task metrics; incurs CloudWatch cost). Off by default to keep labs cheap. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the ECS cluster. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the cluster. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN of the ECS cluster. Pass it to a service module to place the service in this cluster. |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | ID of the ECS cluster (same value as the ARN). |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the ECS cluster. |
<!-- END_TF_DOCS -->
