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
    tier        = var.tier
    edition     = var.edition
    user_labels = var.user_labels

    # REGIONAL provisions a standby in a second zone of the same region with SYNCHRONOUS
    # replication and automatic failover — zonal-failure RPO is zero. ZONAL is a single zone.
    availability_type = var.availability_type

    disk_size             = var.disk_size
    disk_type             = var.disk_type
    disk_autoresize       = var.disk_autoresize
    disk_autoresize_limit = var.disk_autoresize_limit

    # Automated backups + point-in-time recovery (WAL archiving). PITR is what turns "a backup
    # every night" into "restore to any second within the transaction-log retention window".
    dynamic "backup_configuration" {
      for_each = var.backup_configuration == null ? [] : [var.backup_configuration]
      content {
        enabled = backup_configuration.value.enabled
        # Cloud SQL requires start_time in UTC HH:MM.
        start_time = backup_configuration.value.start_time
        # A location different from the instance region keeps a copy of the backups off-region, so a
        # regional outage can't take the instance and its backups at the same time.
        location                       = backup_configuration.value.location
        point_in_time_recovery_enabled = backup_configuration.value.point_in_time_recovery_enabled
        transaction_log_retention_days = backup_configuration.value.transaction_log_retention_days

        backup_retention_settings {
          retained_backups = backup_configuration.value.retained_backups
          retention_unit   = backup_configuration.value.retention_unit
        }
      }
    }

    dynamic "maintenance_window" {
      for_each = var.maintenance_window == null ? [] : [var.maintenance_window]
      content {
        day          = maintenance_window.value.day
        hour         = maintenance_window.value.hour
        update_track = maintenance_window.value.update_track
      }
    }

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

# Cross-region read replicas. ASYNCHRONOUS replication, so the RPO is "replication lag" (typically
# seconds) rather than zero — but a replica survives the loss of the primary's whole region and can
# be PROMOTED to a standalone primary, which is the regional-disaster recovery path. Combine with a
# REGIONAL primary (synchronous, zero-RPO zonal failover) for both failure domains.
#
# Replicas deliberately carry no backup_configuration (Cloud SQL rejects it on a replica) and are
# NOT where IAM DB users are declared — users replicate from the primary.
resource "google_sql_database_instance" "replica" {
  for_each = var.read_replicas

  name                 = "${var.name}-${each.key}"
  project              = var.project_id
  region               = each.value.region
  database_version     = var.database_version
  master_instance_name = google_sql_database_instance.this.name
  deletion_protection  = var.deletion_protection

  settings {
    # Fall back to the primary's shape unless the replica overrides it.
    tier              = coalesce(each.value.tier, var.tier)
    edition           = var.edition
    availability_type = each.value.availability_type
    user_labels       = coalesce(each.value.user_labels, var.user_labels)

    disk_size             = coalesce(each.value.disk_size, var.disk_size)
    disk_type             = coalesce(each.value.disk_type, var.disk_type)
    disk_autoresize       = coalesce(each.value.disk_autoresize, var.disk_autoresize)
    disk_autoresize_limit = coalesce(each.value.disk_autoresize_limit, var.disk_autoresize_limit)

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network
      ssl_mode        = var.ssl_mode
    }

    # Keep IAM auth available after a promotion.
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }
}
