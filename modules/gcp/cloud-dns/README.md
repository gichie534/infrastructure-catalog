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

| Name                                                                      | Version |
| ------------------------------------------------------------------------- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0  |
| <a name="requirement_google"></a> [google](#requirement\_google)          | >= 7.35 |

## Providers

| Name                                                       | Version |
| ---------------------------------------------------------- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | 7.36.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                            | Type     |
| ------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [google_dns_managed_zone.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set)     | resource |

## Inputs

| Name                                                               | Description                                                                                                                                                                                                                                                                                                               | Type                                                                                                                              | Default | Required |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ------- | :------: |
| <a name="input_dns_name"></a> [dns\_name](#input\_dns\_name)       | The DNS domain of the zone, with a trailing dot (e.g. internal.example.com.).                                                                                                                                                                                                                                             | `string`                                                                                                                          | n/a     |   yes    |
| <a name="input_labels"></a> [labels](#input\_labels)               | Labels applied to the managed zone.                                                                                                                                                                                                                                                                                       | `map(string)`                                                                                                                     | `{}`    |    no    |
| <a name="input_name"></a> [name](#input\_name)                     | Name of the managed zone (the Cloud DNS resource name, not the domain).                                                                                                                                                                                                                                                   | `string`                                                                                                                          | n/a     |   yes    |
| <a name="input_networks"></a> [networks](#input\_networks)         | Self links of the VPC networks the zone is visible on. Required (non-empty) for private zones and must be empty for public zones. Wire from the vpc module's network\_self\_link output.                                                                                                                                  | `list(string)`                                                                                                                    | `[]`    |    no    |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to create the managed zone.                                                                                                                                                                                                                                                                | `string`                                                                                                                          | n/a     |   yes    |
| <a name="input_records"></a> [records](#input\_records)            | DNS records to create in the zone, keyed by the record name relative to the zone's dns\_name.<br/>Use "" for the zone apex. Each value sets the record type, ttl, and rrdatas (the record values).<br/>Example: { "api" = { type = "A", rrdatas = ["10.0.0.10"] }, "" = { type = "TXT", rrdatas = ["\"v=spf1 -all\""] } } | <pre>map(object({<br/>    type    = string<br/>    ttl     = optional(number, 300)<br/>    rrdatas = list(string)<br/>  }))</pre> | `{}`    |    no    |
| <a name="input_visibility"></a> [visibility](#input\_visibility)   | Zone visibility: 'public' (resolvable on the internet) or 'private' (resolvable only on the attached VPC networks).                                                                                                                                                                                                       | `string`                                                                                                                          | n/a     |   yes    |

## Outputs

| Name                                                                       | Description                                                                                                                               |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name)             | The DNS domain of the zone (with trailing dot).                                                                                           |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | The zone's authoritative name servers. For a public zone, delegate the domain to these at your registrar. Empty/unused for private zones. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Map of relative record name to its fully-qualified domain name (with trailing dot).                                                       |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name)          | The managed-zone resource name (used to add records or grant DNS IAM).                                                                    |
<!-- END_TF_DOCS -->
