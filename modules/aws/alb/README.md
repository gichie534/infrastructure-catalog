# aws/alb

An **Application Load Balancer** with an HTTP listener, one or more **target groups**, and
**path- and host-based routing rules** — the minimal building block for putting several backends
behind a single entry point.

The module owns only the load balancer, its target groups, the listener, its rules, and (optionally)
a security group. It does **not** create the VPC/subnets or the targets — the consumer supplies
`vpc_id`, `subnet_ids`, and the `target_ids` to register, so the module stays region- and
account-agnostic.

## How routing works

The HTTP listener evaluates `listener_rules` in ascending `priority`. Each rule matches on a path
pattern, a host header, or both, and forwards to one of the `target_groups`:

```
                        ┌── /a, /a/*  ─────────────▶ target group "a"
client ─▶ ALB listener ─┤── /b, /b/*  ─────────────▶ target group "b"
          (:80)         ├── Host: a.example.com ───▶ target group "a"
                        ├── Host: b.example.com ───▶ target group "b"
                        └── (no match) ────────────▶ default_target_group_key, else fixed 404
```

When `default_target_group_key` is null, unmatched requests get a fixed `404` response so they fail
cheaply instead of landing on an arbitrary backend.

## HTTPS (optional)

Pass a `certificate_arn` (an ACM certificate ARN — see the `acm-certificate` module) and the module
terminates TLS:

- adds an **HTTPS listener** on `https_listener_port` (default `443`) using that certificate and
  `ssl_policy`;
- turns the HTTP listener into a permanent **301 redirect to HTTPS** (it no longer serves traffic);
- moves the routing rules and the default action onto the HTTPS listener;
- opens `443` on the module-created security group.

```hcl
  certificate_arn = module.certificate.certificate_arn # HTTP :80 now 301-redirects to HTTPS :443
```

Leave `certificate_arn` null (the default) for plain HTTP — behaviour is unchanged.

## Usage

```hcl
module "alb" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/alb?ref=aws-alb-vX.Y.Z"

  name       = "web"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids # at least two AZs

  target_groups = {
    a = { port = 80, target_ids = [module.app_a.id] }
    b = { port = 80, target_ids = [module.app_b.id] }
  }

  listener_rules = {
    path_a = { priority = 10, target_group_key = "a", path_patterns = ["/a", "/a/*"] }
    path_b = { priority = 20, target_group_key = "b", path_patterns = ["/b", "/b/*"] }
    host_a = { priority = 30, target_group_key = "a", host_headers = ["a.example.com"] }
    host_b = { priority = 40, target_group_key = "b", host_headers = ["b.example.com"] }
  }

  tags = {
    Environment = "dev"
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
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ARN of an ACM certificate. When set, the module adds an HTTPS listener on https\_listener\_port<br/>(default 443) using this certificate, and the HTTP listener on listener\_port becomes a permanent<br/>(301) redirect to HTTPS instead of serving traffic. Listener rules and the default action then<br/>attach to the HTTPS listener. When null (default) the module is plain HTTP as before. | `string` | `null` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Create a security group for the ALB (allowing inbound on listener\_port from ingress\_cidr\_blocks, all egress). Ignored when security\_group\_ids is non-empty. | `bool` | `true` | no |
| <a name="input_default_target_group_key"></a> [default\_target\_group\_key](#input\_default\_target\_group\_key) | Key (from target\_groups) the listener forwards to when no rule matches. When null (default), unmatched requests get a fixed 404 response instead. | `string` | `null` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Guard the ALB against accidental deletion. Keep false for labs so teardown isn't blocked. | `bool` | `false` | no |
| <a name="input_https_listener_port"></a> [https\_listener\_port](#input\_https\_listener\_port) | Port the HTTPS listener accepts traffic on. Only used when certificate\_arn is set. | `number` | `443` | no |
| <a name="input_ingress_cidr_blocks"></a> [ingress\_cidr\_blocks](#input\_ingress\_cidr\_blocks) | CIDR blocks allowed to reach the ALB on listener\_port. Only used when the module creates its own security group. Default open to the internet. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_internal"></a> [internal](#input\_internal) | Whether the ALB is internal (no public IPs). Default false = internet-facing. | `bool` | `false` | no |
| <a name="input_listener_port"></a> [listener\_port](#input\_listener\_port) | Port the HTTP listener accepts traffic on. | `number` | `80` | no |
| <a name="input_listener_rules"></a> [listener\_rules](#input\_listener\_rules) | Listener rules evaluated in priority order, keyed by a logical name. Each value:<br/>  - priority         : evaluation order (lower first); must be unique.<br/>  - target\_group\_key : key (from target\_groups) to forward matched requests to.<br/>  - path\_patterns    : path-based match, e.g. ["/a", "/a/*"]. Optional.<br/>  - host\_headers     : host-based match, e.g. ["a.example.com"]. Optional.<br/>At least one of path\_patterns or host\_headers must be set per rule. | <pre>map(object({<br/>    priority         = number<br/>    target_group_key = string<br/>    path_patterns    = optional(list(string))<br/>    host_headers     = optional(list(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the Application Load Balancer, used as the prefix for its target groups and security group. Must be 1-32 chars, alphanumeric or hyphens. | `string` | n/a | yes |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security group IDs to attach to the ALB. When empty (default) and create\_security\_group is true, the module creates one allowing inbound on listener\_port from ingress\_cidr\_blocks. | `list(string)` | `[]` | no |
| <a name="input_ssl_policy"></a> [ssl\_policy](#input\_ssl\_policy) | ELB security policy (TLS versions/ciphers) for the HTTPS listener. Only used when certificate\_arn is set. | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs to place the load balancer in. An ALB requires at least two subnets in different AZs. Use public subnets for an internet-facing ALB. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource created by this module. | `map(string)` | `{}` | no |
| <a name="input_target_groups"></a> [target\_groups](#input\_target\_groups) | Target groups to create, keyed by a logical name. Each value:<br/>  - port                  : port the targets receive traffic on.<br/>  - protocol              : target group protocol (default HTTP).<br/>  - target\_type           : instance \| ip \| lambda (default instance).<br/>  - target\_ids            : IDs to register (instance IDs for target\_type=instance). May be empty.<br/>  - health\_check\_path     : HTTP path the health check requests (default "/").<br/>  - health\_check\_matcher  : HTTP codes considered healthy (default "200").<br/>  - health\_check\_interval : seconds between health checks (default 30).<br/>  - healthy\_threshold     : consecutive successes before healthy (default 3).<br/>  - unhealthy\_threshold   : consecutive failures before unhealthy (default 3). | <pre>map(object({<br/>    port                  = number<br/>    protocol              = optional(string, "HTTP")<br/>    target_type           = optional(string, "instance")<br/>    target_ids            = optional(list(string), [])<br/>    health_check_path     = optional(string, "/")<br/>    health_check_matcher  = optional(string, "200")<br/>    health_check_interval = optional(number, 30)<br/>    healthy_threshold     = optional(number, 3)<br/>    unhealthy_threshold   = optional(number, 3)<br/>  }))</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC the load balancer and its target groups live in. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the Application Load Balancer. |
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name) | Public DNS name of the ALB — the endpoint clients send requests to. |
| <a name="output_https_listener_arn"></a> [https\_listener\_arn](#output\_https\_listener\_arn) | ARN of the HTTPS listener, or null when no certificate\_arn was supplied. |
| <a name="output_listener_arn"></a> [listener\_arn](#output\_listener\_arn) | ARN of the HTTP listener (a redirect-to-HTTPS listener when certificate\_arn is set, otherwise the traffic-serving listener). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the security group attached to the ALB (the one created by this module, or the first supplied one). |
| <a name="output_target_group_arns"></a> [target\_group\_arns](#output\_target\_group\_arns) | Map of target group key to its ARN. |
| <a name="output_target_group_names"></a> [target\_group\_names](#output\_target\_group\_names) | Map of target group key to its name. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | Route 53 hosted zone ID of the ALB, for aliasing a custom domain to it. |
<!-- END_TF_DOCS -->
