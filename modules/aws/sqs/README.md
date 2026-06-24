# aws/sqs

A single Amazon SQS queue — the minimal building block producers and consumers attach to. Standard
by default (set `fifo_queue = true` for FIFO), with SQS-managed server-side encryption (SSE-SQS) on
by default. The visibility timeout, message retention, and long-poll wait time are inputs so a
consumer can tune them to its workload.

This module owns **only the queue**. It deliberately does not create IAM policies, queue access
policies, or dead-letter wiring — those are the consumer's composition concern. A consumer grants
send/receive on the queue to specific principals using the queue ARN this module outputs. Keeping
the module single-purpose keeps it reusable across labs.

## Usage

```hcl
module "queue" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/sqs?ref=aws-sqs-vX.Y.Z"

  name                      = "jobs"
  receive_wait_time_seconds = 10 # enable long polling

  tags = {
    Environment = "dev"
  }
}
```

Grant a producer send and a consumer receive by referencing the queue ARN in their IAM policies:

```hcl
# producer policy statement
{
  Effect   = "Allow"
  Action   = ["sqs:SendMessage"]
  Resource = module.queue.arn
}

# consumer policy statement
{
  Effect   = "Allow"
  Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
  Resource = module.queue.arn
}
```

Both clients call the SQS API with `module.queue.url` as the `QueueUrl`.

## FIFO

For a FIFO queue, set `fifo_queue = true` and give the queue a name ending in `.fifo`; the module
validates that pairing at plan time. FIFO adds ordering and exactly-once processing at the cost of
lower throughput — standard is sufficient for most workloads.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_sqs_queue.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_fifo_queue"></a> [fifo\_queue](#input\_fifo\_queue) | Whether to create a FIFO queue. When true, name must end in `.fifo`. Default false (a standard queue), which is sufficient for most workloads and supports higher throughput. | `bool` | `false` | no |
| <a name="input_message_retention_seconds"></a> [message\_retention\_seconds](#input\_message\_retention\_seconds) | Seconds SQS retains a message that is not deleted (60-1209600). Default 4 days (345600). | `number` | `345600` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the SQS queue. For a FIFO queue (fifo\_queue = true) the name must end in `.fifo`;<br/>the module validates that pairing so a misconfiguration fails fast at plan time. | `string` | n/a | yes |
| <a name="input_receive_wait_time_seconds"></a> [receive\_wait\_time\_seconds](#input\_receive\_wait\_time\_seconds) | Seconds a ReceiveMessage call waits for a message to arrive before returning empty (0-20). Greater than 0 enables long polling, which cuts empty receives and cost. Default 0 (short polling). | `number` | `0` | no |
| <a name="input_sqs_managed_sse_enabled"></a> [sqs\_managed\_sse\_enabled](#input\_sqs\_managed\_sse\_enabled) | Enable SQS-managed server-side encryption (SSE-SQS) for messages at rest. Default true — encryption on by default; set false only if you have a specific reason. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the queue (the one taggable resource this module creates). | `map(string)` | `{}` | no |
| <a name="input_visibility_timeout_seconds"></a> [visibility\_timeout\_seconds](#input\_visibility\_timeout\_seconds) | Seconds a message is hidden from other consumers after one consumer receives it, before it becomes visible again (0-43200). Set this above your consumer's worst-case processing time. | `number` | `30` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the queue. Use this in IAM policy resource statements that grant send/receive on this queue. |
| <a name="output_name"></a> [name](#output\_name) | Name of the queue. |
| <a name="output_url"></a> [url](#output\_url) | URL (queue endpoint) of the queue. This is what producers/consumers pass to the SQS API as QueueUrl. |
<!-- END_TF_DOCS -->
