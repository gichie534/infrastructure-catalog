# aws/acm-certificate

A public, **DNS-validated ACM certificate** whose validation records are written into a Route 53
hosted zone you already own — so issuance completes **automatically, with no manual DNS step**. The
module blocks (via `aws_acm_certificate_validation`) until the certificate is **ISSUED**, so anything
that reads `certificate_arn` (typically an ALB HTTPS listener or a CloudFront distribution) only
proceeds once the certificate is actually usable.

Self-contained by design: it owns the certificate, its validation records, and the validation wait.
It stays region/account-agnostic — you pass the domain(s) and the zone to validate in.

- **`domain_name`** — the primary FQDN (a wildcard `*.example.com` is allowed).
- **`subject_alternative_names`** — extra names the cert also covers; each gets its own validation
  record.
- **`hosted_zone_id`** — the Route 53 zone that is authoritative for those names on the public
  internet.

> **CloudFront note:** a certificate fronting CloudFront must live in `us-east-1`. Point the `aws`
> provider at `us-east-1` for that use. For an ALB, the cert must be in the ALB's region.

## Usage

```hcl
module "certificate" {
  source = "git::https://github.com/gichie534/infrastructure-catalog.git//modules/aws/acm-certificate?ref=aws-acm-certificate-v0.1.0"

  domain_name    = "app.example.com"
  hosted_zone_id = "Z0123456789ABCDEFGHIJ"

  tags = {
    Environment = "lab"
  }
}

# Attach to an ALB HTTPS listener:
# certificate_arn = module.certificate.certificate_arn
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.53.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Primary fully-qualified domain name the certificate is issued for (e.g. app.example.com). A wildcard (*.example.com) is allowed. | `string` | n/a | yes |
| <a name="input_hosted_zone_id"></a> [hosted\_zone\_id](#input\_hosted\_zone\_id) | Route 53 hosted-zone ID in which to create the DNS-validation records. The zone must be authoritative for domain\_name (and every SAN) so validation can complete. | `string` | n/a | yes |
| <a name="input_key_algorithm"></a> [key\_algorithm](#input\_key\_algorithm) | Key algorithm for the certificate (e.g. RSA\_2048, EC\_prime256v1). Leave null to let ACM choose its default (RSA\_2048). | `string` | `null` | no |
| <a name="input_subject_alternative_names"></a> [subject\_alternative\_names](#input\_subject\_alternative\_names) | Additional names the certificate should also cover (SANs), e.g. ["www.example.com"]. Each gets its own DNS-validation record. Empty by default. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the certificate. | `map(string)` | `{}` | no |
| <a name="input_validation_record_ttl"></a> [validation\_record\_ttl](#input\_validation\_record\_ttl) | TTL (seconds) for the DNS-validation CNAME records. | `number` | `60` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the ISSUED certificate (sourced from the validation resource, so reading it guarantees the cert is validated and ready to attach to a listener/distribution). |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | Primary domain name the certificate was issued for. |
| <a name="output_status"></a> [status](#output\_status) | Status of the certificate (ISSUED once validation completes). |
| <a name="output_validation_record_fqdns"></a> [validation\_record\_fqdns](#output\_validation\_record\_fqdns) | FQDNs of the DNS-validation records created in the hosted zone. |
<!-- END_TF_DOCS -->
