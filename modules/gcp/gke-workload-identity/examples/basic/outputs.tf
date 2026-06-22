output "principal" {
  description = "The federated IAM principal of the demo KSA."
  value       = module.workload_identity.principal
}

output "bucket_name" {
  description = "Name of the bucket the principal was granted access to."
  value       = module.bucket.name
}
