# Structural-lint debt list (ADR-033, BC-13213 — the BC-12700 bullet-#2 ratchet)

<!--
  MACHINE-READ by scripts/eval/eval_gate.py --structural (the ADR-033 full-surface
  structural gate). Keep the table below as the single source of truth for which
  (file, rule) pairs are grandfathered against a PROMOTED (gate-tier) structural
  rule. Schema (positional columns; rows keyed on (file, rule) — a file can be
  grandfathered for ONE rule while still gated on every other):

    | file | rule | reason | added | baseline |

  - file: the full repo-relative spec path (plugins/<p>/commands/<name>.md or
    plugins/<p>/skills/<s>/SKILL.md).
  - rule: the structural_lint rule_id (e.g. R2-body-too-long, R4-nested-refs).
  - baseline: ONLY for R2-body-too-long rows — the grandfathered body line count.
    The gate suppresses the finding only while the body stays <= baseline; growth
    past it BLOCKS (a plain file-level exemption would mute the size rule exactly
    on the biggest files). Leave empty for every other rule.

  Self-cleaning invariants, enforced by the gate (a red --structural run):
  - STALE row: a row whose (file, rule) has no live lint finding fails the gate —
    when you fix a file, remove its row in the same PR.
  - A malformed row (bad baseline, baseline on a non-R2 rule, missing rule id,
    duplicate key) is a loud PROBLEM and never suppresses anything.

  This list is the PER-RULE STRUCTURAL analogue of docs/skill-eval-debt.md (which
  is command-level EVAL debt — different axis, different consumer). Rows are added
  only when a rule is promoted advisory→gate with violations that are deliberately
  grandfathered rather than cleaned (BC-12700 bullet #2: R2 keeps its 13 oversized
  bodies with baselines; R4 keeps the 8 revops upstream-subtree skills).
-->

This file is the **per-rule structural-debt grandfather record** for the ADR-028
Phase-2 advisory→blocking ratchet (BC-12700 bullet #2, mechanism per ADR-033). The
full-surface structural gate (`scripts/eval/eval_gate.py --structural` — a REQUIRED
step in the eval-gate CI job, also run by `validate.sh` §15a-bc-12590 Part 3) fails
on any gate-tier structural-lint finding **not** covered by a row below. The flip
order and per-rule policy are recorded on BC-12700; the burn-down direction is
always toward an empty table.

## Grandfathered (file, rule) pairs

| file | rule | reason | added | baseline |
|---|---|---|---|---|
