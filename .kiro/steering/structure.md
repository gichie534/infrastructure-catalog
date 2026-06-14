---
inclusion: always
---

# Project Structure

## Repository layout

```
<modules-repo>/
  Taskfile.yml
  .terraform-version
  CHANGELOG.md
  modules/
    aws/
      vpc/
      eks-cluster/
      serverless-api/
    gcp/
      vpc/
      gke-cluster/
    _shared/                 # cross-provider helpers/conventions (optional)
  .github/workflows/         # fmt, validate, tflint, trivy, terraform-docs, test
```

## Module layout (every module is identical)

```
modules/<provider>/<name>/
  main.tf
  variables.tf               # the input half of the public contract
  outputs.tf                 # the output half of the public contract
  versions.tf                # required_version + required_providers (pinned)
  README.md                  # header prose + terraform-docs-generated tables
  examples/
    basic/                   # minimal runnable example (doubles as a test fixture)
  test/
    <name>_test.go           # Terratest
```

## Naming

- Module folders: lowercase, hyphenated, named for the concern (`eks-cluster`, not `aws-eks-1`).
- Variables: `snake_case`, descriptive; booleans read as predicates (`enable_flow_logs`).
- Outputs: expose everything a consumer realistically needs to wire downstream (IDs, ARNs, names).

## Rules

- **No environment/account/region values** baked into a module — accept them as variables.
- **No `provider` / `backend` / `remote_state` config** in modules.
- Every input has a `description`; constrain with `type` and `validation` where it prevents misuse.
- Optional inputs have sensible defaults; required inputs have no default.
- Keep modules single-purpose. If a module does two unrelated things, split it.

> Replace `<modules-repo>` with the real repository name for this workspace.
