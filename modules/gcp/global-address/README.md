# gcp/global-address

Reserves a single **global external IPv4 address**. Its primary consumer is a classic **GKE
Ingress** (`kubernetes.io/ingress.class: gce`): by default GKE allocates an *ephemeral* IP for an
Ingress's external Application Load Balancer, and that IP changes if the Ingress is deleted and
recreated. Referencing a reserved address by name
(`kubernetes.io/ingress.global-static-ip-name: <name>`) keeps the IP stable across Ingress
recreation, so a DNS A record pointed at it doesn't need to change.

## Scope

This module owns:

- one `google_compute_global_address` (`address_type = EXTERNAL`, `ip_version = IPV4`).

It deliberately does **not** own:

- **DNS records** — publish the `address` output as an A record with the consumer's DNS module
  (e.g. [`gcp/cloud-dns`](../cloud-dns));
- **the Ingress / ManagedCertificate** — those are application-layer Kubernetes objects (Helm
  chart), not Terraform-managed by this module.

## Usage

```hcl
module "ingress_ip" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/gcp/global-address?ref=vX.Y.Z"

  project_id  = "my-project"
  name        = "my-app-ingress-ip"
  description = "Static IP for my-app's GKE Ingress"
}
```

Wire the `name` output into the Ingress annotation:

```yaml
metadata:
  annotations:
    kubernetes.io/ingress.global-static-ip-name: my-app-ingress-ip
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
| <a name="provider_google"></a> [google](#provider\_google) | 7.44.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_global_address.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_description"></a> [description](#input\_description) | Human-readable description of the address's purpose. | `string` | `""` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the reserved global address. Referenced by an Ingress's kubernetes.io/ingress.global-static-ip-name annotation. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the project in which to reserve the address. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | The reserved IPv4 address (dotted-decimal string). Wire this into a DNS A record and/or read it for reference; the Ingress consumes the address by name, not by value. |
| <a name="output_name"></a> [name](#output\_name) | The name of the reserved address, for the Ingress's kubernetes.io/ingress.global-static-ip-name annotation. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | The self link of the reserved address resource. |
<!-- END_TF_DOCS -->
