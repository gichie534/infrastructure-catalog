# A public, DNS-validated ACM certificate whose validation records are created in a Route 53 hosted
# zone the caller owns — so issuance completes automatically with no manual DNS step. The module
# blocks (via aws_acm_certificate_validation) until the certificate is ISSUED, so a consumer that
# reads certificate_arn (e.g. an ALB HTTPS listener) only proceeds once the cert is usable.
#
# Self-contained by design: it manages the certificate, its validation records, and the validation
# wait. It stays region/account-agnostic — the caller supplies the domain(s) and the zone to
# validate in. (An ALB/CloudFront in region us-east-1 vs. elsewhere is the caller's concern; note
# CloudFront requires the cert in us-east-1, so point the aws provider there for that use.)

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"
  key_algorithm             = var.key_algorithm

  # Replace cleanly if the domain set changes: stand up the new cert before removing the old one so a
  # listener referencing it is never left dangling.
  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# One validation record per distinct validation option. ACM returns the same option for duplicate
# names, so key by domain_name and dedupe. allow_overwrite keeps re-applies idempotent if a record
# with the same name already exists in the zone.
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = var.validation_record_ttl
  records         = [each.value.record]
  allow_overwrite = true
}

# Block until ACM sees the validation records and issues the certificate.
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
