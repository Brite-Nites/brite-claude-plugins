# Orchestrator Checkpoint Pattern

Pointer document — the orchestrator breadcrumb schema is locked in canonical memory and MUST NOT be re-derived here. This file names the schema, points at the line range, and lists the per-skill state extensions that follow the Q31 amendment pattern.

Cribbed from compound-engineering's `ce-optimize` per Q30.2.

## Canonical schema

The base schema for `.flow-phase-state.json` is locked at **`docs/design-rationale/project_fda_plugin_interview.md` lines 300-314** (Q31 sub-decisions 1-7). The file format is JSON, written to `docs/plans/.flow-phase-state.json` per Q12 lock. The companion `.flow/config.json` (committed, per-project) is described in the same lock entry.

Do NOT re-define the schema in this file. Read the lock entry directly.

Required fields named in Q31.1 (memory:302): `version`, `mode`, `status`, `run_started_at`, `last_updated`, `current_phase`, `completed_phases[]`, `in_flight_artifacts[]`, `domains[]` (with per-domain entries), `overrides[]` (gate-override audit), `config_snapshot`.

## Per-skill state extensions

Per-skill run-state is added to the Q31.1 schema via amendment-with-audit-trail, NOT inline in the consuming skill's lock. Schema-evolution discipline established per user lock 2026-05-07 (memory:321). Two amendments are locked today:

- **Amendment 1 — `office_hours_state`** at `docs/design-rationale/project_fda_plugin_interview.md` line 318. Present when `mode = greenfield | retrofit` AND phase 2 (`office-hours`) is in_flight. Captures the L1 interview state and L1 review results across resumes. Full schema is defined in Q42 lock entry sub-decision 6 — cited there, not duplicated here.
- **Amendment 2 — `linear_writeback_state`** at line 323. Present when any Q46 consumer has written within run lifetime. Persists across runs until Q31.3 stale discard, for cross-run audit and idempotency. Full schema is defined in Q46 lock entry sub-decisions 3 + 5 — cited there, not duplicated here. See `linear-writeback-pattern.md` for the consumer-facing contract.

Future amendments (e.g., Q44 `retro_state`, Q53 `ship_state`) follow the same precedent: each Q-lock that needs run-state adds a slot here + an amendment note in Q31's lock entry. Cost: more ceremony per skill. Benefit: Q31 stays canonical; no schema sprawl across multiple Q-locks.

## Write-then-verify

Every breadcrumb write goes through `scripts/flow-resume-breadcrumb.sh` per Q31.5: write to `<path>.tmp` → atomic `mv` → `cat` → `python3 -c 'import json,sys; json.loads(sys.stdin.read())'` parse-verify → content-match check. Atomic rename guarantees no partial-write corruption (POSIX-guaranteed atomic on same filesystem).

## Stale breadcrumb policy

Per Q31.3 (memory:306), three conditions trigger an offer-discard `AskUserQuestion` at orchestrator entry: `last_updated > 7 days` ago; `status == "completed"`; `status == "abandoned"`. Options presented: **Discard breadcrumb + start fresh** (Recommended) / **Force-resume** (override) / **Cancel**.

## Concurrency

No locking in v1. Documented caveat in plugin CLAUDE.md (Q55): do not run multiple FDA orchestrators in parallel against the same project. PID-file lock at `.flow-phase-state.json.lock` is a v1.1 parking-lot candidate; promote only if a real collision occurs.

## References

- Q31 base schema — `docs/design-rationale/project_fda_plugin_interview.md` lines 300-314.
- Q31 amendment 1 (`office_hours_state`) — line 318.
- Q31 amendment 2 (`linear_writeback_state`) — line 323.
- Q12 — path lock at `docs/plans/.flow-phase-state.json`.
- Q7 — orchestrator-as-skill pattern (cribbed from `ce-optimize`).
- Q30.2 — file location lock at `skills/_shared/checkpoint-pattern.md` (line 281).
- Schema-evolution discipline — memory:321 (precedent established 2026-05-07).
