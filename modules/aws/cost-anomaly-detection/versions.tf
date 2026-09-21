terraform {
  # 1.3 for `optional()` attribute defaults in object types, and resource preconditions.
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
