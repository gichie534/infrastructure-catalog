output "certificate_arn" {
  description = "ARN of the ISSUED certificate (sourced from the validation resource, so reading it guarantees the cert is validated and ready to attach to a listener/distribution)."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "domain_name" {
  description = "Primary domain name the certificate was issued for."
  value       = aws_acm_certificate.this.domain_name
}

output "status" {
  description = "Status of the certificate (ISSUED once validation completes)."
  value       = aws_acm_certificate.this.status
}

output "validation_record_fqdns" {
  description = "FQDNs of the DNS-validation records created in the hosted zone."
  value       = [for r in aws_route53_record.validation : r.fqdn]
}
