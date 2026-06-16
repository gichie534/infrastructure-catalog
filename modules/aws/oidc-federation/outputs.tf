output "provider_arn" {
  description = "ARN of the created IAM OIDC identity provider."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "role_arns" {
  description = "Map of role label to its IAM role ARN. Feed the relevant entry to CI as the role to assume (e.g. GitHub's role-to-assume / AWS_ROLE_ARN)."
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}

output "role_names" {
  description = "Map of role label to its IAM role name."
  value       = { for k, r in aws_iam_role.this : k => r.name }
}
