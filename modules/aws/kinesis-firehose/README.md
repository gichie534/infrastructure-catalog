# aws/kinesis-firehose

A Kinesis Data Firehose delivery stream that buffers records and writes them to S3, together with the
IAM role Firehose assumes and the CloudWatch log group it reports delivery failures to.

Firehose is the managed bridge from a stream to durable storage: producers keep writing to a Kinesis
data stream, and Firehose accumulates records and lands them in S3 as objects without you running a
consumer. The tradeoff it introduces is latency — data is not in S3 until a buffer flushes.

## What this module owns, and what it does not

It owns the **delivery stream, its IAM role, and its log group**. The role is owned here rather than
by the consumer because it exists solely to serve this delivery stream, its permissions are entirely
derived from the source stream and destination bucket, and a consumer could not assemble it without
duplicating Firehose's exact requirements. This mirrors how `ecs-fargate-service` owns its execution
and task roles.

It does **not** create the destination bucket or the source stream. Pass their ARNs from
`aws/s3-bucket` and `aws/kinesis-stream`.

## Usage

```hcl
module "delivery" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/kinesis-firehose?ref=aws-kinesis-firehose-vX.Y.Z"

  name                      = "user-events-to-s3"
  source_kinesis_stream_arn = module.events.arn
  destination_bucket_arn    = module.data_lake.arn

  prefix              = "stream/"
  error_output_prefix = "errors/"

  buffering_interval_seconds = 60
  buffering_size_mb          = 1

  tags = {
    Environment = "dev"
  }
}
```

## Buffering is the latency floor

Firehose flushes when **either** `buffering_size_mb` or `buffering_interval_seconds` is reached,
whichever comes first. On a low-volume stream the size threshold is never hit, so the interval is
what governs delivery — and therefore the floor on how fresh any downstream consumer of those objects
can be. 60 seconds is the lowest practical setting.

This is the single most important number when comparing a streaming path against a batch upload: a
direct `PutObject` is queryable immediately, while the same record arriving via Firehose is not in S3
until the buffer flushes. `buffering_interval_seconds` is exported as an output so a consumer can
measure and report that gap rather than guess at it.

## Prefixes

`prefix` scopes delivered objects to a key prefix (default is Firehose's own `YYYY/MM/DD/HH/`
layout). Setting a distinct prefix matters when something downstream loads from the bucket — a
Redshift `COPY` pointed at `stream/` will not accidentally pick up objects written by another path.

Set `error_output_prefix` for the same reason in reverse: undelivered records land somewhere a
downstream load will not read them.

## Direct PUT

Leave `source_kinesis_stream_arn` null for a Direct PUT delivery stream. Producers then call the
Firehose `PutRecord` API directly and no Kinesis data stream is involved — simpler, but you lose the
stream's replay window and the ability to attach multiple independent consumers.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.66.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_stream.s3_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_iam_role.delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kinesis_firehose_delivery_stream.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_firehose_delivery_stream) | resource |
| [aws_iam_policy_document.assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_buffering_interval_seconds"></a> [buffering\_interval\_seconds](#input\_buffering\_interval\_seconds) | Buffer records for at most this many seconds, then flush to S3 (0-900). This is the floor on<br/>end-to-end latency for anything reading the delivered objects, so it is the dominant term in how<br/>fresh streamed data can be. Default 300; 60 is the lowest practical value for a low-latency<br/>pipeline. | `number` | `300` | no |
| <a name="input_buffering_size_mb"></a> [buffering\_size\_mb](#input\_buffering\_size\_mb) | Buffer records until this many MB have accumulated, then flush to S3 (1-128). Firehose flushes on<br/>whichever of size/interval is hit first. | `number` | `5` | no |
| <a name="input_compression_format"></a> [compression\_format](#input\_compression\_format) | Compression applied to delivered objects. `UNCOMPRESSED` (default) keeps them directly readable, which matters when a downstream loader or human inspects them. `GZIP` cuts storage and transfer cost. | `string` | `"UNCOMPRESSED"` | no |
| <a name="input_destination_bucket_arn"></a> [destination\_bucket\_arn](#input\_destination\_bucket\_arn) | ARN of the S3 bucket buffered records are delivered to. The bucket is NOT created by this module — pass one the consumer owns (e.g. the `arn` output of `aws/s3-bucket`). The delivery role is granted write on it. | `string` | n/a | yes |
| <a name="input_enable_cloudwatch_logging"></a> [enable\_cloudwatch\_logging](#input\_enable\_cloudwatch\_logging) | Create a log group and have Firehose report delivery failures to it. Default true — without it a delivery stream that cannot write to S3 fails silently. | `bool` | `true` | no |
| <a name="input_error_output_prefix"></a> [error\_output\_prefix](#input\_error\_output\_prefix) | Key prefix for records Firehose failed to deliver. Null (the default) writes them alongside successful output. Setting a distinct prefix such as `errors/` keeps failures from being picked up by a downstream load. | `string` | `null` | no |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | Retention for the delivery log group. Only used when `enable_cloudwatch_logging` is true. | `number` | `7` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the Firehose delivery stream. Unique per account and region; also used to name the delivery IAM role and log group. | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Key prefix for delivered objects. Null (the default) uses Firehose's own `YYYY/MM/DD/HH/` layout.<br/>Set something like `stream/` to keep delivered data separate from other writers in the same<br/>bucket — useful when a downstream COPY needs to target only these objects. Supports Firehose<br/>prefix expressions such as `stream/!{timestamp:yyyy/MM/dd}/`. | `string` | `null` | no |
| <a name="input_source_kinesis_stream_arn"></a> [source\_kinesis\_stream\_arn](#input\_source\_kinesis\_stream\_arn) | ARN of a Kinesis data stream to read from. When set, Firehose polls that stream and the delivery<br/>role is granted read on it. Leave null (the default) for a Direct PUT delivery stream that<br/>producers write to with the Firehose PutRecord API instead. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource created by this module (delivery stream, IAM role, log group). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the delivery stream. |
| <a name="output_buffering_interval_seconds"></a> [buffering\_interval\_seconds](#output\_buffering\_interval\_seconds) | Configured buffer interval. This is the floor on delivery latency, so a consumer measuring end-to-end freshness needs it. |
| <a name="output_delivery_role_arn"></a> [delivery\_role\_arn](#output\_delivery\_role\_arn) | ARN of the IAM role Firehose assumes. Exported so a consumer can grant it additional access (e.g. a KMS key on the destination bucket). |
| <a name="output_delivery_role_name"></a> [delivery\_role\_name](#output\_delivery\_role\_name) | Name of the IAM role Firehose assumes. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the CloudWatch log group Firehose reports delivery failures to, or null when logging is disabled. |
| <a name="output_name"></a> [name](#output\_name) | Name of the delivery stream. Direct PUT producers pass this to the Firehose API as DeliveryStreamName. |
| <a name="output_prefix"></a> [prefix](#output\_prefix) | Key prefix delivered objects are written under, or null when Firehose's default `YYYY/MM/DD/HH/` layout is used. A downstream loader uses this to scope which objects to read. |
<!-- END_TF_DOCS -->
