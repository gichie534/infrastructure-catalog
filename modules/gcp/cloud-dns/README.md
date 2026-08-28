# gcp/cloud-dns

Creates a single Cloud DNS managed zone — **public** or **private** — and a set of record sets in
it. Built for GKE service discovery: a private zone on the cluster's VPC lets workloads resolve
internal names; a public zone serves external names.

## Scope

This module owns:

- one `google_dns_managed_zone` (visibility public or private; private zones attach to the supplied
  VPC networks);
- one `google_dns_record_set` per entry in `records`.

It deliberately leaves out routing policies (geo/weighted/failover), DNSSEC, and alias records — add
them only when a workload needs them.

## Records

`records` is keyed by the name **relative** to the zone's `dns_name`; `""` is the zone apex. Each
value sets `type`, optional `ttl` (default 300), and `rrdatas`:

```hcl
records = {
  "api" = { type = "A", rrdatas = ["10.0.0.10"] }
  "db"  = { type = "CNAME", ttl = 600, rrdatas = ["api.internal.example.com."] }
}
```

## Validation records (computed names)

`records` is keyed by the record name, which breaks down when the name itself is only known **after
apply** — e.g. an ACME / Certificate Manager DNS-authorization CNAME. Using such a name as a map key
makes Terraform reject the `for_each` ("keys derived from resource attributes... cannot be determined
until apply").

`validation_records` solves this: it's keyed by a **stable caller label**, with the computed name in
the value (written verbatim, not expanded against `dns_name`). Wire a certificate module's
`dns_authorization_records` straight in:

```hcl
module "dns" {
  source = "../cloud-dns"
  # ...
  validation_records = {
    for label, rec in module.certs.dns_authorization_records :
    label => { name = rec.name, type = rec.type, rrdatas = [rec.data] }
  }
}
```

`type` defaults to `CNAME`. This is the supported way to publish Certificate Manager validation
CNAMEs (the ACM-in-Route53 analogue) without hitting the unknown-keys error.

## Subdomain delegation (`delegate_to_parent_zone`)

When this zone is a **child** of another Cloud DNS zone in the same org (e.g. `sub.example.com.`
delegated from an existing `example.com.` zone), set `delegate_to_parent_zone` to have the module
write the `NS` delegation record for this zone into the parent zone automatically, pointing at this
zone's own authoritative name servers:

```hcl
module "child" {
  source = "../cloud-dns"

  project_id = "my-project"
  name       = "sub-example"
  dns_name   = "sub.example.com."
  visibility = "public"

  delegate_to_parent_zone = {
    zone_name = "example-com" # the PARENT's Cloud DNS managed-zone resource name (not the domain)
  }
}
```

This keeps a delegated subdomain **reproducible**: GCP assigns fresh name servers every time the
zone is created, and the NS record is rewritten in lock-step, so destroy/recreate never leaves a
stale delegation. Leave it unset (default) for a top-level zone whose delegation lives at an external
registrar. Set `project_id` inside the object if the parent zone is in a different project, and `ttl`
to override the default 300s.

## external-dns

If you run [external-dns](https://github.com/kubernetes-sigs/external-dns) in the cluster to manage
records dynamically, its controller authenticates as a Google service account that needs project
Cloud DNS access. Grant it via the [`gcp/workload-iam`](../workload-iam) module's `project_roles`
input — no change to this module is required:

```hcl
module "external_dns_iam" {
  source = "../../workload-iam"
  # ...
  project_roles = ["roles/dns.admin"]
}
```

## Usage

```hcl
module "dns" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/cloud-dns?ref=vX.Y.Z"

  project_id = "my-project"
  name       = "internal"
  dns_name   = "internal.example.com."
  visibility = "private"
  networks   = [module.vpc.network_self_link]

  records = {
    "api" = { type = "A", rrdatas = ["10.0.0.10"] }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.35 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.39.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_dns_managed_zone.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.delegation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.sets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.validation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_delegate_to_parent_zone"></a> [delegate\_to\_parent\_zone](#input\_delegate\_to\_parent\_zone) | Optionally delegate this (sub)zone from an existing PARENT managed zone. When set, the module<br/>writes an NS record for this zone's dns\_name into the named parent zone, pointing at this zone's<br/>own authoritative name servers. This makes a delegated subdomain self-contained and reproducible:<br/>GCP assigns fresh name servers each time the zone is recreated, and the NS delegation is rewritten<br/>in lock-step, so destroy/recreate never leaves a stale delegation.<br/><br/>Use this when this zone is a child of another Cloud DNS zone in the same org (e.g. zone<br/>"sub.example.com." delegated from the existing "example.com." zone). Leave null (default) for a<br/>top-level zone whose delegation is handled at an external registrar.<br/><br/>- zone\_name:  the parent's Cloud DNS managed-zone resource name (NOT the domain) to write the NS<br/>              record into.<br/>- project\_id: project of the parent zone, if different from this zone's project\_id (default null<br/>              uses project\_id).<br/>- ttl:        TTL for the NS delegation record (default 300). | <pre>object({<br/>    zone_name  = string<br/>    project_id = optional(string)<br/>    ttl        = optional(number, 300)<br/>  })</pre> | `null` | no |
| <a name="input_dns_name"></a> [dns\_name](#input\_dns\_name) | The DNS domain of the zone, with a trailing dot (e.g. internal.example.com.). | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels applied to the managed zone. | `map(string)` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the managed zone (the Cloud DNS resource name, not the domain). | `string` | n/a | yes |
| <a name="input_networks"></a> [networks](#input\_networks) | Self links of the VPC networks the zone is visible on. Required (non-empty) for private zones and must be empty for public zones. Wire from the vpc module's network\_self\_link output. | `list(string)` | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the managed zone. | `string` | n/a | yes |
| <a name="input_record_sets"></a> [record\_sets](#input\_record\_sets) | DNS records keyed by a caller-chosen LABEL, with the record name carried in the value. This is the<br/>general form of `records` and the one to prefer for a real zone.<br/><br/>`records` is keyed by record name, so it can hold only ONE record per name. A live apex needs<br/>several — e.g. grace.io. simultaneously has A (the site), MX (mail), and TXT (SPF + domain<br/>verification). Use `record_sets` whenever a name needs more than one type; the label is arbitrary<br/>and only has to be unique.<br/><br/>- name:    record name RELATIVE to dns\_name; "" is the zone apex. (Contrast `validation_records`,<br/>           whose name is absolute.)<br/>- type:    record type.<br/>- ttl:     optional, default 300.<br/>- rrdatas: the record values. TXT values must include their own escaped quotes.<br/><br/>Example:<br/>  record\_sets = {<br/>    apex\_a   = { name = "", type = "A",   rrdatas = ["203.0.113.10"] }<br/>    apex\_mx  = { name = "", type = "MX",  rrdatas = ["10 mail.example.com."] }<br/>    apex\_spf = { name = "", type = "TXT", rrdatas = ["\"v=spf1 -all\""] }<br/>  } | <pre>map(object({<br/>    name    = string<br/>    type    = string<br/>    ttl     = optional(number, 300)<br/>    rrdatas = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_records"></a> [records](#input\_records) | DNS records to create in the zone, keyed by the record name relative to the zone's dns\_name.<br/>Use "" for the zone apex. Each value sets the record type, ttl, and rrdatas (the record values).<br/>Example: { "api" = { type = "A", rrdatas = ["10.0.0.10"] }, "" = { type = "TXT", rrdatas = ["\"v=spf1 -all\""] } } | <pre>map(object({<br/>    type    = string<br/>    ttl     = optional(number, 300)<br/>    rrdatas = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_validation_records"></a> [validation\_records](#input\_validation\_records) | Records whose NAME is computed (known only after apply) — chiefly ACME / Certificate Manager<br/>DNS-authorization CNAMEs. Unlike `records` (which is keyed by the record name), this map is keyed<br/>by a STABLE caller-chosen label, with the fully-qualified record name carried in the value. That<br/>keeps the for\_each keys known at plan time, so you can wire a certificate module's<br/>dns\_authorization\_records straight in without Terraform complaining that the keys are unknown.<br/><br/>- name:    the fully-qualified record name (Certificate Manager returns an absolute FQDN, e.g.<br/>           "\_acme-challenge.api.example.com." — trailing dot optional). Written verbatim; NOT<br/>           expanded against dns\_name.<br/>- type:    record type (typically "CNAME").<br/>- ttl:     optional, default 300.<br/>- rrdatas: the record values.<br/><br/>Example (wiring a certificate module):<br/>  validation\_records = module.certs.dns\_authorization\_records  # { api = { name, type, data }, ... }<br/>  # if the source shape uses `data` instead of `rrdatas`, adapt with a for-expression. | <pre>map(object({<br/>    name    = string<br/>    type    = optional(string, "CNAME")<br/>    ttl     = optional(number, 300)<br/>    rrdatas = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_visibility"></a> [visibility](#input\_visibility) | Zone visibility: 'public' (resolvable on the internet) or 'private' (resolvable only on the attached VPC networks). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_delegation_record_name"></a> [delegation\_record\_name](#output\_delegation\_record\_name) | The NS delegation record name written into the parent zone, or null when delegate\_to\_parent\_zone is unset. |
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name) | The DNS domain of the zone (with trailing dot). |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | The zone's authoritative name servers. For a public zone, delegate the domain to these at your registrar. Empty/unused for private zones. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Map of relative record name to its fully-qualified domain name (with trailing dot). |
| <a name="output_validation_record_names"></a> [validation\_record\_names](#output\_validation\_record\_names) | Map of validation-record label to the fully-qualified name actually created (echoes the input names; useful for assertions and debugging). |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | The managed-zone resource name (used to add records or grant DNS IAM). |
<!-- END_TF_DOCS -->
