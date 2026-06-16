# OIDC web identity federation for AWS: let external OIDC identities (GitHub Actions, GitLab CI,
# Terraform Cloud, another cloud) assume IAM roles via short-lived OIDC tokens — no long-lived
# access keys.
#
# This module is deliberately IdP-neutral. It owns the *mechanism* — ONE IAM OIDC identity provider,
# and the role(s) whose trust policy validates an AssumeRoleWithWebIdentity call against the token's
# `aud`/`sub` claims — while the *policy* (which issuer, which subjects to gate on, what the role may
# do) is supplied as inputs. GitHub Actions is just one possible issuer.
#
# ONE PROVIDER PER INSTANCE: this module creates a single OIDC provider. To federate more than one
# issuer, instantiate the module once per issuer (e.g. a separate Terragrunt unit each).
#
# This is the AWS analogue of GCP "direct WIF": CI assumes the role itself, with no intermediary
# identity and no static secret.

# --- Identity provider -----------------------------------------------------
# thumbprint_list is omitted by default for the well-known IdPs because AWS validates them against
# its own trust store.
#
# SHARING CAVEAT: an AWS account may hold only ONE OIDC provider per issuer URL. This module is
# create-only; if the provider already exists in the account (created by another stack/unit), apply
# will collide. Import it into this state or have a single owner create it. See variables.tf.
resource "aws_iam_openid_connect_provider" "this" {
  url             = var.provider_url
  client_id_list  = var.client_id_list
  thumbprint_list = var.thumbprint_list

  tags = var.tags
}

# --- Trust policies --------------------------------------------------------
# Build one AssumeRoleWithWebIdentity trust policy per role: principal is the federated provider,
# the audience claim must match, and the subject claim must match one of the allowed subjects
# (StringLike so callers can use wildcards like "repo:OWNER/REPO:*").
locals {
  # The OIDC condition keys are namespaced by the provider host (issuer URL without scheme), e.g.
  # "token.actions.githubusercontent.com:sub". Derive that host from the provider url.
  provider_host = replace(var.provider_url, "https://", "")
}

data "aws_iam_policy_document" "trust" {
  for_each = var.roles

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    # aud — the token audience. Defaults to the provider's configured client_id_list.
    condition {
      test     = "StringEquals"
      variable = "${local.provider_host}:aud"
      values   = coalesce(each.value.audiences, var.client_id_list)
    }

    # sub — the gated subject(s). StringLike to allow wildcard scoping.
    condition {
      test     = "StringLike"
      variable = "${local.provider_host}:sub"
      values   = each.value.subjects
    }
  }
}

# --- Roles -----------------------------------------------------------------
resource "aws_iam_role" "this" {
  for_each = var.roles

  name                 = "${var.name_prefix}${each.key}"
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = each.value.max_session_seconds

  tags = merge(var.tags, { Name = "${var.name_prefix}${each.key}" })
}

# Attach managed policies. Flatten {role -> [arns]} into one attachment per (role, arn) pair.
locals {
  role_policy_attachments = merge([
    for role_key, r in var.roles : {
      for arn in r.managed_policy_arns : "${role_key}/${arn}" => {
        role_key = role_key
        arn      = arn
      }
    }
  ]...)
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = local.role_policy_attachments

  role       = aws_iam_role.this[each.value.role_key].name
  policy_arn = each.value.arn
}

# Optional inline policy per role, for permissions without a convenient managed policy.
resource "aws_iam_role_policy" "inline" {
  for_each = { for k, r in var.roles : k => r if r.inline_policy != null }

  name   = "${var.name_prefix}${each.key}-inline"
  role   = aws_iam_role.this[each.key].id
  policy = each.value.inline_policy
}
