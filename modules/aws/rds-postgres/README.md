# aws/rds-postgres

A single managed **PostgreSQL** instance on Amazon RDS — the relational store a consumer wires its
application to, and the migration *source* in the `aws-gcp/rds-to-cloudsql-postgres` lab.

The module owns the instance plus the three things one instance always needs: a **DB subnet group**
(which AZs it lives in), a **security group** (who may reach it), and — when you supply
`parameters` — a **parameter group** (engine settings such as `rds.force_ssl` or
`rds.logical_replication`). It deliberately does **not** own the VPC, any database beyond the
initial one, or roles/schemas — those are the consumer's composition and application concerns.

`publicly_accessible` is **off by default** (production shape: private subnets, reachable only from
inside the VPC). A lab that needs to reach the instance from outside sets it `true`, places the
instance in **public** subnets, and narrows `allowed_cidr_blocks` to a single operator `/32` with
`rds.force_ssl=1` enforced.

## Usage

```hcl
module "rds" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/rds-postgres?ref=aws-rds-postgres-vX.Y.Z"

  name       = "app-src"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids

  db_name         = "app"
  master_username = "postgres"
  master_password = var.master_password # from a secret / .env, never hardcoded

  publicly_accessible = true
  allowed_cidr_blocks = ["203.0.113.10/32"] # your operator address

  parameters = [
    { name = "rds.force_ssl", value = "1" },
    # Enable logical decoding for CDC-based migrations (requires a reboot):
    # { name = "rds.logical_replication", value = "1", apply_method = "pending-reboot" },
  ]

  deletion_protection = false
  skip_final_snapshot = true
}
```

## Enforcing TLS

Set `rds.force_ssl=1` (as above) and connect with `sslmode=require` (or stricter). The
`aws-gcp/rds-to-cloudsql-postgres` lab connects with `sslmode=verify-full` against a downloaded RDS
CA bundle.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.57.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.postgres](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Initial storage allocated to the instance, in GiB. | `number` | `20` | no |
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | CIDR blocks allowed to reach the instance on its port via the module-created security group. Keep this narrow (e.g. a single operator /32). | `list(string)` | `[]` | no |
| <a name="input_apply_immediately"></a> [apply\_immediately](#input\_apply\_immediately) | Apply modifications immediately instead of during the next maintenance window. | `bool` | `true` | no |
| <a name="input_auto_minor_version_upgrade"></a> [auto\_minor\_version\_upgrade](#input\_auto\_minor\_version\_upgrade) | Allow RDS to apply minor engine upgrades automatically during maintenance windows. | `bool` | `true` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | Days to retain automated backups. 0 disables automated backups (fine for an ephemeral lab). | `number` | `0` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Name of the initial database created on the instance. | `string` | `"app"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Block deletion of the instance until disabled. Keep true for real environments; examples/labs set it false to tear down cleanly. | `bool` | `true` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | PostgreSQL engine version. A major-only value (e.g. "16") tracks the latest supported minor for that major. | `string` | `"16"` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | RDS instance class (e.g. db.t4g.micro, db.m6g.large). | `string` | `"db.t4g.micro"` | no |
| <a name="input_master_password"></a> [master\_password](#input\_master\_password) | Password for the master user. Required (no default) so it is supplied deliberately, never baked into the module. | `string` | n/a | yes |
| <a name="input_master_username"></a> [master\_username](#input\_master\_username) | Master (admin) login role created with the instance. On RDS this role is a member of rds\_superuser. | `string` | `"postgres"` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | Upper limit (GiB) for storage autoscaling. Set to 0 to disable autoscaling. Must be >= allocated\_storage when enabled. | `number` | `0` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Deploy a standby in a second AZ for HA failover. Off by default to keep labs cheap. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the RDS instance. Used as the DB identifier and the prefix for its subnet group, security group, and parameter group. | `string` | n/a | yes |
| <a name="input_parameter_group_family"></a> [parameter\_group\_family](#input\_parameter\_group\_family) | DB parameter group family, matching the engine major version (e.g. postgres16). | `string` | `"postgres16"` | no |
| <a name="input_parameters"></a> [parameters](#input\_parameters) | DB parameters applied via a module-managed parameter group. Common entries: rds.force\_ssl=1 to<br/>require TLS, and rds.logical\_replication=1 (apply\_method=pending-reboot) to enable logical<br/>decoding for CDC-based migrations. apply\_method is "immediate" or "pending-reboot". | <pre>list(object({<br/>    name         = string<br/>    value        = string<br/>    apply_method = optional(string, "immediate")<br/>  }))</pre> | `[]` | no |
| <a name="input_performance_insights_enabled"></a> [performance\_insights\_enabled](#input\_performance\_insights\_enabled) | Enable Performance Insights on the instance. | `bool` | `false` | no |
| <a name="input_port"></a> [port](#input\_port) | TCP port the instance listens on. | `number` | `5432` | no |
| <a name="input_publicly_accessible"></a> [publicly\_accessible](#input\_publicly\_accessible) | Give the instance a public endpoint. Combine with a tight allowed\_cidr\_blocks and rds.force\_ssl for a lab/migration source reachable from outside the VPC; keep false for production. | `bool` | `false` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip the final snapshot on destroy. True for ephemeral labs; false (a final snapshot is taken) for anything you might need to restore. | `bool` | `false` | no |
| <a name="input_storage_encrypted"></a> [storage\_encrypted](#input\_storage\_encrypted) | Encrypt the instance's storage at rest with the default RDS KMS key. | `bool` | `true` | no |
| <a name="input_storage_type"></a> [storage\_type](#input\_storage\_type) | EBS storage type for the instance (gp3, gp2, io1, io2). | `string` | `"gp3"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the DB subnet group. Use public subnets when publicly\_accessible is true (so the instance gets a routable address), private subnets otherwise. Span at least two AZs. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource created by this module. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC the instance's security group is created in. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | The hostname of the instance endpoint. Use this as the psql/pg\_dump -h host. |
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the RDS instance. |
| <a name="output_db_name"></a> [db\_name](#output\_db\_name) | The name of the initial database. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | The connection endpoint in host:port form. |
| <a name="output_id"></a> [id](#output\_id) | The RDS instance identifier. |
| <a name="output_master_username"></a> [master\_username](#output\_master\_username) | The master (admin) username. |
| <a name="output_parameter_group_name"></a> [parameter\_group\_name](#output\_parameter\_group\_name) | Name of the module-created parameter group, or null when no parameters were supplied. |
| <a name="output_port"></a> [port](#output\_port) | The port the instance listens on. |
| <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id) | The stable RDS-generated resource ID (dbi-...), used for IAM database-auth policy ARNs. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the module-created security group controlling ingress to the instance. |
<!-- END_TF_DOCS -->
