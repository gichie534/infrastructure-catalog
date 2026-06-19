# gcp/certificate-manager

Public, **Google-managed HTTPS certificates for GKE Ingress**, validated by **DNS authorization** —
the GCP analogue of "ACM certificate + Route53 validation + ALB". Certificate Manager provisions and
**auto-renews** each cert as long as its DNS-authorization CNAME stays published in the zone. GKE
Ingress attaches the certs by referencing this module's **certificate map** through the
`networking.gke.io/certmap` annotation (the annotation takes a *map* name, not a cert name).

This is the **all-in-one** variant: one module owns the entire bundle. See
[`gcp/certificate-manager-cert-v2`](../certificate-manager-cert-v2) +
[`gcp/certificate-manager-map-v2`](../certificate-manager-map-v2) for the split-module alternative
(the two are mutually exclusive — pick one to keep).

## AWS analogue

| AWS                                             | GCP (this module)                                                  |
| ----------------------------------------------- | ------------------------------------------------------------------ |
| `aws_acm_certificate` (DNS validation)          | `google_certificate_manager_certificate` (managed, DNS-authorized) |
| ACM validation CNAME in Route53                 | DNS-authorization CNAME in Cloud DNS (output here)                 |
| ALB + cert attached by ARN annotation           | GKE Ingress + certificate **map** via `networking.gke.io/certmap`  |
| AWS Load Balancer Controller (installed add-on) | GKE Ingress controller (built into GKE)                            |

TLS terminates at Google's front-end load balancer, not in the cluster — same as ACM/ALB.

## Scope

This module owns, **per entry in `certificates`**:

- one certificate (one `google_certificate_manager_dns_authorization` + one
  `google_certificate_manager_certificate`, managed, public, auto-renewing), created via the private
  `./modules/certificate` submodule;
- one `google_certificate_manager_certificate_map_entry` (SNI-routed by hostname);

plus exactly **one** `google_certificate_manager_certificate_map` shared across the entries.

Deliberately out of scope: wildcard certs (**per-host only**), private-CA issuance, regional
certs (global only — GKE's external ALB is global), and **writing DNS records** (option (a): the
module *outputs* the validation CNAMEs; you publish them via [`gcp/cloud-dns`](../cloud-dns)).

## DNS authorization (you must publish the records)

Each domain gets a DNS-authorization CNAME that **must resolve** before Certificate Manager will
issue or renew the cert. This module returns them in `dns_authorization_records`; feed them into the
`cloud-dns` module. Nothing validates until they're live — exactly like an ACM cert waiting on its
Route53 CNAME.

## Usage

```hcl
module "certs" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/certificate-manager?ref=vX.Y.Z"

  project_id = "my-project"
  name       = "prod-ingress"

  certificates = {
    api = { domain = "api.example.com" }
    app = { domain = "app.example.com" }
  }
}
```

Then publish the validation CNAMEs (see `examples/basic` for the cloud-dns wiring) and annotate the
Ingress:

```yaml
metadata:
  annotations:
    networking.gke.io/certmap: "prod-ingress" # = module.certs.certificate_map_name
```

## Inputs

- `project_id` (string) — project for all resources.
- `name` (string) — base name; the certificate map's name (and the `certmap` annotation value) and
  the prefix for every per-domain resource (`<name>-<label>`).
- `location` (string) — Certificate Manager location; defaults to `global` (correct for GKE Ingress).
- `certificates` (map) — keyed by a short label (used in resource names); each value sets `domain`
  (a single hostname; wildcards rejected).
- `labels` (map) — labels on every created resource.

## Outputs

- `certificate_map_name` — value for the Ingress `networking.gke.io/certmap` annotation.
- `certificate_map_id` — full resource ID of the map.
- `certificate_ids` — map of label → certificate resource ID.
- `dns_authorization_records` — map of label → `{ name, type, data }` CNAME to publish in the zone.
