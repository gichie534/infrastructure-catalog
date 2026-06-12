output "instance_id" {
  description = "The ID of the created instance"
  value       = module.vm.instance_id
}

output "internal_ip" {
  description = "The internal IP of the created instance"
  value       = module.vm.internal_ip
}
