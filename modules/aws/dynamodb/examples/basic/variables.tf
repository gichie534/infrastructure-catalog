variable "region" {
  description = "AWS region to create the example table in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the example DynamoDB table."
  type        = string
  default     = "dynamodb-example"
}
