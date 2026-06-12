---
inclusion: always
---

# Technology Stack

## IaC

- **Terraform only.** This repo holds plain Terraform modules — **no Terragrunt**, no
  `remote_state`, and no `provider` blocks beyond `required_providers`. Composition and state are
  the consumer's responsibility (the labs repo).

## Providers

- **AWS** and **GCP**. Provider version constraints are pinned in each module's `versions.tf`.

## Versioning

- Semantic versioning via git tags: `vMAJOR.MINOR.PATCH`. See the `release-module` steering for the
  rules on what bumps which number.

## Testing

- **Terratest** (Go) under each module's `test/`. Tests apply the module's `examples/`, assert on
  outputs/real resources, and always destroy with `defer`. Apply a red/green discipline — write or
  adjust the test alongside the change.

## Docs

- **terraform-docs** generates the inputs/outputs tables in each module README. Do not hand-maintain
  those tables.

## Linting / scanning

- `terraform fmt`, `terraform validate`, **tflint**, and **tfsec** (or checkov) run on every module.

## Automation (Task)

A repo-wide `Taskfile.yml` (`version: '3'`, Task is a standalone Go binary — do not assume Make)
exposes:

- `fmt` — `terraform fmt -recursive`.
- `validate` — `terraform validate` across modules and examples.
- `lint` — tflint + tfsec/checkov.
- `docs` — regenerate module READMEs with terraform-docs.
- `test` — run Terratest (`go test ./...`), with a filter to target a single module.
- `check` — `fmt` + `validate` + `lint` + `docs`; this is the cost-free pre-commit / CI gate
  (it does **not** run `test`, which creates real resources).
