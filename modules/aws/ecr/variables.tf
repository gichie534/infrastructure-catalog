variable "name" {
  description = "Name of the ECR repository (e.g. \"my-app\"). Lowercase; may contain slashes for namespacing (e.g. \"team/my-app\")."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._/-][a-z0-9]+)*$", var.name))
    error_message = "name must be lowercase and may contain digits and separators (._-/), matching ECR's repository naming rules."
  }
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten. MUTABLE lets a tag (e.g. \"dev\") be re-pushed; IMMUTABLE forbids overwriting an existing tag."
  type        = string
  nullable    = false
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Run a basic vulnerability scan automatically when an image is pushed."
  type        = bool
  nullable    = false
  default     = true
}

variable "force_delete" {
  description = "Allow Terraform to delete the repository even when it still contains images. Set true in throwaway lab environments so `terraform destroy` tears down cleanly."
  type        = bool
  nullable    = false
  default     = false
}

variable "untagged_image_expiry_days" {
  description = "When set, attach a lifecycle policy that expires untagged images older than this many days — keeps a repo from accumulating orphaned layers. Leave null (default) for no lifecycle policy."
  type        = number
  nullable    = true
  default     = null

  validation {
    condition     = var.untagged_image_expiry_days == null || try(var.untagged_image_expiry_days > 0, false)
    error_message = "untagged_image_expiry_days must be a positive number when set."
  }
}

variable "tags" {
  description = "Tags applied to the repository."
  type        = map(string)
  nullable    = false
  default     = {}
}
