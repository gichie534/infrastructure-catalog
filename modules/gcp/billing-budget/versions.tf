terraform {
  # 1.5 for `optional()` attribute defaults, resource preconditions and `check`-friendly validation.
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}
