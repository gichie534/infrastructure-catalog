# A single SQS queue — the minimal building block a consumer wires producers and consumers to.
#
# This module owns only the queue resource. It deliberately does NOT create IAM policies, access
# policies, or DLQ wiring: those are the consumer's composition concern (the lab grants send/receive
# to specific principals via its own IAM). Keeping the module single-purpose keeps it reusable.
#
# Standard vs FIFO is an input; SSE-SQS encryption is on by default. Long polling and the visibility
# timeout are parameterised so a consumer can tune them to its workload.
resource "aws_sqs_queue" "this" {
  name = var.name

  fifo_queue = var.fifo_queue

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  sqs_managed_sse_enabled = var.sqs_managed_sse_enabled

  tags = var.tags
}
