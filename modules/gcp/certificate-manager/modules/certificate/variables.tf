variable "project_id" {
  description = "The ID of the project in which to create the certificate and DNS authorization."
  type        = string
  nullable    = false
}

variable "name" {
  description = "Name shared by the DNS authorization and the managed certificate."
  type        = string
  nullable    = false
}

variable "location" {
  description = "Certificate Manager location (\"global\" for GKE Ingress)."
  type        = string
  nullable    = false
}

variable "domain" {
  description = "The single fully-qualified hostname the certificate covers."
  type        = string
  nullable    = false
}

variable "labels" {
  description = "Labels applied to the DNS authorization and the certificate."
  type        = map(string)
  nullable    = false
  default     = {}
}
