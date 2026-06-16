# EKS managed add-ons. Keyed by add-on name (e.g. vpc-cni, coredns, kube-proxy,
# eks-pod-identity-agent). Omit a key to leave that add-on unmanaged by this module.
#
# Add-ons that schedule pods (coredns, etc.) need nodes to be available, so all
# add-ons wait for the managed node groups.
resource "aws_eks_addon" "this" {
  for_each = var.addons

  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.key

  # null => EKS picks the default version compatible with the cluster.
  addon_version = each.value.version

  resolve_conflicts_on_create = each.value.resolve_conflicts_on_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update

  # JSON string of advanced settings; null leaves add-on defaults in place.
  configuration_values = each.value.configuration_values

  # Role for the add-on's service account (Pod Identity / IRSA), when it needs AWS access.
  service_account_role_arn = each.value.service_account_role_arn

  tags = var.tags

  depends_on = [aws_eks_node_group.this]
}
