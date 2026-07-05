variable "name" {
  description = "Name of the service. Also used as the task-definition family and the prefix for the log group, IAM roles, and (optional) security group."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,254}$", var.name))
    error_message = "name must be 1-255 characters: letters, digits, hyphens, or underscores, starting alphanumeric."
  }
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster to run the service in."
  type        = string
  nullable    = false
}

variable "container_image" {
  description = "Container image reference the task runs, including a tag or digest (e.g. <account>.dkr.ecr.<region>.amazonaws.com/my-app:dev). When ignore_task_definition_changes is true this is only the BOOTSTRAP image — the CI pipeline registers new revisions with new tags afterwards."
  type        = string
  nullable    = false
}

variable "container_name" {
  description = "Name of the container in the task definition. Referenced by the load balancer target and by CI when rendering new task-definition revisions."
  type        = string
  nullable    = false
  default     = "app"
}

variable "container_port" {
  description = "Port the container listens on and the load balancer forwards to."
  type        = number
  nullable    = false
  default     = 8080
}

variable "cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU). Must be a valid Fargate CPU/memory combination."
  type        = number
  nullable    = false
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB. Must be a valid Fargate CPU/memory combination for the chosen cpu."
  type        = number
  nullable    = false
  default     = 512
}

variable "cpu_architecture" {
  description = "CPU architecture of the task's runtime platform: X86_64 or ARM64. Must match the architecture the image was built for."
  type        = string
  nullable    = false
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "desired_count" {
  description = "Number of task copies to run."
  type        = number
  nullable    = false
  default     = 1
}

variable "subnet_ids" {
  description = "Subnets the tasks' elastic network interfaces are placed in. Use public subnets with assign_public_ip = true (no NAT needed) or private subnets with NAT/VPC endpoints."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "at least one subnet_id is required."
  }
}

variable "assign_public_ip" {
  description = "Give each task ENI a public IP. Required when tasks run in public subnets so they can pull the image and reach AWS APIs over the internet gateway (avoids a NAT gateway)."
  type        = bool
  nullable    = false
  default     = false
}

variable "vpc_id" {
  description = "VPC to create the task security group in. Required only when the module creates its own security group (create_security_group = true and no security_group_ids supplied)."
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = !(var.create_security_group && length(var.security_group_ids) == 0) || (var.vpc_id != null && var.vpc_id != "")
    error_message = "vpc_id is required when the module creates its own security group (create_security_group = true and security_group_ids empty)."
  }
}

variable "security_group_ids" {
  description = "Security groups to attach to the task ENIs. When empty (default) and create_security_group is true, the module creates one allowing inbound on container_port from ingress_security_group_ids."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "create_security_group" {
  description = "Create a task security group (inbound on container_port from ingress_security_group_ids, all egress). Ignored when security_group_ids is non-empty."
  type        = bool
  nullable    = false
  default     = true
}

variable "ingress_security_group_ids" {
  description = "Security group IDs allowed to reach the tasks on container_port — typically the ALB's security group. Only used when the module creates its own security group. Empty = no inbound (tasks reachable only from within their own SG)."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "target_group_arn" {
  description = "ARN of an ALB/NLB target group (target_type = ip) to register the tasks with. When null (default) the service runs without a load balancer."
  type        = string
  nullable    = true
  default     = null
}

variable "health_check_grace_period_seconds" {
  description = "Grace period before the load balancer health check can mark a task unhealthy and the scheduler replaces it — gives the app time to start. Only applied when target_group_arn is set."
  type        = number
  nullable    = false
  default     = 60
}

variable "environment" {
  description = "Environment variables passed to the container, as a name -> value map."
  type        = map(string)
  nullable    = false
  default     = {}
}

variable "execution_policy_arns" {
  description = "Extra IAM policy ARNs attached to the task EXECUTION role (used by the ECS agent to pull images and write logs). AmazonECSTaskExecutionRolePolicy is always attached; add more here (e.g. to read secrets)."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "task_policy_arns" {
  description = "IAM policy ARNs attached to the TASK role (assumed by the application code itself to call AWS APIs). Empty by default."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "log_retention_in_days" {
  description = "Retention for the task's CloudWatch log group."
  type        = number
  nullable    = false
  default     = 14
}

variable "enable_execute_command" {
  description = "Enable ECS Exec (aws ecs execute-command) for interactive debugging into running tasks."
  type        = bool
  nullable    = false
  default     = false
}

variable "ignore_task_definition_changes" {
  description = "Ignore changes to the service's task_definition and desired_count so an external deployer (CI registering new task-def revisions) owns rolling deployments without Terraform reverting the image on the next apply. Set false to let Terraform fully manage the running revision."
  type        = bool
  nullable    = false
  default     = true
}

variable "tags" {
  description = "Tags applied to every taggable resource created by this module."
  type        = map(string)
  nullable    = false
  default     = {}
}
