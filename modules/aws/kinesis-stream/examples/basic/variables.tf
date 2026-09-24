variable "region" {
  description = "AWS region to create the stream in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the Kinesis data stream."
  type        = string
  default     = "kinesis-stream-example"
}
