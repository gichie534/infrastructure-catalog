provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to issue the certificate in (must be us-east-1 if the cert will front a CloudFront distribution)."
  type        = string
  default     = "us-east-1"
}

variable "hosted_zone_id" {
  description = "ID of an EXISTING, publicly-delegated Route 53 hosted zone authoritative for domain_name. Validation only completes when the zone is reachable on the public internet."
  type        = string
}

variable "domain_name" {
  description = "FQDN to issue the certificate for (must fall within the hosted zone), e.g. app.example.com."
  type        = string
}

# Minimal call: a DNS-validated public certificate whose validation records land in the supplied
# zone. The module blocks until the certificate is ISSUED.
module "certificate" {
  source = "../../"

  domain_name    = var.domain_name
  hosted_zone_id = var.hosted_zone_id

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

output "certificate_arn" {
  description = "ARN of the issued certificate."
  value       = module.certificate.certificate_arn
}

output "status" {
  description = "Certificate status (ISSUED on success)."
  value       = module.certificate.status
}
