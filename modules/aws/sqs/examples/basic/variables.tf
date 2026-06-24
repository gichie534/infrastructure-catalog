variable "region" {
  description = "AWS region to create the example queue in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the example queue."
  type        = string
  default     = "sqs-example"
}
