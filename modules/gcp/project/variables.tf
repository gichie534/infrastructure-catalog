variable "name" {
  description = "The display name of the project"
  type        = string
}

variable "project_id" {
  description = "The unique project ID. Must be globally unique across GCP"
  type        = string
}

variable "folder_id" {
  description = "The parent folder ID (e.g. folders/123456)"
  type        = string
}

variable "billing_account" {
  description = "The billing account ID to associate with this project"
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels to apply to the project"
  type        = map(string)
  default     = {}
}

variable "activate_apis" {
  description = "List of Google APIs to activate on the project"
  type        = list(string)
  default     = []
}
