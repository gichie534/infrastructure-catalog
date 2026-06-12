output "network_id" {
  description = "The ID of the created VPC network."
  value       = module.vpc.network_id
}

output "network_self_link" {
  description = "The self link of the created VPC network."
  value       = module.vpc.network_self_link
}

output "subnets" {
  description = "Subnets created by the module."
  value       = module.vpc.subnets
}

output "subnets_secondary_ranges" {
  description = "Pods/Services secondary ranges per subnet for VPC-native GKE."
  value       = module.vpc.subnets_secondary_ranges
}

output "private_service_access_range" {
  description = "Reserved range name for Private Service Access."
  value       = module.vpc.private_service_access_range
}
