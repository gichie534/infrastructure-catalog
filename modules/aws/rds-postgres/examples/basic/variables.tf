variable "region" {
  description = "AWS region to create the example VPC and RDS instance in."
  type        = string
  default     = "us-east-1"
}

variable "master_password" {
  description = "Master password for the example instance."
  type        = string
  sensitive   = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the instance (e.g. your operator address as a /32)."
  type        = list(string)
  default     = []
}
