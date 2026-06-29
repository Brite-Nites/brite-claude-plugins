# Structural-lint debt list (ADR-034, BC-13213 — the BC-12700 bullet-#2 ratchet)

<!--
  MACHINE-READ by scripts/eval/eval_gate.py --structural (the ADR-034 full-surface
  structural gate). Keep the table below as the single source of truth for which
  (file, rule) pairs are grandfathered against a PROMOTED (gate-tier) structural
  rule. Schema (positional columns; rows keyed on (file, rule) — a file can be
  grandfathered for ONE rule while still gated on every other):

    | file | rule | reason | added | baseline |

  - file: the full repo-relative spec path (plugins/<p>/commands/<name>.md or
    plugins/<p>/skills/<s>/SKILL.md).
  - rule: the structural_lint rule_id (e.g. R2-body-too-long, R4-nested-refs).
  - baseline: ONLY for R2-body-too-long rows — the grandfathered body line count.
    The gate suppresses the finding only while the body line count EQUALS the
    baseline; growth past it BLOCKS, and a baseline that EXCEEDS the live body count
    is a loud PROBLEM (BC-13287 — an inflated/stale-high baseline would otherwise
    silently grant growth headroom). So the baseline only ratchets DOWN: any
    count-changing edit (up or down) to a grandfathered body must re-baseline in the
    same PR (a plain file-level exemption would mute the size rule exactly on the
    biggest files). Leave empty for every other rule.

  Self-cleaning invariants, enforced by the gate (a red --structural run):
  - STALE row: a row whose (file, rule) has no live lint finding fails the gate —
    when you fix a file, remove its row in the same PR.
  - A malformed row (bad baseline, baseline exceeding the current body count, baseline
    on a non-R2 rule, missing rule id, duplicate key) is a loud PROBLEM and never
    suppresses anything.

  This list is the PER-RULE STRUCTURAL analogue of docs/skill-eval-debt.md (which
  is command-level EVAL debt — different axis, different consumer). Rows are added
  only when a rule is promoted advisory→gate with violations that are deliberately
  grandfathered rather than cleaned (BC-12700 bullet #2: R2 keeps its 13 oversized
  bodies with baselines; R4 keeps the 8 revops upstream-subtree skills — the 9th
  R4-affected file, marketing/email-copywriting, gets CLEANED in BC-13217, not
  grandfathered. The authoritative set is whatever `--structural` reports at flip
  time, not these counts).
-->

This file is the **per-rule structural-debt grandfather record** for the ADR-028
Phase-2 advisory→blocking ratchet (BC-12700 bullet #2, mechanism per ADR-034). The
full-surface structural gate (`scripts/eval/eval_gate.py --structural` — a REQUIRED
step in the eval-gate CI job, also run by `validate.sh` §15a-bc-12590 Part 3) fails
on any gate-tier structural-lint finding **not** covered by a row below. The flip
order and per-rule policy are recorded on BC-12700; the burn-down direction is
always toward an empty table.

## Grandfathered (file, rule) pairs

| file | rule | reason | added | baseline |
|---|---|---|---|---|
| `plugins/workflows/commands/project-start.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 1081 |
| `plugins/marketing/commands/launch-campaign.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth (re-baselined 1053→1067 for BC-13863 sending-identity tagging + review/Greptile correctness hardening; 1067→1070 for BC-13864 identity-scoped sender attach, chunk 1; 1070→1075 for the review-loop verification hardening — fail-closed tag-id guard + returned-sender membership cross-check; 1075→1076 for Greptile-round-1: move the off-identity check into the reachable mismatch path) | 2026-06-14 | 1076 |
| `plugins/marketing/commands/plan-campaign.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 906 |
| `plugins/flow-architecture/commands/retrofit-project.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth (re-baselined +2 for the persona.md template seed, BC-12905 C2) | 2026-06-14 | 763 |
| `plugins/marketing/commands/tam-map.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 676 |
| `plugins/marketing/skills/tam-mapping/SKILL.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 630 |
| `plugins/marketing/commands/import-campaign.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 612 |
| `plugins/marketing/skills/email-copywriting/SKILL.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); BC-13217 cleans its R4 ref — re-baseline if body line count changes | 2026-06-14 | 611 |
| `plugins/flow-architecture/commands/start-project.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth (re-baselined +2 for the persona.md template seed, BC-12905 C2; re-baselined for the BC-14018 persona-author phase — a genuine new orchestrator phase) | 2026-06-14 | 639 |
| `plugins/cadence/commands/weekly.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 600 |
| `plugins/marketing/skills/campaign-debrief/SKILL.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 582 |
| `plugins/flow-architecture/commands/add-domain.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth (re-baselined for the BC-14018 persona-author phase — a genuine new orchestrator phase) | 2026-06-14 | 609 |
| `plugins/marketing/commands/portfolio-snapshot.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 534 |
| `plugins/revops/commands/deploy-prod.md` | R2-body-too-long | live-deploy orchestrator with `disable-model-invocation: true` + eval-waiver (ADR-028); inline bash phases cannot be split to reference files without breaking the sequential execution model; body grew with BC-12347 forceignore pre-flight | 2026-06-25 | 584 |
| `plugins/revops/commands/deploy-sandbox.md` | R2-body-too-long | live-deploy orchestrator with `disable-model-invocation: true` + eval-waiver (ADR-028); inline bash phases cannot be split to reference files without breaking the sequential execution model; body grew with BC-12347 forceignore pre-flight | 2026-06-25 | 568 |
| `plugins/revops/skills/sf-apex/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-connected-apps/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-data/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-debug/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-diagram-mermaid/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-flow/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-integration/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-lwc/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
