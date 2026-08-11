output "enabled_apis" {
  description = "The set of API service names enabled on the project."
  value       = module.project_services.enabled_apis
}
