variable "display_name" {
  description = "Display name of the folder"
  type        = string
}

variable "parent" {
  description = "Parent resource: organizations/<org_id> or folders/<folder_id>"
  type        = string
}

variable "deletion_protection" {
  description = "Whether to prevent the folder from being deleted while this value is true"
  type        = bool
  default     = true
}
