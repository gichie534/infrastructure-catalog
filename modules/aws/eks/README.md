# aws/eks

A basic EKS cluster with managed node groups. The module provisions the control plane, the IAM
roles it and the nodes require, one or more managed node groups, and any EKS managed add-ons you
pass. Workload-level AWS permissions are expected to be granted via EKS Pod Identity (configured by
the consumer).

The module is network-agnostic: pass in the `subnet_ids` the cluster and nodes should run in
(private subnets recommended). It pairs naturally with the sibling [`aws/vpc`](../vpc) module, whose
`private_subnet_ids` output wires straight into this input (see `examples/basic`).

## Usage

```hcl
module "eks" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/eks?ref=vX.Y.Z"

  name               = "platform"
  kubernetes_version = "1.31"

  subnet_ids = module.vpc.private_subnet_ids

  node_groups = {
    default = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
    }
  }

  # Turn add-ons on by listing them; remove a key to turn it off.
  addons = {
    vpc-cni                = {}
    coredns                = {}
    kube-proxy             = {}
    eks-pod-identity-agent = {}
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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.50.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_role.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.cluster_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.node_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_addons"></a> [addons](#input\_addons) | EKS managed add-ons to install, keyed by add-on name (e.g. vpc-cni, coredns, kube-proxy,<br/>eks-pod-identity-agent). Omit a key to leave that add-on unmanaged by this module. Per add-on:<br/>version (null = EKS default), conflict-resolution strategy on create/update, a JSON<br/>configuration\_values string, and an optional service\_account\_role\_arn for Pod Identity/IRSA. | <pre>map(object({<br/>    version                     = optional(string)<br/>    resolve_conflicts_on_create = optional(string, "OVERWRITE")<br/>    resolve_conflicts_on_update = optional(string, "OVERWRITE")<br/>    configuration_values        = optional(string)<br/>    service_account_role_arn    = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_endpoint_private_access"></a> [endpoint\_private\_access](#input\_endpoint\_private\_access) | Whether the Kubernetes API server is reachable privately from within the VPC. | `bool` | `true` | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Whether the Kubernetes API server is reachable from the public internet (locked down with endpoint\_public\_access\_cidrs). | `bool` | `true` | no |
| <a name="input_endpoint_public_access_cidrs"></a> [endpoint\_public\_access\_cidrs](#input\_endpoint\_public\_access\_cidrs) | CIDR blocks allowed to reach the public API server endpoint. Only used when endpoint\_public\_access is true. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes minor version for the control plane (e.g. 1.31). Node groups inherit this version. | `string` | `"1.31"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the EKS cluster, used as the prefix for its IAM roles, node groups, and related resources. | `string` | n/a | yes |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Managed node groups to create, keyed by name. Each group runs in the cluster's subnets and<br/>scales between min\_size and max\_size. instance\_types and capacity\_type (ON\_DEMAND or SPOT)<br/>are per group. | <pre>map(object({<br/>    instance_types = optional(list(string), ["t3.medium"])<br/>    capacity_type  = optional(string, "ON_DEMAND")<br/>    desired_size   = optional(number, 2)<br/>    min_size       = optional(number, 1)<br/>    max_size       = optional(number, 3)<br/>    disk_size      = optional(number, 20)<br/>    labels         = optional(map(string), {})<br/>  }))</pre> | <pre>{<br/>  "default": {}<br/>}</pre> | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnet IDs for the cluster control plane ENIs and the worker nodes. Use private subnets for nodes. Wire to the vpc module's private\_subnet\_ids. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource created by this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addon_versions"></a> [addon\_versions](#output\_addon\_versions) | Map of installed add-on name to the resolved add-on version. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | The ARN of the EKS cluster. |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64-encoded CA certificate of the cluster, used to authenticate kubectl/provider clients. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | The endpoint of the Kubernetes API server. |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | The ARN of the IAM role assumed by the EKS control plane. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | The cluster security group created and managed by EKS for control-plane-to-node communication. |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | The Kubernetes version running on the control plane. |
| <a name="output_node_group_names"></a> [node\_group\_names](#output\_node\_group\_names) | Map of node group key to its EKS node group name. |
| <a name="output_node_iam_role_arn"></a> [node\_iam\_role\_arn](#output\_node\_iam\_role\_arn) | The ARN of the IAM role assumed by the managed node groups. |
<!-- END_TF_DOCS -->
