# Changelog

All notable changes to the modules in this catalog are recorded here. Modules are consumed by
pinned git tag (`<provider>-<name>-vX.Y.Z`), so each entry maps to a released tag. Versioning follows
the `release-module` steering:

- **MAJOR** — breaking change to a module's public contract (inputs/outputs).
- **MINOR** — backward-compatible additions (new optional inputs, new outputs, opt-in behaviour).
- **PATCH** — fixes that don't change the contract (bug fixes, refactors, docs/tests).

## aws-alb-v0.3.0

Adds **first-class Lambda target support** to the `aws/alb` module — backward compatible
(instance/ip target groups are unchanged).

- **Behaviour when a target group sets `target_type = "lambda"`:** the target group is created
  without `port`/`protocol`/`vpc_id` and without an HTTP health check (all invalid for Lambda
  targets); the module creates an `aws_lambda_permission` granting
  `elasticloadbalancing.amazonaws.com` permission to invoke the function, and registers the function
  (passed as the single `target_ids` entry, its ARN) with the group. Point the listener at it via
  `default_target_group_key` or a listener rule as usual.
- **New `target_groups` field:** `lambda_multi_value_headers_enabled` (default `false`) — send
  headers and query-string parameters to the function as multi-value maps. Ignored for non-lambda
  groups.
- **Contract change (non-breaking):** `target_groups[*].port` is now optional (it is required only
  for instance/ip groups, enforced by validation), and `target_type` is validated against
  `instance | ip | lambda`.
- **Example/test:** new `examples/lambda/` (ALB fronting a Lambda) and a `TestALBLambdaTarget`
  Terratest.

## aws-lambda-v0.2.0

Adds an **`ignore_code_changes`** input to the `aws/lambda` module — backward compatible (default
`false` preserves the existing Terraform-owns-code behaviour).

- **New input:** `ignore_code_changes` (bool, default `false`). When `true`, Terraform creates the
  function from the initial `filename` once and then ignores `filename`/`source_code_hash` on later
  applies, so an external deployer (a CI pipeline running `aws lambda update-function-code`) owns
  code rollouts without Terraform reverting them — the Lambda analogue of an ECS service that ignores
  task-definition changes. Configuration (runtime, memory, environment, role) stays
  Terraform-managed either way.
- **Implementation:** selected between two count-gated `aws_lambda_function` resources (one with a
  `lifecycle.ignore_changes` on the code) because `lifecycle` blocks can't be driven by a variable —
  the same pattern the `ecs-fargate-service` module uses for `ignore_task_definition_changes`.
  Outputs are unchanged and resolve through whichever variant is active.
- **Test:** new `TestLambdaIgnoreCodeChanges` Terratest applying the `ignore_code_changes = true`
  variant.

## aws-alb-v0.2.0

Adds **optional HTTPS termination** to the `aws/alb` module — backward compatible (plain-HTTP
behaviour is unchanged when the new inputs are unset).

- **New inputs:** `certificate_arn` (ACM cert ARN; when set, the module adds an HTTPS listener and
  turns the HTTP listener into a 301 redirect to HTTPS), `https_listener_port` (default `443`),
  `ssl_policy` (default `ELBSecurityPolicy-TLS13-1-2-2021-06`).
- **Behaviour when `certificate_arn` is set:** an `aws_lb_listener` on `https_listener_port`
  terminates TLS with the certificate; the port-`80` listener becomes a permanent redirect to HTTPS;
  listener rules and the default action attach to the HTTPS listener; the module-created security
  group also opens the HTTPS port.
- **New output:** `https_listener_arn` (null when no certificate is supplied).

## aws-ecs-fargate-service-v0.1.0

Initial release of the `aws/ecs-fargate-service` module: a Fargate service plus everything one
containerised workload needs — task definition, service, execution + task IAM roles, a CloudWatch log
group, and an optional task security group. Wire it behind an ALB via `target_group_arn`.

- **Inputs:** `name` (required, validated), `cluster_arn` (required), `container_image` (required),
  `container_name` (default `app`), `container_port` (default `8080`), `cpu`/`memory` (Fargate combo,
  default 256/512), `cpu_architecture` (validated enum, default `X86_64`), `desired_count`,
  `subnet_ids` (required), `assign_public_ip`, `vpc_id` (required only when creating the SG —
  cross-variable validated), `security_group_ids` / `create_security_group` /
  `ingress_security_group_ids`, `target_group_arn` (optional — no LB when null),
  `health_check_grace_period_seconds`, `environment`, `execution_policy_arns` / `task_policy_arns`,
  `log_retention_in_days`, `enable_execute_command`, `ignore_task_definition_changes` (default true),
  `tags`.
- **Deployment ownership:** by default the service ignores `task_definition` and `desired_count`
  changes so an external CI deployer owns rolling deployments (registers new task-def revisions)
  without Terraform reverting the image. Implemented as two count-gated service resources because
  `lifecycle.ignore_changes` cannot be dynamic. Set the flag false for full Terraform management.
- **IAM (owned by the module):** an execution role with `AmazonECSTaskExecutionRolePolicy` (pull
  image, write logs) plus extra `execution_policy_arns`, and a separate task role for the app with
  `task_policy_arns`.
- **Outputs:** `service_name`, `service_id`, `task_definition_arn`, `task_definition_family`,
  `container_name`, `container_port`, `execution_role_arn`, `task_role_arn`, `security_group_id`,
  `log_group_name`.

## aws-ecs-cluster-v0.1.0

Initial release of the `aws/ecs-cluster` module: a serverless (Fargate) ECS cluster and its capacity
providers — the grouping that services and tasks run in.

- **Inputs:** `name` (required, validated), `enable_container_insights` (default false),
  `capacity_providers` (validated subset of `FARGATE`/`FARGATE_SPOT`, default both),
  `default_capacity_provider` (default `FARGATE`), `tags`.
- **Resources (owned by the module):** one `aws_ecs_cluster` and an
  `aws_ecs_cluster_capacity_providers` with a default strategy.
- **Outputs:** `cluster_arn`, `cluster_name`, `cluster_id`.

## aws-ecr-v0.1.0

Initial release of the `aws/ecr` module: a single ECR repository to store an application's images —
the AWS analogue of a `gcp/artifact-registry` repo.

- **Inputs:** `name` (required, validated), `image_tag_mutability` (validated enum, default
  `MUTABLE`), `scan_on_push` (default true), `force_delete` (default false),
  `untagged_image_expiry_days` (optional — attaches a lifecycle policy expiring untagged images),
  `tags`.
- **Security baseline (owned by the module):** encryption at rest (`AES256`) and scan-on-push. Access
  (push/pull) is left to IAM — scope a CI role to the repo's ARN.
- **Outputs:** `repository_url`, `arn`, `name`, `registry_id`.

## aws-acm-certificate-v0.1.0

Initial release of the `aws/acm-certificate` module: a public, DNS-validated ACM certificate whose
validation records are written into a Route 53 hosted zone the caller owns, blocking until the
certificate is ISSUED.

- **Inputs:** `domain_name` (required, validated, wildcard allowed), `subject_alternative_names`
  (default empty), `hosted_zone_id` (required — the zone to validate in), `validation_record_ttl`
  (default 60), `key_algorithm` (optional), `tags`.
- **Resources (owned by the module):** one `aws_acm_certificate` (DNS validation,
  `create_before_destroy`), a deduped `aws_route53_record` per validation option, and an
  `aws_acm_certificate_validation` that waits for issuance.
- **Outputs:** `certificate_arn` (from the validation resource, so reading it guarantees the cert is
  ready), `domain_name`, `status`, `validation_record_fqdns`.

## aws-route53-v0.1.0

Initial release of the `aws/route53` module: a single Route 53 hosted zone (public or private) plus
its records — the AWS analogue of `gcp/cloud-dns`.

- **Inputs:** `name` (required, validated domain), `visibility` (required, `public`/`private`),
  `vpc_associations` (required non-empty for private zones, must be empty for public — validated),
  `records` (map keyed by name relative to the zone; `""` = apex; each entry sets
  `type`/`ttl`/`records`), `validation_records` (map keyed by a stable caller label for
  computed-name ACM DNS-validation CNAMEs — keeps `for_each` plan-time-known), `delegate_to_parent_zone`
  (optional object `zone_id`/`ttl` that writes this zone's `NS` record into a parent zone for
  reproducible subdomain delegation), `comment`, `force_destroy`, `tags`.
- **Resources (owned by the module):** one `aws_route53_zone`, one `aws_route53_record` per entry in
  `records`, per-entry `validation_records`, and an optional `NS` delegation record.
- **Outputs:** `zone_id`, `zone_arn`, `name`, `name_servers`, `record_fqdns`,
  `validation_record_fqdns`, `delegation_record_name`.

## aws-lambda-v0.1.0

Initial release of the `aws/lambda` module: a Lambda function plus its execution role, with optional
VPC attachment and a retention-managed CloudWatch log group.

- **Inputs:** `name` (required, validated), `filename` (required — path to the deployment zip,
  hashed for `source_code_hash`), `handler` (default `bootstrap`), `runtime` (default
  `provided.al2023`), `architecture` (validated enum, default `x86_64`), `memory_size` (validated),
  `timeout` (validated), `environment_variables`, `vpc_config` (optional object of
  `subnet_ids`/`security_group_ids`), `additional_policy_arns`, `inline_policies`,
  `log_retention_in_days` (default 14), `tags`.
- **Execution role (owned by the module):** always attaches `AWSLambdaBasicExecutionRole`; when
  `vpc_config` is set, also attaches `AWSLambdaVPCAccessExecutionRole` so the function can manage the
  ENIs it needs to reach private VPC resources. Extra grants via `additional_policy_arns` /
  `inline_policies`.
- **Outputs:** `function_name`, `function_arn`, `invoke_arn`, `role_arn`, `role_name`,
  `log_group_name`.

## aws-security-group-v0.1.0

Initial release of the `aws/security-group` module: a single VPC security group with
consumer-supplied ingress/egress rules and first-class security-group-to-security-group references.

- **Inputs:** `name` (required, validated), `vpc_id` (required), `description`, `ingress_rules`
  (list — per rule `from_port`/`to_port`/`protocol` plus exactly one of `cidr_blocks` or
  `source_security_group_id`, validated; empty by default = no inbound), `egress_rules` (same shape;
  defaults to a single allow-all rule), `tags`.
- **Rule model (owned by the module):** rules are managed with the current best-practice
  `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` resources (one CIDR or
  one referenced SG per rule) rather than legacy inline blocks; a rule with multiple `cidr_blocks` is
  expanded to one rule resource per CIDR.
- **Outputs:** `id`, `arn`, `name`.

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
