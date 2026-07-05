variable "name" {
  description = "Name of the Lambda function. Also used to name its execution role (<name>-exec) and log group (/aws/lambda/<name>)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,64}$", var.name))
    error_message = "name must be 1-64 chars of [a-zA-Z0-9-_]."
  }
}

variable "filename" {
  description = "Path to the deployment package (.zip) containing the function code. The consumer builds this; the module hashes it for source_code_hash so updates redeploy."
  type        = string
  nullable    = false
}

variable "handler" {
  description = "Function entrypoint. For the Go (provided.al2023) runtime this is the executable name in the zip (e.g. bootstrap)."
  type        = string
  nullable    = false
  default     = "bootstrap"
}

variable "runtime" {
  description = "Lambda runtime identifier (e.g. provided.al2023 for Go, python3.12, nodejs20.x)."
  type        = string
  nullable    = false
  default     = "provided.al2023"
}

variable "architecture" {
  description = "Instruction set architecture: x86_64 or arm64."
  type        = string
  nullable    = false
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "architecture must be one of: x86_64, arm64."
  }
}

variable "memory_size" {
  description = "Memory (MB) allocated to the function. CPU scales with memory."
  type        = number
  nullable    = false
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Maximum execution time in seconds before the function is stopped."
  type        = number
  nullable    = false
  default     = 10

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "environment_variables" {
  description = "Environment variables passed to the function. Empty by default (no environment block created)."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "vpc_config" {
  description = <<-EOT
    Attach the function to a VPC. When set, Lambda runs its ENIs in the given private subnets and
    security groups (letting it reach private resources like RDS or an EC2 instance), and the module
    adds the AWSLambdaVPCAccessExecutionRole managed policy. Null (default) runs the function outside
    any VPC.
  EOT
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "additional_policy_arns" {
  description = "ARNs of extra managed policies to attach to the execution role, on top of the basic (and, in a VPC, VPC-access) execution policies. Empty by default."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "inline_policies" {
  description = "Map of inline least-privilege policies to embed in the execution role, keyed by policy name. Each value is a JSON IAM policy document. Empty by default."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "log_retention_in_days" {
  description = "Retention for the function's CloudWatch log group. Default 14 days keeps lab logs from accumulating indefinitely."
  type        = number
  nullable    = false
  default     = 14
}

variable "ignore_code_changes" {
  description = <<-EOT
    When true, Terraform creates the function from `filename` once and then stops managing the code:
    it ignores changes to the deployment package (`filename`/`source_code_hash`) on subsequent
    applies. This hands ownership of code rollouts to an external deployer (a CI pipeline running
    `aws lambda update-function-code`) — the Lambda analogue of an ECS service that ignores task
    definition changes — so Terraform never reverts a deployed version. Configuration (runtime,
    memory, environment, role, …) is still Terraform-managed either way.

    When false (default) Terraform fully owns the code: a new `filename`/hash redeploys on apply.
  EOT
  type        = bool
  nullable    = false
  default     = false
}

variable "tags" {
  description = "Tags applied to the function, execution role, and log group."
  type        = map(string)
  nullable    = false
  default     = {}
}
