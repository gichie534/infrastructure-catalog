output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "The endpoint of the Kubernetes API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate of the cluster, used to authenticate kubectl/provider clients."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "The Kubernetes version running on the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "The cluster security group created and managed by EKS for control-plane-to-node communication."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "The ARN of the IAM role assumed by the EKS control plane."
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "The ARN of the IAM role assumed by the managed node groups."
  value       = aws_iam_role.node.arn
}

output "node_group_names" {
  description = "Map of node group key to its EKS node group name."
  value       = { for k, g in aws_eks_node_group.this : k => g.node_group_name }
}

output "addon_versions" {
  description = "Map of installed add-on name to the resolved add-on version."
  value       = { for k, a in aws_eks_addon.this : k => a.addon_version }
}
