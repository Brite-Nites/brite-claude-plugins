# Cadence Plugin — Orchestration Shape

**Linear issue:** BC-5810
**Depends on:** BC-5757 (voice spec + Linear recipes + PDF flow)
**Unblocks:** BC-5758 (scaffold), BC-5759 (Phase 1 audit subagent), BC-5760 (Phase 2 scope skill), BC-5761 (Phase 3 housekeeping skill)
**Purpose:** Lock the three load-bearing decisions BC-5757 deferred — architecture, interview set, issue-quality gate — so every downstream phase issue can be written and executed without re-litigating shape.

This document is not a scaffold. No `plugins/cadence/` code lands here. It freezes the conversation shape the scaffold must implement.

## Non-goals

- Phase 1/4 subagent prompt text (BC-5759, BC-5762 own those; this doc gives them the interface)
- Phase 2/3 SKILL.md bodies (BC-5760, BC-5761 own those; this doc gives them the question set + mutation preview contract)
- Entry command orchestration code (BC-5758 owns it; this doc gives it the phase/gate contract)

---

## 1. Architecture — hybrid conversational loop with batch bookends

`/cadence:weekly` runs as a four-phase flow. Two phases are batch, two are interactive. Gates live between phases, not inside them.

```
Phase 1 BATCH   audit fan-out (parallel subagent per project) + cross-project stats
                    │
                    ▼   Gate #1 — show audit summary, user approves moving to scope
                    │
Phase 2 LOOP    per-project interactive scope (carry-over Qs + scope Qs, one project at a time)
                    │
                    ▼   Gate #2 — show accumulated mutation preview, user approves batch
                    │
Phase 3 BATCH   housekeeping mutations (cycle assign, reassign, cancel, milestone ops)
                    │
                    ▼   Gate #3 — show narrative draft, user approves ship
                    │
Phase 4 BATCH   narrative draft + PDF export
```

### 1.1 Three reasons this shape wins, each anchored in W16

**(a) Cross-project stats require batch data.** The W16 narrative opens with five quantitative anchors — `32% / 211 / 92% / 59 / 100%` — derived from cycle-level aggregates across all projects. The W16 planning checkpoint opens with a `## W15 Audit Summary` section that computes these BEFORE walking projects. A pure per-project loop would never surface them because no single project carries the cycle-level denominator.

**Pull-quote from `w16-planning-checkpoint.md` line 9:**

> *"Overall W15 completion rate: 32% of planned issues shipped. 92% of shipped work was unplanned — 211 issues shipped total, only ~22 were in the narrative. Training (100%) and Recruiting (100%) were the standout teams. #1 priority BC-2690 (MI reply sync) did not ship."*

That opener is the headline of every weekly narrative. Phase 1's batch pass exists to compute it.

**(b) Scope decisions load best one project at a time.** The W16 checkpoint walks 17 project sections sequentially (sections 1–7, 9–18, then a double-back to 8 Brite GTM). Each section contains both the project's carry-over audit and its W+1 scope decisions interleaved. That's not an accident — carry-over context ("BC-2439 is superseded by the BC-2281/82/83/84 chain") must be loaded into working memory before the planner can decide "cancel or keep." A pure batch scope phase would force the planner to hold all 17 projects' carry-over state simultaneously, which breaks the one-question-at-a-time feedback rule and matches how the checkpoint actually flowed. The per-project interactive loop additionally dispatches a read-only enricher subagent per project (see § 2.5) to keep main-thread context lean across 25+ projects.

**(c) Mutations batch at the end so rollback is cheap.** The W16 checkpoint's "Actions Taken During This Planning Session" list at line 365 — 10 mutations executed AFTER all scope decisions were made:

> *"1. 8 Brite Base issues moved from old cycle to W15 cycle (BC-4131, 4132, 3698-3703). 2. BC-2439 cancelled (superseded by BC-2281/82/83/84). 3. BC-2282, BC-2280, BC-2285 reassigned Nora → Corinne..."*

This deferred-batch pattern lets the planner revisit decisions — e.g. "Pre-Launch Hardening" renamed to "Production Hardening" affected multiple projects and was decided during one project's section but applied globally. Mid-loop mutation would have required a rollback pass; deferred-batch needs none.

### 1.2 Loser trade-offs

**Pure per-project loop (audit A → scope A → mutate A → narrate A → next project).** Fails reason (a): the narrative opener loses its cross-project stats because no single project iteration has access to cycle-level counts. Fails reason (c): mid-loop mutations make revisit cost O(n²) instead of O(n) — if mutating project A's milestone rename requires touching project B's issues, the planner has to remember to double-back.

**Pure batch (audit all → scope all → mutate all → narrate all).** Fails reason (b): forces the planner to hold 17 projects' audit state in working memory during scope questions. Breaks the one-question-at-a-time rule. Per W16, the checkpoint's per-project walk exists *because* batching scope is cognitively expensive; the shape emerged from experience, not from arbitrary structure.

### 1.3 How this shows up in phase issues

* **BC-5758 scaffold.** Entry command `/cadence:weekly` orchestrates four phases with three gates. Gates use `AskUserQuestion` for proceed/retry. Phase outputs flow between phases via a single session-scoped state object (`cadence-state.json` or in-memory map) — no re-fetching from Linear.
* **BC-5759 audit subagent.** Parallel fan-out, one subagent per project. Each subagent emits a structured audit card (shipped / dropped / carry-over / by-assignee / quality-gate-flags). Subagent is voice-constrained per BC-5757 § 1 because its audit card feeds Phase 4's narrative draft directly.
* **BC-5760 scope skill.** Sequential iteration over projects. For each project, reads the Phase 1 audit card and runs the adaptive interview (see § 2). Stores decisions in the state object; emits no Linear mutations.
* **BC-5761 housekeeping skill.** Reads the state object's accumulated decisions. Renders a preview of every mutation (`reassign BC-X from Nora to Corinne`, `cancel BC-Y superseded by BC-Z`, `add BC-Q to W17 cycle`, `rename milestone "Pre-Launch Hardening" → "Production Hardening"`). User approves the full batch; skill executes atomically.
* **BC-5762 narrative + PDF.** Reads state object + cross-project stats computed in Phase 1. Produces the narrative per BC-5757 § 1 skeleton. Invokes `npx md-to-pdf` per BC-5757 § 3.

---

## 2. Per-Project Interview (adaptive, one question at a time)

The interview runs sequentially across projects in Phase 2. Per project, the skill reads the audit card from Phase 1 and selects which questions to ask — skipping ones the audit already answers. Every question presented uses `AskUserQuestion` with the recommended default first (labeled "(Recommended)") and an Escape path via the "Other" free-text option.

### 2.1 Carry-over block — per issue that was in the prev cycle but did not ship

Asked only if the project has unshipped carry-over issues. If the audit card reports `carry_over: []`, the entire block is skipped for this project.

* **Q1 — Move to next cycle?** Default: move to W+1. Escape: reassign first (then re-ask Q1). Why: the W16 pattern — most unshipped issues move. BC-2690 (MI reply sync) carried from W15 to W16 unchanged.
* **Q2 — Assignee still correct?** Default: unchanged. Escape: reassign (pick new assignee or mark unassigned). Why: W16 had 17 Outbound Sales Ops issues flip Nora → Corinne in one batch; the interview surfaces that pattern per-project instead of per-issue.
* **Q3 — Superseded by a different chain?** Default: keep as-is. Escape: cancel, then name the replacement IDs (comma-separated). Why: BC-2439 → BC-2281/82/83/84 in W16 — supersession is a common cancel path and the replacement chain needs to be recorded for the narrative.
* **Q4 — Blockers still live?** Default: yes, keep declared blockers. Escape: clear specific IDs that are Done or canceled. Why: W16's `"BC-2488 stale blockers cleared (BC-2485, BC-2484 both Done)"` — the audit card flags them; Q4 confirms.
* **Q5 — If staying, which cycle or milestone lands it?** Default: next cycle. Escape: park to a specific future cycle, or park indefinitely (no cycle, backlog state). Why: the W16 "Parked to W17+" list had 7 Low-priority monitoring items deferred past the next cycle.

### 2.2 Next-cycle scope block — once per project after carry-over

Asked once per project even if carry-over block was skipped. If the audit card reports a parked project (no active work, no W+1 capacity), Q1 is asked with default "parked" and the rest of the block is skipped.

* **Q1 — Headline outcome sentence?** Default: agent proposes from top-priority carry-over + top-priority backlog candidates. Escape: custom sentence, or mark project parked. Why: W16 Outbound Sales Ops had an explicit headline — *"BDRs and leadership see dashboards with real data by Friday."* — the narrative cards lead with this.
* **Q2 — Which issue IDs ship this cycle?** Default: agent proposes current-cycle carry-over + High-or-Urgent backlog filtered by the quality gate (see § 3). Escape: exploratory project — no up-front commitments, add issues during the cycle. Why: W16 Salesforce Implementation listed 12 specific IDs with ownership; exploratory projects like Brite Handbook got no list.
* **Q3 — Owner per issue, if different from existing assignee?** Default: keep existing assignees. Escape: reassign specific IDs; mark specific IDs unassigned. Why: ownership drift is common mid-cycle — Q3 catches it at scope time rather than during execution.
* **Q4 — Dependencies between the picked issues?** Default: agent infers from issue descriptions + blocker fields. Escape: all parallel (no dependencies), or add explicit edges ("BC-2068 depends on BC-2067"). Why: W16 Salesforce Implementation had a 6-issue dependency chain implicit in the narrative; capturing it at scope time feeds the narrative card's structure.
* **Q5 — Explicitly parked this cycle?** Default: agent proposes from stale current-cycle items + Low-priority carry-over. Escape: nothing parked, or custom list. Why: W16 parked 7 monitoring items to W17+ with an explicit reason — the narrative's "Parked This Week" table builds from this.

### 2.3 Adaptivity rules

The skill consults the audit card before each question and skips when the audit already answers:

| Condition | Question skipped |
|---|---|
| `carry_over == []` | All 5 carry-over questions for this project |
| `project.status == "parked"` | Q2–Q5 of scope block (Q1 still asked for acknowledgement) |
| `blocker_count == 0` on a carry-over issue | Q4 of carry-over block for that issue |
| `audit.auto_superseded_by` set (e.g. via linked-issue field) | Q3 of carry-over block is prefilled but shown for confirmation |
| `backlog_candidates.length == 0` at Urgent/High priority | Q2 of scope block still asked but default is "carry-over only" |

Every skipped question logs a one-line audit entry in the state object (`skipped: Q3 carry-over because BC-X has superseded_by field set`) so the narrative can explain the resulting decision without needing the skill to re-derive it.

### 2.4 One-question-at-a-time enforcement

The skill MUST call `AskUserQuestion` once per question, wait for the answer, then proceed. No batched question blocks. This is a hard rule per `memory/feedback_one_question_at_a_time.md`:

> *"During checkpoint reviews, ask one question at a time with appropriate background information so the user can make an informed decision. Do not batch multiple questions together."*

Each question carries:

* The issue ID and title (for carry-over Qs) or project name (for scope Qs)
* A one-line audit summary snippet (e.g. *"BC-2690 — MI reply sync investigation. In Progress W15. No PR. Assigned Holden. 0 blockers."*)
* The recommended default as the first option with `(Recommended)` label
* An "Other" free-text escape path

### 2.5 Hybrid dispatch for heavy reads (BC-5902)

Phase 2's interactive interview and Phase 3's per-mutation gate re-run must run inline in main thread because `AskUserQuestion` cannot fire from dispatched subagents. At 25 projects, accumulated context (audit cards + backlog fetches + per-project scope state + brainstorming outputs + per-mutation gate reads) exceeds main-thread budget and the skills silently drop spec-required steps. This surfaced in BC-5763 W17 dogfood attempt 2 as 4 P1s in a "context-pressure family" (BC-5896/5897/5898/5899).

The fix: **two Sonnet agents absorb every heavy read.** Each Phase 2 project dispatches `project-enricher` (cap-10 parallel, mirrors Phase 1 `project-audit` fan-out) which returns a compact card (~1–2KB) containing backlog candidates + enriched carry-over relations + brainstorming-ranked scope candidates. Phase 3 dispatches `housekeeping-preflight` once with the cycle-path mutation slice and receives a `{mutation_id → gate_detail[7]}` manifest (~300B × ~100 rows).

Main-thread context after Phase 1 reads only compact agent outputs — never raw Linear results. Empirically keeps the main-thread Messages category ≤150K across 25 projects (BC-5902 AC evidence; to be confirmed by BC-5874 third dogfood).

Failure posture is fail-loud: any dispatch error halts the phase and surfaces `AskUserQuestion` with Retry / Pause / explicit user-override-to-proceed options. No silent degradation path exists — a spec departure is always opt-in and logged as such (corrects the BC-5896/5898 attempt-2 regression).

**Absorbed into the enricher:** the main-thread `workflows:brainstorming` Skill call from § 2.2 SQ2 default is gone — the enricher ranks scope candidates internally with the same inputs (carry-over count, backlog-high count, shipped pace, owner-load hint from cross-project stats). Closes BC-5867 (brainstorming invocation spec-misfit) as a by-product.

See `plugins/cadence/agents/project-enricher.md`, `plugins/cadence/agents/housekeeping-preflight.md`, and the Phase 2/3 SKILL files for the concrete interface.

### 2.6 Pull-quote — edge case the interview set covers

From `w16-planning-checkpoint.md` line 266:

> *"BC-5260 — W16 Leadership review: Holden + Jaime + Mike (Urgent, due Apr 16). Review/validate ICPs (BC-3270 marked Done without actual meeting). Review/validate headcount model (BC-3269 marked Done without actual meeting)."*

BC-3270 and BC-3269 were marked `Done` without the actual work shipping — a fake-Done. The carry-over block's Q3 ("superseded?") is the wrong lane for this; it's caught by the quality gate in § 3 (check #7, `done_with_evidence`). The quality gate flags the issue during Phase 1 audit; the scope skill in Phase 2 blocks scope-in until the user overrides with a reason. W17+ narrative then carries the override reason in its "Parked This Week" table footnote.

---

## 3. Issue Quality Gate

### 3.1 Location

`plugins/cadence/skills/_shared/issue-quality-gate.md` — a shared skill consulted by Phase 1 (audit-time flag) and Phase 2 (scope-time block). Skill reads one issue object at a time, returns a list of `{check, status, message}` tuples. Cadence's entry command never calls the gate directly; it's always a dependency of a phase skill.

Peer-linked from:

* `plugins/cadence/skills/phase1-audit/SKILL.md` (BC-5759) — calls gate per-issue inside the audit subagent; emits failures into the audit card under `quality_gate_flags`.
* `plugins/cadence/skills/phase2-scope/SKILL.md` (BC-5760) — calls gate per scoped-in issue; blocks scope-in on any failure unless overridden per-check.

### 3.2 Seven checks — concrete pass/fail

| # | Check | Pass criterion | Fail criterion | W16 failure example |
|---|---|---|---|---|
| 1 | `assignee_present` | `issue.assignee != null` | `issue.assignee == null` (the `(unassigned)` bucket from BC-5757 § 2.7) | None — W16 planner assigned explicitly; check is preventive |
| 2 | `title_scopes_work` | Title has ≥3 words AND doesn't start with "TBD" / "???" / `[placeholder]` | `< 3 words` OR starts with placeholder tokens | None in W16 directly; surfaced during BC-5260 cleanup |
| 3 | `priority_set` | `priority` ∈ {1 Urgent, 2 High, 3 Medium, 4 Low} | `priority == 0` (No priority) | None in W16 — check is preventive |
| 4 | `state_matches_cycle` | `cycle_id` null OR (`cycle_id` set AND `state.type` ∈ {`unstarted`, `started`, `completed`}) | `cycle_id` set AND `state.type == "backlog"` | W16 moved 4 landing pages "from Backlog to Todo" — exactly the state/cycle misalignment this check catches |
| 5 | `dependencies_declared` | Description contains `## Dependencies` section with either ≥1 issue ID OR the literal string "none" | Description lacks a Dependencies section (or section exists but is empty and doesn't say "none") | W16's "Holden is the bottleneck on 5 of the pipeline issues" risk flag would have been explicit if each issue declared its deps |
| 6 | `ac_section_non_empty` | Description contains `## Acceptance Criteria` header with ≥1 checkbox line (`- [ ]` or `- [x]`) | Header missing OR body empty | W16's BC-3270 had no testable AC — which is why it was marked Done without evidence |
| 7 | `done_with_evidence` | If `state.type == "completed"`: `completedAt` set AND (comment references a PR/commit URL OR attached linked-issue of type "pull-request") | `state.type == "completed"` AND no PR/commit evidence | **BC-3270 and BC-3269 fake-Done** — marked complete, no meeting artifact, no PR. The pattern from § 2.5 pull-quote |

Checks 1–6 run on any issue the gate sees. Check 7 runs only on `completed` issues — a scoped-in issue that previously shipped still gets audited because the narrative treats it as reference evidence.

### 3.3 Block-with-override posture

Phase 1 audit runs the gate and emits failures into the audit card under `quality_gate_flags: [{issue_id, check, message}]`. No blocking — audit is read-only.

Phase 2 scope runs the gate on every issue the user picks for the next cycle in Q2 of the scope block. If any check fails, the skill:

1. Surfaces the failure with the specific check name + message.
2. Offers three paths via `AskUserQuestion`:
   * **Fix the issue now** (skill opens the issue in Linear via a returned URL; user fixes + confirms; skill re-runs the gate; on pass the issue is scoped in).
   * **Override this check with a reason** (one-line free text; captured in state object under `overrides: [{issue_id, check, reason}]`).
   * **Drop this issue from scope** (issue returns to backlog; user picks a replacement).
3. On override, the reason is carried into the Phase 4 narrative under a `> **Known gaps this cycle**` callout footnote — the narrative never hides an override, per W16's convention of stating what's parked and why.

No global "skip all gates" escape hatch exists. Per-check override with a reason is the only path.

### 3.4 Gate behavior vs phase-issue responsibilities

| Concern | Gate (this doc) | Phase 1 (BC-5759) | Phase 2 (BC-5760) | Phase 3 (BC-5761) |
|---|---|---|---|---|
| Run the checks | ✓ (shared primitive) | calls gate, flags in audit card | calls gate on scope-in | — |
| Decide what to do with a failure | — | read-only surface | block-with-override logic | consumes override reasons when drafting mutations |
| Capture override reasons | stores `{check, reason}` | — | captures via `AskUserQuestion` | — |
| Narrative footnote | — | — | — | Phase 4 (BC-5762) reads overrides and renders them |

---

## 4. Cross-phase summary

| Decision | BC-5758 scaffold | BC-5759 audit | BC-5760 scope | BC-5761 housekeep | BC-5762 narrative |
|---|---|---|---|---|---|
| Hybrid architecture | 4 phases, 3 gates, session state object | parallel per-project fan-out | sequential per-project iter | batched mutation preview+exec | reads state object end-to-end |
| Adaptive interview | — | emits audit card fields that drive skip rules | reads audit card; calls `AskUserQuestion` per question; one at a time | — | renders skipped-question reasons under project cards |
| Quality gate | — | calls gate; flags into audit card | calls gate; block-with-override | consumes overrides when rendering mutation preview | renders override reasons under `Known gaps this cycle` callout |
| Hybrid dispatch (BC-5902) | — | project-audit (existing) | project-enricher per project | housekeeping-preflight once | — |

## 5. References

* **BC-5757 baseline:** `docs/designs/cadence-plugin.md` — voice spec (§ 1), Linear query recipes (§ 2), PDF flow (§ 3), plugin destination (§ 4)
* **Ground-truth conversation shape:** `weekly-planning/w16-2026-04-13/w16-planning-checkpoint.md` (17 project sections + batch actions list)
* **Narrative template:** `weekly-planning/w16-2026-04-13/w16-sprint-narrative.md` (skeleton enforced by BC-5757 § 1.3)
* **Feedback memory (one-question-at-a-time enforcement):** `memory/feedback_one_question_at_a_time.md`
* **Feedback memory (atomic issues for agents):** `memory/feedback_atomic_issues_for_agents.md`
* **Feedback memory (thorough audits):** `memory/feedback_thorough_audits.md`
* **Linear MCP:** `plugin:workflows:linear-server` (declared in the workflows plugin, reused by Cadence — see BC-5757 § 2.1)
* **AskUserQuestion convention:** first option wins `(Recommended)` suffix; "Other" path is always available as the escape hatch
