# gcp/cloud-sql-postgres

A minimal Cloud SQL for PostgreSQL instance designed for GKE pods to connect over **private IP**
using **IAM database authentication** (passwordless). The instance gets a private IP on the
consumer's VPC (which must have Private Service Access configured — see [`gcp/vpc`](../vpc)), and
the supplied Google service accounts are registered as IAM database users.

## Scope

This module owns:

- the Cloud SQL instance (private IP only, `cloudsql.iam_authentication` enabled) and one database;
- an IAM database user for each Google service account passed in `iam_service_account_emails`;
- optionally, the instance's availability shape, disk sizing, backup/PITR configuration, maintenance
  window, and any cross-region read replicas.

The consumer owns the rest of the auth chain. The [`gcp/workload-iam`](../workload-iam) module is
the home for it (see `examples/basic`):

- the Google service account(s) themselves;
- the project IAM grants the GSA needs to connect (`roles/cloudsql.client`, `roles/cloudsql.instanceUser`);
- the Workload Identity binding from the Kubernetes SA to the GSA.

## How a pod authenticates

1. The pod runs under a Kubernetes SA bound via Workload Identity to a GSA.
2. The GSA is registered here as an IAM database user (no password).
3. The pod connects to the private IP and logs in as the GSA's database username
   (the GSA email with the `.gserviceaccount.com` suffix removed).

## Usage

```hcl
module "cloud_sql" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/cloud-sql-postgres?ref=vX.Y.Z"

  name       = "platform-pg"
  project_id = "my-project"
  region     = "us-central1"
  network    = module.vpc.network_self_link

  iam_service_account_emails = [module.workload_iam.service_account_email]
}
```

## Durability and availability

Three independent controls, addressing three different failure domains. The defaults are the cheap,
non-production shape (single zone, no backups); a real environment sets all three.

| Failure                    | Control                                                      | RPO                                           |
| -------------------------- | ------------------------------------------------------------ | --------------------------------------------- |
| A zone goes down           | `availability_type = "REGIONAL"`                             | **Zero** — synchronous standby, auto failover |
| The whole region goes down | `read_replicas` in another region, promoted manually         | Replication lag — typically seconds           |
| Bad write / logical damage | `backup_configuration` with `point_in_time_recovery_enabled` | Restore to any second in the log window       |

`REGIONAL` is the only one of the three that is synchronous, so it is the only one with a genuine
zero RPO. Cloud SQL offers no synchronous cross-region option — a cross-region replica is always
asynchronous, so "near-zero, not zero" is the honest description of regional-outage RPO. Setting
`backup_configuration.location` to a region other than the instance's keeps the backups themselves
out of the primary's blast radius.

```hcl
availability_type = "REGIONAL"

disk_size             = 150
disk_type             = "PD_SSD"
disk_autoresize       = true
disk_autoresize_limit = 500

backup_configuration = {
  start_time                     = "02:00" # UTC
  location                       = "eu"    # backups outside the instance's region
  point_in_time_recovery_enabled = true
  transaction_log_retention_days = 7
  retained_backups               = 30
}

maintenance_window = {
  day          = 7 # Sunday
  hour         = 3 # UTC
  update_track = "stable"
}

read_replicas = {
  dr = { region = "europe-west1" }
}
```

Promoting a replica after a regional failure is a deliberate operator action, not something
Terraform does: `gcloud sql instances promote-replica <name>-dr`. It is one-way — the replica becomes
a standalone primary and stops replicating.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.35 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.39.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_sql_database.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) | resource |
| [google_sql_database_instance.replica](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_database_instance.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_user.admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [google_sql_user.iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | When set, assigns this password to the built-in `postgres` user (a member of cloudsqlsuperuser),<br/>enabling password authentication for that admin role. Required for a password-auth migration that<br/>restores as `postgres`. Leave null to keep the instance IAM-auth-only. | `string` | `null` | no |
| <a name="input_authorized_networks"></a> [authorized\_networks](#input\_authorized\_networks) | Public CIDR allowlist for the instance's public IP. Only meaningful when enable\_public\_ip is<br/>true. Each entry has a name (label) and value (CIDR). Keep this narrow (e.g. a single operator /32). | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_availability_type"></a> [availability\_type](#input\_availability\_type) | High availability shape of the instance. REGIONAL provisions a standby in a second zone of the<br/>same region with SYNCHRONOUS replication and automatic failover (zero RPO for a zonal failure);<br/>ZONAL is a single zone with no standby. Production instances should be REGIONAL. | `string` | `"ZONAL"` | no |
| <a name="input_backup_configuration"></a> [backup\_configuration](#input\_backup\_configuration) | Automated backups and point-in-time recovery. Null (the default) creates no backup configuration<br/>at all, leaving the instance unbacked-up — set this for any environment holding real data.<br/><br/>- `start_time` is UTC `HH:MM`; pick a low-traffic window.<br/>- `location` stores the backups in a different (multi-)region from the instance, so one region's<br/>  loss can't take the data and its backups together. Null keeps them in the instance's region.<br/>- `point_in_time_recovery_enabled` turns on write-ahead-log archiving, allowing a restore to any<br/>  point inside `transaction_log_retention_days` rather than only to the last nightly backup.<br/>- `retention_unit` is `COUNT`, so `retained_backups` is a number of backups, not days. | <pre>object({<br/>    enabled                        = optional(bool, true)<br/>    start_time                     = optional(string, "03:00")<br/>    location                       = optional(string)<br/>    point_in_time_recovery_enabled = optional(bool, true)<br/>    transaction_log_retention_days = optional(number, 7)<br/>    retained_backups               = optional(number, 30)<br/>    retention_unit                 = optional(string, "COUNT")<br/>  })</pre> | `null` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the application database to create on the instance. | `string` | `"app"` | no |
| <a name="input_database_version"></a> [database\_version](#input\_database\_version) | PostgreSQL version for the instance (e.g. POSTGRES\_16). | `string` | `"POSTGRES_16"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether the instance is protected from deletion. Keep true for real environments; examples/tests set it false. | `bool` | `true` | no |
| <a name="input_disk_autoresize"></a> [disk\_autoresize](#input\_disk\_autoresize) | Let Cloud SQL grow the data disk automatically when it fills up. Null leaves the provider default (true). | `bool` | `null` | no |
| <a name="input_disk_autoresize_limit"></a> [disk\_autoresize\_limit](#input\_disk\_autoresize\_limit) | Upper bound in GB for automatic disk growth. 0 means no limit. Only meaningful when disk\_autoresize is enabled. | `number` | `null` | no |
| <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size) | Size of the data disk in GB. Null leaves the Cloud SQL default (10 GB). The disk can grow but never shrink. | `number` | `null` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | Data disk type. PD\_SSD is the default for production; PD\_HDD is cheaper and slower. Null leaves the provider default. | `string` | `null` | no |
| <a name="input_edition"></a> [edition](#input\_edition) | The edition of the Cloud SQL instance. ENTERPRISE\_PLUS unlocks higher performance and availability features; the chosen tier must be compatible with the edition. | `string` | `"ENTERPRISE"` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Give the instance a public IPv4 endpoint in addition to its private IP. Off by default<br/>(private-IP-only is the production shape). A migration or bootstrap that must reach the instance<br/>from outside the VPC (e.g. an operator running pg\_restore) can enable it, paired with a narrow<br/>authorized\_networks allowlist and ssl\_mode = ENCRYPTED\_ONLY. | `bool` | `false` | no |
| <a name="input_iam_service_account_emails"></a> [iam\_service\_account\_emails](#input\_iam\_service\_account\_emails) | Email addresses of Google service accounts to register as IAM database users. A GKE pod<br/>authenticates to the instance (no password) by running under a Kubernetes SA bound via<br/>Workload Identity to one of these GSAs. The GSAs and their project-level IAM grants<br/>(roles/cloudsql.client, roles/cloudsql.instanceUser) are owned by the consumer, not this module. | `list(string)` | `[]` | no |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | Weekly window in which Cloud SQL may apply maintenance (a brief restart / failover). `day` is<br/>1 (Monday) to 7 (Sunday), `hour` is 0-23 UTC. `update_track` of `stable` receives updates later<br/>than `canary`, which is what a production instance normally wants. Null leaves it unmanaged, so<br/>maintenance can land at any time. | <pre>object({<br/>    day          = number<br/>    hour         = number<br/>    update_track = optional(string, "stable")<br/>  })</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the Cloud SQL instance. Also used as the prefix for the database. | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | Self link or ID of the VPC network the instance gets a private IP on. Wire this to the vpc module's network\_self\_link output; the VPC must have Private Service Access configured. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the instance. | `string` | n/a | yes |
| <a name="input_read_replicas"></a> [read\_replicas](#input\_read\_replicas) | Read replicas to create, keyed by a short suffix appended to the instance name (e.g. `dr` gives<br/>`<name>-dr`). Set `region` to a DIFFERENT region than the primary for a cross-region replica: it<br/>survives the loss of the primary's region and can be promoted to a standalone primary, which is<br/>the regional-disaster recovery path. Replication is ASYNCHRONOUS, so the RPO is the replication<br/>lag (usually seconds), not zero — pair it with a REGIONAL primary for zero-RPO zonal failover.<br/><br/>Each replica inherits the primary's tier / disk settings unless it overrides them. Backups are<br/>not configurable on a replica (Cloud SQL rejects it); IAM database users replicate from the<br/>primary. The VPC's Private Service Access allocation is global, so no extra network setup is<br/>needed for the replica's region. | <pre>map(object({<br/>    region                = string<br/>    tier                  = optional(string)<br/>    availability_type     = optional(string, "ZONAL")<br/>    disk_size             = optional(number)<br/>    disk_type             = optional(string)<br/>    disk_autoresize       = optional(bool)<br/>    disk_autoresize_limit = optional(number)<br/>    user_labels           = optional(map(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_region"></a> [region](#input\_region) | Region for the Cloud SQL instance (e.g. us-central1). | `string` | n/a | yes |
| <a name="input_ssl_mode"></a> [ssl\_mode](#input\_ssl\_mode) | Enforcement of TLS on connections. ENCRYPTED\_ONLY requires TLS but not a client cert;<br/>ALLOW\_UNENCRYPTED\_AND\_ENCRYPTED permits plaintext; TRUSTED\_CLIENT\_CERTIFICATE\_REQUIRED also<br/>demands a client certificate. Null (default) leaves the provider default in place. | `string` | `null` | no |
| <a name="input_tier"></a> [tier](#input\_tier) | Machine tier for the instance (e.g. db-custom-1-3840, db-f1-micro). | `string` | `"db-custom-1-3840"` | no |
| <a name="input_user_labels"></a> [user\_labels](#input\_user\_labels) | Labels applied to the Cloud SQL instance. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_availability_type"></a> [availability\_type](#output\_availability\_type) | The configured availability shape of the primary (REGIONAL = synchronous standby in a second zone with automatic failover). |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | The name of the application database. |
| <a name="output_iam_user_names"></a> [iam\_user\_names](#output\_iam\_user\_names) | Map of GSA email to the IAM database username registered on the instance. Use the username as the Postgres login role. |
| <a name="output_instance_connection_name"></a> [instance\_connection\_name](#output\_instance\_connection\_name) | Connection name in the form project:region:instance, used by Cloud SQL connectors and the Auth Proxy. |
| <a name="output_instance_name"></a> [instance\_name](#output\_instance\_name) | The name of the Cloud SQL instance (used as the connection target and by the Auth Proxy / connectors). |
| <a name="output_private_ip_address"></a> [private\_ip\_address](#output\_private\_ip\_address) | The private IP address of the instance on the VPC. Pods connect to this address. |
| <a name="output_public_ip_address"></a> [public\_ip\_address](#output\_public\_ip\_address) | The public IPv4 address of the instance, or null when enable\_public\_ip is false. |
| <a name="output_replica_connection_names"></a> [replica\_connection\_names](#output\_replica\_connection\_names) | Map of read\_replicas key to the replica's connection name (project:region:instance), for connectors and the Auth Proxy. |
| <a name="output_replica_instance_names"></a> [replica\_instance\_names](#output\_replica\_instance\_names) | Map of read\_replicas key to the created replica instance name. |
| <a name="output_replica_private_ip_addresses"></a> [replica\_private\_ip\_addresses](#output\_replica\_private\_ip\_addresses) | Map of read\_replicas key to the replica's private IP address on the VPC — the read endpoint, and the write endpoint after a promotion. |
<!-- END_TF_DOCS -->
