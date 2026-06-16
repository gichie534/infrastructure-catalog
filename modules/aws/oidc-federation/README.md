# aws/oidc-federation

OIDC web identity federation for AWS: lets **external OIDC identities** (GitHub Actions, GitLab CI,
Terraform Cloud, another cloud) **assume IAM roles** with short-lived OIDC tokens — **no long-lived
access keys**. An external workload presents a signed OIDC token; AWS STS validates it against an
IAM OIDC identity provider and the role's trust policy, then returns temporary credentials.

This module is deliberately **IdP-neutral**. It owns the *mechanism* — **one** IAM OIDC identity
provider and the role(s) whose trust policy gates an `AssumeRoleWithWebIdentity` call on the token's
`aud`/`sub` claims — while the *policy* (which issuer, which subjects to trust, what the role may do)
is supplied as inputs. GitHub Actions is just one possible issuer.

This is the AWS analogue of GCP "direct WIF": CI assumes the role **itself**, with no intermediary
identity and no static secret.

## One provider per instance

This module creates **exactly one** OIDC provider. To federate more than one issuer (e.g. GitHub
*and* GitLab), instantiate the module once per issuer — a separate Terragrunt unit each. This keeps
each provider's lifecycle independent and avoids a single unit owning unrelated trust roots.

## Usage

```hcl
module "oidc" {
  source = "git::https://github.com/<github-org>/infrastructure-catalog.git//modules/aws/oidc-federation?ref=aws-oidc-federation-vX.Y.Z"

  name_prefix = "ci-"

  provider_url   = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # thumbprint_list omitted on purpose: AWS trusts GitHub's IdP via its own trust store.

  roles = {
    deployer = {
      # ALWAYS scope the subject. "repo:OWNER/REPO:*" = any workflow in that one repo.
      subjects            = ["repo:octo-org/my-repo:*"]
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      # Optional: scope down further with an inline policy instead of/alongside managed ARNs.
      # inline_policy = data.aws_iam_policy_document.scoped.json
    }
  }
}
```

CI then assumes `module.oidc.role_arns["deployer"]` via the OIDC token — for GitHub Actions, set
`permissions: id-token: write` and use `aws-actions/configure-aws-credentials` with
`role-to-assume`. No access keys are stored.

## Subject (`sub`) scoping

The `subjects` list is matched against the token `sub` claim with `StringLike` (wildcards allowed).
For GitHub Actions the subject looks like:

- `repo:OWNER/REPO:ref:refs/heads/main` — pushes to `main`
- `repo:OWNER/REPO:environment:prod` — the `prod` deployment environment
- `repo:OWNER/REPO:*` — any workflow in the repo (used here for simplicity)

Always scope to your own org/repo. A subject of `*` (or `repo:*`) would let **any** GitHub repo on
earth assume the role — the module rejects an empty `subjects` list to discourage this.

## Sharing the OIDC provider (important)

An AWS account can hold **only one** IAM OIDC provider per issuer URL. This module is **create-only**:
if `token.actions.githubusercontent.com` already exists in the account (created by another stack or
unit), `terraform apply` here will **collide**. Options:

1. Let a single owner create the provider and reference it elsewhere, or
2. `terraform import` the existing provider into this state.

A future revision can add an "adopt existing provider by ARN" input (rule of three) once a second
consumer actually needs to share one. Until then, assume one creator per account.

## Inputs

- `provider_url` (string) — the single issuer's OIDC URL (e.g.
  `https://token.actions.githubusercontent.com`).
- `client_id_list` (list) — accepted audiences (`aud`); defaults to `["sts.amazonaws.com"]`.
- `thumbprint_list` (list) — optional; leave empty for well-known IdPs.
- `roles` (map) — roles keyed by label: `subjects`, optional `audiences`, `managed_policy_arns`,
  `inline_policy`, `max_session_seconds`.
- `name_prefix` (string) — prefix for created role names.
- `tags` (map) — tags on all taggable resources.

## Outputs

- `provider_arn` — the OIDC provider ARN.
- `role_arns` — map of label → role ARN (feed to CI as `role-to-assume` / `AWS_ROLE_ARN`).
- `role_names` — map of label → role name.

## Test

`test/oidcfederation_test.go` applies `examples/basic` against a sandbox account, asserts the
provider and role ARNs, and destroys. Requires AWS credentials. Note: because the GitHub OIDC
provider is account-global, the test fails if that provider already exists in the account (see the
sharing caveat above).
