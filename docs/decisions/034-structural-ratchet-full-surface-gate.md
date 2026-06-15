# 034. Full-surface structural gate + per-rule structural-debt list (ADR-028 Phase-2 ratchet wiring)

**Status:** Accepted
**Date:** 2026-06-10
**Linear:** [BC-13213](https://linear.app/brite-nites/issue/BC-13213) (ratchet 1/5, the mechanism PR) under [BC-12700](https://linear.app/brite-nites/issue/BC-12700) bullet #2
**Amended:** 2026-06-15 ([BC-13287](https://linear.app/brite-nites/issue/BC-13287)) — R2 baseline suppression tightened `≤` → `==`: an inflated baseline that *exceeds* the live body count is now a loud PROBLEM (it would otherwise silently grant growth headroom). See the **Baseline** bullet under Decision § 2.
**Related ADRs:** [ADR-028](028-skill-engineering-discipline.md) (the discipline this enforces; D1 commits the advisory→blocking promotion), [ADR-007](007-revops-plugin-design.md) (augment-not-replace — why the revops subtree gets grandfathered rather than restructured)

> **ADR numbering:** claimed as 033 per CDR-025 (at claim time 029 was taken on `main` + open PR #401, 030+031 by open PR #398, 032 by open PR #432) — then **lost the 033 race to PR #475** (`033-fda-journey-frontmatter-canon.md`, opened inside the claim-to-PR window) and renumbered to **034** pre-merge. Caught by the `cross-pr-adr-guard` advisory CI job — its first live catch, working exactly as designed (BC-12698).

## Context

ADR-028 D1 committed Phase 2: backfill behavioral evals (done — BC-12700 bullet #1, grandfathered → 0) **and promote the advisory structural rules to blocking**. The rules live in `scripts/eval/structural_lint.py` (R2 body-size, R3 first-person description, R4 nested refs, R5 unqualified MCP names, R6 hardcoded paths); `severity == "gate"` is the tier `eval_gate.py` consumes as build-failing. BC-12700 locked a **per-rule, one-at-a-time ratchet**: each rule flips only after its surface is clean or grandfathered.

Wiring the flips through the existing enforcement surface alone doesn't work. The only REQUIRED CI check is the eval-gate job's **diff-gate**, which gates the changed `plugins/*/commands/*.md` set. Measured at flip time (`origin/main` @ `19ff8794`): every live R4, R5, and R6 violation is in a `SKILL.md` — invisible to the diff-gate. Worse, R4 (nested refs) is **graph-shaped**: a violation on a SKILL.md can be *introduced by editing a bundled reference file* (refA gains a link to refB) with no spec file in the diff at all. And there was no grandfather mechanism for structural findings — `docs/skill-eval-debt.md` is command-level *eval* debt, a different axis.

## Decision

1. **A full-surface structural gate**: `eval_gate.py --structural`, a diff-free mode that lints the whole commands+skills surface (`structural_lint.scan_surface`) and **fails on any `severity == "gate"` finding not covered by a structural-debt row**. It runs as a **second step in the existing REQUIRED eval-gate CI job** (so "eval_gate is the gate of record" stays a single check) and as `validate.sh` §15a-bc-12590 Part 3 (diff-free → shallow-checkout-safe, giving local feedback). The per-changed-command diff-gate (R1 + the eval precedence ladder) is untouched.
2. **A per-rule structural-debt list**: `docs/structural-lint-debt.md`, machine-read, rows keyed **`(file, rule)`** — a file can be grandfathered for one rule while still gated on every other. Schema `| file | rule | reason | added | baseline |`.
   - **Baseline** (R2-body-too-long rows only): pins the grandfathered body line count. The gate suppresses only while the body line count **equals** the baseline; growth past it blocks, and a baseline that **exceeds** the live body count is a loud PROBLEM (BC-13287) — an inflated or stale-high baseline would otherwise silently grant growth headroom up to the inflated value, the same unbounded-growth failure mode a *missing* baseline would. A baseline therefore only ratchets **down**: any count-changing edit (up or down) to a grandfathered body must re-baseline in the same PR. This tiles with the staleness invariant below — a body trimmed but still ≥ 500 raises the inflated-baseline PROBLEM (*lower the baseline*); a body trimmed below 500 drops its R2 finding entirely and raises the stale-row PROBLEM (*remove the row*) — no gap, no overlap. A plain file-level exemption would mute the size rule precisely on the biggest files — the rule's core failure mode.
   - **Staleness invariant**: a row whose `(file, rule)` has no live lint finding fails the gate — fixing a file forces removing its row in the same PR, so the list can only shrink toward empty.
   - **Malformed rows are loud**: a non-integer baseline, a baseline that exceeds the current body count (BC-13287), a baseline on a non-R2 rule, a missing rule id, or a duplicate key is a PROBLEM (gate red) and never suppresses — degenerate input must not silently become an exemption.
3. **A rule's promotion is then literally its severity constant** (`SEV_ADVISORY → SEV_GATE`) plus lockstep self-test/fixture updates — the gate reads `severity` only, zero re-detection. Flip order locked on BC-12700: R3 → R5 → R6 → R2 → R4.

## Consequences

- Once a rule flips, **no new violation of it can merge anywhere** (commands or skills), and grandfathered R2 files cannot grow. Untouched-file violations of *unflipped* rules stay WARN-only as before.
- A full-surface gate punishes the PR that *trips* it, which in a merge race may not be the PR that *introduced* the finding. Accepted: surfaces are clean at flip time, the scan is deterministic and stdlib-only (~1s), and the fix is local either way.
- R1 gate findings are now also enforced full-surface (previously changed-set only). Behavioral delta is nil today (0 full-surface gate findings) and R1 is file-local — a violation requires editing the file, which the diff-gate already catches; the full-surface pass only adds merge-race coverage.
- Two debt lists coexist by design: `docs/skill-eval-debt.md` (command-level eval debt, `--check`) and `docs/structural-lint-debt.md` (per-rule structural debt, `--structural`). Different axes, different invariants; merging them would couple unrelated burn-downs.
- `validate.sh` §15a-bc-12588's lint surfacing stays WARN-only for advisory-tier findings; its gate-tier tag wording changed from "advisory this slice" to "blocking via eval-gate".

## Alternatives considered

| Alternative | Rejected because |
|---|---|
| Extend the diff-gate's changed-set to SKILL.md | Still blind to R4-via-reference-edit regressions; keeps the touch-a-file cliff (editing `sf-flow/SKILL.md` would demand fixing its 17 pre-existing R4 findings at once) |
| Commands-only enforcement (no new wiring) | At flip time, 50 of the 63 advisory findings (all of R4/R5/R6) live in skills — "promoted to blocking" would be hollow |
| Blocking via `validate.sh` only | The `validate` CI check is advisory in branch protection; only the eval-gate job is REQUIRED — a gate that doesn't gate |
| File-level (rule-less) debt rows | A row would mute *every* rule on a file; `(file, rule)` keeps each rule's ratchet independent |
| R2 rows without a baseline | A grandfathered 1081-line body could grow unbounded while exempt — the exact failure mode R2 exists to stop |
