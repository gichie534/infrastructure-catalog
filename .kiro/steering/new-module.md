---
inclusion: manual
---

# Playbook: Create a new module from scratch

Invoke with `#new-module` (or the `/new-module` slash command). If the provider and module name
aren't given, ask. Follow the `structure`, `module-conventions`, and `testing-conventions` steering.

## 1. Scaffold

Create `modules/<provider>/<name>/`:

```
main.tf
variables.tf
outputs.tf
versions.tf
README.md
examples/basic/main.tf
test/<name>_test.go
```

## 2. Define the contract first

- In `variables.tf`, declare inputs with `type`, `description`, validation, and defaults
  (required inputs have no default). Accept all environment-specific values as inputs.
- In `outputs.tf`, export every identifier a consumer will need downstream.

## 3. Implement

- Write `main.tf` using only the inputs — no hardcoded region/account, no provider/backend/state.
- Pin `required_version` and `required_providers` in `versions.tf`.

## 4. Example

- Write `examples/basic/main.tf` that configures a provider/region and calls the module with minimal
  inputs. It must `terraform apply` cleanly on its own.

## 5. Test

- Add a Terratest in `test/` that applies `examples/basic`, asserts on outputs, and destroys via
  `defer` (see `testing-conventions`).

## 6. Docs & gate

- `task docs` to generate the README inputs/outputs tables.
- `task check` (fmt + validate + lint + docs) must pass.
- `task test` against a sandbox account must pass.

## 7. How consumers use it

- Labs reference it as
  `git::https://github.com/<github-org>/<modules-repo>.git//modules/<provider>/<name>?ref=vX.Y.Z`.
  It becomes consumable once released (see `release-module`).

## Acceptance criteria

- Module is pure (no env/account/region/provider/state baked in).
- Inputs and outputs form a complete, documented contract.
- The example applies; the Terratest passes; `task check` is green.
