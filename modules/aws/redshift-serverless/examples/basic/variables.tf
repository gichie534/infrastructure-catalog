variable "region" {
  description = "AWS region to create the resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Base name for the warehouse, its VPC, and its security group."
  type        = string
  default     = "redshift-example"
}

variable "bucket_name" {
  description = "Globally unique name for the source S3 bucket the COPY role is granted read on."
  type        = string
}
