# aws/kinesis-stream

A single Amazon Kinesis data stream — the ordered, replayable buffer producers write records into and
consumers read from independently, each tracking its own position. Provisioned single-shard by
default, with server-side encryption via the AWS-managed `alias/aws/kinesis` key and the free-tier
24-hour replay window.

This module owns **only the stream**. It deliberately does not create producer/consumer IAM
policies, nor any downstream delivery (Firehose, Lambda event source mapping) — those are the
consumer's composition concern, wired from the stream ARN this module outputs. Keeping the module
single-purpose keeps it reusable across labs.

## Usage

```hcl
module "events" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/kinesis-stream?ref=aws-kinesis-stream-vX.Y.Z"

  name        = "user-events"
  shard_count = 1

  shard_level_metrics = [
    "WriteProvisionedThroughputExceeded",
    "IteratorAgeMilliseconds",
  ]

  tags = {
    Environment = "dev"
  }
}
```

Grant a producer and a consumer by referencing the stream ARN from their own IAM policies:

```hcl
# producer policy statement
{
  Effect   = "Allow"
  Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
  Resource = module.events.arn
}

# consumer policy statement
{
  Effect   = "Allow"
  Action   = ["kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:DescribeStream", "kinesis:ListShards"]
  Resource = module.events.arn
}
```

Both clients call the Kinesis API with `module.events.name` as the `StreamName`.

## Capacity mode

`PROVISIONED` (the default) means you choose `shard_count` and pay per shard-hour. Each shard absorbs
1 MiB/s or 1,000 records/s of writes and 2 MiB/s of reads — predictable and cheapest when you know
your throughput.

`ON_DEMAND` lets AWS scale shards for you at a higher per-GB rate. It ignores `shard_count`, so the
module requires that you leave it null; the pairing is validated at plan time rather than failing
during apply.

## Retention is the replay window

`retention_period_hours` is how far back a consumer can re-read. That replay capability is the main
thing a stream gives you over a queue: a second consumer can be added later and read history, and a
broken consumer can be fixed and re-run. Anything beyond the default 24 hours bills as extended
retention.

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
| [aws_kinesis_stream.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_stream) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_encryption_type"></a> [encryption\_type](#input\_encryption\_type) | Server-side encryption for records at rest. `KMS` (default) encrypts with the key in `kms_key_id`; `NONE` disables encryption and should only be used with a specific reason. | `string` | `"KMS"` | no |
| <a name="input_enforce_consumer_deletion"></a> [enforce\_consumer\_deletion](#input\_enforce\_consumer\_deletion) | Allow the stream to be destroyed even when registered enhanced fan-out consumers still exist. Leave false for anything you care about; set true in throwaway lab environments so destroy runs clean. | `bool` | `false` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key used when `encryption_type` is `KMS`. Accepts an alias, key ID, or ARN. Defaults to the AWS-managed Kinesis key, which costs nothing extra. | `string` | `"alias/aws/kinesis"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the Kinesis data stream. Unique per account and region. | `string` | n/a | yes |
| <a name="input_retention_period_hours"></a> [retention\_period\_hours](#input\_retention\_period\_hours) | Hours a record stays readable in the stream (24-8760). This is the replay window: a consumer can<br/>re-read anything inside it. Default 24 (the free tier); beyond 24 hours incurs extended-retention<br/>charges. | `number` | `24` | no |
| <a name="input_shard_count"></a> [shard\_count](#input\_shard\_count) | Number of shards, used only when `stream_mode` is `PROVISIONED`. Each shard takes 1 MiB/s or<br/>1,000 records/s of writes and 2 MiB/s of reads. Must be null when `stream_mode` is `ON_DEMAND`. | `number` | `1` | no |
| <a name="input_shard_level_metrics"></a> [shard\_level\_metrics](#input\_shard\_level\_metrics) | Per-shard CloudWatch metrics to enable. Empty by default because each one bills as a custom<br/>metric. `WriteProvisionedThroughputExceeded` surfaces producer throttling and<br/>`IteratorAgeMilliseconds` surfaces consumer lag — the two worth enabling first. | `list(string)` | `[]` | no |
| <a name="input_stream_mode"></a> [stream\_mode](#input\_stream\_mode) | Capacity mode. `PROVISIONED` (default) means you choose `shard_count` and pay per shard-hour —<br/>cheapest and predictable when you know your throughput. `ON_DEMAND` lets AWS scale shards<br/>automatically at a higher per-GB rate, and ignores `shard_count`. | `string` | `"PROVISIONED"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the stream (the one taggable resource this module creates). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the stream. Use this in IAM policy resource statements granting PutRecord/GetRecords, and as the source ARN for a Firehose delivery stream or Lambda event source mapping. |
| <a name="output_id"></a> [id](#output\_id) | ID of the stream (equal to its name). |
| <a name="output_name"></a> [name](#output\_name) | Name of the stream. This is what producers and consumers pass to the Kinesis API as StreamName. |
| <a name="output_retention_period_hours"></a> [retention\_period\_hours](#output\_retention\_period\_hours) | Replay window in hours — how far back a consumer can re-read records. |
| <a name="output_shard_count"></a> [shard\_count](#output\_shard\_count) | Number of shards for a PROVISIONED stream, or null for ON\_DEMAND. A consumer reading shards directly uses this to know how many shard iterators to open. |
| <a name="output_stream_mode"></a> [stream\_mode](#output\_stream\_mode) | Capacity mode the stream was created with (PROVISIONED or ON\_DEMAND). |
<!-- END_TF_DOCS -->
