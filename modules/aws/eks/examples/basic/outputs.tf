output "cluster_name" {
  description = "The name of the created EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The API server endpoint of the created cluster."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version of the cluster."
  value       = module.eks.cluster_version
}

output "node_group_names" {
  description = "Names of the created managed node groups."
  value       = module.eks.node_group_names
}

output "addon_versions" {
  description = "Installed add-on versions."
  value       = module.eks.addon_versions
}

output "vpc_id" {
  description = "The ID of the VPC the cluster runs in."
  value       = module.vpc.vpc_id
}
