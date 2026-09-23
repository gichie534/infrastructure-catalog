variable "name" {
  description = "Name of the HA VPN gateway."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.name))
    error_message = "name must be 1-63 characters, lowercase letters, numbers, or hyphens, start with a letter, and not end with a hyphen."
  }
}

variable "project_id" {
  description = "The ID of the project to create the gateway in."
  type        = string
  nullable    = false
}

variable "region" {
  description = "Region for the HA VPN gateway. Must match the region of the Cloud Router that terminates its tunnels."
  type        = string
  nullable    = false
}

variable "network" {
  description = "Self link or name of the VPC network the gateway attaches to. Wire this to the vpc module's network_self_link output."
  type        = string
  nullable    = false
}

variable "stack_type" {
  description = "IP stack for the gateway interfaces. IPV4_ONLY is the only stack an AWS Site-to-Site VPN peer supports today."
  type        = string
  nullable    = false
  default     = "IPV4_ONLY"

  validation {
    condition     = contains(["IPV4_ONLY", "IPV4_IPV6", "IPV6_ONLY"], var.stack_type)
    error_message = "stack_type must be one of IPV4_ONLY, IPV4_IPV6, or IPV6_ONLY."
  }
}
