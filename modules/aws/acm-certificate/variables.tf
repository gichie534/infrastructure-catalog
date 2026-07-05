variable "domain_name" {
  description = "Primary fully-qualified domain name the certificate is issued for (e.g. app.example.com). A wildcard (*.example.com) is allowed."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^(\\*\\.)?([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}\\.?$", lower(var.domain_name)))
    error_message = "domain_name must be a valid DNS name, optionally a wildcard like *.example.com."
  }
}

variable "subject_alternative_names" {
  description = "Additional names the certificate should also cover (SANs), e.g. [\"www.example.com\"]. Each gets its own DNS-validation record. Empty by default."
  type        = list(string)
  nullable    = false
  default     = []
}

variable "hosted_zone_id" {
  description = "Route 53 hosted-zone ID in which to create the DNS-validation records. The zone must be authoritative for domain_name (and every SAN) so validation can complete."
  type        = string
  nullable    = false
}

variable "validation_record_ttl" {
  description = "TTL (seconds) for the DNS-validation CNAME records."
  type        = number
  nullable    = false
  default     = 60

  validation {
    condition     = var.validation_record_ttl > 0
    error_message = "validation_record_ttl must be a positive number."
  }
}

variable "key_algorithm" {
  description = "Key algorithm for the certificate (e.g. RSA_2048, EC_prime256v1). Leave null to let ACM choose its default (RSA_2048)."
  type        = string
  nullable    = true
  default     = null
}

variable "tags" {
  description = "Tags applied to the certificate."
  type        = map(string)
  nullable    = false
  default     = {}
}
