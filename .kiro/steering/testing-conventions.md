---
inclusion: fileMatch
fileMatchPattern: ["modules/**/test/**/*.go", "modules/**/*_test.go"]
---

# Testing Conventions (Terratest)

Module correctness is asserted with **Terratest** (Go) in each module's `test/`.

## Structure

- One test package per module under `modules/<provider>/<name>/test/`.
- Tests target the module's `examples/` (usually `examples/basic`) as the fixture — this verifies
  the module and its example together.

## Pattern

- Build `terraform.Options` pointing at the example dir; pass inputs explicitly.
- `defer terraform.Destroy(...)` immediately after `terraform.InitAndApply(...)` so resources are
  always cleaned up, even on failure.
- Assert on `terraform.Output(...)` and real provider state, not on plan text.
- Prefer table-driven cases for multiple input permutations.
- Use randomised, unique names (e.g. `random.UniqueId()`) so parallel/repeat runs don't collide.

## Discipline

- Write or adjust the test alongside the change (red/green). A change to a module's input/output
  contract requires a corresponding test change.
- Tests create real cloud resources — run them against a sandbox account. They are **not** part of
  the cost-free checks (`fmt`/`validate`/`lint`/`docs`); gate them behind `task test`.

## Running

- `task test` runs `go test ./...`. Support a filter to run a single module's tests while iterating.
