output "repository_url" {
  description = "URL of the repository (<account>.dkr.ecr.<region>.amazonaws.com/<name>). Tag and push images here, and reference it as the container image (with a tag) in a task definition."
  value       = aws_ecr_repository.this.repository_url
}

output "arn" {
  description = "ARN of the repository. Use it to scope an IAM policy granting push/pull to a CI role."
  value       = aws_ecr_repository.this.arn
}

output "name" {
  description = "Name of the repository."
  value       = aws_ecr_repository.this.name
}

output "registry_id" {
  description = "The account ID of the registry holding the repository."
  value       = aws_ecr_repository.this.registry_id
}
