---
inclusion: manual
---

# Playbook: Release / version a module

Invoke with `#release-module` (or the `/release-module` slash command). Modules are consumed by
**pinned git tag**, so versioning is the contract that protects every lab.

## Semantic versioning rules (vMAJOR.MINOR.PATCH)

- **MAJOR** — a breaking change to the public contract: removing or renaming an input or output,
  adding a new **required** input, or changing a default in a way that alters existing infra.
- **MINOR** — backward-compatible additions: new optional inputs (with defaults), new outputs,
  new opt-in behaviour.
- **PATCH** — fixes that don't change the contract: bug fixes, internal refactors, doc/test changes.

## Steps

1. Confirm `task check` and `task test` are green.
2. Decide the bump using the rules above. When unsure whether a change is breaking, ask: "would an
   existing consumer's `plan` change unexpectedly, or fail?" If yes → MAJOR.
3. Update `CHANGELOG.md`: new version, a short consumer-facing summary of what changed, and
   migration notes for any MAJOR bump.
4. Tag and push:
   - Repo-wide tag: `git tag v<X.Y.Z> && git push --tags`.
   - For per-module versioning, use a namespaced tag instead: `aws-vpc/v<X.Y.Z>`.
5. Notify the relevant labs that they can bump their `?ref=` to the new tag. Never expect a lab to
   pick up changes without a tag bump.

## Acceptance criteria

- Checks and tests passed before tagging.
- `CHANGELOG.md` updated; tag pushed.
- Breaking changes released as a MAJOR bump with migration notes.
