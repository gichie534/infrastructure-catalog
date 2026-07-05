variable "region" {
  description = "AWS region for the provider configuration. Route 53 is global, but the provider still needs a region."
  type        = string
  default     = "us-east-1"
}

variable "zone_name" {
  description = "Domain name for the public hosted zone."
  type        = string
  default     = "basic.example.com"
}
