# gcp/cloud-sql-postgres

A minimal Cloud SQL for PostgreSQL instance designed for GKE pods to connect over **private IP**
using **IAM database authentication** (passwordless). The instance gets a private IP on the
consumer's VPC (which must have Private Service Access configured — see [`gcp/vpc`](../vpc)), and
the supplied Google service accounts are registered as IAM database users.

## Scope

This module owns:

- the Cloud SQL instance (private IP only, `cloudsql.iam_authentication` enabled) and one database;
- an IAM database user for each Google service account passed in `iam_service_account_emails`.

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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name                                                                      | Version |
| ------------------------------------------------------------------------- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0  |
| <a name="requirement_google"></a> [google](#requirement\_google)          | >= 7.35 |

## Providers

| Name                                                       | Version |
| ---------------------------------------------------------- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.36.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                                      | Type     |
| ----------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [google_sql_database.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database)                   | resource |
| [google_sql_database_instance.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_user.iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user)                            | resource |

## Inputs

| Name                                                                                                                   | Description                                                                                                                                                                                                                                                                                                                                                                     | Type           | Default              | Required |
| ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------------------- | :------: |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name)                                            | Name of the application database to create on the instance.                                                                                                                                                                                                                                                                                                                     | `string`       | `"app"`              |    no    |
| <a name="input_database_version"></a> [database\_version](#input\_database\_version)                                   | PostgreSQL version for the instance (e.g. POSTGRES\_16).                                                                                                                                                                                                                                                                                                                        | `string`       | `"POSTGRES_16"`      |    no    |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection)                          | Whether the instance is protected from deletion. Keep true for real environments; examples/tests set it false.                                                                                                                                                                                                                                                                  | `bool`         | `true`               |    no    |
| <a name="input_edition"></a> [edition](#input\_edition)                                                                | The edition of the Cloud SQL instance. ENTERPRISE\_PLUS unlocks higher performance and availability features; the chosen tier must be compatible with the edition.                                                                                                                                                                                                              | `string`       | `"ENTERPRISE"`       |    no    |
| <a name="input_iam_service_account_emails"></a> [iam\_service\_account\_emails](#input\_iam\_service\_account\_emails) | Email addresses of Google service accounts to register as IAM database users. A GKE pod<br/>authenticates to the instance (no password) by running under a Kubernetes SA bound via<br/>Workload Identity to one of these GSAs. The GSAs and their project-level IAM grants<br/>(roles/cloudsql.client, roles/cloudsql.instanceUser) are owned by the consumer, not this module. | `list(string)` | `[]`                 |    no    |
| <a name="input_name"></a> [name](#input\_name)                                                                         | Name of the Cloud SQL instance. Also used as the prefix for the database.                                                                                                                                                                                                                                                                                                       | `string`       | n/a                  |   yes    |
| <a name="input_network"></a> [network](#input\_network)                                                                | Self link or ID of the VPC network the instance gets a private IP on. Wire this to the vpc module's network\_self\_link output; the VPC must have Private Service Access configured.                                                                                                                                                                                            | `string`       | n/a                  |   yes    |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id)                                                     | The ID of the project in which to create the instance.                                                                                                                                                                                                                                                                                                                          | `string`       | n/a                  |   yes    |
| <a name="input_region"></a> [region](#input\_region)                                                                   | Region for the Cloud SQL instance (e.g. us-central1).                                                                                                                                                                                                                                                                                                                           | `string`       | n/a                  |   yes    |
| <a name="input_tier"></a> [tier](#input\_tier)                                                                         | Machine tier for the instance (e.g. db-custom-1-3840, db-f1-micro).                                                                                                                                                                                                                                                                                                             | `string`       | `"db-custom-1-3840"` |    no    |
| <a name="input_user_labels"></a> [user\_labels](#input\_user\_labels)                                                  | Labels applied to the Cloud SQL instance.                                                                                                                                                                                                                                                                                                                                       | `map(string)`  | `{}`                 |    no    |

## Outputs

| Name                                                                                                             | Description                                                                                                            |
| ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name)                                    | The name of the application database.                                                                                  |
| <a name="output_iam_user_names"></a> [iam\_user\_names](#output\_iam\_user\_names)                               | Map of GSA email to the IAM database username registered on the instance. Use the username as the Postgres login role. |
| <a name="output_instance_connection_name"></a> [instance\_connection\_name](#output\_instance\_connection\_name) | Connection name in the form project:region:instance, used by Cloud SQL connectors and the Auth Proxy.                  |
| <a name="output_instance_name"></a> [instance\_name](#output\_instance\_name)                                    | The name of the Cloud SQL instance (used as the connection target and by the Auth Proxy / connectors).                 |
| <a name="output_private_ip_address"></a> [private\_ip\_address](#output\_private\_ip\_address)                   | The private IP address of the instance on the VPC. Pods connect to this address.                                       |
<!-- END_TF_DOCS -->
