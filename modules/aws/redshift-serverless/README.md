# aws/redshift-serverless

A Redshift Serverless data warehouse: a **namespace** (the database, its admin identity, and the IAM
roles it may assume) and a **workgroup** (the compute that serves queries, placed in your VPC),
together with the IAM role Redshift assumes to `COPY` from S3.

Serverless rather than a provisioned cluster because there is no instance type to size and no cluster
to keep running — you pay per RPU-second while queries execute. `base_capacity` defaults to 8 RPUs,
the minimum.

## What this module owns, and what it does not

It owns the **namespace, the workgroup, and the COPY role**. The role is owned here because Redshift
requires it to be associated with the namespace at creation time, its trust policy is
Redshift-specific, and its permissions derive entirely from the buckets named in
`s3_read_bucket_arns`. This mirrors how `ecs-fargate-service` owns its execution and task roles.

It does **not** create the VPC, subnets, security groups, or source buckets. Those come from the
consumer, which keeps the module account- and region-agnostic.

## Usage

```hcl
module "warehouse" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/redshift-serverless?ref=aws-redshift-serverless-vX.Y.Z"

  name          = "events-warehouse"
  database_name = "labdb"

  subnet_ids         = module.vpc.private_subnet_ids # at least three, across three AZs
  security_group_ids = [module.warehouse_sg.id]

  base_capacity = 8
  max_capacity  = 8 # cost guard

  s3_read_bucket_arns = [module.data_lake.arn]

  tags = {
    Environment = "dev"
  }
}
```

## Credentials: no password anywhere

`manage_admin_password` is on by default, so Redshift creates and rotates the admin credential secret
in Secrets Manager. No password passes through a Terraform variable, a `.env` file, or state. The
secret's ARN is exported as `admin_password_secret_arn`.

This works because queries are expected to run over the **Redshift Data API**, which authenticates
with IAM against a regional AWS endpoint rather than connecting to the warehouse over the network. A
caller needs `redshift-data:ExecuteStatement` / `DescribeStatement` / `GetStatementResult` plus
`redshift-serverless:GetCredentials` on the workgroup — no database password, no VPC ingress, no
bastion, no `psql`.

Set `admin_user_password` only if something genuinely requires a static password.

## Networking

`subnet_ids` must contain **at least three subnets across three Availability Zones** — Redshift
Serverless rejects fewer, and the module validates this at plan time rather than letting apply fail
several minutes in. Each subnet also needs enough free IP addresses for the chosen `base_capacity`.

Private subnets and `publicly_accessible = false` (the default) are correct for Data API access. An
egress-only security group is sufficient; nothing needs to connect inbound.

## COPY from S3

The module associates the COPY role with the namespace and marks it the default, so a load statement
can name it either way:

```sql
COPY user_events
FROM 's3://my-bucket/batch/'
IAM_ROLE default
FORMAT AS CSV
IGNOREHEADER 1;
```

The role is granted `s3:GetObject` on the contents of every bucket in `s3_read_bucket_arns`, plus
`ListBucket` and `GetBucketLocation` on the buckets themselves. Pass bucket ARNs, not object ARNs —
the module validates the shape.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.66.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.copy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.copy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_redshiftserverless_namespace.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshiftserverless_namespace) | resource |
| [aws_redshiftserverless_workgroup.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshiftserverless_workgroup) | resource |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.copy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_user_password"></a> [admin\_user\_password](#input\_admin\_user\_password) | Admin password. Leave null (the default) and Redshift creates and rotates the credential secret in<br/>Secrets Manager instead — no password in your variables or in Terraform state. Only set this if<br/>something genuinely needs a static password; Data API access with IAM authentication does not. | `string` | `null` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Username of the database administrator. Note that `admin` is reserved by Redshift and rejected. | `string` | `"dbadmin"` | no |
| <a name="input_base_capacity"></a> [base\_capacity](#input\_base\_capacity) | Base compute capacity in Redshift Processing Units, in multiples of 8. Billed per RPU-second while<br/>queries run, so 8 (the minimum, and the default) is the right choice for a warehouse that serves<br/>occasional loads and queries rather than sustained analytics. | `number` | `8` | no |
| <a name="input_config_parameters"></a> [config\_parameters](#input\_config\_parameters) | Database configuration parameters applied to the workgroup, as a map of parameter key to value (e.g. `{ require_ssl = "true" }`). Empty by default. | `map(string)` | `{}` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the first database created in the namespace. This is what a Data API call passes as `Database`. | `string` | `"dev"` | no |
| <a name="input_enhanced_vpc_routing"></a> [enhanced\_vpc\_routing](#input\_enhanced\_vpc\_routing) | Force traffic between the workgroup and other services through your VPC instead of over the internet. Default false; enabling it requires VPC endpoints or NAT for S3 reachability. | `bool` | `false` | no |
| <a name="input_log_exports"></a> [log\_exports](#input\_log\_exports) | Log types the namespace exports to CloudWatch Logs. Valid values are `userlog`, `connectionlog`, and `useractivitylog`. Empty by default. | `list(string)` | `[]` | no |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Optional ceiling on RPUs used to serve queries, in multiples of 8. Null (the default) applies no explicit ceiling. Worth setting as a cost guard on a warehouse anyone can query. | `number` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Base name for the warehouse. Used for the namespace, the workgroup, and the COPY IAM role unless `namespace_name` / `workgroup_name` override the first two. | `string` | n/a | yes |
| <a name="input_namespace_name"></a> [namespace\_name](#input\_namespace\_name) | Override the namespace name. Defaults to `name`. | `string` | `null` | no |
| <a name="input_publicly_accessible"></a> [publicly\_accessible](#input\_publicly\_accessible) | Whether the workgroup accepts connections from the public internet. Default false — with Data API access there is no reason to expose it. | `bool` | `false` | no |
| <a name="input_s3_read_bucket_arns"></a> [s3\_read\_bucket\_arns](#input\_s3\_read\_bucket\_arns) | Bucket ARNs the COPY role is granted read access to (`s3:GetObject` on their contents, plus<br/>`ListBucket`/`GetBucketLocation` on the buckets themselves). Empty (the default) creates the role<br/>with no S3 access, which is only useful if a consumer attaches its own policy. Pass the `arn`<br/>output of `aws/s3-bucket`, not an object ARN. | `list(string)` | `[]` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security groups attached to the workgroup. Empty (the default) lets AWS attach the VPC's default security group. An egress-only group is sufficient when queries arrive via the Data API. | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnets the workgroup's compute is placed in. Redshift Serverless requires **at least three<br/>subnets spanning three different Availability Zones**, and each needs enough free IPs for the<br/>chosen `base_capacity`. Private subnets are the right choice — the Data API does not need the<br/>workgroup to be reachable from outside the VPC. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource created by this module (namespace, workgroup, COPY role). | `map(string)` | `{}` | no |
| <a name="input_workgroup_name"></a> [workgroup\_name](#input\_workgroup\_name) | Override the workgroup name. Defaults to `name`. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_admin_password_secret_arn"></a> [admin\_password\_secret\_arn](#output\_admin\_password\_secret\_arn) | ARN of the Secrets Manager secret holding the admin credentials, when Redshift manages them. Null if a password was supplied explicitly. |
| <a name="output_admin_username"></a> [admin\_username](#output\_admin\_username) | Username of the database administrator. |
| <a name="output_copy_role_arn"></a> [copy\_role\_arn](#output\_copy\_role\_arn) | ARN of the IAM role Redshift assumes to read S3. Pass this to `COPY ... IAM_ROLE '<arn>'`, or use `IAM_ROLE default` since the module sets it as the namespace default. |
| <a name="output_copy_role_name"></a> [copy\_role\_name](#output\_copy\_role\_name) | Name of the IAM role Redshift assumes to read S3. |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Name of the first database in the namespace. A Data API call passes this as `Database`. |
| <a name="output_endpoint_address"></a> [endpoint\_address](#output\_endpoint\_address) | DNS address of the workgroup's VPC endpoint. Only needed for a direct SQL connection; Data API callers do not use it. |
| <a name="output_endpoint_port"></a> [endpoint\_port](#output\_endpoint\_port) | Port the workgroup listens on. |
| <a name="output_namespace_arn"></a> [namespace\_arn](#output\_namespace\_arn) | ARN of the namespace. |
| <a name="output_namespace_id"></a> [namespace\_id](#output\_namespace\_id) | ID of the namespace. |
| <a name="output_namespace_name"></a> [namespace\_name](#output\_namespace\_name) | Name of the namespace. |
| <a name="output_workgroup_arn"></a> [workgroup\_arn](#output\_workgroup\_arn) | ARN of the workgroup. Use this in IAM policy resource statements granting Data API access. |
| <a name="output_workgroup_id"></a> [workgroup\_id](#output\_workgroup\_id) | ID of the workgroup. |
| <a name="output_workgroup_name"></a> [workgroup\_name](#output\_workgroup\_name) | Name of the workgroup. This is what a Redshift Data API call passes as `WorkgroupName`. |
<!-- END_TF_DOCS -->
