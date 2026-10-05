terraform {
  # 1.5 for `optional()` attribute defaults and the startswith() function used in validation.
  required_version = "~> 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}
