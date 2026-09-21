variable "export_name" {
  description = "Name of the data export. Unique per account."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9!_.*'()-]{1,128}$", var.export_name))
    error_message = "export_name must be 1-128 characters of alphanumerics or !_.*'()- ."
  }
}

variable "s3_bucket" {
  description = <<-EOT
    Name of the destination S3 bucket. The bucket must already exist — compose this module with
    `aws/s3-bucket` rather than having it create one.

    The bucket should be DEDICATED to exports, because this module manages its bucket policy (see
    `manage_bucket_policy`) and S3 allows only one policy per bucket.
  EOT
  type        = string
  nullable    = false
}

variable "s3_prefix" {
  description = "Key prefix within the bucket to deliver under, e.g. `cur2`. Default empty writes to the bucket root. A prefix is worth setting so a lifecycle rule can target the export without touching anything else."
  type        = string
  nullable    = false
  default     = ""
}

variable "s3_region" {
  description = "Region of the destination bucket. Taken as an input rather than inferred, because the export's control plane always lives in us-east-1 while the bucket can live anywhere."
  type        = string
  nullable    = false
}

variable "table" {
  description = <<-EOT
    Which export table to deliver.

      - `COST_AND_USAGE_REPORT` (default) — CUR 2.0, the recommended detailed cost and usage dataset.
      - `FOCUS_1_0_AWS` / `FOCUS_1_2_AWS` — the FinOps Open Cost and Usage Specification with AWS
        columns. Worth choosing if you intend to compare AWS spend against another cloud on the same
        schema.
      - `COST_OPTIMIZATION_RECOMMENDATIONS` — Cost Optimization Hub recommendations.
      - `CARBON_EMISSIONS` — carbon footprint data.
  EOT
  type        = string
  nullable    = false
  default     = "COST_AND_USAGE_REPORT"

  validation {
    condition = contains(
      ["COST_AND_USAGE_REPORT", "FOCUS_1_0_AWS", "FOCUS_1_2_AWS", "COST_OPTIMIZATION_RECOMMENDATIONS", "CARBON_EMISSIONS"],
      var.table
    )
    error_message = "table must be one of COST_AND_USAGE_REPORT, FOCUS_1_0_AWS, FOCUS_1_2_AWS, COST_OPTIMIZATION_RECOMMENDATIONS, CARBON_EMISSIONS."
  }
}

variable "table_configurations" {
  description = <<-EOT
    Table configuration overrides for the chosen table, as a flat map of string to string. Null (default)
    applies the module's defaults, which for CUR 2.0 are hourly granularity with resource IDs included.

    Hourly + resource IDs is the most granular the table offers and therefore the largest. It is the
    right default for a foundation: granularity you did not capture cannot be recovered later, whereas
    an export that is too big is a lifecycle rule away from being fine. Drop to `DAILY` and
    `INCLUDE_RESOURCES = "FALSE"` if size matters more than answerability.

    Recognised keys for CUR 2.0: `TIME_GRANULARITY` (HOURLY/DAILY/MONTHLY), `INCLUDE_RESOURCES`,
    `INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY`, `INCLUDE_SPLIT_COST_ALLOCATION_DATA` (all "TRUE"/"FALSE").
    Pass `{}` to send no configuration at all.
  EOT
  type        = map(string)
  nullable    = true
  default     = null
}

variable "columns" {
  description = <<-EOT
    Columns to select from the table. Empty (default) uses the module's curated column list for the
    chosen table; tables with no curated list require either this input or `query_statement`.

    Selecting columns rather than everything is the point of Data Exports: a narrower export is cheaper
    to store and query, and it lets you leave sensitive cost detail out of a dataset you intend to share
    more widely.
  EOT
  type        = list(string)
  nullable    = false
  default     = []
}

variable "query_statement" {
  description = "Full SQL SELECT statement, overriding `columns`. Null (default) builds `SELECT <columns> FROM <table>`. Use this when you need row filters (a `WHERE` clause) or renamed columns."
  type        = string
  nullable    = true
  default     = null
}

variable "format" {
  description = "Output format: PARQUET (default) or TEXT_OR_CSV. Parquet is columnar and typed, so it is both smaller and far cheaper to query with Athena — prefer it unless something downstream can only read CSV."
  type        = string
  nullable    = false
  default     = "PARQUET"

  validation {
    condition     = contains(["PARQUET", "TEXT_OR_CSV"], var.format)
    error_message = "format must be PARQUET or TEXT_OR_CSV."
  }
}

variable "compression" {
  description = "Compression: PARQUET (default) or GZIP. AWS pairs these with the format — PARQUET format requires PARQUET compression, TEXT_OR_CSV requires GZIP. The module validates the pairing."
  type        = string
  nullable    = false
  default     = "PARQUET"

  validation {
    condition     = contains(["PARQUET", "GZIP"], var.compression)
    error_message = "compression must be PARQUET or GZIP."
  }
}

variable "overwrite" {
  description = <<-EOT
    How each refresh is written:

      - `OVERWRITE_REPORT` (default) replaces the current period's file in place, so the bucket holds one
        copy per period. Cheaper, and what you want unless you need an audit trail.
      - `CREATE_NEW_REPORT` keeps every version, so storage grows with each refresh (several times a day).
  EOT
  type        = string
  nullable    = false
  default     = "OVERWRITE_REPORT"

  validation {
    condition     = contains(["OVERWRITE_REPORT", "CREATE_NEW_REPORT"], var.overwrite)
    error_message = "overwrite must be OVERWRITE_REPORT or CREATE_NEW_REPORT."
  }
}

variable "manage_bucket_policy" {
  description = <<-EOT
    When true (default), the module attaches the bucket policy Data Exports requires in order to deliver
    at all. AWS refuses to create the export without it, and the console reports only a generic "Invalid
    bucket".

    Set false if something else owns the bucket's policy — then take `required_bucket_policy_json` from
    the outputs and attach it yourself, and make sure it exists before this module runs.
  EOT
  type        = bool
  nullable    = false
  default     = true
}

variable "source_account_id" {
  description = "Account that owns the export, used in the bucket policy's `aws:SourceArn` / `aws:SourceAccount` conditions. Null (default) uses the calling account."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = var.source_account_id == null || can(regex("^[0-9]{12}$", var.source_account_id))
    error_message = "source_account_id must be a 12-digit AWS account id."
  }
}

variable "tags" {
  description = "Tags applied to the export."
  type        = map(string)
  nullable    = false
  default     = {}
}
