variable "name" {
  description = "Name tag for the instance and its root volume."
  type        = string
  nullable    = false
}

variable "ami_id" {
  description = "AMI ID to launch. The consumer resolves this (e.g. the latest Amazon Linux 2023 via an SSM public parameter) so the module stays region-agnostic."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^ami-[0-9a-f]+$", var.ami_id))
    error_message = "ami_id must be an AMI ID of the form ami-xxxxxxxx."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Default t3.micro — enough for a demo instance."
  type        = string
  nullable    = false
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "ID of the subnet to launch the instance in."
  type        = string
  nullable    = false
}

variable "iam_instance_profile" {
  description = "Name of the IAM instance profile to attach, granting the instance its role. Null (default) launches with no instance profile."
  type        = string
  default     = null
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach. Empty (default) uses the VPC's default security group. For SSM-only access no inbound rules are needed — egress is enough."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "associate_public_ip_address" {
  description = "Whether to assign a public IP. Needed when the instance sits in a public subnet and reaches the SSM/AWS endpoints over the internet gateway (no NAT). Default true."
  type        = bool
  nullable    = false
  default     = true
}

variable "user_data" {
  description = "User data script run at first boot (plain text; the provider base64-encodes it). Null (default) runs nothing."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB."
  type        = number
  nullable    = false
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}

variable "tags" {
  description = "Tags applied to the instance and root volume."
  type        = map(string)
  nullable    = false
  default     = {}
}
