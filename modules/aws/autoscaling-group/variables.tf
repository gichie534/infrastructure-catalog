variable "name" {
  description = "Name prefix for the launch template, Auto Scaling group, and the Name tag on launched instances."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]$", var.name))
    error_message = "name must be 1-63 characters, alphanumeric or hyphens, and not start or end with a hyphen."
  }
}

variable "ami_id" {
  description = "AMI ID the launch template uses. The consumer resolves this (e.g. the latest Amazon Linux 2023 via an SSM public parameter) so the module stays region-agnostic."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^ami-[0-9a-f]+$", var.ami_id))
    error_message = "ami_id must be an AMI ID of the form ami-xxxxxxxx."
  }
}

variable "instance_type" {
  description = "EC2 instance type for launched instances. Default t3.micro — enough for a scaling demo."
  type        = string
  nullable    = false
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "Subnet IDs the Auto Scaling group launches instances into (its vpc_zone_identifier). Spread across AZs for resilience."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "at least one subnet ID must be provided."
  }
}

variable "iam_instance_profile" {
  description = "Name of the IAM instance profile to attach to launched instances. Null (default) launches with no instance profile."
  type        = string
  default     = null
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach to launched instances. Empty (default) uses the VPC's default security group. For SSM-only access no inbound rules are needed — egress is enough."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "associate_public_ip_address" {
  description = "Whether launched instances get a public IP. Needed when the group sits in public subnets and reaches the SSM/AWS endpoints over the internet gateway (no NAT). Default true."
  type        = bool
  nullable    = false
  default     = true
}

variable "user_data" {
  description = "User data script run at first boot (plain text; the module base64-encodes it). Null (default) runs nothing."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB for launched instances."
  type        = number
  nullable    = false
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}

variable "min_size" {
  description = "Minimum number of instances the group maintains."
  type        = number
  nullable    = false
  default     = 1

  validation {
    condition     = var.min_size >= 0
    error_message = "min_size must be zero or greater."
  }
}

variable "max_size" {
  description = "Maximum number of instances the group may scale out to."
  type        = number
  nullable    = false
  default     = 3

  validation {
    condition     = var.max_size >= 1
    error_message = "max_size must be at least 1."
  }
}

variable "desired_capacity" {
  description = "Initial desired number of instances. Target tracking adjusts this at runtime, so on subsequent applies avoid fighting the policy by leaving it at the baseline."
  type        = number
  nullable    = false
  default     = 1
}

variable "target_cpu_utilization" {
  description = "Target average CPU utilization (percent) for the target-tracking policy. The group scales out above this and in below it. A low value (e.g. 30) makes a stress load trip scale-out quickly for demos."
  type        = number
  nullable    = false
  default     = 40

  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "target_cpu_utilization must be between 1 and 100."
  }
}

variable "estimated_instance_warmup" {
  description = "Seconds to ignore a newly launched instance's metrics while it warms up, so the group doesn't over-scale before new capacity absorbs load."
  type        = number
  nullable    = false
  default     = 120
}

variable "health_check_type" {
  description = "Health check type for the group: EC2 (instance status) or ELB (target group health). Use ELB only when the group is attached to a load balancer."
  type        = string
  nullable    = false
  default     = "EC2"

  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "health_check_type must be either EC2 or ELB."
  }
}

variable "health_check_grace_period" {
  description = "Seconds after an instance launches before its health check counts, giving user_data time to run."
  type        = number
  nullable    = false
  default     = 120
}

variable "tags" {
  description = "Tags applied to the launch template and Auto Scaling group, and propagated to launched instances."
  type        = map(string)
  nullable    = false
  default     = {}
}
