variable "region" {
  description = "AWS region to create the resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the Firehose delivery stream."
  type        = string
  default     = "firehose-example"
}

variable "bucket_name" {
  description = "Globally unique name for the destination S3 bucket."
  type        = string
}

variable "stream_name" {
  description = "Name of the source Kinesis data stream."
  type        = string
  default     = "firehose-example-source"
}
