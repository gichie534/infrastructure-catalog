---
inclusion: always
---

# Product Overview — Terraform Modules Library

This repository is the **reusable, versioned Terraform module library** for the cloud-engineering
labs. It is the single source of reusable infrastructure; the separate **labs repo** consumes these
modules to build self-contained practice examples.

## Goals

- **Reusable** — each module solves one infrastructure concern well and is consumed by many labs.
- **Versioned** — modules are released via semantic git tags (`vMAJOR.MINOR.PATCH`); consumers pin
  an exact tag.
- **Pure / low coupling** — modules contain **no environment, account, or region knowledge** and no
  remote-state or provider configuration. Those belong to the consumer (the labs repo).
- **Tested** — module behaviour is asserted with Terratest before release.

## Relationship to the labs repo

- Labs reference modules by pinned ref:
  `git::https://github.com/<github-org>/<modules-repo>.git//modules/aws/vpc?ref=v1.2.0`.
- A change here is only adopted by a lab when that lab bumps the `?ref=` tag — so breaking changes
  never silently reach consumers.

## Engineering principle

A module is a contract: its **input variables** and **output values** are the public API. High
cohesion inside, low coupling outside. Treat any change to that contract as an API change
(see the `release-module` steering).

> Replace `<github-org>` and `<modules-repo>` with the real values for this workspace.
