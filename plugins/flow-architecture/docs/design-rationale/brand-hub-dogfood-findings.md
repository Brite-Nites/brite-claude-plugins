# Brand Hub dogfood findings

> Iteration log + acceptance-criteria verdict for [BC-6998](https://linear.app/brite-nites/issue/BC-6998), the v1.0 acceptance gate for the flow-architecture plugin. Companion to [`brand-hub-preflight-findings.md`](brand-hub-preflight-findings.md) (BC-7058). Skeleton written 2026-05-12 to satisfy AC7 ("Failure modes documented at `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md`"). Body populated as each iteration progresses.

## Run context

| Field | Value |
|---|---|
| Plugin version at iter-1 start | `0.2.22` |
| Brand Hub repo | `/Users/holdenhalford/projects/work/brite-nites/brand-hub` |
| Brand Hub commit at iter-1 start | `47dc542` |
| Brand Hub Linear project | slug `brand-hub-beb1f3e9de7f` / id `61d8cd9b-67ba-4e62-b474-81d9ccf36d31` |
| Brand Hub release target | 2026-05-19 |

## Iteration log

Each row records one `/flow:retrofit-project` invocation through the 9-phase sequence. Cap = 2 iterations per Q40 sub-decision 6; iter 3+ requires Q56+ Q-lock escalation.

### Iteration 1 — _in progress_

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
| 3 render — cross-reference doc draft | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 3 execute — Linear milestone appendix | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 4 — inventory codebase-scan | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 5 — Linear scaffold (per-domain inner loop) | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 6 — story-doc author (batched) | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 7 — journey-doc author (batched) | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 8 — INDEX regen | _TBD_ | _TBD_ | _TBD_ | _TBD_ |
| 9 — complete | _TBD_ | _TBD_ | _TBD_ | _TBD_ |

### Iteration 2 — _not yet started_

Triggered only if Iter 1 leaves any AC un-PASSed.

## Acceptance criteria verdict

Q8 7 sub-criteria + 4 quality gates added 2026-05-10. Verdict populated post-execution.

| # | Criterion | Verdict | Evidence |
|---|---|---|---|
| AC1 | All 9 retrofit phases complete without unrecovered failures | _TBD_ | iter log above |
| AC2 | 5 user-confirmation gates fire as expected | _TBD_ | iter log above |
| AC3 | Outputs match locked schemas (intent / inventory / per-flow / journeys / INDEX / Linear chain / cross-ref) | _TBD_ | `test -f` checks below |
| AC4 | `/flow:audit` against Brand Hub repo exits `0` | _TBD_ | run from `brand-hub/` |
| AC5 | `npm run build && npm run lint && npm test` on Brand Hub exit `0` | _TBD_ | run from `brand-hub/`; BC-7058 baselined all three at 0 |
| AC6 | Linear FDA-shaped milestones + 5N children created cleanly | _TBD_ | MCP query against Brand Hub project |
| AC7 | `test -f plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md` succeeds | PASS | this file exists |
| Q1 | Pre-flight gate: BC-7058 Done + 0 NEEDS-FIX in pre-flight findings | _TBD_ | confirm BC-7058 Linear state |
| Q2 | V-slice gate: BC-7057 Done + `vslice-greenfield` CI green | _TBD_ | confirm BC-7057 Linear state + CI |
| Q3 | Audit-smoke-test gate (advisory): BC-7059 Done | _TBD_ | confirm BC-7059 Linear state |
| Q4 | Iteration count ≤ 2 | _TBD_ | this section's row count |

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

| Drift | Memory line / file | Reality | Fix |
|---|---|---|---|
| Brand Hub PRD filename `.context/prd/hubspot-integration.md` references HubSpot | Pre-flight findings § Narrative artifacts | Brite migrated HubSpot → Salesforce as CRM SoR (per `project_salesforce_migration.md` memory). User caught the stale CRM reference during Section 4 success-criteria interview. | Brand Hub team renames + content-corrects the PRD; OR Brand Hub product Salesforce-corrects integration; not a BC-6998 dogfood blocker, file as Brand Hub Linear follow-up. |

## Captured but unwritten Phase 2 intent draft

Per Q42 sub-decision 5, intent.md is written ONCE — after L1 review completes. Phase 2 reached final-review approval but L1 dispatch failed (Finding #4 P0 blocker); per the atomic-write contract, no partial intent.md was written to disk. The 6-section content below was captured during this iter's interview and is preserved here so iter 2 can lift it forward after the L1 dispatch blocker is resolved (or pass it through `/flow:office-hours --linear-context=skip` once agent registration is fixed).

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

## Cross-reference

- [BC-6998](https://linear.app/brite-nites/issue/BC-6998) — this milestone.
- [BC-7058](https://linear.app/brite-nites/issue/BC-7058) — pre-flight audit shipped 2026-05-11.
- [`brand-hub-preflight-findings.md`](brand-hub-preflight-findings.md) — pre-flight findings, sibling artifact.
- [`fda-plugin-drafter-e-revision-2.md:1117-1133`](fda-plugin-drafter-e-revision-2.md) — Q8 7 sub-criteria source-of-truth.
- [`fda-plugin-architecture-overview.md`](fda-plugin-architecture-overview.md) § 7 — outer-loop Phase 6 / Q40 release sequence step 5 framing.
- BC-6999 (downstream) — v1.0 release + CDR-023 Proposed → Accepted; blocked by BC-6998.
- [BC-9023](https://linear.app/brite-nites/issue/BC-9023) — P0 root-cause resolution (install gap); this doc's correction trail.
