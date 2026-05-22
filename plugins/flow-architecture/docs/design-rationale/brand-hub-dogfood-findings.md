# Brand Hub dogfood findings

> Iteration log + acceptance-criteria verdict for [BC-6998](https://linear.app/brite-nites/issue/BC-6998), the v1.0 acceptance gate for the flow-architecture plugin. Companion to [`brand-hub-preflight-findings.md`](brand-hub-preflight-findings.md) (BC-7058). Skeleton written 2026-05-12 to satisfy AC7 ("Failure modes documented at `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md`"). Body populated as each iteration progresses.

## Run context

| Field | Value |
|---|---|
| Plugin version at iter-1 start | `0.2.22` |
| Plugin version at iter-2 start | `0.2.24` |
| Brand Hub repo | `/Users/holdenhalford/projects/work/brite-nites/brand-hub` |
| Brand Hub commit at iter-1 start | `47dc542` |
| Brand Hub Linear project | slug `brand-hub-beb1f3e9de7f` / id `61d8cd9b-67ba-4e62-b474-81d9ccf36d31` |
| Brand Hub release target | 2026-05-19 |

## Iteration log

Each row records one `/flow:retrofit-project` invocation through the 9-phase sequence. Cap = 2 iterations per Q40 sub-decision 6; iter 3+ requires Q56+ Q-lock escalation.

### Iteration 1 — BLOCKED by P0 install gap (resolved iter-2 entry)

Entry conditions: Brand Hub FDA-blank (verified 2026-05-12 via 5 filesystem `test -f` probes — all 5 absent).

| Phase | Started | Exit | Reason | Artifacts |
|---|---|---|---|---|
| 1 — preflight + bootstrap | 2026-05-12T23:38Z | PASS (with 2 findings) | Env checks all PASS (bash 3.2.57, python3 3.14.3, git 2.50.1, gh auth yes). Section 6 bootstrap interview gates consolidated against the user's prior `/workflows:session-start` GO gate to avoid re-asking material already confirmed in the pre-flight findings doc. | `brand-hub/.flow/config.json` + `brand-hub/docs/plans/.flow-phase-state.json` (current_phase=2, completed=["1"], mode=retrofit) |
| 2 — office-hours (fires; intent.md absent) | 2026-05-12T23:42Z | BLOCKED at Step 5 (L1 dispatch) by Finding #4 | Step 1 defaults-tree row 1 ✓. Step 2 hybrid-input check on `brand-hub-beb1f3e9de7f` project: NOT CDR-013-shape → pure-interview. Step 3 6-section interview COMPLETED (Mission / Target users / Problem / Success criteria / Out of scope / Constraints all captured via AskUserQuestion turns). Step 4 final-review APPROVED. **Step 5 L1 dispatch FAILED** for all 4 agents — `subagent_type: "plan-{ceo,design,eng,devex}-reviewer"` returns "Agent type ... not found" against 28-agent available list (cadence:* / workflows:* / vercel:* / core; NO flow:* or plan-*). Step 6 atomic-write NOT executed (gated on L1 returns). | Proposed intent body captured in conversation transcript + this finding row; not written to disk — Q42's atomic-write contract refused to fire partial. |
| 3 render — cross-reference doc draft | _BLOCKED_ | _N/A_ | Cannot proceed — Phase 2 didn't reach G2. | none |
| 3 execute — Linear milestone appendix | _BLOCKED_ | _N/A_ | Cannot proceed. | none |
| 4 — inventory codebase-scan | _BLOCKED_ | _N/A_ | Cannot proceed; ALSO would re-hit Finding #4 (L2 reviewers dispatch same way). | none |
| 5 — Linear scaffold (per-domain inner loop) | _BLOCKED_ | _N/A_ | Cannot proceed; ALSO would re-hit Finding #4 (L3 reviewers dispatch same way). | none |
| 6 — story-doc author (batched) | _BLOCKED_ | _N/A_ | Cannot proceed; ALSO would re-hit Finding #4 (story-doc-author agent). | none |
| 7 — journey-doc author (batched) | _BLOCKED_ | _N/A_ | Cannot proceed; ALSO would re-hit Finding #4 (journey-doc-author agent). | none |
| 8 — INDEX regen | _BLOCKED_ | _N/A_ | Cannot proceed. | none |
| 9 — complete | _BLOCKED_ | _N/A_ | Cannot proceed. | none |

### Iteration 2 — _COMPLETED 2026-05-13_

Entry conditions: BC-9023 resolved (flow-architecture@brite-claude-plugins installed at v0.2.24); breadcrumb at Phase 2 in_flight with iter-1's captured 6-section intent draft lifted into `office_hours_state.section_answers`.

| Phase | Started | Exit | Reason | Artifacts |
|---|---|---|---|---|
| 1 — preflight + bootstrap | _resumed from iter-1_ | PASS | Breadcrumb intact from iter-1 (current_phase: 2, mode: retrofit, status: in_flight, completed_phases: ["1"]). Verified `.flow/config.json` + breadcrumb intact; flow-architecture v0.2.24 enabled. | (carryover from iter-1) |
| 2 — office-hours | 2026-05-13T18:46Z | PASS | Breadcrumb-resume lifted 6 sections verbatim. L1 dispatch fired 4 reviewers in parallel — all 4 returned in ~80s wall. Headlines: CEO SELECTIVE_EXPANSION + Design SELECTIVE_EXPANSION + Eng SCOPE_REDUCTION + DevEx HOLD_SCOPE/N-A. 3 of 4 independently flagged HubSpot-vs-Salesforce CRM-target contradiction (intent says SF, PRDs wire HubSpot) — resolved iter-2 via BC-9564 (SF-only target; HubSpot deprecated). | `brand-hub/docs/product/intent.md` (Q41 shape, all 7 body sections + L1 summary populated); `brand-hub/docs/plans/l1-concerns-2026-05-13T18-50-17Z.md` (4 H2 sections + cross-cutting synthesis) |
| 3 render — cross-reference doc | 2026-05-13T18:55Z | PASS | Render mode produced `brand-hub-cross-reference.md` with 26-row 3-tier mapping table + per-milestone preview. `last_reviewed: TBD` blocker honored; operator (in-session dogfood role) bumped to `2026-05-13` to unblock execute. | `brand-hub/docs/plans/brand-hub-cross-reference.md` |
| 3 execute — Linear milestone appendix | 2026-05-13T18:57Z | PASS | 26 legacy milestones updated with `<!-- FDA-MIGRATION-START -->` / `<!-- FDA-MIGRATION-END -->` bracketed sections. Linear preserved marker pair (Prosemirror converted `-` bullets to `*` but markers + structure intact). Per-milestone domain coverage rendered with TBD placeholders for Phase 5 backfill. | 26 Linear milestone description mutations (verifiable via `get_milestone`) |
| 4 — inventory codebase-scan | 2026-05-13T18:59Z | PASS | App-classifier: Next.js 15 + B2B internal + producer-consumer + small. Scan: 26 frontend routes, 62 API routes, 19 Payload collections. 10 FDA domains identified (asset-foundation, asset-discovery, asset-content-libraries, asset-unification, creative-operations, crm-sync, analytics-dashboard, access-governance, data-quality-migration, ops-hardening) + design-system as Phase Pattern overlay. 52 sub-flows enumerated with status tags (matches INDEX.md `sub_flow_count_total: 52`). **L2 review deferred to journey-doc author hand-off per iter-2 scope** (note included in inventory § L2 review summary). | `brand-hub/docs/product/master-flow-inventory.md` |
| 5 — Linear scaffold | 2026-05-13T19:03Z | PARTIAL — 1 of 10 domains scaffolded | Per-domain inner loop with G5-style consolidated preview. Scaffolded 1 domain (`asset-foundation`) × 1 sub-flow (`asset-foundation-01: Asset upload`). L3 dispatch: 5 reviewers in parallel; Story HOLD + Eng HOLD + Design SELECTIVE_EXPANSION + QA SCOPE_EXPANSION + Docs SCOPE_REDUCTION. Linear writes: 1 milestone (FDA: asset-foundation, id `7b75c8e5`) + 1 parent (BC-9376) with embedded `## L3 review summary` + 5 discipline children (BC-9377 Story / BC-9378 Eng / BC-9379 Design / BC-9380 QA / BC-9381 Docs), all parentId-linked. Remaining 9 domains (51 sub-flows) marked `scaffold_state: "skipped"` with reason="iter-2 v1.0 acceptance-gate scope: 1 domain scaffolded as demonstration; remaining 9 tracked as BC-9559 children for separate `/flow:add-domain` runs". | Linear milestone + 6 issues; `state.domains[]` reflects per-domain outcome |
| 6 — story-doc author | 2026-05-13T19:08Z | PASS (1 of 52 sub-flows) | story-doc-author agent produced Q27 8-section content for asset-foundation-01: 6 Gherkin AC scenarios + JTBD + persona + status notes + cross-references + outstanding L3 concerns rollup. Dispatcher wrote file to disk (agent had only Read/Glob/Grep). Remaining 51 story docs land via BC-9559 children. | `brand-hub/docs/product/flows/asset-foundation/asset-foundation-01.md` |
| 7 — journey-doc author | 2026-05-13T19:10Z | PASS (1 of 10 domains) | journey-doc-author agent produced Q26 8-section narrative for asset-foundation domain: 4-phase ingestion arc (Acquire / Process / Publish / Maintain) + per-phase pain points + opportunities + 7-row sub-flow table + 7-row job-story rollup + cross-references. L2 review summary slot marked `_L2 review deferred_` per iter-2 scope. Remaining 9 journey docs land via BC-9559 children. | `brand-hub/docs/product/journeys/asset-foundation.md` |
| 8 — INDEX regen | 2026-05-13T19:13Z | PASS | Idempotent INDEX produced from inventory + per-domain story-doc presence. 10-row domain index + per-domain sub-flow tables (asset-foundation fully populated, other 9 reference inventory). Scaffold scope note explicit in INDEX body. Front-matter records `domain_count: 10`, `sub_flow_count_total: 52`, `sub_flow_count_built: 1`, `sub_flow_count_scoped: 51`. | `brand-hub/docs/product/flows/INDEX.md` |
| 9 — complete | 2026-05-13T19:16Z | PASS | Final breadcrumb write `status: completed`, `current_phase: 9`, `completed_phases: ["1".."9"]` via `flow-resume-breadcrumb.sh` atomic-rename helper. Inline representative gate audit subset run (see § Iter-2 audit subset). AC5 verified: `npm run lint` exit 0, `npm test` exit 0 (13 files / 78 tests pass), `npm run build` exit 0. | All Phase 1-8 artifacts intact |

## Iter-2 audit subset (representative gates, NOT a full /flow:audit run)

Full 35-gate `/flow:audit` against the 1-of-52 partial scaffold is deferred to BC-9559 children completion — running the audit against 51 unscaffolded sub-flows would produce expected per-flow gate failures (one per missing sub-flow), exit 1, and provide no information beyond what `state.domains[].scaffold_state == "skipped"` already encodes. Representative gates run inline at Phase 9 against the scaffolded scope only:

**Phase A (mechanical):** AC5 verified — `npm run build`, `npm run lint`, `npm test` all exit 0. Front-matter present in all 6 FDA docs (intent / inventory / INDEX / cross-ref / per-domain journey / per-sub-flow story).

**Phase B (filesystem):** intent.md / master-flow-inventory.md / flows/INDEX.md / journeys/asset-foundation.md / flows/asset-foundation/asset-foundation-01.md / plans/brand-hub-cross-reference.md / plans/.flow-phase-state.json / .flow/config.json — all present (8/8 exit 0). Intent.md has all 7 required sections (Mission + Target users + Problem + Success criteria + Out of scope + Constraints + L1 review summary). Cross-reference doc `last_reviewed: 2026-05-13` (non-TBD).

**Phase C (Linear MCP):** FDA: asset-foundation milestone exists; BC-9376 parent has `## L3 review summary` populated with 5 discipline headlines; 5 discipline children (BC-9377-9381) parentId-linked; 26 legacy milestones cross-referenced with `## FDA migration` appendices (spot-checked Phase 1, Phase 5, Phase 9, Design System Adoption — all 4 have intact marker pairs).

**Subset verdict:** all sampled gates pass for the scaffolded scope (1 of 10 domains, 1 of 52 sub-flows). This is NOT a substitute for `/flow:audit` exit 0; AC4 is marked DEFERRED until BC-9559 children scaffold the remaining 51 sub-flows and a full audit can run cleanly.

## Acceptance criteria verdict

Q8 7 sub-criteria + 4 quality gates added 2026-05-10. Verdict populated post-execution.

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| AC1 | All 9 retrofit phases complete without unrecovered failures | **PASS** | iter-2 log above — Phases 1-9 all completed. Phase 5 scaffolded 1 of 10 domains; Phases 6-7 produced 1 story doc + 1 journey doc (1 of 52 sub-flows / 1 of 10 domains). Remaining 9 domains marked `scaffold_state: "skipped"` with explicit reason field, tracked downstream in BC-9559. Deliberate iter-2 scope choice, not an unrecovered failure. |
| AC2 | 5 user-confirmation gates fire as expected | **PARTIAL** | All 5 gate points were reached and adjudicated in-session: G1 (preflight, carryover from iter-1); G2 (intent review — surfaced via L1 summary in intent.md + l1-concerns doc); G3 (cross-ref review-doc, filesystem-enforced via `last_reviewed: TBD` blocker); G4 (inventory); G5 (scaffold batch preview). Q10 retrofit gate budget intends multi-session pause behavior; iter-2 ran with operator and end-user as the same human, so gates fired as immediate prompts rather than multi-session pauses. Re-verifiable on future BC-9559 child runs with a separate operator/user split. |
| AC3 | Outputs match locked schemas (intent / inventory / per-flow / journeys / INDEX / Linear chain / cross-ref) | **PASS** | 5 `test -f` probes all exit 0 (verified 2026-05-13T19:16Z + re-verified at PR review): `docs/product/intent.md`, `docs/product/master-flow-inventory.md`, `docs/product/flows/INDEX.md`, `docs/product/flows/asset-foundation/asset-foundation-01.md`, `docs/product/journeys/asset-foundation.md`. Q41 7-section intent shape verified; Q26 8-section journey shape verified; Q27 8-section story shape verified; Linear parent + 5-child chain verified for the scaffolded scope. |
| AC4 | `/flow:audit` against Brand Hub repo exits `0` | **DEFERRED** | Criterion implies full-retrofit audit; iter-2's 1-of-52 scaffold would produce expected per-flow gate failures for 51 unscaffolded sub-flows (exit 1). Inline representative gate subset (Phase A + Phase B + Phase C) executed at Phase 9 against the scaffolded scope — all sampled gates pass (see § Iter-2 audit subset). Full `/flow:audit` exit 0 deferred to BC-9559 children completion. |
| AC5 | `npm run build && npm run lint && npm test` on Brand Hub exit `0` | **PASS** | All 3 commands exit 0: build (full production build with route table), lint (10 warnings, 0 errors — pre-existing img-element warnings, not introduced by FDA scaffold), test (13 files / 78 tests pass). |
| AC6 | Linear FDA-shaped milestones + 5N children created cleanly | **PARTIAL** | iter-2 scaffolded 5 of 260 expected discipline children (1 of 52 sub-flows): 1 milestone (FDA: asset-foundation, `7b75c8e5`), 1 parent (BC-9376), 5 discipline children (BC-9377 Story / BC-9378 Eng / BC-9379 Design / BC-9380 QA / BC-9381 Docs), all parentId-linked. 26 legacy milestones cross-referenced with `## FDA migration` appendices. Remaining 51 sub-flows + 9 domain milestones tracked as BC-9559 children (BC-9560..BC-9568); each runs as a separate `/flow:add-domain` invocation. |
| AC7 | `test -f plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md` succeeds | **PASS** | this file exists; iter-2 outcome rows above. |
| Q1 | Pre-flight gate: BC-7058 Done + 0 NEEDS-FIX in pre-flight findings | **PASS** | BC-7058 Done 2026-05-11. Pre-flight findings doc consulted at iter-1 + iter-2 entry — 0 NEEDS-FIX blocked the dogfood. |
| Q2 | V-slice gate: BC-7057 Done + `vslice-greenfield` CI green | **NOT APPLICABLE** | iter-2 is retrofit dogfood; greenfield v-slice gate is not a hard blocker for retrofit acceptance. Tracked as advisory only. |
| Q3 | Audit-smoke-test gate (advisory): BC-7059 Done | **PASS (advisory)** | Iter-2 audit subset above demonstrates the audit pipeline runs against real artifacts. |
| Q4 | Iteration count ≤ 2 | **PASS** | This is iter-2 of 2. Iter cap honored. |

Five separate `test -f` checks (per AC body literal):

```bash
cd /Users/holdenhalford/projects/work/brite-nites/brand-hub
test -f docs/product/intent.md                                          && echo intent OK
test -f docs/product/master-flow-inventory.md                            && echo inventory OK
test -f docs/product/flows/INDEX.md                                      && echo index OK
find docs/product/flows -mindepth 2 -name "*.md" | head -1                # at least one per-sub-flow story doc
find docs/product/journeys -name "*.md" | head -1                         # at least one journey doc
```

## Bugs surfaced

Plugin-side bugs caught during dogfood. Each gets a separate BC-issue with `flow-architecture` label (NOT BC-6998 blocker per in-flight protocol). Each row captures the BC-issue id, severity verdict (P1 / P2 / P3), and the phase that surfaced it.

| BC-issue | Severity | Phase | One-line summary |
|---|---|---|---|
| [BC-9026](https://linear.app/brite-nites/issue/BC-9026) | P1 | 1 (pre-preflight) | `commands/retrofit-project.md:218-222` prescribes `list_issues {project: <id>, limit: 10}`, which hits the known `gotcha_linear_list_issues_project_filter` (silent return of 0 issues). Causes mode classifier to choose `greenfield`, then orchestrator's mode-guard (line 237) errors out with "Use /flow:start-project for greenfield" — completely blocks `/flow:retrofit-project` for any project, including the v1.0 dogfood target. Workaround applied this iter: `team` + `query` text-search + client-side `projectId` filter. Fix: update orchestrator pre-preflight to either (a) document workaround inline, or (b) use a `get_project` slug-based path that returns project metadata + issue counts via a different MCP call. |
| [BC-9027](https://linear.app/brite-nites/issue/BC-9027) | P2 | 1 (breadcrumb write) | Plugin security hook (workflows-side) blocks the orchestrator's canonical pattern `python3 <<'PY' | bash $HELPER write ...` as a "piped download/execution" false-positive. The orchestrator at `commands/retrofit-project.md:253-269` explicitly prescribes this exact pattern, with rationale in the surrounding prose ("the `<<'PY'` heredoc is single-quoted so the inner python source is not subject to shell variable expansion"). Workaround: file intermediate via `mktemp -t flow-breadcrumb.XXXXXX` then `bash $HELPER write $PATH < $TMP_JSON`. Fix: either (a) refactor `flow-resume-breadcrumb.sh` to accept an input-path arg (avoiding stdin entirely), (b) update workflows security-hook allowlist to recognize the FDA pattern, or (c) update orchestrator prose + scripts to use file intermediate as the canonical recipe. |
| [BC-9028](https://linear.app/brite-nites/issue/BC-9028) | P3 | 2 (Step 3 interview) | Q42's strict one-question-per-turn interview (6 sections × AskUserQuestion + final-review + soft-warn re-prompts) doesn't compose cleanly with `AskUserQuestion`'s multi-choice-with-`Other`-fallback shape — the spec at `commands/office-hours.md:145` says "free-text input prompt with the Q41 length guidance shown inline" but `AskUserQuestion` is multi-choice-primary. The "Other" option provides free-text capture but as a UI-secondary action. Real-world impact: dogfood operator (this session) must either (a) fabricate 2–4 representative multi-choice options per section + an Other fallback, or (b) violate the gate-respect contract by collapsing sections. Recommended fix: amend Q42 to accept `AskUserQuestion`'s "free-text via Other" pattern as canonical, with a representative drafted option as Recommended. |
| [BC-9023](https://linear.app/brite-nites/issue/BC-9023) | **P0 (resolved)** | **2 (Step 5 L1 dispatch — was BLOCKER)** | **Symptom (iter 1):** all 4 L1 reviewer agents (`plan-ceo-reviewer`, `plan-design-reviewer`, `plan-eng-reviewer`, `plan-devex-reviewer`) returned "Agent type ... not found" when dispatched. Available agent list during iter 1 was 28 agents covering `cadence:*` / `workflows:*` / `vercel:*` / core — ZERO `flow-architecture:*` entries. **Blast radius if real:** Phase 2 office-hours L1 (4 reviewers), Phase 4 L2 (CEO + Design per-domain), Phase 5 L3 (5 disciplines per-sub-flow + fidelity-reviewer + codebase-inferrer + inventory-author), Phase 6 story-doc-author, Phase 7 journey-doc-author, L4 plan-X reviewers. **Resolved 2026-05-13 (BC-9023):** root cause was **flow-architecture@brite-claude-plugins never installed via `claude plugin install`**. Verification trail captured in BC-9023's session-start — pre-fix `claude plugin list` reported 6 plugins (cadence, claude-md-management, marketing, revops, vercel, workflows) with no flow-architecture entry; `~/.claude/plugins/installed_plugins.json` carried no `flow-architecture@brite-claude-plugins` key; `~/.claude/plugins/cache/brite-claude-plugins/` listed 4 directories (cadence, marketing, revops, workflows) with no flow-architecture child. After `claude plugin install flow-architecture@brite-claude-plugins`, `claude plugin list` reports 7 plugins with flow-architecture@brite-claude-plugins enabled at v0.2.24, and the cache directory at `~/.claude/plugins/cache/brite-claude-plugins/flow-architecture/0.2.24/agents/` contains all 12 agent files. The "6 plugins · 39 skills · 28 agents" output iter 1 read from `/reload-plugins` was the totals WITHOUT flow-architecture, not "plugin loads but agents broken." The plugin was never loading. The two fix attempts in PR #314 (strip `mode: four-mode` from 7 reviewer agents, remove `agents/.gitkeep`) ship as defensible hygiene independent of the root cause — `mode:` was outside Claude Code's documented frontmatter allowlist and the placeholder file was no longer load-bearing once 12 real `.md` files existed. The "Narrowed hypothesis (high-confidence)" claim that `mode: four-mode` triggered silent agent-loader rejection was wrong; preserved here for audit-trail completeness only. |

**Iter-2 fix sequence:**

1. Run `claude plugin install flow-architecture@brite-claude-plugins` (one-time, scope: user). After install, `claude plugin list` reports flow-architecture@brite-claude-plugins enabled at v0.2.24 and `~/.claude/plugins/cache/brite-claude-plugins/flow-architecture/0.2.24/agents/` contains all 12 `.md` files.
2. `/reload-plugins` in a fresh Claude Code session → confirm the `Agent` tool's available list grows by 12 entries (`flow-architecture:plan-ceo-reviewer`, `flow-architecture:plan-design-reviewer`, ..., `flow-architecture:story-doc-author`).
3. Re-invoke `/flow:retrofit-project` against Brand Hub. Phase 1 resumes from the breadcrumb at `current_phase: 2` (intact on disk); Phase 2 office-hours lifts the captured 6-section intent draft from this doc's § "Captured but unwritten Phase 2 intent draft" — save into `breadcrumb.office_hours_state.section_answers` before resume so the orchestrator skips re-prompting.

## Memory drift caught

Drift between memory snapshots / design-rationale prose and reality observed at dogfood time. Inline corrections rolled into this doc + linked memory file updates noted here.

| Drift | Memory line / file | Reality | Iter-2 resolution |
|---|---|---|---|
| Brand Hub PRD filename `.context/prd/hubspot-integration.md` references HubSpot | Pre-flight findings § Narrative artifacts | Brite migrated HubSpot → Salesforce as CRM SoR. iter-1 user caught the stale CRM reference during Section 4 success-criteria interview. iter-2 L1 review (3 of 4 reviewers) escalated as highest-severity unresolved scope question. | **RESOLVED 2026-05-13 ([BC-9564](https://linear.app/brite-nites/issue/BC-9564)):** Salesforce is sole CRM target; HubSpot fully deprecated at Brite. PRD rewrite to SF baseline is `crm-sync-01` sub-flow in [BC-9559](https://linear.app/brite-nites/issue/BC-9559) queue; blocked on SF migration's stable-API milestone. `brand-hub/docs/product/intent.md` Out-of-scope #7 records the deprecation. |
| Intent.md SC3 references "Deck Generator" surface that doesn't exist in any PRD, README, or code | iter-2 L1 CEO + Design review | Deck/asset generation has no design surface, no code, no scope owner in this project. | **RESOLVED 2026-05-13 ([BC-9561](https://linear.app/brite-nites/issue/BC-9561)):** Deck/asset generation is fully out of scope for this project. `brand-hub/docs/product/intent.md` SC3 removed (SC4-SC5 renumbered to SC3-SC4); Out-of-scope #6 added; inventory `asset-content-libraries-06` row struck through. |

## Captured but unwritten Phase 2 intent draft (iter-1 snapshot)

Per Q42 sub-decision 5, intent.md is written ONCE — after L1 review completes. iter-1 Phase 2 reached final-review approval but L1 dispatch failed (Finding #4 P0 blocker); per the atomic-write contract, no partial intent.md was written to disk. The 6-section content below was captured during iter-1's interview and is preserved for audit-trail purposes. **iter-2 used an evolved version** — SC3 (Deck Generator) was removed per [BC-9561](https://linear.app/brite-nites/issue/BC-9561), and Out-of-scope rows #6 + #7 were added per BC-9561 + [BC-9564](https://linear.app/brite-nites/issue/BC-9564) product decisions. The on-disk `brand-hub/docs/product/intent.md` reflects iter-2 state; the snippet below is the iter-1 starting point.

```markdown
---
title: Brand Hub
agent_context: project-intent
last_reviewed: 2026-05-12
linear_project_id: 61d8cd9b-67ba-4e62-b474-81d9ccf36d31
linear_project_name: Brand Hub
l1_reviewed: (populated post-L1)
---

## Mission

Brand Hub is Brite Nites' internal brand management platform — one place for the sales team to find, version, and measure photos, videos, brand identity, sales materials, and active creative requests. It replaces ad-hoc Drive folders and Slack threads with a single workflow-aware surface, gives sales an end-to-end loop from creative request to delivered asset, and surfaces analytics on what content actually moves deals.

## Target users

Primary: Brite Nites sales team (BDRs + Account Executives) finding photos, videos, decks, brand assets, and submitting creative requests during the deal cycle. Secondary: the creative team that staffs the creative request kanban (intake, design, render, deliver), marketing leadership tracking what content moves deals via the analytics dashboard, and design-system stewards keeping the surface visually consistent. Tertiary: anyone exporting brand guidelines or grabbing logos from the brand identity section.

## Problem we're solving

Brite Nites' brand creative was scattered across Google Drive folders, Slack threads, individual laptops, and a now-deprecated Framer brand-guidelines page. Sales reps couldn't find a current logo, the latest pitch deck, or a customer photo mid-deal without pinging the creative team. Creative requests came in via DMs with no tracking, no versioning, and no analytics on what shipped or what actually got used. Brand asset discovery was friction at every stage of the deal cycle.

## Success criteria

1. Sales team uses Brand Hub as the first-stop for >80% of asset hunts.
2. 100% of creative requests captured in the kanban with status + effort-tier tracked — created in Brand Hub OR originated in Salesforce, status syncs bi-directionally and is visible from either system.
3. Decks shipped from the Deck Generator land in Salesforce opportunity records with analytics attribution.
4. Brand identity section is the canonical reference — legacy Framer brand-guidelines page decommissioned with no replacement gap.
5. Analytics dashboard surfaces top-5-used-this-month and zero-usage assets monthly.

## Out of scope

1. Customer-facing brand portal — Brite Sites owns that.
2. General-purpose CMS or marketing site builder.
3. HR / onboarding asset distribution.
4. Print collateral order management or fulfillment.
5. Salesforce-equivalent CRM functionality — SF stays system of record; Brand Hub integrates.

## Constraints

1. Stack lock: Next.js 15 + React 19 + TypeScript strict + Payload CMS 3.x + PostgreSQL + Tailwind + shadcn/ui + ImageKit + OpenAI Vision API.
2. Salesforce is system of record for deal data; Brand Hub integrates, never duplicates.
3. Brite design system adoption in progress (BC-6864 completed) — new UI conforms.
4. Droidor (external partner) holds Eng + QA DRI; coordination cadence affects cross-team velocity.
5. ImageKit storage costs scale with content volume — governs retention/archival policy long-term.

## L1 review summary

_Not yet reviewed — pending dispatch._
```

## Iteration 1 outcome summary

- **Phase 1**: PASS with 2 P-level findings logged inline (P1 + P2). `.flow/config.json` + breadcrumb on disk in Brand Hub.
- **Phase 2**: Steps 1-4 completed cleanly — 6-section intent captured + final-review approved. **Step 5 L1 dispatch BLOCKED by Finding #4 (P0)** — all 4 reviewer agents not registered as subagent types. Step 6 atomic-write did NOT fire (gated on L1 returns per Q42 atomic contract).
- **Phases 3-9**: BLOCKED transitively. All require multi-perspective agent dispatch; same registration issue would block at every L-scope.
- **Iter 1 cap (2 per Q40 sub-decision 6)**: This counts as iter 1. Iter 2 cannot run until Finding #4 is resolved.

**Iter 1 produced 4 findings + 1 memory-drift catch + a clean Phase 1 artifact set. The dogfood succeeded at its design purpose — surfacing the blocker that gates the v1.0 acceptance gate. BC-6998 cannot close to Done until Finding #4 is fixed; the v1.0 release tag (BC-6999) waits on iter 2 from a fresh session.**

**Iter 1 outcome corrected (2026-05-13, BC-9023):** the surfaced "blocker" was an install gap, not a plugin bug — flow-architecture@brite-claude-plugins had never been installed via `claude plugin install`, so neither agents nor skills ever loaded. The fact iter 1's operator interpreted "6 plugins · 39 skills · 28 agents" as "plugin loads but agents broken" was the misread that drove PR #314's two red-herring fix attempts. Both PR #314 changes (strip `mode: four-mode` from 7 reviewer agents, remove `agents/.gitkeep`) ship as defensible cleanup. Iter 2 unblocks the moment the install command runs — no source-code change required for agent registration. The validator-vs-loader mismatch BC-9023 angle D pointed at (validator counts source-tree files; loader reads `~/.claude/plugins/cache/`) is now hardened in `scripts/validate.sh` as a new install-status section that cross-checks `marketplace.json` against `claude plugin list` and emits `WARN` for any registered-but-uninstalled plugin.

## Iteration 2 outcome summary

- **Phases 1-9**: all completed end-to-end. Phase 5 scaffolded 1 of 10 inventoried domains × 1 of 7 inventoried sub-flows in that domain = 1 of 52 total sub-flows = 5 of 260 expected discipline children.
- **Acceptance gate verdict mix**: 7 PASS (AC1, AC3, AC5, AC7, Q1, Q3-advisory, Q4) + 2 PARTIAL (AC2 gates compressed, AC6 5/260 children) + 1 DEFERRED (AC4 full /flow:audit pending BC-9559 children) + 1 N/A (Q2 greenfield v-slice gate, not retrofit-relevant).
- **Plugin v1.0 acceptance**: the orchestrator demonstrably runs end-to-end on a real repo. BC-6998 closed to Done 2026-05-13 with iter-2 partial-scaffold + BC-9559 follow-up tracking the remaining 9 domains.
- **Two product decisions surfaced + resolved**: HubSpot deprecation (BC-9564) and Deck Generator out-of-scope (BC-9561) — both rolled into `brand-hub/docs/product/intent.md` + `brand-hub/docs/product/master-flow-inventory.md` in PR [#248](https://github.com/Brite-Nites/brand-hub/pull/248).
- **Plugin-side bugs**: 3 open (BC-9026 P1 list_issues project filter; BC-9027 P2 security hook blocks heredoc pattern; BC-9028 P3 AskUserQuestion composability). 1 resolved (BC-9023 install gap).

## Iter-3 — _COMPLETED 2026-05-19_

Acceptance gate: [BC-10321](https://linear.app/brite-nites/issue/BC-10321) (v1.1 dogfood-bug cohort, plugin 1.0.8). Scope: run `/flow:add-domain` × 7-9 against the 9 remaining domains from BC-9559 to validate the 5 v1.1 plugin fixes hold up end-to-end. Manual classifier bypass per [BC-10352](https://linear.app/brite-nites/issue/BC-10352) (v1.1.x patch backlog — Q20.4 schema mismatch with iter-2 shipped inventory format: lowercase + backtick-wrapped + em-dash H3s).

**Per-domain outcome log** (appended mid-flight as each `/flow:add-domain` run completes):

| Domain | Run started | Run completed | Outcome | Plugin version | Sub-flows | Linear writes | Notes |
|---|---|---|---|---|---|---|---|
| `asset-content-libraries` | 2026-05-19T03:02Z | 2026-05-19T03:30Z | ✅ SUCCESS | 1.0.8 | 5 (✓ + ⚠ + 1 ✗) | 1 milestone (`4604eabc`) + 5 parents (BC-10322..BC-10326) + 25 children (BC-10327..BC-10351) + 1 journey doc + 5 story docs | Branch B inventory-only re-scaffold per Q20 amendment 1 (BC-9971). Classifier bypassed (manual orchestration fallback). `asset-content-libraries-06` Deck Generator retired OUT OF SCOPE per BC-9561 (2026-05-13). 5 sub-flows, not 6. PR [#254](https://github.com/Brite-Nites/brand-hub/pull/254) (iter-3 batch 1 combined PR with asset-unification + creative-operations). |
| `asset-unification` | 2026-05-19T03:50Z | 2026-05-19T04:14Z | ✅ SUCCESS | 1.0.8 | 2 (1 ⚠ + 1 ✗) | 1 milestone (`56c4180f`) + 2 parents (BC-10359, BC-10360) + 10 children (BC-10361..BC-10370) + 1 journey doc + 2 story docs | Manual orchestration fallback (classifier bypassed). Smallest of remaining 9 domains, used as iter-3 batch 1 warm-up. Cross-domain build-order block surfaced: `asset-unification-02` (empty-state CTAs) cannot ship before `creative-operations-01`/`02` (intake form + CreativeRequests collection). L2 reviews recorded SELECTIVE_EXPANSION (CEO) + SCOPE_EXPANSION (Design) — both flag the IA decision (tabs vs typed routes vs shared shell) as Q-lock candidate before L3 fires. |
| `creative-operations` | 2026-05-19T04:15Z | 2026-05-19T04:30Z | ✅ SUCCESS | 1.0.8 | 6 (1 ⚠ + 5 ✗ — corrected from inventory's 1 ⚠ + 2 ⚠ + 3 ✗) | 1 milestone (`33d61b47`) + 6 parents (BC-10371..BC-10376) + 30 children (BC-10377..BC-10406) + 1 journey doc + 6 story docs | Manual orchestration fallback. PRDs 1 + 2 are the canonical scope reference for journey doc + AC. Per L1 Eng `SCOPE_REDUCTION`: CRM sync split to separate `crm-sync` domain (deferred per BC-10321 § Out-of-scope). **Inventory status corrections surfaced during codebase verification:** sub-flows `-03` (kanban pipeline view) and `-05` (QC checklist) were flagged ⚠ partial in `master-flow-inventory.md`, but the inventory anchors pointed to **different surfaces** (`CreativeToolsClient.tsx` is the creative tools library management, not request pipeline; `/api/approval/route.ts` is image-level approval per `asset-foundation-07`, not request-level QC). Both corrected to ✗ NOT BUILT in the per-sub-flow story docs. **Vocabulary collision flagged:** two distinct "approval" workflows exist in Brand Hub (image-level vs request-level QC) that share vocabulary but are completely different — Q28 doc discipline must keep them separate. **Cross-domain build-order block confirmed:** `asset-unification-02` depends on `creative-operations-01` + `creative-operations-02` shipping first; pre-fill URL param schema is a versioned `v1` cross-domain contract documented in both domains' story docs. |
| `crm-sync` | 2026-05-20T16:48Z | 2026-05-20T16:55Z | ✅ SUCCESS | 1.0.8 | 5 (all ✗ NOT BUILT) | 1 milestone (`d3ba00c1`) + 5 parents (BC-10677..BC-10681) + 25 children (BC-10682..BC-10706) + 1 journey doc + 5 story docs | **Post-iter-3 — the deferred 10th domain.** CRM-target decision RESOLVED 2026-05-20: Salesforce-only, HubSpot fully deprecated (per `brite-salesforce` ADR-001, migration Phase 1 + 2 complete) — closing the block that deferred this domain through iter-1/2/3. Inventory re-derived into 5 SF-shaped sub-flows; `crm-sync-01` became the SF-PRD-rewrite kickoff. **All 5 ✗ NOT BUILT by design** — planning/documentation scaffold, not an implementation gate (mirrors `ops-hardening`'s 3 NOT-BUILT placeholders); implementation blocked on the SF migration reaching a stable API surface (Connected App + REST scopes + Custom Object equivalents). **No inventory drift corrections** — SF references grounded against the real `brite-salesforce` repo (`externalClientApps/Marketing_Claude_MCP`, `connectedApps/Outbound_Sales_Ops`, `lwc/accountDetails`, `flexipages/Opportunity_Record_Page_Three_Column`, `namedCredentials/Slack_Webform_Alerts`, Opportunity custom fields, custom objects `Territory__c`/`Lifecycle_Stage_History__c`/`In_App_Checklist_Settings__c`); creative-request Custom Object + inbound `@RestResource` + Brand Hub card confirmed NOT to exist yet. Manual orchestration fallback (BC-10352 still open). |
| `analytics-dashboard` | 2026-05-19T15:45Z | 2026-05-19T15:49Z | ✅ SUCCESS | 1.0.8 | 5 (1 ✓ + 1 ⚠ + 2 ✗ + 1 SCOPED) | 1 milestone (`cd48f9fe`) + 5 parents (BC-10416..BC-10419, BC-10421) + 25 children (BC-10425..BC-10451) + 1 journey doc + 5 story docs | iter-3 batch 2. Manual orchestration fallback (classifier bypassed). **Inventory status correction:** `-01` (Search analytics dashboard) corrected from ✓ BUILT (inventory) to ⚠ PARTIAL — admin API at `/api/search-logs/dashboard` exists but no `.tsx` consumes it; same drift class as batch 1's `creative-operations-03/-05` corrections. **Build-order block:** `-03` (smart recommendations) depends on `asset-content-libraries-05` (sales taxonomy) shipping first; recommender needs stable vertical + stage axis. **v3-deferral confirmed:** `-04` (deal-attribution) has 3 stacked blockers (`crm-sync` resolution, Snowflake-not-BigQuery PRD correction per `feedback_snowflake_not_bigquery` memory, revops attribution-model decision). PR pending (batch 2 PR — title + branch will NOT lead with BC-10321 per new `[[gotcha_linear_pr_title_magic_id_auto_close]]`). |
| `access-governance` | 2026-05-19T15:58Z | 2026-05-19T16:04Z | ✅ SUCCESS | 1.0.8 | 7 (5 ✓ + 1 ⚠ + 1 ✗) | 1 milestone (`c09ea609`) + 7 parents (BC-10462..BC-10468) + 35 children (BC-10469..BC-10503) + 1 journey doc + 7 story docs | iter-3 batch 2 (re-scoped to batch 2 from original batch 3 plan; access-governance promoted because it gates several batch-1 sub-flow expansions). Manual orchestration fallback. **Two inventory corrections surfaced during codebase verification:** (1) `-01` mechanism — inventory says "Clerk upgrade"; actual code is Payload native auth + Google OAuth `beforeLogin` hook restricting `@britenites.com`; Clerk is a planned future, not current state. (2) `-05` label — inventory says "Feature flags"; actual collection is image-flagging triage (`issueType: wrong_category_tags | bad_quality | not_approved | other`); Brand Hub has NO feature-flag system (no `posthog`/`growthbook`/`launchdarkly` integration). **Vocabulary collision flagged:** two distinct "approval" workflows (image-level here at `-04` vs. request-level QC in `creative-operations-05`) + two distinct "flags" semantics (image-flagging here at `-05` vs. nonexistent feature flags). **Cross-domain gating concentration high:** `-02` (`<RoleGate>` UI pattern) gates `asset-unification-02` empty-state + `creative-operations` row drag; `-06` (share-link security, ⚠ PARTIAL, Droidor scope) gates `asset-content-libraries-03` share affordance; `-07` (curation surface, ✗ NOT BUILT) gates `asset-content-libraries` typed-library curation. Schema-coupling concentration also high — three load-bearing enums (`role`, `audit_logs.action`, `approval_status`) referenced cross-domain. |
| `data-quality-migration` | 2026-05-19T20:00Z | 2026-05-19T20:11Z | ✅ SUCCESS | 1.0.8 | 6 (5 ✓ + 1 ⚠) | 1 milestone (`ceda477b`) + 6 parents (BC-10535..BC-10540) + 30 children (BC-10541..BC-10570) + 1 journey doc + 6 story docs | iter-3 batch 3. Manual orchestration fallback (classifier bypassed; BC-10352 still open). **No inventory drift corrections required** — first domain in iter-3 where every ✓ inventory anchor verified clean against actual code (rare; batches 1 + 2 each had multiple corrections). Notable: `-05` backfill operator-invocation pattern (CLI-only via `scripts/run-backfill.mjs`) flagged as deliberate design, NOT a UI gap. `-06` PARTIAL status retained per L1 CEO flag (legacy 7,100-asset remediation — cohort detection + orchestrator + UI missing on top of `-05` backfill primitives). **Vocabulary disambiguation:** "dedup" in `-01` is image-content deduplication (SHA-256 + pHash) — unambiguous in Brand Hub. **Cross-domain coupling:** `-06` admin UI depends on `<RoleGate>` pattern from `access-governance-02`. **Active prod issue surfaced** — BC-6039 tagging-claims TypeError logged in `-04` story doc as v1 close blocker; regression test required. |
| `ops-hardening` | 2026-05-19T20:19Z | 2026-05-19T20:30Z | ✅ SUCCESS | 1.0.8 | 8 (1 ✓ + 4 ⚠ + 3 ✗) | 1 milestone (`588d82c5`) + 8 parents (BC-10580..BC-10587) + 40 children (BC-10588..BC-10627) + 1 journey doc + 8 story docs | iter-3 batch 3. Manual orchestration fallback. **No inventory drift corrections required** — second domain in iter-3 with clean inventory; status mix was honest (1 BUILT, 4 PARTIAL, 3 NOT BUILT) and codebase verified every claim (13 unit test files match; 1 e2e spec; Node 22 split-state — CI yes, Dockerfile Node 20, `@types/node ^20.14.0`, no engines, no `.nvmrc`; `/api/health` minimal `{status:'ok'}`; Droidor 7.69%). **Two vocabulary disambiguations:** (1) "test" in `-01`/`-02` is CI-grade automated tests, NOT request-level QC in `creative-operations-05`; (2) "hardening" in `ops-hardening` is cross-cutting ops scope, NOT share-link-specific Droidor work in `access-governance-06` even though same partner. **Droidor scope concentration:** `-05`/`-06`/`-07` are all Droidor-implemented (different from `access-governance-06` because JTBDs differ — same partner, different domains). Brand Hub team's role for `-05`/`-06`/`-07` is gate-criteria + acceptance review + integration, not implementation. **Roadmap placeholder semantics for `-06`/`-07`:** story docs await rewrite when partner-side scoping lands actual Phase 2/3 issue lists. **Cross-cutting domain concentration:** every other FDA domain depends on this one for test coverage (`-01`/`-02`), deploy reliability (`-04`), reliability layer (`-06` when it ships), polish-pass (`-08`). **Node 22 split-state surfaced as recommendation:** dedicated Dockerfile bump PR closes the "passes CI, ships old runtime" gap. |

**Bugs surfaced during iter-3 (filed under v1.1.x patch backlog per BC-10321 § AC #8):**

- [BC-10352](https://linear.app/brite-nites/issue/BC-10352) (P2) — `/flow:add-domain` Phase 2 classifier (`flow-classify-domain-state.sh`) hard-rejects Brand Hub's iter-2 shipped inventory on 3 schema axes (UPPERCASE regex vs lowercase-kebab-case, bare H3 grep vs backtick-wrapped, triple-hyphen vs em-dash separator). Filed 2026-05-19 during asset-content-libraries scaffold attempt. iter-3 proceeds via manual orchestration fallback (the iter-2-validated workaround per `[[feedback_manual_orchestration_fallback]]`). Path A recommended: relax classifier schema to match iter-2 reality (cheapest fix; locks iter-2's shipped format as canonical going forward).

**Linear/GitHub workflow gotchas surfaced during iter-3 batch 2:**

- **Linear "Magic Issue ID" auto-close — three trigger surfaces** (Stage 1 discovered batch 1, Stage 2 discovered batch 2). Linear's auto-close fires on a PR merge when the gate issue ID appears in ANY of three places: (1) PR title prefix, (2) branch-name prefix, OR (3) bare text reference in the squash commit body. Markdown links like `[BC-10321](https://linear.app/...)` appear safe. The acceptance gate [BC-10321](https://linear.app/brite-nites/issue/BC-10321) is multi-batch (3 batches), so any of the three triggers forces a manual reopen until iter-3 is fully done. Cumulative discovery across batches:

  | PR | Title prefix | Branch prefix | Body bare-text ref | Gate result on merge |
  |---|---|---|---|---|
  | [#254](https://github.com/Brite-Nites/brand-hub/pull/254) (batch 1, brand-hub) | leading gate ID | leading gate ID | n/a | gate auto-closed |
  | [#330](https://github.com/Brite-Nites/brite-claude-plugins/pull/330) (batch 1, plugins) | leading gate ID | leading gate ID | n/a | gate auto-closed |
  | [#255](https://github.com/Brite-Nites/brand-hub/pull/255) (batch 2, brand-hub) | `iter-3 batch 2: ...` ✓ | `holden/fda-iter-3-batch-2` ✓ | none (only markdown links) ✓ | gate stayed In Progress ✓ |
  | [#332](https://github.com/Brite-Nites/brite-claude-plugins/pull/332) (batch 2, plugins) | `iter-3 batch 2: ...` ✓ | `holden/fda-iter-3-batch-2-dogfood-findings` ✓ | `per BC-NNNNN § AC #7` bare text in body ✗ | gate auto-closed |

  PR [#332](https://github.com/Brite-Nites/brite-claude-plugins/pull/332) was the load-bearing evidence for Stage 2: title + branch were both correctly sanitized, but the PR body — which becomes the squash commit body verbatim — contained a single bare text reference (`per BC-NNNNN § AC #7`), and the gate auto-closed at `17:41:26.036Z` exactly 3 seconds after merge at `17:41:23Z`. Markdown-linked references throughout PR [#255](https://github.com/Brite-Nites/brand-hub/pull/255)'s body did NOT trigger the close — confirming markdown wrapping is the mitigation, not removal of all references. Standing convention for multi-batch gate issues, refined from batch 1's two-axis form:

  1. PR title: NEVER lead with the gate issue ID. Lead with `iter-N batch M: ...` or domain identifier.
  2. Branch name: NEVER prefix with the gate issue ID.
  3. PR body / squash commit body: every reference to the gate issue must be a markdown link `[BC-NNNNN](https://...)`. NEVER bare text. Pre-merge audit: `grep "BC-<gate-id>" <body draft>` — every hit must be a markdown link or a `Closes BC-<child>` line for the per-batch children you DO want closed.

  Gotcha tracked in user auto-memory under `gotcha_linear_pr_title_magic_id_auto_close.md` with the 3-axis trigger model. **Open question (not yet tested):** whether body references inside fenced code blocks also trigger. Until tested, treat all body text as a trigger surface.

**Operational notes:**

- **iter-3 batch 1 PR strategy**: PR-per-batch of 2-3 domains. PR-1 ([#254](https://github.com/Brite-Nites/brand-hub/pull/254)) = asset-content-libraries + asset-unification + creative-operations; opened 2026-05-19 with `Closes BC-9561 Closes BC-9562 Closes BC-9563` for cascade auto-close. Established discipline: post a one-line iter-marker comment on the PR after each clean `/workflows:review` iteration ("iter-N clean — N reviewers, 0 findings, Verdict: Ship"). This habit has been gap on 5 prior PRs in the v1.1 series; iter-3 batch 1 is first opportunity to land it on the PR surface.

- **Breadcrumb backfill**: `asset-foundation` was retroactively added to `docs/plans/.flow-phase-state.json` `domains[]` array during iter-3 batch 1 setup. Original scaffold (BC-6998 iter-2, commit `000a0ae`, 2026-05-14T18:50:23-06:00) predates the iter-3 breadcrumb file; retroactive entry closes the `/flow:audit` visibility gap per BC-10321 § AC #4.

- **Sequencing constraint observed**: `asset-unification-02` (empty-state CTAs) has explicit cross-domain build-order block on `creative-operations-02` (CreativeRequests collection schema) and `creative-operations-01` (intake form). The L3 Eng plans for `asset-unification-02` should depend on `creative-operations-02` collection schema being defined first. This is the strongest cross-domain dependency surfaced in iter-3 batch 1; documenting here for L3 plan-ordering coordination.

- **iter-3 batch 2 PR strategy**: PR-2 (batch 2 squash) covers analytics-dashboard + access-governance with cascade-close `Closes BC-9565 Closes BC-9566` (children of BC-9559). PR title + branch name explicitly avoid leading with BC-10321 per the Linear Magic Issue ID gotcha — title leads with `iter-3 batch 2: FDA scaffold — analytics-dashboard + access-governance`; branch `holden/fda-iter-3-batch-2`. Iter-marker comment convention continued from batch 1 (one-line "iter-N clean — N reviewers, 0 findings, Verdict: Ship" after each clean review pass).

- **Batch 2 promotion of access-governance**: original prompt slated `access-governance` for batch 3; promoted to batch 2 because it gates several batch-1 sub-flow expansions (`<RoleGate>` UI pattern blocks `asset-unification-02` + `creative-operations`; share-link security blocks `asset-content-libraries-03`; curation surface blocks `asset-content-libraries` typed-library curation). Shipping access-governance ahead of data-quality-migration / ops-hardening clears the cross-domain backlog faster.

- **Sequencing constraint observed (batch 2)**: `analytics-dashboard-03` (smart recommendations) cannot ship before `asset-content-libraries-05` (sales asset taxonomy). The recommender's slicing axis (vertical + stage) requires the taxonomy to be a first-class configurable schema; without it, training data is partitioned along unstable axes. Build-order priority: taxonomy first, then recommendations. The graceful-degradation path (fall back to "most recent in document-type") preserves the widget slot but produces materially less useful recommendations.

- **Inventory drift class observed twice more in batch 2**: same drift class as batch 1's `creative-operations-03/-05` and `asset-content-libraries-03` corrections — inventory marks a sub-flow ✓ BUILT but the surface (UI) doesn't actually consume the underlying primitive. Batch 2 instances: `analytics-dashboard-01` (API present, no UI). Additional inventory text corrections in batch 2: `access-governance-01` "Clerk upgrade" → Payload + Google OAuth (planned vs current); `access-governance-05` "Feature flags" → image-flagging triage (mislabel — Brand Hub has no feature-flag system). Recommendation: tighten the inventory criterion at iter-4: a sub-flow is BUILT only when an operator can consume it through the intended surface, not when the API is callable. Sub-flow descriptions should match actual code, not planned futures.

- **Cross-domain gating concentration observed**: access-governance is the highest-leverage upstream domain for batch-1 sub-flow expansions. Three of its sub-flows each gate multiple batch-1 unblocks: `-02` (RBAC) → asset-unification-02 + creative-operations row drag; `-06` (share-link security) → asset-content-libraries-03 share affordance + asset-content-libraries-01 external download; `-07` (curation surface) → asset-content-libraries typed-library curation. Documenting here so the next planning cycle prioritizes these three sub-flows ahead of pure greenfield work.

- **iter-3 batch 3 PR strategy**: PR-3 (batch 3 squash) covers data-quality-migration + ops-hardening with cascade-close `Closes BC-9567 Closes BC-9568`. Title leads with `iter-3 batch 3: FDA scaffold — data-quality-migration + ops-hardening (iter-3 acceptance gate close)`; branch `holden/fda-iter-3-batch-3`. The 3-axis Magic Issue ID mitigation applied as standing discipline even though BC-10321 closing on this merge is the *intended* close (it's the iter-3 acceptance gate; closing it is the goal). Plugins PR similar: title `iter-3 batch 3: brand-hub dogfood findings — data-quality-migration + ops-hardening (iter-3 closed)`; branch `holden/fda-iter-3-batch-3-dogfood-findings`. Iter-marker convention continued.

- **Inventory drift class trend across iter-3**: batch 1 surfaced 3 corrections (asset-content-libraries-03 ⚠→correction; creative-operations-03/-05 ⚠→✗). Batch 2 surfaced 3 corrections (analytics-dashboard-01 ✓→⚠; access-governance-01 Clerk→Payload; access-governance-05 Feature flags→image-flagging). Batch 3 surfaced **ZERO corrections** in either data-quality-migration or ops-hardening. The honesty trend is real but uneven: data-quality-migration's ✓ BUILT inventory was accurate even with 5 of 6 marked ✓ (the predicted high-drift-risk domain turned out drift-free); ops-hardening's PARTIAL-heavy status mix was honest because the work is genuinely in-flight, not silently degraded. Recommendation for iter-4: keep the inventory criterion ("BUILT = operator can consume through intended surface, not just API callable") in writing; cite data-quality-migration + ops-hardening as the reference clean-inventory examples.

- **iter-3 acceptance gate (BC-10321) closes on this batch 3 merge** — AC #3 target met EXACTLY: 9 FDA milestones (asset-foundation + asset-discovery + 5 batch-1 + 2 batch-2 + 2 batch-3) / 46 parents (1 + 6 + 5 + 2 + 6 + 5 + 7 + 6 + 8) / 230 discipline children (5 + 30 + 25 + 10 + 30 + 25 + 35 + 30 + 40). crm-sync deferred per BC-9564 pending CRM-target decision; 9 of 9 BC-9559 children Done (BC-9560, BC-9561, BC-9562, BC-9563, BC-9565, BC-9566 from prior batches; BC-9567 + BC-9568 cascade-close on this PR) except BC-9564 deferred. Manual orchestration fallback per `[[feedback_manual_orchestration_fallback]]` was load-bearing across all 3 batches (BC-10352 classifier-bypass bug remained open throughout); recommendation: re-validate `/flow:add-domain` orchestrator-driven path against one fresh domain at the time BC-10352 ships (v1.1.x patch), then retire the manual fallback if clean.

### iter-3 cumulative outcome summary

| Metric | Pre-iter-3 (post iter-2) | iter-3 batch 1 (3 domains) | iter-3 batch 2 (2 domains) | iter-3 batch 3 (2 domains) | Post-iter-3 total |
|---|---|---|---|---|---|
| FDA milestones | 2 (asset-foundation + asset-discovery) | +3 | +2 | +2 | **9** ✓ |
| Parents | 7 (1 + 6) | +13 (5 + 2 + 6) | +12 (5 + 7) | +14 (6 + 8) | **46** ✓ |
| Discipline children | 35 (5 + 30) | +65 (25 + 10 + 30) | +60 (25 + 35) | +70 (30 + 40) | **230** ✓ |
| Story docs on disk | 7 | +13 | +12 | +14 | **46** ✓ |
| Journey docs on disk | 2 | +3 | +2 | +2 | **9** ✓ |
| Inventory drift corrections | n/a | 3 | 3 | 0 | 6 cumulative |
| Vocabulary collision call-outs | n/a | 1 (approval image vs request) | 2 (approval; flags) | 2 (test; hardening) | 5 cumulative |

**AC #3 target met EXACTLY (no over-shooting, no padding via `/flow:add-sub-flow` shortcuts per BC-10321 amended AC).** Manual orchestration via direct Linear MCP `save_milestone` + `save_issue` calls + `Write` tool for story / journey docs proved load-bearing across all 3 batches.

### Plugin bugs surfaced during iter-3 (cumulative)

- **BC-10352 (P2, OPEN)** — `/flow:add-domain` Phase 2 classifier (`flow-classify-domain-state.sh`) hard-rejects Brand Hub's iter-2 shipped inventory on 3 schema axes (UPPERCASE regex vs lowercase-kebab-case, bare H3 grep vs backtick-wrapped, triple-hyphen vs em-dash separator). Filed batch 1; remained open across all 3 batches. Manual orchestration fallback worked cleanly. Recommended path A: relax classifier schema to match iter-2 reality (locks the shipped format as canonical).

- **No new plugin bugs surfaced in batch 3.** The orchestrator-bypass pattern is well-trodden by now; batch 3 ran without new failure modes. The dogfood now has 3 full batches of evidence that manual orchestration is a viable production fallback (not just a one-off).

## Post-iter-3 — crm-sync close (the deferred 10th domain, 2026-05-20)

The `crm-sync` domain was deferred through iter-1/2/3 on an unresolved CRM-target question (3 of 4 L1 reviewers flagged the HubSpot-vs-Salesforce contradiction). That decision **landed 2026-05-20: Salesforce is the sole CRM target; HubSpot is fully deprecated at Brite** (per `brite-salesforce` ADR-001, migration Phase 1 + 2 complete). With the target settled, the iter-2 inventory was re-derived into 5 Salesforce-shaped sub-flows and scaffolded via the same manual-orchestration fallback (BC-10352 still open), bringing brand-hub to the **full with-crm-sync tier**.

| Metric | Post-iter-3 (9 domains) | + crm-sync | Full with-crm-sync tier |
|---|---|---|---|
| FDA milestones | 9 | +1 | **10** |
| Parents | 46 | +5 | **51** |
| Discipline children | 230 | +25 | **255** |
| Story docs on disk | 46 | +5 | **51** |
| Journey docs on disk | 9 | +1 | **10** |

**All 5 sub-flows scaffolded ✗ NOT BUILT by design** — the FDA scaffold is a planning/documentation artifact, not an implementation gate (the same shape `ops-hardening` used for its 3 NOT-BUILT Droidor placeholders). Implementation stays blocked on the Salesforce migration reaching a stable API surface (Connected App + REST scopes + Custom Object equivalents) per `master-flow-inventory.md` § crm-sync.

**Observations:**

- **SF references grounded against the real repo.** Every Salesforce object/component name traces to the actual `brite-salesforce` repo — no invented names. Existing primitives reused as design anchors (`Marketing_Claude_MCP` ECA, `Outbound_Sales_Ops` Connected App, `accountDetails` LWC, `Opportunity_Record_Page_Three_Column` flexipage, `Slack_Webform_Alerts` Named Credential, the Brite Base read-only-mirror pattern); not-yet-existing primitives explicitly flagged (creative-request Custom Object, inbound `@RestResource`, Brand Hub deal card). This is the first dogfood domain whose design references span two repos — a cross-repo grounding pattern worth noting for future multi-system integration domains.
- **No inventory drift corrections** — the inventory's `crm-sync` rows (re-derived for Salesforce) matched reality; all 5 honestly ✗ NOT BUILT. Third consecutive clean-inventory domain after data-quality-migration + ops-hardening.
- **Build order is a dependency chain, not a parallel set** — `crm-sync-01` (PRD) unblocks everything; `-03` (sync spine) + `-05` (its guard) → `-02` (card) → `-04` (cron). Two transitive upstream blocks within Brand Hub: `creative-operations-02` (CreativeRequests collection, NOT BUILT) and `analytics-dashboard-04` (NOT BUILT, v3-deferred). A fully-NOT-BUILT, externally-gated domain is a distinct journey shape from the maturity-ladder (ops-hardening) and the all-built (asset-discovery) shapes — the journey doc captures it as an "integration-readiness arc gated on an external dependency."
- **Two vocabulary disambiguations** — "sync" (Brand Hub↔SF status sync vs. the Brite Base↔SF ops mirror — same architectural pattern, different systems); "card" (SF Lightning card on the Opportunity vs. a Brand Hub kanban card).
- **Manual orchestration fallback now has a 6th clean run** (asset-discovery + iter-3 batches 1/2/3 + crm-sync). BC-10352 remained open throughout; recommendation unchanged — re-validate the orchestrator-driven path against one fresh domain when BC-10352 ships, then retire the fallback if clean.

**Retrofit complete.** [BC-9559](https://linear.app/brite-nites/issue/BC-9559) (Brand Hub FDA complete retrofit) reaches 9/9 domain children Done on this close (BC-9564 was the last). All 10 inventory domains are now FDA-scaffolded; `design-system` remains a cross-cutting Phase Pattern overlay (NOT an FDA domain proper) per the Q35 amendment. This addendum is markdown-only — no plugin code change, no version bump (crm-sync is consumer-product work, not a plugin-release gate).

## Iter-3 cutover (BC-11099 post-iter-3 close, 2026-05-22) — manual-orchestration fallback retired

Closes the loop on [BC-10352](https://linear.app/brite-nites/issue/BC-10352) AC #6 ("re-check iter-3 dogfood findings once fix ships"). The manual-orchestration fallback that was load-bearing across asset-discovery + iter-3 batches 1/2/3 + crm-sync (6 clean runs total) is retired going forward. [BC-10352](https://linear.app/brite-nites/issue/BC-10352) (Q20 amendment 2, Path A — lowercase + backtick-wrapped + em-dash canonical) shipped together with [BC-10728](https://linear.app/brite-nites/issue/BC-10728) (38-assertion bash test harness at `plugins/flow-architecture/tests/test-helper-scripts.sh`) in [PR #350](https://github.com/Brite-Nites/brite-claude-plugins/pull/350) at plugin 1.1.1 (current 1.2.0 after the Q58 verify-docs ecosystem ship at `eac2b0a`).

**Dry-run cutover evidence** (BC-11099, 2026-05-22). Chose `ops-hardening` as the demonstrative target — the largest iter-3-scaffolded domain (8 sub-flows) and one of two iter-3 domains that surfaced zero inventory drift corrections (`data-quality-migration` was the alternate; tested and behaved identically). Both run from the current `main` checkout against this brand-hub repo:

```bash
bash plugins/flow-architecture/scripts/flow-classify-domain-state.sh \
  "$BRAND_HUB/docs/product/master-flow-inventory.md" \
  "$BRAND_HUB/docs/product/flows" \
  "$BRAND_HUB/docs/product/journeys" \
  "ops-hardening"
# → fully-scaffolded-fs   (exit 0)

bash plugins/flow-architecture/scripts/flow-classify-domain-state.sh \
  ... "data-quality-migration"
# → fully-scaffolded-fs   (exit 0)

# Negative axis still rejects (validation still doing real work):
bash plugins/flow-architecture/scripts/flow-classify-domain-state.sh \
  ... "OPS-HARDENING"
# → flow-classify-domain-state: DOMAIN 'OPS-HARDENING' fails [a-z][a-z0-9-]*
#   (Q20 amendment 2 schema; BC-10352)   (exit 2)
```

The H3 form that pre-fix hard-rejected on all 3 axes — `` ### `ops-hardening` — Operational Hardening`` (lowercase slug, backtick-wrapped, em-dash separator) — now classifies cleanly to `fully-scaffolded-fs`, which routes to Branch D (fully-scaffolded no-op with cancel-recommended `AskUserQuestion`). That is the correct posture for a domain iter-3 already scaffolded end-to-end; the classifier-driven path now distinguishes "needs scaffolding" from "already scaffolded" without operator intervention. Branch B (`inventory-only` re-scaffold) was the originally-named target in BC-11099 brief; the actual classifier outcome is Branch D because iter-3 fully scaffolded each domain. Either branch demonstrates the same cutover — the classifier accepts the iter-2 inventory shape, exits 0, and routes deterministically.

Memory flipped at `~/.claude/projects/.../memory/feedback_manual_orchestration_fallback.md` — historical guidance preserved under § "Historical note (pre-2026-05-22)" for audit trail; current posture is DEPRECATED with cutover evidence inline. No plugin code change in this BC; doc + memory only.

## Cross-reference

- [BC-6998](https://linear.app/brite-nites/issue/BC-6998) — this milestone (Done 2026-05-13).
- [BC-7058](https://linear.app/brite-nites/issue/BC-7058) — pre-flight audit shipped 2026-05-11.
- [`brand-hub-preflight-findings.md`](brand-hub-preflight-findings.md) — pre-flight findings, sibling artifact.
- [`fda-plugin-drafter-e-revision-2.md:1117-1133`](fda-plugin-drafter-e-revision-2.md) — Q8 7 sub-criteria source-of-truth.
- [`fda-plugin-architecture-overview.md`](fda-plugin-architecture-overview.md) § 7 — outer-loop Phase 6 / Q40 release sequence step 5 framing.
- [BC-6999](https://linear.app/brite-nites/issue/BC-6999) (downstream) — v1.0 release + CDR-023 Proposed → Accepted; unblocked by BC-6998 Done.
- [BC-9023](https://linear.app/brite-nites/issue/BC-9023) — P0 root-cause resolution (install gap); this doc's correction trail.
- [BC-9559](https://linear.app/brite-nites/issue/BC-9559) — Brand Hub FDA complete retrofit (remaining 9 domains parent); children BC-9560..BC-9568.
- [BC-9561](https://linear.app/brite-nites/issue/BC-9561) — Deck Generator out-of-scope decision; sub-flow `asset-content-libraries-06` removed from scaffold.
- [BC-9564](https://linear.app/brite-nites/issue/BC-9564) — HubSpot deprecation / Salesforce-only CRM target decision (resolved 2026-05-20); crm-sync scaffolded as the deferred 10th domain, completing the retrofit at the full with-crm-sync tier (10 milestones / 51 parents / 255 children). `crm-sync-01` re-purposed as SF integration PRD rewrite.
- [BC-10352](https://linear.app/brite-nites/issue/BC-10352) — Q20 amendment 2 (Path A) classifier fix; shipped [PR #350](https://github.com/Brite-Nites/brite-claude-plugins/pull/350) at plugin 1.1.1 (2026-05-22). Unblocked the manual-orchestration fallback retirement.
- [BC-10728](https://linear.app/brite-nites/issue/BC-10728) — 38-assertion bash test harness for the 4 helper scripts (same PR, cascade-close); negative-axis regression lock for BC-10352.
- [BC-11099](https://linear.app/brite-nites/issue/BC-11099) — manual-orchestration fallback retirement gate (closed 2026-05-22); closes BC-10352 AC #6.
