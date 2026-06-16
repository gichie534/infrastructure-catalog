variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for the VPC and its resources."
  type        = string
  default     = "example-vpc"
}

variable "azs" {
  description = "Availability zones for the example subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
