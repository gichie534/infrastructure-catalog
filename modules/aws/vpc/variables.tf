variable "name" {
  description = "Name applied to the VPC and used as the prefix for its subnets, gateways, and route tables."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]$", var.name))
    error_message = "name must be 1-63 characters, alphanumeric or hyphens, and not start or end with a hyphen."
  }
}

variable "cidr_block" {
  description = "Primary IPv4 CIDR block for the VPC (e.g. 10.0.0.0/16). Subnet CIDRs must fall within this range."
  type        = string
  nullable    = false
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid CIDR (e.g. 10.0.0.0/16)."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across. One public and one private subnet is created per AZ, paired by index with public_subnet_cidrs / private_subnet_cidrs."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.azs) > 0
    error_message = "at least one availability zone must be provided."
  }

  validation {
    condition     = length(distinct(var.azs)) == length(var.azs)
    error_message = "availability zones must be unique."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per AZ (index-aligned with azs). Public subnets route to the internet gateway and host load balancers / NAT gateways."
  type        = list(string)
  nullable    = false

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "every public subnet CIDR must be a valid CIDR (e.g. 10.0.0.0/20)."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets, one per AZ (index-aligned with azs). Private subnets host EKS/ECS workloads and egress via NAT."
  type        = list(string)
  nullable    = false

  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "every private subnet CIDR must be a valid CIDR (e.g. 10.0.128.0/20)."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) so private subnets can reach the internet for egress (pulling images, package installs, EKS/ECS control-plane traffic)."
  type        = bool
  nullable    = false
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway in the first public subnet instead of one per AZ. Cheaper for non-prod; set false for per-AZ HA. Only used when enable_nat_gateway is true."
  type        = bool
  nullable    = false
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Assign public DNS hostnames to instances with public IPs. Required by EKS."
  type        = bool
  nullable    = false
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS resolution via the Amazon-provided DNS server in the VPC. Required by EKS."
  type        = bool
  nullable    = false
  default     = true
}

variable "public_subnet_tags" {
  description = "Additional tags applied to public subnets. Defaults include kubernetes.io/role/elb so EKS can place internet-facing load balancers."
  type        = map(string)
  nullable    = false
  default     = { "kubernetes.io/role/elb" = "1" }
}

variable "private_subnet_tags" {
  description = "Additional tags applied to private subnets. Defaults include kubernetes.io/role/internal-elb so EKS can place internal load balancers."
  type        = map(string)
  nullable    = false
  default     = { "kubernetes.io/role/internal-elb" = "1" }
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module."
  type        = map(string)
  nullable    = false
  default     = {}
}
