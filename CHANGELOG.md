# Changelog

All notable changes to the modules in this catalog are recorded here. Modules are consumed by
pinned git tag (`<provider>-<name>-vX.Y.Z`), so each entry maps to a released tag. Versioning follows
the `release-module` steering:

- **MAJOR** — breaking change to a module's public contract (inputs/outputs).
- **MINOR** — backward-compatible additions (new optional inputs, new outputs, opt-in behaviour).
- **PATCH** — fixes that don't change the contract (bug fixes, refactors, docs/tests).

## aws-alb-v0.1.0

Initial release of the `aws/alb` module: an Application Load Balancer with an HTTP listener, target
groups, and path- and host-based routing rules.

- **Inputs:** `name` (required, validated), `vpc_id` (required), `subnet_ids` (required, ≥2 AZs),
  `target_groups` (required map — port/protocol/target\_type/target\_ids/health-check settings per
  group), `listener_rules` (map — priority + target\_group\_key + path\_patterns and/or host\_headers,
  validated to require at least one matcher), `default_target_group_key`, `internal`,
  `enable_deletion_protection`, `listener_port`, `security_group_ids` / `create_security_group` /
  `ingress_cidr_blocks`, `tags`.
- **Routing:** listener evaluates rules by ascending priority and forwards to the matched target
  group; unmatched requests forward to `default_target_group_key` or, when null, get a fixed `404`.
- **Security group:** optionally created by the module (inbound on `listener_port` from
  `ingress_cidr_blocks`, all egress), or supply your own via `security_group_ids`.
- **Outputs:** `arn`, `dns_name`, `zone_id`, `security_group_id`, `target_group_arns`,
  `target_group_names`, `listener_arn`.

## aws-cloudfront-s3-v0.1.0

Initial release of the `aws/cloudfront-s3` module: a CloudFront distribution that fronts one or more
**private** S3 buckets and routes requests to them by path pattern, using Origin Access Control (OAC)
so the buckets stay fully private.

- **Inputs:** `name` (required, validated), `origins` (required map — per-origin
  `domain_name`/`origin_path`, keyed by logical origin id), `default_origin_key` (required),
  `ordered_cache_behaviors` (list of `path_pattern` -> `origin_key`, first match wins),
  `cache_policy_id` (optional — managed/custom cache policy applied to every behavior; defaults to
  the managed CachingOptimized policy, set to CachingDisabled to bypass caching),
  `default_root_object` (default `index.html`), `price_class` (validated enum, default
  `PriceClass_100`), `comment`, `tags`.
- **Access model (owned by the module):** one shared Origin Access Control (`always` sign, `sigv4`)
  wired to every S3 origin; viewer requests redirected to HTTPS; `GET`/`HEAD` only with the managed
  CachingOptimized policy on the default `*.cloudfront.net` certificate. The module does **not** own
  the buckets or their policies — the consumer grants `s3:GetObject` to the `cloudfront.amazonaws.com`
  principal scoped by `AWS:SourceArn = distribution_arn`.
- **Outputs:** `distribution_id`, `distribution_arn`, `domain_name`, `hosted_zone_id`,
  `origin_access_control_id`.

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
