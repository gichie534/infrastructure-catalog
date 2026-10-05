# A single BigQuery dataset.
#
# Deliberately thin: location, expiration defaults, encryption and deletion behaviour. Tables, views and
# fine-grained access are the consumer's concern — for a billing export, Google creates the tables itself
# and adds its own export service account as a dataset OWNER.
#
# That last point decides how access is managed here. An authoritative `access` block (or
# google_bigquery_dataset_iam_policy) would remove Google's export account on the next apply, and the export
# would stop writing with no error anywhere. So this module manages access additively via
# google_bigquery_dataset_iam_member only, and never declares `access` on the dataset itself.

resource "google_bigquery_dataset" "this" {
  project       = var.project_id
  dataset_id    = var.dataset_id
  friendly_name = var.friendly_name
  description   = var.description
  location      = var.location
  labels        = var.labels

  default_table_expiration_ms     = var.default_table_expiration_ms
  default_partition_expiration_ms = var.default_partition_expiration_ms

  delete_contents_on_destroy = var.delete_contents_on_destroy

  dynamic "default_encryption_configuration" {
    for_each = var.kms_key_name == null ? [] : [var.kms_key_name]
    content {
      kms_key_name = default_encryption_configuration.value
    }
  }

  lifecycle {
    # Google appends its own access entries (the export service account, the creator as OWNER). Without
    # this, every plan would propose deleting them.
    ignore_changes = [access]
  }
}

resource "google_bigquery_dataset_iam_member" "this" {
  for_each = { for b in var.iam_members : "${b.role}|${b.member}" => b }

  project    = var.project_id
  dataset_id = google_bigquery_dataset.this.dataset_id
  role       = each.value.role
  member     = each.value.member
}
