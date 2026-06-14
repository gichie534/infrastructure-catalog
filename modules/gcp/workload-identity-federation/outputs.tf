output "pool_id" {
  description = "The short ID of the Workload Identity Pool."
  value       = google_iam_workload_identity_pool.this.workload_identity_pool_id
}

output "pool_name" {
  description = "The full resource name of the Workload Identity Pool (projects/<num>/locations/global/workloadIdentityPools/<id>). Used to build principalSet members and the audience."
  value       = google_iam_workload_identity_pool.this.name
}

output "provider_names" {
  description = "Map of provider ID to its full resource name. The provider name is what external CI passes as the federation provider (e.g. GitHub's workload_identity_provider input)."
  value       = { for k, p in google_iam_workload_identity_pool_provider.this : k => p.name }
}

output "provider_ids" {
  description = "Map of provider ID to its short workload_identity_pool_provider_id."
  value       = { for k, p in google_iam_workload_identity_pool_provider.this : k => p.workload_identity_pool_provider_id }
}

output "principal_set_members" {
  description = <<-EOT
    Map of binding label (from project_iam_bindings) to the full principalSet:// IAM member string.
    Feed these into resource-scoped IAM bindings (a single bucket, repo, ...) for direct WIF without
    a service account. Only includes labels present in project_iam_bindings.
  EOT
  value = {
    for label, b in var.project_iam_bindings :
    label => "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.this.name}/${b.principal_set}"
  }
}
