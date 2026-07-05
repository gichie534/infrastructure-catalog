variable "name" {
  description = "Name of the Application Load Balancer, used as the prefix for its target groups and security group. Must be 1-32 chars, alphanumeric or hyphens."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,30}[a-zA-Z0-9]$", var.name))
    error_message = "name must be 1-32 characters, alphanumeric or hyphens, and not start or end with a hyphen."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the load balancer and its target groups live in."
  type        = string
  nullable    = false
}

variable "subnet_ids" {
  description = "Subnet IDs to place the load balancer in. An ALB requires at least two subnets in different AZs. Use public subnets for an internet-facing ALB."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "an ALB requires at least two subnet_ids in different availability zones."
  }
}

variable "internal" {
  description = "Whether the ALB is internal (no public IPs). Default false = internet-facing."
  type        = bool
  nullable    = false
  default     = false
}

variable "enable_deletion_protection" {
  description = "Guard the ALB against accidental deletion. Keep false for labs so teardown isn't blocked."
  type        = bool
  nullable    = false
  default     = false
}

variable "security_group_ids" {
  description = "Security group IDs to attach to the ALB. When empty (default) and create_security_group is true, the module creates one allowing inbound on listener_port from ingress_cidr_blocks."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "create_security_group" {
  description = "Create a security group for the ALB (allowing inbound on listener_port from ingress_cidr_blocks, all egress). Ignored when security_group_ids is non-empty."
  type        = bool
  nullable    = false
  default     = true
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the ALB on listener_port. Only used when the module creates its own security group. Default open to the internet."
  type        = list(string)
  nullable    = false
  default     = ["0.0.0.0/0"]
}

variable "listener_port" {
  description = "Port the HTTP listener accepts traffic on."
  type        = number
  nullable    = false
  default     = 80
}

variable "certificate_arn" {
  description = <<-EOT
    ARN of an ACM certificate. When set, the module adds an HTTPS listener on https_listener_port
    (default 443) using this certificate, and the HTTP listener on listener_port becomes a permanent
    (301) redirect to HTTPS instead of serving traffic. Listener rules and the default action then
    attach to the HTTPS listener. When null (default) the module is plain HTTP as before.
  EOT
  type        = string
  nullable    = true
  default     = null
}

variable "https_listener_port" {
  description = "Port the HTTPS listener accepts traffic on. Only used when certificate_arn is set."
  type        = number
  nullable    = false
  default     = 443
}

variable "ssl_policy" {
  description = "ELB security policy (TLS versions/ciphers) for the HTTPS listener. Only used when certificate_arn is set."
  type        = string
  nullable    = false
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "target_groups" {
  description = <<-EOT
    Target groups to create, keyed by a logical name. Each value:
      - port                  : port the targets receive traffic on. Ignored for target_type=lambda.
      - protocol              : target group protocol (default HTTP). Ignored for target_type=lambda.
      - target_type           : instance | ip | lambda (default instance). For "lambda", pass the
                                function ARN as the single target_ids entry; the module registers it
                                and grants Elastic Load Balancing permission to invoke it. A lambda
                                target group has no port/protocol/vpc_id.
      - target_ids            : IDs to register (instance IDs for instance, IPs for ip, the function
                                ARN for lambda). May be empty.
      - lambda_multi_value_headers_enabled : for target_type=lambda, send headers/query params to the
                                function as multi-value maps. Default false. Ignored otherwise.
      - health_check_path     : HTTP path the health check requests (default "/"). Ignored for lambda
                                (lambda target groups have health checks disabled by this module).
      - health_check_matcher  : HTTP codes considered healthy (default "200"). Ignored for lambda.
      - health_check_interval : seconds between health checks (default 30). Ignored for lambda.
      - healthy_threshold     : consecutive successes before healthy (default 3). Ignored for lambda.
      - unhealthy_threshold   : consecutive failures before unhealthy (default 3). Ignored for lambda.
  EOT
  type = map(object({
    port                               = optional(number)
    protocol                           = optional(string, "HTTP")
    target_type                        = optional(string, "instance")
    target_ids                         = optional(list(string), [])
    lambda_multi_value_headers_enabled = optional(bool, false)
    health_check_path                  = optional(string, "/")
    health_check_matcher               = optional(string, "200")
    health_check_interval              = optional(number, 30)
    healthy_threshold                  = optional(number, 3)
    unhealthy_threshold                = optional(number, 3)
  }))
  nullable = false

  validation {
    condition     = length(var.target_groups) > 0
    error_message = "at least one target group must be defined."
  }

  validation {
    condition     = alltrue([for tg in values(var.target_groups) : contains(["instance", "ip", "lambda"], tg.target_type)])
    error_message = "target_type must be one of: instance, ip, lambda."
  }

  validation {
    condition     = alltrue([for tg in values(var.target_groups) : tg.target_type == "lambda" || tg.port != null])
    error_message = "port is required for instance and ip target groups."
  }

  validation {
    condition     = alltrue([for tg in values(var.target_groups) : tg.target_type != "lambda" || length(tg.target_ids) <= 1])
    error_message = "a lambda target group registers a single function; provide at most one target_id (the function ARN)."
  }
}

variable "default_target_group_key" {
  description = "Key (from target_groups) the listener forwards to when no rule matches. When null (default), unmatched requests get a fixed 404 response instead."
  type        = string
  default     = null
}

variable "listener_rules" {
  description = <<-EOT
    Listener rules evaluated in priority order, keyed by a logical name. Each value:
      - priority         : evaluation order (lower first); must be unique.
      - target_group_key : key (from target_groups) to forward matched requests to.
      - path_patterns    : path-based match, e.g. ["/a", "/a/*"]. Optional.
      - host_headers     : host-based match, e.g. ["a.example.com"]. Optional.
    At least one of path_patterns or host_headers must be set per rule.
  EOT
  type = map(object({
    priority         = number
    target_group_key = string
    path_patterns    = optional(list(string))
    host_headers     = optional(list(string))
  }))
  nullable = false
  default  = {}

  validation {
    condition = alltrue([
      for r in values(var.listener_rules) :
      (r.path_patterns != null && length(r.path_patterns) > 0) ||
      (r.host_headers != null && length(r.host_headers) > 0)
    ])
    error_message = "each listener rule must set at least one of path_patterns or host_headers."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module."
  type        = map(string)
  nullable    = false
  default     = {}
}
