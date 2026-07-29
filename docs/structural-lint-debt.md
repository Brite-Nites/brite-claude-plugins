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
| `plugins/marketing/commands/launch-campaign.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth (re-baselined 1053→1067 for BC-13863 sending-identity tagging + review/Greptile correctness hardening; 1067→1070 for BC-13864 identity-scoped sender attach, chunk 1; 1070→1075 for the review-loop verification hardening — fail-closed tag-id guard + returned-sender membership cross-check; 1075→1076 for Greptile-round-1: move the off-identity check into the reachable mismatch path; 1076→1096 for BC-13864 sender-match mode selection — the `--sender-match` flag + IV-12 validator + Phase 7 four-mode operator prompt, fail-closed on not-yet-wired modes; 1096→1103 for BC-13864 `all` mode — uniform full-pool enumeration, count-only verify, mode-aware step-7/metadata/forbidden-patterns + an explicit numbered-Steps mode guard for the not-yet-wired esp/both; 1103→1150 for BC-13864 per-bucket `esp`/`both` modes — runtime Google/Outlook tag resolution, the three-way Google/Microsoft/SMTP filter mapping, per-cell enumerate/verify/zero-pool, per-cell render/gate/execute/verify/metadata, and the generalized invariant + forbidden patterns; 1150→1161 for BC-13864 empty-cell handling — `both`→identity fallback + `esp` surface-at-gate-7, the inline provisional note, and the sender_match_fallbacks/sender_unsent_cells metadata; 1161→1163 for BC-13864 `--no-host-lookup` restriction — IV-12 rejects `esp`/`both` there at pre-flight + the Phase 7 prompt offers only identity/all; 1163→1167 for BC-13864 review-loop fixes — P1 both-fallback pool overwrite so steps 6/7/8 reference the effective pool, plus excluded_tag_ids fail-closed, esp_tag_ids resume re-resolve, per-bucket zero floor, skip-unsent-cells, sender_ids_attached/sender_verify_mode schema docs, Phase-5 ref qualifiers; 1167→1188 for BC-14044 input-email duplicate handling — Phase 1 input-list dedup + deliverability filter (+ gate-1 differing-duplicate conflict display / verbal keep-override), Phase 4 step-7d workspace-collision recovery (gate 4b, never-silent resubmit) + collision-aware step-9 count, and the consolidated skipped-contacts writer; 1188→1223 for BC-17214 salesforce-preload phase — the personal-only Phase 1b (invoke the `salesforce-preload` skill on the cleaned set, instance resolution + idempotent-resume + surviving-set hand-off), the Phase-2 step-4c `sf_preload_held` skipped-writer hook, and the `salesforce_preload` metadata-schema field + docs; +durable surviving_csv_path artifact that Phases 2/4 read + `--preview`→skill `--dry-run` guard, Greptile #550; 1223→1240 for BC-17334 shared column-mapper swap — Phase 1 step 1 now resolves the CSV header through `_shared/column_map.py` (BC-17213) with this command's own required set layered over the mapper's pre-load requiredness, Phase 2 step 2 de-positionalizes the `awk` email field via `resolved_columns`, Phase 4 step 2 builds the lead body from `resolved_columns` instead of literal column names, Phase 10 Mode 1 renders the preview through the same map, plus the `resolved_columns` metadata-schema field; 1240→1241 for the Greptile round — route Phase 1 step 2a dedup through the resolved email column and make step 10 actually persist `resolved_columns` with a re-resolve fallback for pre-BC-17334 breadcrumbs; 1241→1251 for the quoted-field fix — Phase 1 header parse + Phase 2 domain extract now use Python's `csv` reader addressing columns by resolved name, replacing `head -1` and the `awk -F','` split that silently corrupted every field after a quoted comma like `Stone Ridge, LLC` in a company column, plus a quoted-field rule banning naive delimiter splits across the command) | 2026-06-14 | 1251 |
| `plugins/marketing/commands/plan-campaign.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 906 |
| `plugins/flow-architecture/commands/retrofit-project.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth (re-baselined +2 for the persona.md template seed, BC-12905 C2; re-baselined for the persona-author phase — a genuine new orchestrator phase, mirroring BC-14018; re-baselined 806→856 for the BC-16783 pre-commit hook-wiring step — a genuine new scaffold behavior) | 2026-06-14 | 856 |
| `plugins/marketing/commands/tam-map.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 676 |
| `plugins/marketing/skills/tam-mapping/SKILL.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 630 |
| `plugins/marketing/commands/import-campaign.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 612 |
| `plugins/marketing/skills/email-copywriting/SKILL.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); BC-13217 cleans its R4 ref — re-baseline if body line count changes | 2026-06-14 | 611 |
| `plugins/flow-architecture/commands/start-project.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth (re-baselined +2 for the persona.md template seed, BC-12905 C2; re-baselined for the BC-14018 persona-author phase — a genuine new orchestrator phase; re-baselined 639→689 for the BC-16783 pre-commit hook-wiring step — a genuine new scaffold behavior) | 2026-06-14 | 689 |
| `plugins/cadence/commands/weekly.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 600 |
| `plugins/marketing/skills/campaign-debrief/SKILL.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 582 |
| `plugins/flow-architecture/commands/add-domain.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth (re-baselined for the BC-14018 persona-author phase — a genuine new orchestrator phase) | 2026-06-14 | 609 |
| `plugins/marketing/commands/portfolio-snapshot.md` | R2-body-too-long | oversized body grandfathered per BC-12700 (ratchet 4/5); baseline pins growth | 2026-06-14 | 534 |
| `plugins/revops/commands/deploy-prod.md` | R2-body-too-long | live-deploy orchestrator with `disable-model-invocation: true` + eval-waiver (ADR-028); inline bash phases cannot be split to reference files without breaking the sequential execution model; body grew with BC-12347 forceignore pre-flight; re-baselined 584→582 for BC-16872 (pr-diff arg-builder → portable bash+zsh array form, net −2 lines) | 2026-06-25 | 582 |
| `plugins/revops/commands/deploy-sandbox.md` | R2-body-too-long | live-deploy orchestrator with `disable-model-invocation: true` + eval-waiver (ADR-028); inline bash phases cannot be split to reference files without breaking the sequential execution model; body grew with BC-12347 forceignore pre-flight | 2026-06-25 | 568 |
| `plugins/revops/skills/sf-apex/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-connected-apps/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-data/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-debug/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-diagram-mermaid/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-flow/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-integration/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/revops/skills/sf-lwc/SKILL.md` | R4-nested-refs | revops upstream subtree (ADR-007 augment-not-replace) — restructuring the reference tree = drift; grandfathered per BC-12700 (ratchet 5/5) | 2026-06-14 |  |
| `plugins/cadence/commands/weekly.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/flow-architecture/commands/add-domain.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/flow-architecture/commands/add-sub-flow.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/flow-architecture/commands/deprecate-legacy.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/flow-architecture/commands/office-hours.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/flow-architecture/commands/retrofit-project.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/flow-architecture/commands/review.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/flow-architecture/commands/session-start.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/flow-architecture/commands/ship.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/flow-architecture/commands/start-project.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/workflows/commands/retrospective.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/workflows/commands/review.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/workflows/commands/scope.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/workflows/commands/session-start.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/workflows/commands/ship.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
| `plugins/workflows/commands/sprint-planning.md` | R8-allowed-tools-required | genuine orchestrator MCP invocation, grandfathered forward-only when R8 graduated to the command surface (BC-16865); triaged as a real invocation, not a subagent tool-spec — adding `allowed-tools` here is a per-plugin least-privilege pass with a version bump, tracked separately | 2026-07-29 |  |
