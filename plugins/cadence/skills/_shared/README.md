# Shared skills (Cadence)

This directory hosts skills consumed by multiple Cadence phases. Each skill is one primitive — shared across phases, not a phase itself.

## Planned

- **`issue-quality-gate/SKILL.md`** — 7-check quality gate (assignee, title, priority, state/cycle alignment, dependencies, AC, done-with-evidence). Authoritative spec: [`docs/designs/cadence-orchestration.md`](../../../../docs/designs/cadence-orchestration.md) § 3 (BC-5810).

  Consumers:
  - Phase 1 audit (BC-5759) — calls the gate per-issue inside the audit subagent; emits failures into the audit card under `quality_gate_flags`.
  - Phase 2 scope (BC-5760) — calls the gate on every scope-in candidate; blocks scope-in on any failure unless per-check override with reason.

  Overrides flow into the Phase 4 narrative (BC-5762) under a `> **Known gaps this cycle**` callout footnote.

This scaffold issue (BC-5758) does not implement the skill body. The skill lands with BC-5759 or BC-5760 — whichever phase issue executes first.
