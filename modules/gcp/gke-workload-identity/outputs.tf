output "principal" {
  description = "The federated IAM principal of the Kubernetes service account. Grant this anything (here, done via the module's own inputs). A pod running under the KSA authenticates to Google APIs as this principal with no exported key and no GSA impersonation."
  value       = local.ksa_principal
}
