output "name" {
  description = "Name of the created bucket."
  value       = module.bucket.name
}

output "url" {
  description = "gs:// URL of the created bucket."
  value       = module.bucket.url
}
