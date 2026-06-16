provider "aws" {
  region = var.region
}

# A GitHub Actions OIDC provider plus one role a single repo's workflows may assume — the
# direct-federation pattern (CI assumes the role itself, no static keys). The role gets a harmless
# read-only managed policy here; real consumers attach what they actually need.
module "oidc" {
  source = "../../"

  name_prefix = "${var.name}-"

  provider_url   = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # thumbprint_list omitted on purpose: AWS trusts GitHub's IdP via its own trust store.

  roles = {
    deployer = {
      subjects            = ["repo:${var.github_repository}:*"]
      managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    }
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
