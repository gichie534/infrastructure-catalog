# aws/lambda

A Lambda function plus its execution role — the minimal serverless-compute building block. The
consumer supplies the deployment package (a `.zip`), handler, and runtime; the module wires the
execution role, an optional VPC attachment, and a retention-managed CloudWatch log group.

The module owns the **function, its IAM execution role, and its log group**. It does not build the
zip or create the VPC/subnets/security groups — those are inputs — so it stays region- and
account-agnostic.

Execution-role policy, chosen by context:

- Always attaches **`AWSLambdaBasicExecutionRole`** (CloudWatch Logs).
- When `vpc_config` is set, also attaches **`AWSLambdaVPCAccessExecutionRole`** so the function can
  manage the ENIs it needs to run inside the VPC and reach private resources.
- Extra grants go through `additional_policy_arns` (managed) or `inline_policies` (least-privilege
  JSON).

Setting `vpc_config` is what lets the function reach **private** resources (RDS, an EC2 instance in
a private subnet, etc.) over the VPC network instead of the public internet.

## Usage

```hcl
module "lambda" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/lambda?ref=aws-lambda-vX.Y.Z"

  name     = "reader"
  filename = "${path.module}/build/function.zip" # compiled Go `bootstrap`, zipped
  handler  = "bootstrap"
  runtime  = "provided.al2023"

  # Attach to a VPC to reach private resources.
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.lambda_sg.id]
  }

  environment_variables = {
    TARGET_URL = "http://10.0.128.10:8080"
  }

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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_policy_arns"></a> [additional\_policy\_arns](#input\_additional\_policy\_arns) | ARNs of extra managed policies to attach to the execution role, on top of the basic (and, in a VPC, VPC-access) execution policies. Empty by default. | `list(string)` | `[]` | no |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | Instruction set architecture: x86\_64 or arm64. | `string` | `"x86_64"` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Environment variables passed to the function. Empty by default (no environment block created). | `map(string)` | `{}` | no |
| <a name="input_filename"></a> [filename](#input\_filename) | Path to the deployment package (.zip) containing the function code. The consumer builds this; the module hashes it for source\_code\_hash so updates redeploy. | `string` | n/a | yes |
| <a name="input_handler"></a> [handler](#input\_handler) | Function entrypoint. For the Go (provided.al2023) runtime this is the executable name in the zip (e.g. bootstrap). | `string` | `"bootstrap"` | no |
| <a name="input_inline_policies"></a> [inline\_policies](#input\_inline\_policies) | Map of inline least-privilege policies to embed in the execution role, keyed by policy name. Each value is a JSON IAM policy document. Empty by default. | `map(string)` | `{}` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | Retention for the function's CloudWatch log group. Default 14 days keeps lab logs from accumulating indefinitely. | `number` | `14` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Memory (MB) allocated to the function. CPU scales with memory. | `number` | `128` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the Lambda function. Also used to name its execution role (<name>-exec) and log group (/aws/lambda/<name>). | `string` | n/a | yes |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Lambda runtime identifier (e.g. provided.al2023 for Go, python3.12, nodejs20.x). | `string` | `"provided.al2023"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the function, execution role, and log group. | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Maximum execution time in seconds before the function is stopped. | `number` | `10` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | Attach the function to a VPC. When set, Lambda runs its ENIs in the given private subnets and<br/>security groups (letting it reach private resources like RDS or an EC2 instance), and the module<br/>adds the AWSLambdaVPCAccessExecutionRole managed policy. Null (default) runs the function outside<br/>any VPC. | <pre>object({<br/>    subnet_ids         = list(string)<br/>    security_group_ids = list(string)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_arn"></a> [function\_arn](#output\_function\_arn) | ARN of the Lambda function. |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Name of the Lambda function. |
| <a name="output_invoke_arn"></a> [invoke\_arn](#output\_invoke\_arn) | ARN to be used for invoking the function (e.g. from API Gateway integrations). |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the CloudWatch log group receiving the function's logs. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the function's execution role. Attach further permissions to it if needed. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the function's execution role. |
<!-- END_TF_DOCS -->
