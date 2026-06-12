---
inclusion: fileMatch
fileMatchPattern: ["modules/**/*.tf", "**/examples/**/*.tf"]
---

# Module Authoring Conventions

Applies when editing Terraform in this repo. A module's `variables.tf` (inputs) and `outputs.tf`
(outputs) are its **public API** — design them deliberately.

## Inputs (variables.tf)

- Every variable has `type` and `description`.
- Required inputs have **no** default. Optional inputs have sensible defaults.
- Use `validation` blocks to reject misuse early (CIDR shape, allowed enum values, …).
- Accept environment-specific values (region, account, names, CIDRs, tags) as inputs — never hardcode.
- Provide a `tags` (AWS) / `labels` (GCP) input and apply it to every taggable resource.

## Outputs (outputs.tf)

- Export every identifier a consumer would need to wire this module to another (IDs, ARNs, names,
  endpoints). Missing outputs force consumers to fork the module — avoid that.
- Mark sensitive outputs `sensitive = true`.

## versions.tf

- Pin `required_version` (Terraform) and `required_providers` with pessimistic constraints
  (`~>`), not unbounded ones.

## Purity

- No `provider`, `backend`, or `remote_state` blocks.
- No `data` lookups that assume a particular account/region unless those are parameterised.
- A module must be usable by any lab in any account/region purely by changing inputs.

## Examples

- Keep at least one runnable example under `examples/basic/` that a consumer (and the test) can apply
  as-is. Examples configure the provider/region; modules do not.

## Docs

- After changing inputs or outputs, regenerate the README tables with `task docs` (terraform-docs).
  Do not edit the generated tables by hand.
