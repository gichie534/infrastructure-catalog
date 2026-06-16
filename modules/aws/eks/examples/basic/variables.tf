variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the EKS cluster and prefix for its resources."
  type        = string
  default     = "example-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane and node groups."
  type        = string
  default     = "1.31"
}

variable "azs" {
  description = "Availability zones for the VPC subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
