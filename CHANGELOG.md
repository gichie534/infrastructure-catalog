# Changelog

All notable changes to the modules in this catalog are recorded here. Modules are consumed by
pinned git tag (`<provider>-<name>-vX.Y.Z`), so each entry maps to a released tag. Versioning follows
the `release-module` steering:

- **MAJOR** — breaking change to a module's public contract (inputs/outputs).
- **MINOR** — backward-compatible additions (new optional inputs, new outputs, opt-in behaviour).
- **PATCH** — fixes that don't change the contract (bug fixes, refactors, docs/tests).

## aws-s3-bucket-v0.1.0

Initial release of the `aws/s3-bucket` module: a single, hardened-by-default S3 bucket.

- **Inputs:** `bucket_name` (required, validated), `force_destroy` (bool, default `false`),
  `bucket_policy` (optional JSON string — attached via `aws_s3_bucket_policy` when set, mirroring the
  raw passthrough style of `iam-instance-profile`), `tags`.
- **Security baseline (owned by the module):** all public access blocked, server-side encryption
  (SSE-S3 / `AES256`) on by default, and object ownership `BucketOwnerEnforced` (ACLs disabled).
- **Outputs:** `bucket` (name/id), `arn`.
