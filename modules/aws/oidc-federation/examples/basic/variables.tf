variable "region" {
  description = "AWS region to create the example resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for the example's IAM role."
  type        = string
  default     = "oidc-example"
}

variable "github_repository" {
  description = "GitHub repository (OWNER/REPO) whose Actions workflows may assume the example role."
  type        = string
  default     = "octo-org/example-repo"
}
