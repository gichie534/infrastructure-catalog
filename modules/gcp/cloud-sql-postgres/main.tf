# Cloud SQL for PostgreSQL with a private IP on the consumer's VPC and IAM database
# authentication. GKE pods connect over private IP and authenticate (passwordless) by
# running under a Kubernetes SA bound via Workload Identity to a registered GSA.
#
# This module owns only (a) the instance + database and (b) the IAM database users for
# the supplied GSAs. The GSA lifecycle and project-level IAM grants belong to the consumer.

locals {
  # IAM service-account database users are named by the GSA email with the
  # ".gserviceaccount.com" suffix removed.
  iam_user_names = {
    for email in var.iam_service_account_emails :
    email => trimsuffix(email, ".gserviceaccount.com")
  }
}

resource "google_sql_database_instance" "this" {
  name                = var.name
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    edition           = var.edition
    user_labels       = var.user_labels
    availability_type = "ZONAL"

    ip_configuration {
      # Private IP on the consumer's VPC (requires Private Service Access on the network). A public
      # endpoint is added only when enable_public_ip is true (e.g. for an external migration client),
      # gated by the authorized_networks allowlist.
      ipv4_enabled    = var.enable_public_ip
      private_network = var.network
      ssl_mode        = var.ssl_mode

      dynamic "authorized_networks" {
        for_each = { for n in var.authorized_networks : n.name => n.value }
        content {
          name  = authorized_networks.key
          value = authorized_networks.value
        }
      }
    }

    # Enable IAM database authentication.
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }
}

resource "google_sql_database" "this" {
  name     = var.database_name
  project  = var.project_id
  instance = google_sql_database_instance.this.name
}

# Optionally set a password on the built-in `postgres` admin user, enabling password authentication
# for it (e.g. so a migration can restore as postgres). The user already exists on the instance;
# this manages its password.
resource "google_sql_user" "admin" {
  count = var.admin_password == null ? 0 : 1

  name     = "postgres"
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  password = var.admin_password

  # The built-in postgres user owns objects once a database has been populated (extensions, restored
  # schema, ...), so dropping it on destroy fails ("role cannot be dropped because objects depend on
  # it"). ABANDON removes it from Terraform state without issuing DROP ROLE — the instance teardown
  # takes the user with it. (Also, the built-in admin user isn't meant to be dropped.)
  deletion_policy = "ABANDON"
}

# Register each GSA as a passwordless IAM database user.
resource "google_sql_user" "iam" {
  for_each = local.iam_user_names

  name     = each.value
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
