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
      # Private IP only — no public endpoint. Requires Private Service Access on the network.
      ipv4_enabled    = false
      private_network = var.network
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

# Register each GSA as a passwordless IAM database user.
resource "google_sql_user" "iam" {
  for_each = local.iam_user_names

  name     = each.value
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
