# aws/vpc

A compute-ready VPC for EKS, ECS, and other workloads: a VPC with public and private subnets across
the supplied availability zones, an internet gateway, NAT gateway(s) for private egress, and per-AZ
private route tables. Public subnets are tagged `kubernetes.io/role/elb` and private subnets
`kubernetes.io/role/internal-elb` so EKS can place internet-facing and internal load balancers
without extra wiring.

## Usage

```hcl
module "vpc" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/vpc?ref=vX.Y.Z"

  name       = "platform"
  cidr_block = "10.0.0.0/16"

  azs                  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
  private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]

  tags = {
    Environment = "dev"
  }
}
```

Wire EKS / ECS to the outputs:

```hcl
# EKS managed node groups and ECS services run in the private subnets;
# load balancers land in the public subnets.
vpc_id     = module.vpc.vpc_id
subnet_ids = module.vpc.private_subnet_ids
```

When attaching an EKS cluster, also add the cluster-ownership tag to the subnets from the consuming
configuration (`kubernetes.io/cluster/<cluster-name> = shared`); this module intentionally leaves
cluster-specific tags to the consumer.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.50.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_azs"></a> [azs](#input\_azs) | Availability zones to spread subnets across. One public and one private subnet is created per AZ, paired by index with public\_subnet\_cidrs / private\_subnet\_cidrs. | `list(string)` | n/a | yes |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | Primary IPv4 CIDR block for the VPC (e.g. 10.0.0.0/16). Subnet CIDRs must fall within this range. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_enable_dns_hostnames"></a> [enable\_dns\_hostnames](#input\_enable\_dns\_hostnames) | Assign public DNS hostnames to instances with public IPs. Required by EKS. | `bool` | `true` | no |
| <a name="input_enable_dns_support"></a> [enable\_dns\_support](#input\_enable\_dns\_support) | Enable DNS resolution via the Amazon-provided DNS server in the VPC. Required by EKS. | `bool` | `true` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Create NAT gateway(s) so private subnets can reach the internet for egress (pulling images, package installs, EKS/ECS control-plane traffic). | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | Name applied to the VPC and used as the prefix for its subnets, gateways, and route tables. | `string` | n/a | yes |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | CIDR blocks for the private subnets, one per AZ (index-aligned with azs). Private subnets host EKS/ECS workloads and egress via NAT. | `list(string)` | n/a | yes |
| <a name="input_private_subnet_tags"></a> [private\_subnet\_tags](#input\_private\_subnet\_tags) | Additional tags applied to private subnets. Defaults include kubernetes.io/role/internal-elb so EKS can place internal load balancers. | `map(string)` | <pre>{<br/>  "kubernetes.io/role/internal-elb": "1"<br/>}</pre> | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | CIDR blocks for the public subnets, one per AZ (index-aligned with azs). Public subnets route to the internet gateway and host load balancers / NAT gateways. | `list(string)` | n/a | yes |
| <a name="input_public_subnet_tags"></a> [public\_subnet\_tags](#input\_public\_subnet\_tags) | Additional tags applied to public subnets. Defaults include kubernetes.io/role/elb so EKS can place internet-facing load balancers. | `map(string)` | <pre>{<br/>  "kubernetes.io/role/elb": "1"<br/>}</pre> | no |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Use a single shared NAT gateway in the first public subnet instead of one per AZ. Cheaper for non-prod; set false for per-AZ HA. Only used when enable\_nat\_gateway is true. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource created by this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | The ID of the internet gateway. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | List of NAT gateway IDs, or an empty list when NAT is disabled. |
| <a name="output_nat_public_ips"></a> [nat\_public\_ips](#output\_nat\_public\_ips) | List of Elastic IPs assigned to the NAT gateways. |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | Map of availability zone to private route table ID. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of private subnet IDs (for EKS/ECS workloads and other compute). |
| <a name="output_private_subnets_by_az"></a> [private\_subnets\_by\_az](#output\_private\_subnets\_by\_az) | Map of availability zone to private subnet ID. |
| <a name="output_public_route_table_id"></a> [public\_route\_table\_id](#output\_public\_route\_table\_id) | The ID of the public route table. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of public subnet IDs (for load balancers, NAT gateways, bastions). |
| <a name="output_public_subnets_by_az"></a> [public\_subnets\_by\_az](#output\_public\_subnets\_by\_az) | Map of availability zone to public subnet ID. |
| <a name="output_vpc_arn"></a> [vpc\_arn](#output\_vpc\_arn) | The ARN of the VPC. |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | The primary IPv4 CIDR block of the VPC. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC. |
<!-- END_TF_DOCS -->
