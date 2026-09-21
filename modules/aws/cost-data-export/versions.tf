terraform {
  # 1.3 for `optional()` attribute defaults in object types, and resource preconditions.
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.0 for the aws_billing_views data source, which the module uses to resolve the account's PRIMARY
      # billing view — see the BILLING_VIEW_ARN note in main.tf.
      version = ">= 6.0"
    }
  }
}
