provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name for the Lambda function."
  type        = string
  default     = "example-lambda"
}

variable "ignore_code_changes" {
  description = "Whether Terraform should stop managing the deployment package after creation."
  type        = bool
  default     = false
}

# Zip a placeholder bootstrap so the example is self-contained and applies with no build step. This
# proves the module creates the function/role/log group; it is not meant to be invoked. A real
# consumer supplies a compiled Go `bootstrap` (or a package for another runtime).
data "archive_file" "package" {
  type        = "zip"
  output_path = "${path.module}/bootstrap.zip"

  source {
    content  = "#!/bin/sh\necho placeholder\n"
    filename = "bootstrap"
  }
}

module "lambda" {
  source = "../../"

  name     = var.name
  filename = data.archive_file.package.output_path

  ignore_code_changes = var.ignore_code_changes

  # Defaults: handler "bootstrap", runtime "provided.al2023", no VPC.

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "function_name" {
  description = "Name of the created function."
  value       = module.lambda.function_name
}

output "function_arn" {
  description = "ARN of the created function."
  value       = module.lambda.function_arn
}

output "role_arn" {
  description = "ARN of the function's execution role."
  value       = module.lambda.role_arn
}
