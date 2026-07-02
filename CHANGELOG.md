# Changelog

All notable changes to the modules in this catalog are recorded here. Modules are consumed by
pinned git tag (`<provider>-<name>-vX.Y.Z`), so each entry maps to a released tag. Versioning follows
the `release-module` steering:

- **MAJOR** — breaking change to a module's public contract (inputs/outputs).
- **MINOR** — backward-compatible additions (new optional inputs, new outputs, opt-in behaviour).
- **PATCH** — fixes that don't change the contract (bug fixes, refactors, docs/tests).

## aws-autoscaling-group-v0.1.0

Initial release of the `aws/autoscaling-group` module: an EC2 Auto Scaling group fronted by a
launch template, with a single CPU target-tracking scaling policy.

- **Inputs:** `name` (required, validated), `ami_id` (required, validated), `subnet_ids` (required),
  `instance_type`, `iam_instance_profile`, `vpc_security_group_ids`, `associate_public_ip_address`,
  `user_data`, `root_volume_size`, `min_size` / `max_size` / `desired_capacity`,
  `target_cpu_utilization`, `estimated_instance_warmup`, `health_check_type` /
  `health_check_grace_period`, `tags`.
- **Scaling:** `TargetTrackingScaling` on the `ASGAverageCPUUtilization` predefined metric — AWS
  manages the underlying CloudWatch alarms; the consumer only sets a CPU target.
- **Security baseline (owned by the module):** IMDSv2 required and an encrypted `gp3` root volume on
  the launch template.
- **Outputs:** `autoscaling_group_name`, `autoscaling_group_arn`, `launch_template_id`,
  `launch_template_latest_version`, `scaling_policy_arn`.

## aws-s3-bucket-v0.1.0

Initial release of the `aws/s3-bucket` module: a single, hardened-by-default S3 bucket.

- **Inputs:** `bucket_name` (required, validated), `force_destroy` (bool, default `false`),
  `bucket_policy` (optional JSON string — attached via `aws_s3_bucket_policy` when set, mirroring the
  raw passthrough style of `iam-instance-profile`), `tags`.
- **Security baseline (owned by the module):** all public access blocked, server-side encryption
  (SSE-S3 / `AES256`) on by default, and object ownership `BucketOwnerEnforced` (ACLs disabled).
- **Outputs:** `bucket` (name/id), `arn`.
