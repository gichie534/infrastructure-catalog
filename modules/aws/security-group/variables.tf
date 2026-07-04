variable "name" {
  description = "Name for the security group. Also applied as the Name tag."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,254}$", var.name))
    error_message = "name must be 1-255 chars, start alphanumeric, and use only [a-zA-Z0-9._-]."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the security group belongs to."
  type        = string
  nullable    = false
}

variable "description" {
  description = "Description for the security group. Defaults to a generic label derived from the name."
  type        = string
  nullable    = false
  default     = "Managed by Terraform"
}

variable "ingress_rules" {
  description = <<-EOT
    Inbound rules. Each rule opens a port range for either CIDR blocks or another security group
    (source_security_group_id) — set exactly one of the two per rule. Empty by default (no inbound),
    which is the right posture for egress-only workloads like a VPC-attached Lambda.
  EOT
  type = list(object({
    description              = optional(string, "")
    from_port                = number
    to_port                  = number
    protocol                 = optional(string, "tcp")
    cidr_blocks              = optional(list(string), [])
    source_security_group_id = optional(string)
  }))
  nullable = false
  default  = []

  validation {
    condition = alltrue([
      for r in var.ingress_rules :
      (length(r.cidr_blocks) > 0) != (r.source_security_group_id != null)
    ])
    error_message = "each ingress rule must set exactly one of cidr_blocks or source_security_group_id."
  }
}

variable "egress_rules" {
  description = <<-EOT
    Outbound rules. Defaults to a single allow-all egress rule (the common case: let the workload
    reach anything). Override to constrain egress.
  EOT
  type = list(object({
    description              = optional(string, "")
    from_port                = number
    to_port                  = number
    protocol                 = optional(string, "tcp")
    cidr_blocks              = optional(list(string), [])
    source_security_group_id = optional(string)
  }))
  nullable = false
  default = [{
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }]
}

variable "tags" {
  description = "Tags applied to the security group."
  type        = map(string)
  nullable    = false
  default     = {}
}
