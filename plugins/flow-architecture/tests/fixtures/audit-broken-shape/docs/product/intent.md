---
project: audit-clean-shape-fixture
linear_project_id: 00000000-0000-0000-0000-000000000000
linear_team_key: BC
status: shipped
last_reviewed: 2026-05-10
owner: fixture-author
---

# Project intent — audit-clean-shape

Synthetic fixture project for BC-7059 `/flow:audit` smoke test. Represents a successful retrofit project at end-of-Phase-8 (all artifacts present and consistent).

## Mission

Provide a deterministic, clean FDA shape for `/flow:audit` regression testing.

## Problem we're solving

`/flow:audit` regressions can silently corrupt every ship workflow because the command is auto-invoked from `/flow:ship` and `/flow:plan-{discipline}`. Without a fixture, there is nothing to test against.

## Target users

The `/flow:audit` runner; future v1.1 headless-runner promotion candidates.

## Success criteria

A bash smoke test running against this fixture asserts all deterministic Phase B gates pass — would yield `/flow:audit` exit 0.

## Out of scope

Phase C Linear-MCP gates (no Linear access from CI); Phase A `verify-docs.sh` deep coverage (the fixture's stub verifier returns 0).

## Constraints

Bash 3.2 compatibility (macOS default). Stdlib python3 only. No PyYAML.

## L1 review summary

- **CEO** — HOLD_SCOPE: synthetic fixture is purpose-built and minimal; no scope adjustments.
- **Design** — HOLD_SCOPE: no UI surface.
- **Eng** — HOLD_SCOPE: filesystem-only contract; deterministic.
- **DevEx** — HOLD_SCOPE: reusable for v1.1 headless-runner promotion.
