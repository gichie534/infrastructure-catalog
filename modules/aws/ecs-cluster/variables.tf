variable "name" {
  description = "Name of the ECS cluster."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,254}$", var.name))
    error_message = "name must be 1-255 characters: letters, digits, hyphens, or underscores, starting alphanumeric."
  }
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the cluster (extra per-task metrics; incurs CloudWatch cost). Off by default to keep labs cheap."
  type        = bool
  nullable    = false
  default     = false
}

variable "capacity_providers" {
  description = "Fargate capacity providers available to services in this cluster."
  type        = list(string)
  nullable    = false
  default     = ["FARGATE", "FARGATE_SPOT"]

  validation {
    condition     = length(var.capacity_providers) > 0 && alltrue([for c in var.capacity_providers : contains(["FARGATE", "FARGATE_SPOT"], c)])
    error_message = "capacity_providers must be a non-empty subset of [\"FARGATE\", \"FARGATE_SPOT\"]."
  }
}

variable "default_capacity_provider" {
  description = "Capacity provider used by default when a service in this cluster does not specify a launch type or strategy. Must be one of capacity_providers."
  type        = string
  nullable    = false
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "FARGATE_SPOT"], var.default_capacity_provider)
    error_message = "default_capacity_provider must be FARGATE or FARGATE_SPOT."
  }
}

variable "tags" {
  description = "Tags applied to the cluster."
  type        = map(string)
  nullable    = false
  default     = {}
}
