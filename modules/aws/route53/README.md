# aws/route53

Creates a single Route 53 hosted zone — **public** or **private** — and a set of records in it. The
AWS analogue of [`gcp/cloud-dns`](../../gcp/cloud-dns): a private zone associated with one or more
VPCs lets workloads resolve internal names; a public zone serves external names and is delegated to
at a registrar (or a parent zone).

## Scope

This module owns:

- one `aws_route53_zone` (public, or private with one or more VPC associations);
- one `aws_route53_record` per entry in `records`;
- optional ACM DNS-validation records (`validation_records`);
- an optional `NS` delegation record written into a parent zone (`delegate_to_parent_zone`).

It deliberately leaves out routing policies (weighted/latency/geo/failover), health checks, DNSSEC,
and alias records — add them only when a workload needs them.

## Records

`records` is keyed by the name **relative** to the zone's `name`; `""` is the zone apex. Each value
sets `type`, optional `ttl` (default 300), and `records` (the values):

```hcl
records = {
  "api" = { type = "A", records = ["203.0.113.10"] }
  "www" = { type = "CNAME", ttl = 600, records = ["api.example.com"] }
}
```

## Validation records (computed names)

`records` is keyed by the record name, which breaks down when the name itself is only known **after
apply** — e.g. an ACM certificate DNS-validation CNAME. Using such a name as a map key makes
Terraform reject the `for_each` ("keys derived from resource attributes... cannot be determined until
apply").

`validation_records` solves this: it's keyed by a **stable caller label**, with the computed name in
the value (written verbatim, not expanded against `name`). Wire an ACM certificate's
`domain_validation_options` straight in:

```hcl
module "dns" {
  source = "../route53"
  # ...
  validation_records = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name    = dvo.resource_record_name
      type    = dvo.resource_record_type
      records = [dvo.resource_record_value]
    }
  }
}
```

`type` defaults to `CNAME`. This is the supported way to publish ACM validation records without
hitting the unknown-keys error.

## Subdomain delegation (`delegate_to_parent_zone`)

When this zone is a **child** of another Route 53 zone in the same account (e.g. `sub.example.com`
delegated from an existing `example.com` zone), set `delegate_to_parent_zone` to have the module
write the `NS` delegation record for this zone into the parent zone automatically, pointing at this
zone's own authoritative name servers:

```hcl
module "child" {
  source = "../route53"

  name       = "sub.example.com"
  visibility = "public"

  delegate_to_parent_zone = {
    zone_id = aws_route53_zone.parent.zone_id # the PARENT's hosted-zone ID
  }
}
```

This keeps a delegated subdomain **reproducible**: Route 53 assigns fresh name servers every time
the zone is created, and the NS record is rewritten in lock-step, so destroy/recreate never leaves a
stale delegation. Leave it unset (default) for a top-level zone whose delegation lives at an external
registrar. Set `ttl` inside the object to override the default 300s.

## Private zones

For an internal zone, set `visibility = "private"` and supply one or more `vpc_associations`. Only
VPCs listed there can resolve the zone:

```hcl
module "internal" {
  source = "../route53"

  name       = "internal.example.com"
  visibility = "private"

  vpc_associations = [
    { vpc_id = module.vpc.vpc_id },
  ]

  records = {
    "api" = { type = "A", records = ["10.0.0.10"] }
  }
}
```

## Usage

```hcl
module "dns" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/route53?ref=vX.Y.Z"

  name       = "aws.example.com"
  visibility = "public"

  records = {
    "api" = { type = "A", records = ["203.0.113.10"] }
  }
}
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
| [aws_route53_record.delegation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_comment"></a> [comment](#input\_comment) | Comment attached to the hosted zone. | `string` | `"Managed by Terraform"` | no |
| <a name="input_delegate_to_parent_zone"></a> [delegate\_to\_parent\_zone](#input\_delegate\_to\_parent\_zone) | Optionally delegate this (sub)zone from an existing PARENT hosted zone. When set, the module<br/>writes an NS record for this zone's name into the named parent zone, pointing at this zone's own<br/>authoritative name servers. This makes a delegated subdomain self-contained and reproducible:<br/>Route 53 assigns fresh name servers each time the zone is recreated, and the NS delegation is<br/>rewritten in lock-step, so destroy/recreate never leaves a stale delegation.<br/><br/>Use this when this zone is a child of another Route 53 zone in the same account (e.g. zone<br/>"sub.example.com" delegated from the existing "example.com" zone). Leave null (default) for a<br/>top-level zone whose delegation is handled at an external registrar.<br/><br/>- zone\_id: the parent's Route 53 hosted-zone ID to write the NS record into.<br/>- ttl:     TTL for the NS delegation record (default 300). | <pre>object({<br/>    zone_id = string<br/>    ttl     = optional(number, 300)<br/>  })</pre> | `null` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Whether to allow Terraform to destroy the zone even when it still contains records not managed by this module. Set true in throwaway lab environments so `terraform destroy` tears down cleanly. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | The domain name of the hosted zone, e.g. example.com or aws.example.com. A trailing dot is optional (Route 53 normalizes it). | `string` | n/a | yes |
| <a name="input_records"></a> [records](#input\_records) | DNS records to create in the zone, keyed by the record name relative to the zone's name.<br/>Use "" for the zone apex. Each value sets the record type, ttl, and records (the record values).<br/>Example: { "api" = { type = "A", records = ["203.0.113.10"] }, "" = { type = "TXT", records = ["\"v=spf1 -all\""] } } | <pre>map(object({<br/>    type    = string<br/>    ttl     = optional(number, 300)<br/>    records = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the hosted zone. | `map(string)` | `{}` | no |
| <a name="input_validation_records"></a> [validation\_records](#input\_validation\_records) | Records whose NAME is computed (known only after apply) — chiefly ACM certificate DNS-validation<br/>CNAMEs. Unlike `records` (which is keyed by the record name), this map is keyed by a STABLE<br/>caller-chosen label, with the fully-qualified record name carried in the value. That keeps the<br/>for\_each keys known at plan time, so you can wire an ACM certificate's<br/>domain\_validation\_options straight in without Terraform complaining that the keys are unknown.<br/><br/>- name:    the fully-qualified record name (ACM returns an absolute FQDN, e.g.<br/>           "\_x1.api.example.com."). Written verbatim; NOT expanded against the zone name.<br/>- type:    record type (typically "CNAME").<br/>- ttl:     optional, default 300.<br/>- records: the record values.<br/><br/>Example (wiring an ACM certificate):<br/>  validation\_records = {<br/>    for dvo in aws\_acm\_certificate.this.domain\_validation\_options :<br/>    dvo.domain\_name => { name = dvo.resource\_record\_name, type = dvo.resource\_record\_type, records = [dvo.resource\_record\_value] }<br/>  } | <pre>map(object({<br/>    name    = string<br/>    type    = optional(string, "CNAME")<br/>    ttl     = optional(number, 300)<br/>    records = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_visibility"></a> [visibility](#input\_visibility) | Zone visibility: 'public' (resolvable on the internet) or 'private' (resolvable only on the associated VPCs). | `string` | n/a | yes |
| <a name="input_vpc_associations"></a> [vpc\_associations](#input\_vpc\_associations) | VPCs the private zone is resolvable on. Required (non-empty) for private zones and must be empty for public zones. vpc\_region defaults to the provider region when omitted. | <pre>list(object({<br/>    vpc_id     = string<br/>    vpc_region = optional(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_delegation_record_name"></a> [delegation\_record\_name](#output\_delegation\_record\_name) | The NS delegation record name written into the parent zone, or null when delegate\_to\_parent\_zone is unset. |
| <a name="output_name"></a> [name](#output\_name) | The domain name of the zone. |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | The zone's authoritative name servers. For a public zone, delegate the domain to these at your registrar (or parent zone). Unused for private zones. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Map of relative record name to its fully-qualified domain name. |
| <a name="output_validation_record_fqdns"></a> [validation\_record\_fqdns](#output\_validation\_record\_fqdns) | Map of validation-record label to the fully-qualified name actually created (echoes the input names; useful for assertions and debugging). |
| <a name="output_zone_arn"></a> [zone\_arn](#output\_zone\_arn) | ARN of the hosted zone. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | The hosted-zone ID (used to add records or wire other resources such as ALB alias records). |
<!-- END_TF_DOCS -->
