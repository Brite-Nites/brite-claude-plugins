---
name: FDA-as-plugin codification interview (in flight)
description: Multi-session design interview to turn Brite's Flow-Driven Architecture into a Claude Code plugin (`flow-architecture`) and a new operating-standards CDR. Locks through 2026-05-06 evening: Q1-Q12 (process meta + V1 scope + retrofit semantics + UX cadence + inventory internals + preflight internals), Q22-Q28 (all 7 FDA templates), meta-Q autoplan-recurrence (Q54), Q47/Q48/Q49/Q50/Q51/Q52/Q53 still pending design. Phase A (sub-skill internals walk) in flight starting Q13. ~25 design questions still pending in TaskCreate task list at session-end.
type: project
originSessionId: 3178b23f-ec01-4bdf-ae82-811c5e31fca0
---

After Phase 3 sign-off (BC-6578, 2026-05-06, decision: scale), the user opened a multi-session design interview to turn Brite's Flow-Driven Architecture (FDA) into a Claude Code plugin called `flow-architecture`. Style is one-question-per-turn with recommended answer + reasoning + honest pushback per question. Locks through Q12 + Q22-Q28 + meta-Q autoplan-recurrence captured below.

> **Status update (2026-05-27, BC-11891):** Context7 was removed from the workflows plugin and ADR-001 marked Withdrawn. Q-lock entries below (notably Q32 and Q50) reference Context7 as an inherited/available MCP — those references describe the prior plugin state and are preserved as historical audit trail. Workflows now registers 3 MCPs (sequential-thinking, linear-server, gbrain-team); FDA's `.mcp.json` is still empty `{}` per the cadence precedent — that part of the lock is unchanged.

## Critical clarifications (foundational — read first)

**The "5" only applies to discipline children.** Three quantities in FDA are commonly conflated; only one is fixed:

| Thing | Always 5? | Notes |
|---|---|---|
| Discipline children per sub-flow parent | **YES — always 5** | Story / Design / Engineering / QA / Docs (strict-5 contract from Phase 1 sign-off) |
| Sub-flows per journey/milestone | **NO — whatever makes sense** | TEAM has 8, QUO might have 20+, AUTH has 11 — variable per domain |
| Narrative phases in journey doc | **NO — whatever makes narrative sense** | Driven by user's actual behavior, not a target count |

This was a real source of confusion mid-interview — Q22's first lock said "5-phase shape" which was a conflation; corrected to "Narrative shape:" with no count constraint. Q26 dropped the existing template's "4-8 phases" range language entirely for the same reason.

**`.flow/config.json` is the project-stable mapping convention.** Lives at repo-root, committed to git (workspace-level mapping is team-shared). v1 fields: linear_project_id, linear_project_name, linear_team_key, fda_first_setup_at, fda_plugin_version. Read by flow-preflight to skip user-confirmation gate after first successful run.

**Brand Hub is the dogfood acceptance target, NOT BriteBase.** BriteBase Phase 4 will use existing Linear issues to scaffold manually. The plugin is for OTHER Brite properties + future projects. Brand Hub Linear project id `61d8cd9b-67ba-4e62-b474-81d9ccf36d31`, lead Sarah Cullen, 27 milestones (mix of Phase-pattern legacy + domain-flavored).

**Clone-and-swap from workflows plugin (NOT integrate).** FDA plugin is self-contained inner loop. **Clone what differs (3 commands per Q50 sub-decision 2 user lock 2026-05-07):** session-start, review, ship → FDA `/flow:session-start` (Q51 LOCKED), `/flow:review` (Q52 LOCKED), `/flow:ship` (Q53 LOCKED). **Reuse what's identical (corrected per Q50 amendment 2 user lock 2026-05-07):**
- **DIRECT REUSE (6 items):** `git-worktrees` skill + `executing-plans` skill + `verification-before-completion` skill + `code-review` command + `brainstorming` skill + `writing-plans` skill — FDA-cloned commands explicitly orchestrate as primary purpose
- **TRANSITIVE REUSE (3 skills + 15 agents per Q50 amendment 2):** `compound-learnings` + `best-practices-audit` + `handbook-drift-check` skills (invoked via Q53 ship.md preserved Steps 4/5/6); 15 workflows agents (invoked via Q52 review.md preserved Step 4 dispatch). See Q50 amendment 2 entry for full classification.

Dogfood end-to-end before any graduation decision. **NO modifications to the workflows plugin in v1.** _Memory:26 superseded by Q50 lock 2026-05-07 + Q50 amendment 2 lock 2026-05-07: original sketch had "clone brainstorming + writing-plans"; Q30.2 surface authority + Q50 sub-decision 3 user lock confirmed REUSE both; Q50 amendment 2 surfaced TRANSITIVE REUSE classification gap caught at Q53 drafting via parking-lot-#39 extension methodology. Stale reference corrections: "worktree" → "git-worktrees"; "code-review" clarified as command (not skill)._

## Locked decisions (Q1-Q12 + Q22-Q28 + meta-Q autoplan-recurrence)

**Q1 — Domain-as-Milestone is primary; Phase-as-Milestone is variant.** Domain milestones default for UI-bearing software Builds. CDR-014 needs amendment, not supersession.

**Q2 — Codification shape `a + c + d + e`.** (a) CDR-023 "Flow-Driven Architecture for UI-Bearing Builds"; (c) operating-standards page at `handbook/how-we-work/operating-standards/flow-driven-architecture.md`; (d) promoted templates at `handbook/about-handbook/style-guide/templates/`; (e) plugin quality gates.

**Q2 amendment 1 — about-handbook is subdirectory of handbook, NOT separate repo (LOCKED 2026-05-10, drafter D session per Step 2.B pre-flight catch).**

**Original Q2 lock content** referenced FDA promoted-templates target as `about-handbook/style-guide/templates/` and elsewhere `Brite-Nites/about-handbook` — implying about-handbook was a separate repository at the Brite-Nites org level.

**Catch event:** Step 2.B pre-flight `gh api repos/Brite-Nites/about-handbook` 2026-05-10 returned 404. Subsequent enumeration `gh api orgs/Brite-Nites/repos --paginate` confirmed Brite-Nites org has NO `about-handbook` repository. Recursive tree search of `handbook` repo via `gh api repos/Brite-Nites/handbook/git/trees/main?recursive=1` revealed `about-handbook/` is a SUBDIRECTORY of the existing `handbook` repo. Real path: `Brite-Nites/handbook/about-handbook/style-guide/templates/`. Same-day-lock conflict undetected during Q2 drafting because parking-lot-#39 cribbing-verification discipline was not yet established at 2026-05-06 (Q48 lock established the discipline at 2026-05-07; first execution-phase Step 2.A application caught CDR-022 collision; second execution-phase Step 2.B application caught about-handbook subdirectory).

**Renumber/repath applied:** all `about-handbook/style-guide/templates/` path occurrences in memory bulk-renamed to `handbook/about-handbook/style-guide/templates/` via Edit replace_all 2026-05-10. URL form `https://github.com/Brite-Nites/about-handbook/tree/main/style-guide/templates/` bulk-renamed to `https://github.com/Brite-Nites/handbook/tree/main/about-handbook/style-guide/templates/`. Affected lock entries (cascading amendments cross-linked to this Q2 amendment 1 as canonical rationale): Q22 amendment 1 (Lives-at path), Q28 amendment 1 (Lives-at path), Q41 amendment 1 (Lives-at path), Q33 amendment 2 (sub-decision 3 path + sub-decision 6 URL), Q34 amendment 2 (sub-decision 5 path).

**Cascading effect on shipped artifacts:** CDR-023 + operating-standards FDA page (PR #513 commit `3dd9dda`) shipped with absolute URLs `https://github.com/Brite-Nites/about-handbook/tree/main/style-guide/templates/` — URLs that 404. Fix-commit pushed to PR #513 branch 2026-05-10 correcting URLs to `https://github.com/Brite-Nites/handbook/tree/main/about-handbook/style-guide/templates/` form.

**Schema-evolution discipline reinforced:** Q2 amendment 1 follows Q31 amendments 1+2 + Q24 amendment 1 + Q21 amendment 1 + Q50 amendments 1+2 + Q33/Q34/Q35 amendments 1 precedent — explicit amendment-number + audit trail in originating Q-lock; cross-link to companion amendments (Q22/Q28/Q33/Q34/Q41 amendments) which inherit the audit-trail context. Total amendment count after this remediation: **16 amendments** (Q31 amend 1+2, Q24 amend 1, Q21 amend 1, Q50 amend 1+2, Q33 amend 1, Q34 amend 1, Q35 amend 1, **Q2 amend 1, Q22 amend 1, Q28 amend 1, Q41 amend 1, Q33 amend 2, Q34 amend 2, Q49 amend 1**).

**Methodology lesson recorded (parking-lot-#39 second execution-phase extension):** the namespace-collision discipline applies not only to (a) external cribbed sources [original parking-lot-#39] and (b) org-level artifact namespaces with parallel claimants [Q33/Q34/Q35 amend 1 catch — duplicate CDR numbers], but also to (c) **assumed-existing org-level artifacts that don't actually exist** AND (d) **assumed-separate repos that are actually subdirectories of larger repos**. Drafter D Step 2.B pre-flight catch (about-handbook = subdir-not-repo) extends parking-lot-#39 with this third extension; recorded in parking lot #39 below.

**Q3 — New `flow-architecture` plugin** in own slot. Parking lot: re-evaluate workflows-plugin split later.

**Q4 — V1 = Option D (FDA fully independent).** No `/workflows:project-start` integration in v1. Future v2 = Option A handoff.

**Q5 — Inventory at `docs/product/master-flow-inventory.md`** in the project's repo. No Linear mirror.

**Q6 — Three inventory skills at v1:** `flow-inventory-interview`, `flow-inventory-codebase-scan`, `flow-inventory-add`.

**Q7 — Orchestrator-as-skill pattern**, modeled on compound-engineering's lfg + ce-optimize. Orchestrators are SKILLS with `disable-model-invocation: true`. Sub-skills NOT user-invocable. Gates are filesystem-artifact-existence checks, NOT LLM self-report. Resume support copies ce-optimize: `.flow-phase-state.json` breadcrumb + per-phase artifact markers + write-then-verify.

**Q8 — V1 MVP = full surface (collapsed v1.0+v1.1).** All slash entries, all sub-skills, all 9 agents, richer quality-gate stack — all ship in v1. Per-phase artifact-existence gate mandatory. Resume-via-breadcrumb mandatory. Acceptance test = `/flow:retrofit-project` end-to-end against Brand Hub.

**Q9 (revised) — Retrofit is additive-only with cross-reference annotations.** Existing milestones/issues left untouched. New FDA-shape created from scratch. Cross-reference appendices (`## FDA migration` section) on legacy milestones. Milestone-level granularity for v1; issue-level deferred to v1.1. In-flight work follows policy (a): finish where you are, new work in new structure. Implemented by `flow-legacy-cross-reference` sub-skill.

**Q10 — High-stakes user-confirmation cadence (B).** 5 pauses for retrofit / 4 for greenfield. Terse cross-reference review document.

**Q11 — `/flow:inventory` 6-phase architecture.** Phase 0: read PROJECT-INTENT.md as priority filter. Phase 1: app-classifier interview (shared utility used by both retrofit and greenfield). Phase 2: pattern-driven candidate generation (WebSearch + pattern catalogs + agent SaaS knowledge). Phase 3: deterministic code scan (Glob/Grep/Read for routes, server actions, dialogs, menu items, API endpoints — Next.js App Router). Phase 4: synthesis with status tags (`implemented` ✓ / `partially-implemented` ⚠ / `missing-but-recommended` ✗ / `implemented-no-pattern-match` ?) + value-priority. Phase 5: user confirmation. Pushback resolutions: framework=Next.js for v1, evidence-anchors per candidate, agent-proposes-but-user-overrides slugs, fewer-larger-flows bias, thin-code fallback redundant.

**Q12 — `flow-preflight` internals (LOCKED 2026-05-06).** Five responsibilities:

1. **Environment checks (fail-closed):** Linear MCP reachable (list_projects limit:1), repo root detected, `docs/product/` exists or offer to bootstrap, `gh` auth soft-warn.
2. **FDA-artifact discovery (read-only):** scan for `docs/product/intent.md`, `master-flow-inventory.md`, `flows/INDEX.md`, `flows/<domain>/*.md`, `journeys/<domain>.md`, `docs/plans/.flow-phase-state.json`.
3. **Mode classification — 4 modes:** `greenfield` / `retrofit` / `incremental-add` / `resume`. Edge: intent + inventory + zero-domains-with-full-FDA → `retrofit`. Stale breadcrumb (>7 days or completed) → offer discard, fall through.
4. **Linear scope confirmation + persisted config:** read `.flow/config.json` if exists → skip user gate; else AskUserQuestion → write `.flow/config.json` on success (committed, team-shared). v1 fields: `linear_project_id`, `linear_project_name`, `linear_team_key`, `fda_first_setup_at`, `fda_plugin_version`. Stale config (project ID no longer resolves) → warn, re-prompt, update. Parking-lot fields v1.1+: `preferred_mode_override`, `app_classifier_cache`, `last_inventory_regen_at`, `linear_team_id` (UUID).
5. **Output:** structured preamble echoed into LLM context (gstack pattern) — MODE / LINEAR_PROJECT_ID / LINEAR_PROJECT_NAME / REPO_ROOT / INTENT_EXISTS / INVENTORY_EXISTS / FLOWS_DIR_EXISTS / BREADCRUMB_EXISTS / GH_AUTH / LINEAR_MCP. Downstream sub-skills read this rather than re-running discovery.

Read-only EXCEPT `.flow/config.json` write on first successful confirmation.

**Q13 — `flow-linear-scaffold` internals (LOCKED 2026-05-06).** Heaviest-mutation skill; per-domain footprint = **2 + 7N writes** (1 milestone create + N parents + 5N children + N Children-summary comments + 1 milestone description refresh after all sub-flows complete). Five sub-decisions:

1. **Mutation order:** per-sub-flow execution unit, per-domain preview/approval. Per sub-flow: parent → [Story] → ([Design] || [Eng] in parallel) → [QA] → [Docs] → Children-summary comment. After all sub-flows complete: refresh milestone description Sub-flows table via save_milestone. blockedBy chain per templates: [Story] foundation (no blockedBy); [Design] blockedBy [Story]; [Eng] blockedBy [Story]; [QA] blockedBy [Eng]+[Design]; [Docs] blockedBy [QA]. **Execution graph: [Story] → ([Design] || [Eng]) → [QA] → [Docs]** — Design and Eng parallelize AFTER Story exists, not from the start.

2. **Idempotency (3 layers):** L1 `.flow/scaffold-log/<domain>.md` append-only log (cheap resume cache; no Linear reads); L2 per-sub-flow `list_issues({labels: ["domain:<slug>"], title contains "<DOMAIN-NN>"})` lookup at sub-flow start (catches manual creates outside plugin); L3 MCP error row flag (errored rows skip re-issue).

3. **Per-issue fidelity-review:** 100% coverage, background dispatch (`Agent(general-purpose, run_in_background: true)`), sub-flow-boundary collection (every 6 issues). Diff live Linear body vs rendered template + L3 review summary; PASS or top-5 drift findings <150 words. FAILs fixed via `save_issue {id, body:...}` + re-dispatch review on fixed version. Pattern from `feedback_bulk_create_review_agents.md`.

4. **User-confirmation gates:** 1 mandatory gate (pre-scaffold preview); conditional gates for failure recovery only. L3 reviews per Q23 mod 2 fire INSIDE scaffold but BEFORE the preview gate, so their per-discipline headlines populate the parent's `## L3 review summary` section in the rendered preview.

5. **Failure recovery:** sub-flow-atomic with classified retry. **Transient** (timeout, rate-limit) → 1 retry + 2s backoff → permanent if persists. **Permanent** (invalid label, missing project membership, malformed markdown rejected by Prosemirror, fractional estimate's `auth_invalid`) → abort sub-flow → `AskUserQuestion`(Retry sub-flow / Skip sub-flow + continue domain / Halt). **Cascading** ([Story] failed → [Eng] blockedBy unresolvable) → treat as permanent; NEVER proceed with empty blockedBy (would produce broken Linear state).

Preview time-budget for the gate UX: `(2+7N) × ~500ms` — N=10 ≈ 36s; N=30 ≈ 106s. Cadence linear-housekeeping is the closest precedent (preview-all → one-approval → execute → log + pre-flight reads).

**Q14 — `flow-legacy-cross-reference` internals (LOCKED 2026-05-06).** Retrofit-only sub-skill (NEVER invoked from greenfield). Satisfies Q9's "additive-only with cross-reference annotations" lock. Per-domain footprint = `M × 2 × ~500ms` ≈ ~27s for M=27 legacy milestones (1 `get_milestone` + 1 `save_milestone` per legacy milestone). Six sub-decisions:

1. **Mapping determination — 3-tier cascade.** Tier 1 flow-ID histogram (parse legacy issue bodies for `\b[A-Z]{2,5}-\d{2,3}\b`, cross-check master-flow-inventory.md, top 1-3 domains by frequency, threshold 0.6 — degenerate for v1 retrofits like Brand Hub since the project hasn't adopted FDA flow-IDs yet, but kept for future-state). Tier 2 title-fuzzy (Levenshtein/token-overlap, threshold 0.6). Tier 3 LLM semantic-mapping fallback (Agent general-purpose, parallel across unmatched milestones, returns `{domains: [...], confidence, rationale}` JSON or null). Tier 3 is NOT authoritative — output seeds the Q14.6 review doc; user is final arbiter. Review-doc "Source signal" column shows which tier produced each proposal. **Wall-time estimate** (revised at lock time 2026-05-06): theoretical max ~27 parallel calls × ~5-10s ≈ ~10s assumes unlimited concurrency; in practice fan-out caps at 6-10 concurrent → 20-50s for all 27. But most milestones hit Tier 2; Tier 3 realistically fires for 5-10 fall-throughs only → **~5-15s actual** for Brand Hub-shaped retrofit. Re-measure once skill is built — see parking lot.

2. **Appendix format — HTML-comment-bracketed `## FDA migration` section.** Markers `<!-- FDA-MIGRATION-START -->` / `<!-- FDA-MIGRATION-END -->` are the idempotency mechanism (re-running rewrites between markers; never touches outside). Section contains: CDR-023 + operating-standards links as **absolute GitHub URLs** (`https://github.com/Brite-Nites/handbook/blob/main/...` — relative paths don't resolve from Linear in a different repo); coverage table (FDA domain | one-line summary | Linear milestone link); policy (a) callout; `Generated by ... on <ISO-8601>` footer. Template includes TODO comment for future GitBook migration. Numbered/bullet hybrid avoids Linear MCP markdown bullet-truncation gotcha. Post-write `get_milestone(id)` spot-check for Prosemirror mangling (per Q13.5 pattern).

3. **Mutation order — preview → review-doc gate → execute serial.** No parallelism; 27 writes serial at ~500ms each ≈ 14s execute (plus ~14s pre-write `get_milestone` reads = ~27s total). Each `save_milestone` is independent.

4. **Idempotency — marker-based only; NO scaffold-log analog.** Pre-write `get_milestone(id)`. If `<!-- FDA-MIGRATION-START -->` present → rewrite content between markers (replace section). If absent → append section to end of description. Linear-side state IS the persistence layer. 27 milestones × 2 MCP calls × ~500ms ≈ ~27s overhead acceptable.

5. **Failure recovery — cadence "log + continue" pattern.** Each `save_milestone` is independent (no chains). On error: transient → 1 retry + 2s backoff; permanent → log + continue to next milestone. NO sub-flow-atomic (legacy milestones aren't dependency-graph-shaped). End-of-run summary surfaces errored rows; user can re-run skill (idempotent) to retry just the failures.

6. **User-confirmation gate — literal markdown review document at `docs/plans/<retrofit>-cross-reference.md`.** Front-matter has `last_reviewed: TBD` blocker; skill **refuses to execute** until user bumps to ISO-8601 date. This makes review-completion an unambiguous filesystem check, not a chat-ack. Two-pass execution: (1) skill generates the doc with proposed mapping; (2) user reviews + edits inline; (3) user re-invokes skill to execute, which reads the (possibly user-edited) doc as source of truth. Doc is one of the 5 Q10 retrofit gates ("terse cross-reference review document"). Deletable post-retrofit (it's a `docs/plans/` artifact).

**Q15 — `flow-doc-author` internals (LOCKED 2026-05-06).** Per-domain story doc authoring sub-skill. Output: N markdown files at `docs/product/flows/<domain>/<flow-id>.md`, one per sub-flow, conforming to Q27 locked template. Triggered by `/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`. **Runs AFTER `flow-linear-scaffold`** so `parent_issue` + `children.*` BC numbers are available for substitution. Seven sub-decisions:

1. **Authoring strategy — hybrid.** Programmatic substitution for **17 deterministic top-level YAML keys** (per Q27 lock with mod 1's `intent` field counted) + **2 deterministic body items** (H1 title from `<DOMAIN-NN>: <Inventory title>`; doc-type-warning blockquote from template boilerplate). Agent-authored for **8 narrative sections**: one-line summary blockquote, optional `## Status notes` (Q27 mod 2), `## Job story` (When/I want/So I can JTBD format), `## Actor` (RBAC + persona doc cross-link), `## Preconditions` (≤3 bullets), `## Acceptance criteria` (3-5 Gherkin), `## Out of scope`, `## QA history` initial empty row. Deterministic substitution sources: `flow_id` (inventory), `domain` (flow_id prefix), `status` (inventory OR Q15.7 code-evidence capped at BUILT), `parent_issue` (scaffold), `children.story|engineering|design|qa|docs` (scaffold), `personas` (inventory), `related_flows` (inventory adjacency), `figma` (TBD), **`sandbox_url` (Q15.7 code-evidence scan when status > NOT_STARTED, else TBD — NOT inventory Notes column, which holds component names like `edit-role-dialog`)**, `staging_url`/`real_app_url`/`e2e_test`/`user_docs_url` (TBD), `qa_status` (`not-tested`), `qa_last_signed_off` (`null`), `last_reviewed` (current ISO-8601), `intent` (`../../intent.md` per Q27 mod 1).

2. **Dispatch pattern — parallel background.** One `Agent(general-purpose, run_in_background: true)` per sub-flow; skill collects at sub-flow completion. Wall time: ~30-60s for any N (vs 4-8 min serial for N=8). Each agent receives skeleton with TBD markers for narrative + Q27 template + persona doc + journey doc + inventory row + code-evidence (if status > NOT_STARTED).

3. **Idempotency — skip-if-exists + `--force`.** Pre-write check per sub-flow path; if exists, skip and summarize at end. `--force` overwrites; per-doc `AskUserQuestion` in interactive mode.

4. **Fidelity-review — 2-layer.** Mechanical: `bash scripts/verify-docs.sh` once after batch (logs but does not block). Narrative: per-doc background fidelity-review agent diffing against Q27 template + persona + journey + inventory row + code-evidence; PASS or top-3 narrative drift findings <100 words. Same pattern as Q13.3.

5. **Failure recovery — log + continue.** Story docs independent; agent failure doesn't cascade. Failed-doc surfaces in summary; user re-runs skill (idempotent) on failures. Same as Q14.5.

6. **User-confirmation gates — 0 synchronous gates.** Filesystem mutations reviewable post-hoc via `git diff` + `verify-docs.sh` + commit/PR review. Linear writes (Q13) need sync gates because team-visible immediately; markdown files in branch aren't. **Pattern rule:** Linear writes = sync gate; filesystem writes = git review gate. Contributes 0 to Q10's 5/4 gate budget.

7. **Retrofit code-evidence — deterministic per-sub-flow scan when inventory status > NOT_STARTED.** Glob/Grep/Read targeted at feature folders (`src/components/<domain>/`, `src/app/(frontend)/(app)/<route>/`, `src/payload/collections/<collection>.ts`). Extract: existing AC scenarios from `*.test.ts` files, component file paths, sandbox URL from `src/components/sandbox/sandbox-nav.tsx`. **Mapping caps at BUILT:** code-exists+tests+sandbox-URL → BUILT; code-exists-but-incomplete → IN_PROGRESS; no-code → NOT_STARTED. **Cannot promote to QA_SIGNED_OFF** (requires Linear QA child sign-off — workflow event, not codebase state). **Cannot promote to SHIPPED** (requires customer-doc filesystem signal at `docs/product/customer-docs/<domain>/<flow-id>.md` — scoped out of code-evidence; v1.1 candidate). Status drift from inventory flagged in `## Status notes` section (e.g., "BUILT — code-evidence cited; inventory marked NOT_STARTED — recommend reconcile") rather than silently overwriting. BriteBase Cut 1a "BUILT — code-evidence cited" pattern (TEAM-01..06 precedent).

Per-domain footprint: greenfield N=10 ≈ ~60s end-to-end. Retrofit with code-evidence ≈ ~90s end-to-end. Status taxonomy verified against `docs/product/master-flow-inventory.md:22-27`, `docs/product/flows/INDEX.md:15-20`, `docs/templates/job-story.md:4` — all enumerate `NOT_STARTED → IN_PROGRESS → BUILT → QA_SIGNED_OFF → SHIPPED` + BLOCKED orthogonal; no `PARTIALLY_BUILT` state.

**Q16 — `flow-journey-author` internals (LOCKED 2026-05-06).** Per-domain journey doc authoring sub-skill. Output: ONE markdown file at `docs/product/journeys/<domain>.md`, conforming to Q26 locked template (variable phase count per Q26 mod 5; ~290-450+ lines based on TEAM precedent at 447 lines). Triggered by `/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`. **Runs AFTER `flow-doc-author`** so story docs are available as authoring context. Eight sub-decisions:

1. **Authoring strategy — hybrid.** Programmatic substitution for **8 deterministic top-level YAML keys** (Q26 base 7 + mod 1's `intent`): `domain` (inventory section), `milestone` (scaffold output BC-XXXX), `personas` (deduplicated from inventory rows OR personas/INDEX.md), `flow_ids_in_scope` (inventory domain section row IDs), `status` (`in-progress` initial — describes doc authoring lifecycle, NOT delivery state), `figma` (`TBD`), `last_reviewed` (current ISO-8601), `intent` (`../intent.md` per Q26 mod 1). Plus **2 deterministic body items**: H1 title `# <DOMAIN> — <Display name>`; doc-type blockquote (~3 lines from template `:12-14`). **Single Agent call** for **7-9 narrative sections**: 7 always-required (`## Actor / Persona`, `## Scenario + Expectations`, `## Journey phases` with N variable sub-phases, `## Out of scope`, `## Related domains and cross-scenario journeys`, `## Open questions`, `## See also`); 1 sometimes-included (`## Decision points` — skip if linear journey); 1 optional (`## L2 review summary` per Q26 mod 2 — populated only if L2 review ran for this domain per meta-Q lock, capturing CEO + Design perspectives). Per phase: `*Persona:*` line + `*Mindset:*` line + 2-paragraph narrative + `**Pain points:**` bullets + `**Opportunities:**` bullets + Job stories table referencing real flow IDs. **Single agent (not multi-agent staged)** preserves cross-phase narrative continuity. Multi-agent-staged authoring parked v1.1 if domain bloats past context limits.

2. **Dispatch pattern — 1 agent per domain; parallel across domains for multi-domain scaffolds.** `/flow:add-domain` (1 domain) ≈ ~60-90s wall. `/flow:start-project` + `/flow:retrofit-project` (multi-domain) ≈ ~60-90s wall regardless of N (parallel).

3. **Idempotency — skip-if-exists + `--force`.** Same as Q15.3.

4. **Fidelity-review — 2-layer.** Mechanical via `bash scripts/verify-docs.sh`; narrative via per-doc background fidelity-review. Journey-specific drift checks added to reviewer prompt: phase count > 0; each phase has required sub-structure (persona / mindset / narrative / pain points / opportunities / job stories table); job stories table references real flow IDs (no fabricated); status values match canonical taxonomy; cross-scenario journey references resolve OR are explicitly TBD.

5. **Failure recovery — log + continue.** Same as Q15.5.

6. **User-confirmation gates — 0 synchronous gates.** Filesystem write; git review is the implicit gate. Contributes 0 to Q10's 5/4 budget. Same as Q15.6.

7. **Authoring context.** Per-domain agent prompt receives: Q26 template path, inventory section block for the domain, all N story docs at `docs/product/flows/<domain>/*.md` (authored by flow-doc-author in prior step), persona docs for in-scope personas, PROJECT-INTENT.md, Linear milestone description from scaffold output, optional L2 review summary if `state.l2_review_<domain>` exists. Story-docs-as-context is what makes journey synthesize across flows (TEAM cut-1a-then-cut-1b precedent).

8. **Ordering constraint.** Serial — flow-journey-author runs AFTER flow-doc-author, NOT in parallel. Per-domain pipeline: flow-linear-scaffold → flow-doc-author → flow-journey-author. Even greenfield NOT_STARTED stubs confirm flow IDs + personas + related_flows for journey author. Uniform ordering simplifies orchestrator; ~60s parallelism savings on greenfield doesn't justify conditional ordering against ~5min/gate human review time in retrofit.

Per-domain footprint ≈ ~90s end-to-end. Brand Hub-shaped 27 domains in parallel ≈ ~90s wall total. **L2/L3/L4 review-summary routing** (clarified at lock time): L2 → journey doc (Q16 mod 2); L3 → parent issue body (Q23 mod 2); L4 → discipline child (single-discipline plan-X, NOT autoplan per meta-Q).

**Q17 — `flow-sandbox-scaffold` internals (LOCKED 2026-05-06).** Per-flow sandbox harness scaffolding sub-skill. **Scope semantic LOCKED at per-flow on-demand from L4 workflows** (Option B), superseding the original TEAM-precedent-based "one harness per QA-cycle target" line in the Internal architecture section (see parking lot #20). **L4 scope** — invoked from inside the [Eng] discipline child workflow (engineer-initiated via `/flow:plan-eng`) OR by `/flow:plan-qa` pre-flight if `/sandbox/<flow>` doesn't exist when QA starts. Per-flow scope, not per-domain. **Outputs functional code** (not markdown) — verification is build/lint/test, not fidelity-review. Outside Q10's 5/4 orchestrator gate budget (L4 has its own per-skill interactions). Boundary clarification: the existing `/backend-handoff`, `/frontend-handoff`, `/handoff-audit` slash commands cover sandbox↔app **Linear-issue creation**; Q17 is the **harness-code creator** — different scope. Ten sub-decisions:

1. **Invocation context.** L4 scope, per-flow; triggered by `/flow:plan-eng` or `/flow:plan-qa` pre-flight. Not per-domain at scaffold time.

2. **Three modes determined by code-evidence scan** (reuses `_shared/code-evidence-collector.md` from parking lot #18): **EXTRACT** mode when `<FeaturePage>` exists at `src/app/(frontend)/(app)/<route>/page.tsx` AND no `<FeatureView>` at `src/components/<feature>/` (refactor Page → View + Page-wrapper, then create sandbox harness wrapping View); **WRAP** mode when `<FeatureView>` already exists (just create sandbox harness wrapping existing View; no app-code mutation); **STUB** mode when no app code exists yet (greenfield NOT_STARTED — create placeholder page + nav entry, "TBD per [Eng] child BC-XXXX"). Maps to Q15.7 status taxonomy: BUILT/IN_PROGRESS with View → WRAP; BUILT/IN_PROGRESS without View → EXTRACT; NOT_STARTED → STUB.

3. **Component extraction (EXTRACT mode only).** Single Agent call + mandatory pre-extraction sync gate. Workflow: (a) read `<feature>-page.tsx` → identify presentation vs. handler logic → compute extraction plan; (b) `AskUserQuestion` gate with three options — Approve refactor / Skip → fall through to STUB / Cancel; (c) on approve, agent writes new `<FeatureView>` + rewrites Page as wrapper (matches BriteBase TEAM-04 / `UserListView` precedent per CLAUDE.md "Sandbox flows import existing pages"); (d) `npm run build` post-refactor; on fail, surface error + roll back via git stash if dirty.

4. **Sandbox harness shape — three templates.** WRAP/EXTRACT-after-refactor template: `"use client"` + `useState` over seed const + seed-mutating handlers that mirror server-side guards (each `toast.info`s "Sandbox — <action>" + mutates local state) + `<FeatureView>` rendered with handler props. STUB template: placeholder rendering "TBD per [Eng] child BC-XXXX" with Linear link. Optional View-as selector sub-template added when role-based AC requires it (detected by scanning AC scenarios in story doc for role-conditional language OR handler logic for role-gated branches; per TEAM-04 cut-3 precedent).

5. **Seed-gap policy — `requireSeedField()` runtime assertion (LOUD signal, not silent TODO).** Skill compares View's prop shape (TypeScript types) against seed constant's shape. For each gap, auto-generates a `requireSeedField(seedSample.<field>, "<TypeName>.<field>")` call at the top of the harness body. Pattern:
   ```tsx
   function requireSeedField<T>(value: T | undefined, field: string): T {
     if (value === undefined) {
       throw new Error(`Seed gap: ${field} missing from @/mocks/seed. Extend the seed schema before this harness can render.`);
     }
     return value;
   }
   ```
   Throws at route-render if seed schema regresses; survives optional View prop types (compiles cleanly, lint passes, runtime throws). Skill summarizes seed-gap assertions at end of run so they're visible. **Does NOT auto-extend seed** — schema is a cross-domain decision; `requireSeedField()` calls block runtime until human decides + extends.

6. **Sandbox-nav update.** Auto-append entry to `src/components/sandbox/sandbox-nav.tsx`. Mechanical id/label/href/icon (best-match Phosphor icon from `@phosphor-icons/react/dist/ssr`, default `<Square>`). Auto-detects `SidebarSubgroup` by domain (`screens/<lowercase-domain>` if exists, else creates new subgroup). Idempotent on re-run via id-match.

7. **Idempotency.** Skip-if-exists + `--force`. Pre-write check on page file path AND nav-entry id.

8. **Verification.** Run `npm run build && npm run lint && npm test` after harness creation. **Skip per-doc fidelity-review agent** — harness is code, not narrative; drift modes (compile fails, type errors, lint failures, test regressions) are caught by the build pipeline. Per-doc fidelity-review (Q15.4/Q16.4) would be overkill.

9. **Failure recovery.** Per-flow log + continue. EXTRACT-mode failures (Page logic too intertwined to cleanly split) fall through to STUB mode + flag for manual; flag captured in scaffold log. Build-failure on EXTRACT mode triggers git-stash rollback before the user gate result is committed.

10. **User-confirmation gates — 1 conditional gate (EXTRACT mode only — Q17.3); 0 for WRAP / STUB.** L4 scope, doesn't count against Q10's 5/4 orchestrator budget.

Per-flow footprint: STUB ≈ ~5s; WRAP ≈ ~10-30s; EXTRACT ≈ ~30-90s + user gate review time + build/lint/test pass.

**Q18 — `flow-regen-index` internals (LOCKED 2026-05-06).** Deterministic INDEX.md rebuild from story-doc front-matter + Linear discipline state. Regenerates 11-column table rows per Q25 schema; preserves section headers, status notes, footnotes, intro prose. **No `Agent` dispatch, no fidelity-review** — deterministic algorithmic output, not narrative. Triggers: `/flow:regen-index` (user-invocable), auto-invoked at end of `/flow:add-domain` + `/flow:add-sub-flow`, auto-invoked by `/flow:ship` after story-doc front-matter edit. Per-regen footprint ≈ ~14s Linear batches + ~1s parse/write ≈ ~15s end-to-end for Brand Hub-shaped 28 domains. Eight sub-decisions:

1. **Source of truth.** Reads: (a) story docs at `docs/product/flows/<domain>/*.md` front-matter (`status`, `parent_issue`, `children.*`, `figma`, `sandbox_url`, `staging_url`, `real_app_url`, `qa_status`, `user_docs_url`, `flow_id`); (b) `master-flow-inventory.md` for canonical section order + flow titles (foreign-key registry — never trust story-doc title); (c) `docs/product/journeys/<domain>.md` front-matter `milestone:` field for section-header link; (d) Linear via batched `list_issues({labels: ["domain:<slug>"]})` per domain for Eng + Design state; (e) `.flow/config.json` for `<PROJECT_NAME>` placeholder + `linear_project_id` for milestone URL construction.

2. **Parser mechanism.** Column-header-signature-based table parser: regex match `| ID | Flow | Status | Story | Parent | Eng | Design | QA | Docs | Figma | Live |` (whitespace-tolerant); identify table boundaries (header row → separator row → contiguous data rows → terminator blank line OR `##` heading); replace ONLY data rows. Preserves section headers, status note paragraphs, footnotes, intro prose verbatim. Updates `(N sub-flows)` parenthetical in immediately-preceding `## DOMAIN` section header (table-derived). Anti-pattern explicitly avoided: regenerating entire file from scratch (would clobber hand-curated content like INDEX.md:62's "TEAM-04 status note").

3. **Per-column derivation (all 11 columns)** — 2 text + 1 taxonomy-string + 4 link + 4 emoji:
   - **ID** (text): `flow_id` cross-validated against master-inventory row ID
   - **Flow** (text): master-inventory row's title (canonical — never trust story-doc title)
   - **Status** (taxonomy-string): front-matter `status:` verbatim
   - **Story** (link): `[📄](./<domain>/<flow-id>.md)` relative path; missing → `⏳`
   - **Parent** (link): `[BC-XXXX](https://linear.app/<workspace>/issue/BC-XXXX)` from front-matter `parent_issue` + `.flow/config.json` workspace; `TBD` → literal
   - **Eng** (emoji): Linear batched `list_issues` → match `children.engineering` BC; `state.type=="completed"` → ✓; `started` → 🚧; `unstarted/backlog` → ⏳; `canceled` or `blocked` label → ❌; missing/`TBD` → —
   - **Design** (emoji): same Linear batch + same mapping; matched by `children.design` BC
   - **QA** (emoji): front-matter `qa_status:`; `signed-off` → ✓; `rework-needed` → 🚧; `not-tested` → ⏳; `blocked` → ❌; missing → —
   - **Docs** (emoji): front-matter `user_docs_url:`; non-TBD path → ✓; `TBD` → ⏳; explicit `blocked` → ❌; missing → —
   - **Figma** (link): non-TBD URL → `[frame](<figma-url>)` (per INDEX.md:78 sample); literal `TBD` → render `TBD`
   - **Live** (link): URL fallback chain `sandbox_url` → `staging_url` → `real_app_url` (sandbox-first per TEAM-04 precedent + template comment "real_app_url populated for SHIPPED flows post-auth-restoration"); first non-`TBD` → `[<path>](<path>)`; all three `TBD` → literal `TBD`

4. **Section header policy — two-mode dispatch + soft-warning.** **Refresh-rows-only** when `## <DOMAIN>` section EXISTS (preserves header text verbatim except parenthetical sub-flow count; replaces table rows). **Initial-create** when section MISSING (writes fresh section with Q25 mod 1 amended schema: `## <DOMAIN> — <Display name> · [📕 journey](../journeys/<domain>.md) · [📍 milestone](<linear-url>) · (<N> sub-flows)`). **Legacy sections preserved as-is** — does NOT auto-upgrade headers missing Q25 mod 1's emoji-prefixed links. **Post-regen soft-warning summary:** detection by emoji-prefixed-link-substring match (`[📕 journey](` AND `[📍 milestone](`); missing → emit warning to stdout listing each section that doesn't match: `INDEX.md sections not matching Q25 mod 1 schema (consider upgrading): - QUO — Quote Building (missing journey link, missing milestone link) - …`. `--force-upgrade-headers` flag for v1.1 (parking lot).

5. **Front-matter regen.** Add/refresh: `generated_at: <ISO-8601 datetime>`, `generated_by: flow-regen-index@<version>`, flip `generated: true` if `false`. `last_reviewed:` preserved (regen is mechanical, not a review event).

6. **`<PROJECT_NAME>` placeholder + PROJECT-INTENT reference (Q25 mods 5 + 2).** Substitute `<PROJECT_NAME>` from `.flow/config.json` `linear_project_name`. Ensure Q25 mod 2 PROJECT-INTENT reference paragraph exists in header — if present, preserve verbatim; if missing (legacy), one-time-add the sentence: `> See [PROJECT-INTENT.md](./intent.md) for the product intent that anchors every flow in this index.` Then preserve on subsequent regens.

7. **Failure recovery.** Per-flow: skip-row + comment marker `<!-- regen skipped <FLOW-ID>: <error> -->` so user sees the gap on next git diff. Linear-fetch transient: retry once with 2s backoff (Q13.5 pattern); on persistent fail → `?`-placeholder emojis + footnote `<!-- regen: linear lookup failed for domain X; rerun to refresh -->`. Don't abort whole regen for one bad doc.

8. **Idempotency / no-op detection / 0 gates.** Diff-aware: skill computes would-be-output, diffs against current INDEX.md (excluding `generated_at` field). If only `generated_at` would change → skill prints `"INDEX.md unchanged; skipping write to avoid timestamp churn."` and exits without writing. Avoids the "every regen produces a one-line timestamp diff" PR-noise problem; makes pre-commit-hook usage practical (parking lot). 0 synchronous gates per filesystem-write pattern.

**Q19 — `flow-inventory-interview` internals (LOCKED 2026-05-06).** Greenfield Socratic inventory generator. Output: `docs/product/master-flow-inventory.md` populated with proposed domains + flows. Triggered by `/flow:start-project` or standalone `/flow:inventory` when `flow-preflight` mode classifier returns `greenfield`. **Per-run footprint:** ~5-15 min Phase 1 interview (user-paced) + ~10-30s Phase 2 pattern-catalog generation + ~5s Phase 4 synthesis + user-paced Phase 5 review ≈ ~10-30 min end-to-end (mostly user time). **Critical relationship to Q11:** shares Phases 0/1/2/5 verbatim via `_shared/app-classifier-pattern.md` shared utility; differs in skipping Phase 3 (no code) + Phase 4 status taxonomy + heavier Phase 1 interview. Seven sub-decisions:

1. **Phase sequence — 5 phases.** Phase 0 (PROJECT-INTENT.md priority filter) → Phase 1 (app-classifier interview, shared) → Phase 2 (pattern-driven candidate generation, shared) → **[skip Phase 3 — no codebase to scan]** → Phase 4 (greenfield synthesis) → Phase 5 (user confirmation, shared). Skill explicitly logs the Phase 3 skip with rationale `"Greenfield mode: no codebase to scan; proceeding to synthesis from interview + pattern signals."` for audit trail.

2. **Phase 1 Socratic depth.** Shared `_shared/app-classifier-pattern.md` utility owns the base questions (framework, app category, primary persona shape, scale) — used by both Q11 and Q19. Q19 adds 4 greenfield-only follow-ups defined in `flow-inventory-interview/SKILL.md` itself (NOT in `_shared/`): (a) **domain envisioning** ("What top-level domains do you imagine? Examples: SaaS CRM = Contacts/Deals/Pipeline/Reports; installation business = Quotes/Properties/Crew/Routing/Billing"); (b) **flow-density-per-domain** ("Which domains will have heavy UI investment 10+ atomic actions vs admin-only ≤5?"); (c) **MVP sequencing** ("Which 2-3 domains are MVP-essential vs post-launch?"); (d) **persona density** ("How many distinct personas access this app? small SaaS = 1-2; multi-tenant CRM = 4-8; complex ops = 10+"). Phase 1 depth is dominant signal source for Q19 (vs. Q11 where code-evidence dominates).

3. **Phase 4 synthesis status tags — 3-tag scope-priority taxonomy.** Per-flow tag: `mvp` (must-have for v1; user flagged domain MVP-essential + flow is core to domain's primary user task) / `nice-to-have` (plausible v1 inclusion if scope permits; pattern-catalog-suggested but not user-flagged) / `post-launch` (out of v1 scope; user flagged domain post-launch OR pattern catalog flags as advanced). Rendered in **Notes column** alongside any pattern context (no new column needed; Status column stays blank per master-flow-inventory.md:18 lock). **Deliberate divergence from Q11 on Notes-column content type** (verified against BriteBase master-flow-inventory.md AUTH section `:42-52`): Q11 retrofit uses Notes for code-evidence anchors (route paths like `/login`, component names like `User-nav dropdown`, scope references like `Droidor scope (BC-5988)`); Q19 greenfield uses Notes for scope-priority tags because no code-evidence anchor exists yet. Both modes' Notes carry mode-appropriate context, but the content type differs by design.

4. **Output format.** Produces `docs/product/master-flow-inventory.md` matching the BriteBase schema (front-matter `last_reviewed: <ISO-8601>` + status block + top-level groupings + domain sections + per-domain table with columns `# / Flow / Status / Notes`). `<PROJECT_NAME>` substituted from `.flow/config.json` `linear_project_name`. Status column **left blank** per existing schema. `Status map: TBD` and `Journey: TBD` populated later by `flow-linear-scaffold`. **Top-level groupings derivation:** agent infers groupings during Phase 4 synthesis from domain semantics + pattern-catalog conventions (auth/tenancy/team → `PLATFORM FOUNDATIONS`; primary product domains → `CORE WORKFLOWS`; admin/reporting → `OPERATIONS`). Defaults are agent-proposed; user reviews + edits during Phase 5 confirmation. **Single-grouping fallback:** if user declines all proposed groupings (small project), emit a single `## CORE` grouping containing all domains.

5. **Idempotency — skip / interactive merge / `--force` overwrite.** Three scenarios: (a) **no existing inventory** → create from scratch (greenfield common case); (b) **existing inventory + skill re-run** → `AskUserQuestion` with three options — Skip (preserve existing) / Merge (add only newly-proposed flows under existing domains; preserve existing rows + Status column values) / Force overwrite (regenerate from scratch — destructive, requires confirmation); (c) **`--force` flag** bypasses interactive prompt; overwrites. Merge is natural for iterative greenfield discovery (Phase 1 reveals new domain after initial pass).

6. **Failure recovery.** Phase 1 interview-loop on clarification failures (max 2 retries per question; on third unclear answer → flag question as `skipped/needs-revisit` + continue). Phase 4 synthesis: insufficient signal to tag a flow → tag `nice-to-have` with Notes annotation `(unclear from interview — revisit at user confirmation)`. Phase 5 reject → skill exits cleanly; user re-runs after refining intent. Don't auto-iterate forever.

7. **User-confirmation gates — Phase 5 = 1 of Q10's 4 greenfield gates.** Within-Phase-1-interview `AskUserQuestion`s are interview-cadence interactions, NOT high-stakes orchestrator gates — don't count against Q10's budget. Phase 5 surface (matches Q11): preview proposed inventory rendered as output markdown; user can Approve as-is / Edit inline (slug overrides per Q11 pushback / move flows between mvp/nice-to-have/post-launch / drop flows) / Reject (exit; user refines intent).

**Q20 — `flow-inventory-add` internals (LOCKED 2026-05-06).** Lightweight inventory append skill. Triggered by `/flow:add-sub-flow` (single new flow under existing domain) and `/flow:add-domain` (whole new domain). Q47 (still pending) governs orchestrator-layer split between these; Q20 is the shared inventory layer they call into. **Per-run footprint:** sub-flow-add ≈ ~30s (mostly user prompt response); domain-add ≈ ~5-10 min (Q19-mini interview pace). **Critical relationship:** append-only semantics; never rewrites existing rows; never renames IDs (per CLAUDE.md "never rename existing IDs" + master-flow-inventory.md guardrail). Seven sub-decisions:

1. **Two modes dispatched by caller.** **sub-flow-add** (`/flow:add-sub-flow`): inputs target domain, optional flow_id (auto-suggested), title, primary persona, related_flows, Notes → template-fill prompt → append row → bump domain-section flow count. **domain-add** (`/flow:add-domain`): inputs proposed domain code + display name → scoped Q19-mini interview (Phases 1+4+5 for one domain only) → append new domain section under appropriate grouping. Mode determined by caller; standalone invocation `AskUserQuestion`s to pick.

2. **Flow ID auto-suggestion (sub-flow-add).** Parse target domain rows → find highest existing `<DOMAIN>-NN` → propose `<DOMAIN>-(N+1)` 2-digit zero-padded (matches `TEAM-08`/`AUTH-11`). **Split-suffix support** per CLAUDE.md: if user indicates "split of existing flow", offer `<DOMAIN>-NN-a`/`-b` instead of next sequential. Suggested ID rendered in confirmation prompt; user can override.

3. **Append mechanics.** Sub-flow-add: regex-locate target domain section by H3 header `^### <DOMAIN> — .* \(\d+ flows\)$` → locate table by column-header signature → find table terminator (next `### ` heading OR `---` boundary OR EOF) → insert new row before terminator → update H3 heading flow count. Domain-add: Q19-mini produces new domain block (H3 + metadata line + table) → determine top-level grouping per Q19.4 derivation → insert new domain block at end of grouping (before next `## ` heading OR `---`). Preserves all unrelated content verbatim.

4. **Idempotency — hard-reject on duplicate.** Sub-flow-add: if proposed `<DOMAIN-NN>` already exists → reject with clear error citing line number + suggesting split-suffix or next sequential + abort. Domain-add: if `<DOMAIN>` code already has a section → reject with "use /flow:add-sub-flow instead" + abort. No silent overwrite. Re-run safety: same-input re-run aborts identically (no half-state).

5. **Failure recovery.** Inventory parse failure → abort + surface line number; do NOT auto-repair (would risk silent data loss). User-cancel at confirmation gate → no write; clean exit. Domain-add interview clarification failures: max 2 retries per question (Q19.6 pattern). Single-output skill: a failure means that single output didn't land; orchestrator decides next steps.

6. **User-confirmation gates — 1 within-skill confirmation per mode; 0 orchestrator-budget gates.** Sub-flow-add: `"Add <DOMAIN-NN>: <title> under <DOMAIN> section as flow #<N>? Notes: <notes>. Approve / Edit / Cancel"`. Domain-add: matches Q19 Phase 5 surface (preview proposed section + flows; Approve / Edit inline / Reject). Incremental-add mode is outside Q10's 5/4 retrofit/greenfield gate budget per Q12 mode classification. Q47 (pending) decides whether the orchestrator adds gates beyond Q20's.

7. **Downstream regen trigger.** Q20 ends at the master-inventory edit. Per Q18's V1 surface: regen is auto-invoked at end of `/flow:add-domain`/`/flow:add-sub-flow` — that's the orchestrator's job. Q20 emits `state.inventory_changed = true` flag in orchestrator's state object so downstream `flow-regen-index` (and `flow-linear-scaffold` if applicable) can dispatch.

**Q20 amendment 1 — inventory-only-domain re-scaffold branch (LOCKED 2026-05-18 per BC-9971).** Q20 sub-decision 4 ("Idempotency — hard-reject on duplicate") locks the domain-add path to a binary outcome: `<DOMAIN>` either is absent from inventory (proceed with `flow-inventory-add` domain-add interview + write) or already has an H3 section (hard-reject with "use /flow:add-sub-flow instead" + abort). The Brand Hub iter-2 dogfood (BC-6998, 2026-05-13) created an intermediate state Q20.4 doesn't accommodate: iter-2 deliberately scoped the `/flow:retrofit-project` run to 1 domain × 1 sub-flow as a v1.0 demonstration, leaving the 9 remaining inventoried domains with H3 sections + sub-flow rows + status tags landed in `master-flow-inventory.md` but no Linear milestone, no journey doc, and no story docs authored. The 9 BC-9559 children (BC-9560..BC-9568) each said "Run /flow:add-domain for the `<domain>` domain" — but `/flow:add-domain` hits Q20.4's hard-reject because the H3 section is already there from iter-2's inventory phase. `/flow:add-sub-flow` doesn't fit either — that's for adding individual sub-flows to existing FDA-scaffolded domains, not for scaffolding the milestone + 5N children + journey doc + story docs against an inventoried-but-unscaffolded domain. The manual-orchestration fallback (read `commands/add-domain.md` as prose spec, run Phases 3-6 by hand) is validated end-state per the asset-foundation scaffold (2026-05-13) but is ~30-45 min per domain and not durable as the dogfood-product UX.

This amendment introduces a **filesystem-driven classifier** invoked by `/flow:add-domain` Phase 2 **before** dispatching `flow-inventory-add`. The classifier (`plugins/flow-architecture/scripts/flow-classify-domain-state.sh`) takes `<inventory-path> <flows-dir> <journeys-dir> <DOMAIN>` and emits one of four outcomes (the table below is canonical):

| Outcome | H3 in inventory | Journey doc present | Story docs present | Orchestrator behavior |
|---|---|---|---|---|
| `absent` | no | n/a | n/a | **Unchanged** — dispatch `flow-inventory-add` domain-add (Q19-mini interview + Q20.6 + append). Q20.4 hard-reject remains as the safety net inside the sub-skill for direct callers. |
| `inventory-only` | yes | no | n/a | **NEW** — skip Q19-mini interview. Parse the existing H3 section as canonical (sub-flow rows, status tags, persona). Q20.6 still fires with a different preview surface (the existing inventory section, not a freshly-drafted one). Approve → proceed to Phase 3. The orchestrator additionally queries Linear via `list_milestones` to confirm `FDA: <domain>` is absent; if present, log a drift advisory and proceed (Phase 3's milestone-create step is idempotent against `milestone_id` per the Resume contract). |
| `journey-exists` | yes | yes | no | **NEW** — surface an `AskUserQuestion` advising the user that journey doc exists but story docs are missing. Options: `Re-run Phase 4 only (story-doc author)` / `Re-run Phases 3-6 with --force (clobbers journey)` / `Cancel`. |
| `fully-scaffolded-fs` | yes | yes | yes | **NEW** — no-op-with-warning. Surface `AskUserQuestion`: `Domain '<DOMAIN>' already has journey doc + story docs on filesystem. Re-scaffold via --force?` Default: Cancel; on Cancel, breadcrumb `status: abandoned` with synthetic override row tagging `reason: 'already-scaffolded (Q20 amendment 1)'`. |

The `inventory-only` outcome is the load-bearing addition — it directly unblocks BC-9559's 9 children + any future iter-N retrofit-then-incremental-scaffold pattern. The `journey-exists` + `fully-scaffolded-fs` outcomes are defense-in-depth: they replace what would have been silent `flow-inventory-add` Q20.4 hard-rejects with explicit user-facing choices.

The Linear-milestone overlay (`FDA: <domain>` present? absent?) is the orchestrator's responsibility per Q32 — bash can't call MCP. The combined classification logic is documented inline in `commands/add-domain.md` Phase 2 prose. The classifier itself is filesystem-only and testable in isolation against the v-slice fixture pattern (BC-9971 ships three new fixtures + `tests/run-inventory-only-rescaffold-vslice.sh` alongside the existing greenfield vslice).

**Original Q20 sub-decision 4 text preserved verbatim above per schema-discipline amendment pattern** (cf. Q21 amendment 1, Q23 amendment 1, Q24 amendment 1, Q29 amendment 1, Q31 amendments 1+2, Q41 amendment 1, Q47 amendment 1). The hard-reject behavior remains the binding contract of the `flow-inventory-add` sub-skill in domain-add mode — the amendment moves the decision-point UP to the orchestrator's Phase 2 pre-dispatch, where the classifier picks the right caller-side branch. On the `inventory-only` outcome (Branch B), the orchestrator dispatches `flow-inventory-add` in a new **`inventory-read` mode** (the third mode added to Q20 sub-decision 1's mode table) rather than re-implementing the H3-section parser at the orchestrator layer — this preserves Q47 sub-decision 4's boundary ("Q47 delegates to Q20 — the orchestrator NEVER edits inventory directly") on both the write axis AND the parse axis. Q20.5 parse-failure semantics apply identically across all three modes. Q31.7 forward-tolerance (`v1.x reader is forward-tolerant within major — ignores unknown fields`) accommodates a new optional `domains[0].inventory_only_rescaffold: bool` breadcrumb field without a Q31 amendment — extending the rule established by `milestone_id` + `new_sub_flow_count` on the same `domains[0]` shape (Q47 sub-decision 7 schema note in `commands/add-domain.md`). A Q31 amendment 3 to formalize the field is a v1.1 candidate per the existing `milestone_id` schema-extension precedent.

**Cross-link:** `commands/add-domain.md` Phase 2 carries the operational implementation of this amendment; `skills/flow-inventory-add/SKILL.md` Section 4 carries the caller-side-guard note pointing back here.

**Schema-evolution discipline reinforced:** Q20 amendment 1 follows Q21 + Q23 + Q24 + Q29 + Q31 + Q41 + Q42 + Q47 amendment-with-audit-trail precedent. Total amendment count after this remediation: **21 amendments** (Q31 amend 1+2, Q24 amend 1, Q21 amend 1, Q50 amend 1+2, Q33 amend 1+2, Q34 amend 1+2, Q35 amend 1, Q2 amend 1, Q22 amend 1, Q28 amend 1, Q41 amend 1, Q49 amend 1, Q29 amend 1, Q23 amend 1, Q47 amend 1, Q42 amend 1, **Q20 amend 1**).

**Q20 amendment 2 — H3 + DOMAIN schema (lowercase + backtick-wrap + em-dash canonical) (LOCKED 2026-05-22 per BC-10352).** Q20 sub-decisions 3 + 4 were originally drafted with **UPPERCASE kebab-case domain slugs implied via examples** (`TEAM-08`, `AUTH-11`, `ASSET-DISCOVERY`) — formalized in `flow-classify-domain-state.sh`'s pre-fix validate-DOMAIN block as `^[A-Z][A-Z0-9_-]*$` with the literal error string `(Q20.4 schema)`, and in `flow-inventory-add/SKILL.md` Section 3 as `^### <DOMAIN> ---.* \(\d+ flows\)$` (**triple-hyphen** separator, **bare** H3 — no backtick wrap). Q20.3 prose at memory:230 simultaneously specified an em-dash separator (`^### <DOMAIN> — .* \(\d+ flows\)$`), leaving the plugin's internal schemas already disagreeing across the separator axis. Brand Hub iter-2 (BC-6998, 2026-05-13) shipped its 10-domain inventory in **lowercase kebab-case + backtick-wrapped + em-dash** form (`### \`asset-foundation\` — Asset Foundation`, `### \`asset-discovery\` — Asset Discovery`, etc.), matching the Q20.3-prose separator but diverging from `flow-classify-domain-state.sh`'s case axis and `flow-inventory-add` Section 3's separator + backtick axes. The BC-9971 fix's classifier-driven Branch B (Q20 amendment 1) hard-rejected **every** domain in Brand Hub's shipped inventory:

1. **Case** — `flow-classify-domain-state.sh`'s pre-fix validate-DOMAIN regex `^[A-Z][A-Z0-9_-]*$` rejected `asset-foundation` outright with `(Q20.4 schema)` exit 2.
2. **Backtick wrap** — `flow-classify-domain-state.sh`'s pre-fix H3 grep `^### ${DOMAIN}[[:space:]]` matched bare H3s only; iter-2's `### \`asset-foundation\` — ...` form was unreachable even if the regex permitted it.
3. **Separator** — `flow-inventory-add` Section 3's prescribed triple-hyphen `---` diverged from Q20.3 memory + iter-2 reality (both em-dash `—`). The classifier's whitespace-boundary grep tolerated either separator, but the inventory-write skill prescribed the wrong one.

Net effect: BC-9971's classifier never ran on real Brand Hub state; iter-3's 8 brand-hub domain scaffolds (asset-discovery + 5 batch-1 + 2 batch-2 + 2 batch-3 + crm-sync — 6 clean fallback runs to date) proceeded via the manual-orchestration fallback (`[[feedback_manual_orchestration_fallback]]`, BC-6998 iter-2's validated end-state). Surfaced during BC-10321 iter-3 asset-content-libraries scaffold attempt (2026-05-19) — same class of bug as BC-10302 (schema/code/docs drift surfaced only by dogfood).

This amendment locks **iter-2's shipped reality as canonical** (Path A per BC-10352 § Design question). The new Q20 schema is:

| Axis | Pre-Q20-amend-2 spec | Q20 amendment 2 lock | Source of truth |
|---|---|---|---|
| Domain slug case | UPPERCASE kebab-case (implied via examples) | **lowercase kebab-case** (`^[a-z][a-z0-9-]*$`) | `flow-classify-domain-state.sh` § validate-DOMAIN block |
| H3 backtick wrap | bare only (`### <DOMAIN> ...`) | **either backtick-wrapped or bare** (`^### \`?<DOMAIN>\`?[[:space:]]`) | `flow-classify-domain-state.sh` § H3 match block |
| Separator | inconsistent: Q20.3 em-dash `—` / Section 3 triple-hyphen `---` | **em-dash `—` canonical** | `flow-inventory-add/SKILL.md` Section 3 + Q20.3 prose |
| Q20.4 hard-reject | unchanged (binding safety net inside `flow-inventory-add` for direct callers) | unchanged | `flow-inventory-add/SKILL.md` Section 4 |
| Q20 amendment 1 four-outcome classifier | unchanged (`absent` / `inventory-only` / `journey-exists` / `fully-scaffolded-fs`) | unchanged | `flow-classify-domain-state.sh` |

**Rationale for Path A (Path B + Path C rejected).** BC-10352 § Design question evaluated three paths:

- **Path A** — Relax Q20 schema to match iter-2 reality. Cheapest; locks iter-2's shipped format as canonical going forward. Also resolves the pre-existing triple-hyphen-vs-em-dash internal disagreement (lines 56-62 comment in the classifier). **Selected.**
- **Path B** — Migrate Brand Hub's already-canonical inventory + the 9 created Linear milestones to UPPERCASE. Invasive (one-shot migration script + Linear milestone renames); preserves Q20.4's implied case but trades migration cost for schema purity. Rejected.
- **Path C** — Hybrid: accept both shapes (`^[a-zA-Z][a-zA-Z0-9_-]*$`); brand-hub stays as-is; new projects bootstrap with UPPERCASE. Trades schema simplicity for backward-compat. Rejected as the worst-of-both: future drift across new projects is more expensive than a one-time canonicalization.

**Cross-link:** `flow-classify-domain-state.sh` (regex + grep + comment block updated); `skills/flow-inventory-add/SKILL.md` Section 3 (sub-flow-add + inventory-read H3 regex + return-shape comment updated); `tests/test-helper-scripts.sh` (new BC-10728 bash unit-test harness includes a 15-assertion Section 4 covering all 3 schema axes against an iter-2-shape inventory); `tests/run-inventory-only-rescaffold-vslice.sh` + fixtures (synthetic-inventory-only-domain / synthetic-journey-exists-domain / synthetic-fully-scaffolded-domain) migrated UPPERCASE → lowercase + backtick + em-dash, story doc filename renamed `ASSET-DISCOVERY-01.md` → `asset-discovery-01.md`.

**Original schema preserved per schema-discipline amendment pattern.** Pre-Q20-amend-2 the case axis was implicit (UPPERCASE only documented via Q15 + Q20 example slugs like `TEAM-08` / `AUTH-11` / `ASSET-DISCOVERY` and the explicit `^[A-Z][A-Z0-9_-]*$` regex in `flow-classify-domain-state.sh` with `(Q20.4 schema)` error string); the backtick-wrap axis was the silent default of "bare only" (no `\`` allowed); the separator axis was the disagreement at the heart of the bug (Section 3 prescribed `---`, Q20.3 prose specified `—`). The audit trail is preserved here in this amendment block + in the `flow-classify-domain-state.sh` comment block (now narrating both the post-fix schema and the pre-fix divergence).

**Schema-evolution discipline reinforced:** Q20 amendment 2 follows the same precedent as Q21 + Q23 + Q24 + Q29 + Q31 + Q41 + Q42 + Q47 + Q20-amend-1. Total amendment count after this remediation: **22 amendments** (Q31 amend 1+2, Q24 amend 1, Q21 amend 1, Q50 amend 1+2, Q33 amend 1+2, Q34 amend 1+2, Q35 amend 1, Q2 amend 1, Q22 amend 1, Q28 amend 1, Q41 amend 1, Q49 amend 1, Q29 amend 1, Q23 amend 1, Q47 amend 1, Q42 amend 1, Q20 amend 1, **Q20 amend 2**). This is the **23rd entry** in the FDA interview lock/amendment canon (counting Q56 + Q57 as the two post-v1.0 Q-lock entries; Q20 amend 2 is the 22nd amendment + the 23rd canon entry overall). Q56 (BC-9023 install-discipline reflection) + Q57 (BC-10651/2 retire-fallback parking-lot defer) remain at their v1.0 / v1.1 positions; Q20 amend 2 is the third v1.1.x schema mutation (after Q42 amendment 1 / BC-9028 and Q20 amendment 1 / BC-9971).

**Q29 — Quality-gate stack enumeration (LOCKED 2026-05-06).** Per Q7: gates are filesystem-artifact-existence checks (deterministic, NOT LLM self-report). Per Q8: per-phase artifact-existence gate mandatory + richer quality-gate stack. Q29 is the gate manifest; `/flow:audit` (Q38, pending) is the runner. Resolves Q23 mod 5 stub ("All discipline-quality-gates pass per /flow:audit on this parent"). Total locked gate count: **8 phase-transition + ~22 per-flow discipline-child (varies per discipline) + 5 cross-cutting = 35 distinct gate types** (multiplied by N flows for per-flow gates). Seven sub-decisions:

1. **Phase-transition gates (8 gates).** Fire between FDA orchestrator phases:
   - `env-ready` (→ preflight): Linear MCP reachable + repo root + `gh` auth (per Q12)
   - `preflight-complete` (preflight → office-hours): `.flow/config.json` exists with required v1 fields (`linear_project_id`, `linear_project_name`, `linear_team_key`, `fda_first_setup_at`, `fda_plugin_version`) per Q12.4; structured preamble emitted per Q12.5. Maps to greenfield-orchestrator G1 gate per §3e ("bootstrap completed"). **Added per Q29 amendment 1 — see amendment entry below.**
   - `intent-exists` (office-hours → inventory): `docs/product/intent.md` exists with required sections (per Q41 — pending)
   - `inventory-complete` (inventory → linear-scaffold): `master-flow-inventory.md` exists with ≥1 domain section + verify-docs.sh orphan-flow-IDs check passes
   - `scaffold-complete` per domain (linear-scaffold → doc-author): `.flow/scaffold-log/<domain>.md` has rows for 1 milestone + N parents + 5N children, all `result: executed` or `skipped-idempotent`
   - `story-docs-complete` per domain (doc-author → journey-author): N story doc files at `docs/product/flows/<domain>/*.md` for all N flows in domain
   - `journey-complete` per domain (journey-author → regen-index): `docs/product/journeys/<domain>.md` exists
   - `index-complete` (regen-index → done): INDEX.md `generated_at` timestamp **>= orchestrator's `run_started_at` from `.flow-phase-state.json` breadcrumb** (semantically: "INDEX regenerated as part of THIS orchestrator run"; avoids failure modes from orchestrator pauses)

2. **Discipline-child-completion gates (~22 per-flow, varies per discipline).** Aggregated from Q24 templates' Done-means / Verify sections:
   - **[Story] (5 checks):** file at `docs/product/flows/<domain>/<flow-id>.md` exists; all required front-matter populated (TBD acceptable for sibling-blocked); job story sentence matches regex `^> \*\*When\*\*.*\*\*I want to\*\*.*\*\*so I can\*\*`; AC has 3-5 Gherkin `Scenario:` blocks; `verify-docs.sh` passes for the doc.
   - **[Eng] (4 checks):** Linear [Eng] child `state.type == "completed"`; `npm run build && npm run lint && npm test` pass on `main`; sandbox URL accessible (HTTP 200 via curl smoke-test); story-doc front-matter `children.engineering` populated.
   - **[Design] (3 checks):** Linear [Design] child `state.type == "completed"`; `figma:` field in story-doc front-matter populated (URL with node ID — regex `figma\.com/file/.*\?node-id=`); story-doc front-matter `children.design` populated. (v1.1 candidate: HTTP HEAD on figma URL — may not work for private frames; track in parking lot.)
   - **[QA] (5 checks):** story-doc front-matter `qa_status: signed-off` (or `rework-needed` blocks Done); `qa_last_signed_off` populated with valid ISO-8601; QA history table has at least one row with `signed-off` status; structured QA-run comment posted on Linear QA child (detected via `list_comments` matching template signature); story-doc front-matter `children.qa` populated.
   - **[Docs] (5 checks):** customer-doc file exists at `docs/product/customer-docs/<domain>/<flow-id>.md`; customer-doc front-matter populated per Q28 schema (`flow_id`, `public_slug`, `title`, `last_reviewed` minimum); `user_docs_url` in story-doc front-matter populated (non-TBD); `verify-docs.sh` passes for the customer-doc; story-doc front-matter `children.docs` populated.
   - Per-discipline total: 5 + 4 + 3 + 5 + 5 = 22 per-flow checks.

3. **Cross-cutting consistency gates (5 gates).** Cross-file integrity:
   - `inventory-story-doc-id-match`: every story doc's `flow_id` front-matter exists as a row in `master-flow-inventory.md`
   - `index-story-doc-status-match`: INDEX.md row's Status column matches story doc's front-matter `status` field
   - `linear-children-match`: story doc's `children.*` BC numbers match actual Linear issue parentId chain. **Implementation note (v1.1 perf candidate, parking lot):** v1 uses per-child `get_issue` (~250 reads × 500ms = ~125s for a 50-flow project); v1.1 should batch via `list_issues({labels: ["domain:<slug>"]})` per domain (~28 batches × 500ms = ~14s; same correctness, much faster).
   - `parent-l3-summary-populated`: Linear parent issue body contains `## L3 review summary` section with 5 discipline headlines (Q23 mod 2)
   - `milestone-subflows-table-match`: Linear domain milestone description's Sub-flows table matches actual children of that milestone (Q22 schema)

4. **Hard vs soft classification.** **Hard** (blocks downstream): file existence, Linear issue creation, AC count (3-5 Gherkin), `qa_status: signed-off` for [Docs] to start, verify-docs.sh mechanical pass. **Soft** (warns but doesn't block; surfaces in audit summary): stale `last_reviewed` (>90 days, per verify-docs.sh existing convention), missing optional front-matter fields (`e2e_test: TBD` is OK), missing `## L3 review summary` section, transient cross-cutting consistency drift mid-edit.

5. **Override mechanism.** Mirrors cadence linear-housekeeping § 6: hard gate failure → `AskUserQuestion` (Fix now / Override with reason / Halt) → on Override: follow-up `AskUserQuestion` for reason → append `{gate, reason, timestamp}` to `.flow-phase-state.json` breadcrumb's `overrides[]`. Persistent for the phase invocation; not re-prompted within same run. `/flow:audit` reports overrides in summary.

6. **`/flow:audit` reporting format.** Three-section markdown: (a) Phase status table; (b) Per-flow discipline-grid (5-column ✓/🚧/⏳/❌/—/⚠ per Q25 legend, one row per flow); (c) Cross-cutting consistency report (flat list); plus Summary line + Overrides section.

7. **`verify-docs.sh` integration — leverage, don't duplicate.** `/flow:audit` runs verify-docs.sh FIRST (mechanical layer: build/lint/test, internal links, orphan flow IDs, front-matter presence, stale dates). Then layers FDA-specific gates on top. If verify-docs.sh fails: FDA-specific gates marked `skipped (verify-docs failed)`; user fixes mechanical issues first, re-runs `/flow:audit`. Keeps existing BriteBase infrastructure load-bearing.

**Q29 amendment 2 — add 6th cross-cutting consistency gate `cross-domain-deps-bidirectional` (LOCKED 2026-05-26 per BC-10729 — Q27 amendment 1 sibling, Triage Event #3 entry #6 v1.1.x promotion).** Brand-hub iter-3 dogfood documented ~10 cross-domain build-order blocks + gating-concentration hotspots as prose in story-doc bodies; Q27 amendment 1 ships the doc-side `## Cross-domain dependencies` section as the queryable view + 1:1 mirror of Linear `blockedBy` relations on sub-flow parent issues. This amendment adds the cross-cutting consistency gate that enforces the 1:1 mapping. Without this gate, the doc-side and Linear-side surfaces could silently drift, defeating the purpose of the annotation.

The new 6th cross-cutting gate joins the existing 5 (`inventory-story-doc-id-match`, `index-story-doc-status-match`, `linear-children-match`, `parent-l3-summary-populated`, `milestone-subflows-table-match`):

- `cross-domain-deps-bidirectional` — bidirectional cross-ref consistency between story-doc `## Cross-domain dependencies` section (Q27 amendment 1, mod 4) and Linear `blockedBy` relations on sub-flow parent issues. Per-direction predicate:
  - **doc → Linear half:** every `<this-flow-id> blockedBy <other-flow-id>` bullet in a story doc has a matching Linear `blockedBy` relation pointing from this flow's parent issue to the other flow's parent issue.
  - **Linear → doc half:** every Linear `blockedBy` relation between two FDA sub-flow parents (identified via `domain:*` label on both endpoints) has a matching doc-side bullet in the blocked flow's story doc.
  - **`gates` direction:** every `<this-flow-id> gates <other-flow-id>` bullet asserts the inverse view of a `blockedBy` on the OTHER flow's parent — checked symmetrically as part of the Linear → doc half (the OTHER flow's story doc should carry the matching `blockedBy` bullet).
  - **Excluded relations:** same-domain blockedBy (sibling sub-flows within one domain) is tracked via story-doc front-matter `related_flows` (Q27 base template field) and is OUT OF SCOPE for this gate. Linear relations to discipline children (Story/Eng/Design/QA/Docs) are also excluded — only parent-issue ↔ parent-issue relations participate.
  - **Hard vs soft:** **hard** — drift between doc and Linear represents a silent contract break that would erode the gate's value if treated as informational-only. Override via Q29.5 standard flow.

  Implementation note (Q38 sub-decision 3 batched-list-issues consistency): use the same per-domain `list_issues({label: "domain:<slug>"})` batched response that backs `linear-children-match` + `parent-l3-summary-populated` to harvest each parent issue's `blockedBy` relations; no additional `get_issue` round-trips required. Doc-side parse happens once per story doc in the audit run's per-doc cache (per the `audit.md` § Per-doc parse cache rule). Net Phase C cost: ~0s added on top of the existing `linear-children-match` batched list (same call, additional field extraction from response).

**Correction to total gate count.** Q29 lock entry's total-count line (above) commits to "8 phase-transition + ~22 per-flow + 5 cross-cutting = 35 distinct gate types". Post-Q29 amendment 2, the canonical total is **8 phase-transition + ~22 per-flow discipline-child + 6 cross-cutting = 36 distinct gate types** (multiplied by N flows for per-flow gates). Original Q29 lock body text "5 cross-cutting = 35" is preserved verbatim above per the schema-discipline amendment pattern (cf. Q47 amendment 1's "= 7 writes" / "= 8 writes" correction shape). Derivatives carrying the count are updated inline: `commands/audit.md` (description + body + Phase C list + `--gate=<id>` table + see-also), `skills/_shared/artifact-gate-pattern.md` (cross-cutting section + arithmetic + references), `CLAUDE.md` § Quality gate stack reference, `docs/design-rationale/fda-plugin-architecture-overview.md` (TOC + §3h diagram + Q-lock summary + appendices). The Q29.3 sub-decision 3 enumeration in the lock body (5 bullets) is preserved verbatim; the 6th bullet's full definition lives in this amendment block, mirroring Q47 amendment 1's derivative-only inline-update pattern.

**Fixture coverage.** A focused v-slice harness at `plugins/flow-architecture/tests/run-cross-domain-deps-vslice.sh` exercises the doc-side parse contract against 3 synthetic story-doc fixtures under `tests/fixtures/synthetic-cross-domain-deps/`: (a) PASS — doc references blockedBy with matching Linear-state JSON mock; (b) FAIL — doc references blockedBy with no matching Linear relation (doc → Linear half fails); (c) FAIL — Linear has blockedBy with no doc mention (Linear → doc half fails). The harness validates the doc-side regex contract + the set-comparison logic for the bidirectional check, scoped to filesystem-only fixtures since CI has no Linear access (per the BC-7059 vslice-greenfield precedent — Phase C Linear MCP gates are SKIP in the audit smoke test and the full bidirectional verdict against live Linear is exercised in Brand Hub dogfood). The new gate ID `cross-domain-deps-bidirectional` is added to `run-audit-smoke.sh` § RECOGNIZED_GATES so it doesn't trip the UNCATEGORIZED-GATE-FAIL bucket on any audit-fixture run that surfaces it.

**Schema-evolution discipline reinforced.** Q29 amendment 2 follows Q29 amendment 1 + Q47 amendment 1 + Q23 amendment 1 + the broader amendment-precedent canon. The total-count update mirrors Q47 amendment 1's "7 writes → 8 writes" correction shape (lock-body verbatim preserved; derivatives updated inline; amendment block records the canonical post-amendment value). Future Q29 amendments would be Q29 amendment 3+. The v1.1 parking-lot #51 ("Q29 amendment 1 — extend gate stack with plan-X-section discipline-completion gate") was originally labeled "Q29 amendment 1" but Q29 amendment 1 was claimed by BC-7066's `preflight-complete` correction; that parking-lot entry's promotion would now constitute Q29 amendment 3 territory if/when it lands (label drift acknowledged here; parking-lot entry text preserved verbatim per amendment discipline). **Label re-drift (2026-05-31):** Q29 amendment 3 is now claimed by the story-frame narrowing entry below (BC-11983); the parking-lot #51 plan-X-section gate, if/when it lands, becomes **Q29 amendment 4** territory.

---

**Q29 amendment 3 — per-repo config-gated story-frame strictness (`story_frame: strict`) (LOCKED 2026-05-31 per BC-11983, sequel to BC-12134).** The human-anchoring decision (grill-with-holden 2026-05-30; see `memory/decision_fda_human_anchored_retire_constraint_spec.md`) retired the constraint-spec / system-as-actor story frame in favor of human-anchored JTBD always. BC-12134 stopped the bleed at the generators + seed templates + rubric while keeping the **mechanical gates lenient** (the `story-job-story-regex` presence-floor still accepts the legacy `**Given**`+`**MUST**`+`**so that**` frame so the 6 not-yet-reframed WS-E consumer repos keep passing audit mid-migration). This amendment defines how that floor is *narrowed* — and decisively, **per-repo and transiently, not as a single global flip**:

- **Semantics.** The `story-job-story-regex` gate's **accepted-frame-set is config-gated** by the consuming repo's `.flow/config.json` `story_frame` field. **`lenient`** (the default — field absent, or any value other than the literal `strict`) accepts EITHER the human job-story frame OR the legacy constraint-spec frame (the BC-12134 floor, unchanged). **`strict`** accepts ONLY the human job-story frame; a constraint-spec-only doc then FAILs the gate and must be re-anchored on the human the mechanism serves (the operator who trusts the run, or the customer who reads the output — per the anchor rule). Resolution is **fail-safe**: anything that isn't the string `strict` (case-insensitive) resolves to `lenient`, so the gate can only ever accidentally STAY permissive, never accidentally narrow.
- **Gate ID retained; gate COUNT unchanged.** This config-gates the accepted-frame-set of the existing `story-job-story-regex` gate — it does **not** mint a new gate ID (preserving Q29 gate-stack stability, the same discipline as BC-12134's lenient *widening*). The canonical total stays **36 distinct gate types** (8 phase-transition + ~22 per-flow + 6 cross-cutting per Q29 amendment 2); amendment 3 narrows an existing gate's behavior, it does not add one.
- **Transient strangler-fig (pre-blessed lifecycle).** The flag is introduced as a migration device, not a permanent dual-mode: (1) add the config-gate + flip the one already-reframed repo (brite-sites) to `strict` now — the first verified enforcement landing; (2) flip each remaining WS-E repo to `strict` as its story docs are reframed; (3) once **all 7 WS-E repos** (`brite-sites`, `brite-roster`, `brand-hub`, `brite-labs-site`, `brite-supply-react`, `brite-pim`, `brite-lseo`) are `strict`, REMOVE the flag and hardcode `strict` as the global end-state. Two gate-changes total. A permanent dual-mode flag was **rejected**: every FDA flow is human-anchored always (BriteBase 0/399), so no legitimate repo type should permanently emit the constraint-spec frame (YAGNI — re-add a flag if a real exception ever appears). The removal is tracked on a BC-11983 child (trigger: "all 7 repos' `.flow/config.json` = `strict`"); a plugin-side `validate.sh` reminder surfaces that the transient flag mechanism still exists (it cannot count N/7 — no plugin-side surface sees the 7 consumer repos' configs; the N/7 checklist is tracked on the child).
- **Two-surface scope (locked).** The narrowing lives ONLY in the floor gate that produces the pass/fail verdict: `commands/audit.md` § Phase B [Story] check prose + its deterministic mirror `tests/run-audit-smoke.sh` (`story_frame_present <doc> <mode>` reusing the existing region logic + `story_frame_mode <repo>` reading the config; regression-locked across the three states — human PASS strict, constraint-spec FAIL strict, constraint-spec PASS lenient — plus an end-to-end config→gate wiring assertion, in Sections 4b/4c/4d, CI-wired via `.github/workflows/validate-plugin.yml`). `scripts/lib/flow_doc_lint.sh`'s D11 `FRAME_MISMATCH` is **not** made a second detection surface (the floor gate is authoritative); its scope comment is updated to point at the live floor. The brite-base GOLD multi-line blockquoted form is preserved in both modes (line-form-agnostic since BC-11988 / T0-4).
- **Config schema.** `story_frame` is an **optional** `.flow/config.json` field, NOT written by `flow-preflight` (the Q12.4 writer stays at its 5 v1 fields) — it is set manually when a repo's story docs are reframed (documented in `skills/flow-preflight/SKILL.md` § 4.3). Extra keys are safe: the `preflight-complete` gate is a required-subset check, not a closed allowlist.

Schema-evolution discipline reinforced: Q29 amendment 3 follows Q29 amendments 1+2 + Q47 amendment 1 + the broader amendment-precedent canon (explicit amendment-number + audit trail in the lock entry; original lenient-floor behavior preserved as the default mode). Future Q29 amendments would be Q29 amendment 4+ (the parking-lot #51 plan-X gate, per the label re-drift note above).

---

**Q29 amendment 1 — name the 8th phase-transition gate `preflight-complete` (LOCKED 2026-05-11 per BC-7066 reconciliation).** Q29 sub-decision 1 originally enumerated 7 phase-transition gate bullets despite the sub-decision header committing to "(8 gates)" and the Q29 lock entry's total-count line committing to "8 phase-transition + ~22 per-flow + 5 cross-cutting = 35 distinct gate types". /workflows:review of BC-6955 (PR #263) surfaced the gap via code-reviewer P3 + simplify-quality conf 9; validator subagent confirmed faithful-echo discipline ("fix should be filed against the source-of-truth, not the derivative") — see BC-6955 task-3 precedent at `docs/precedents/BC-6955.md`. This amendment adds the missing 8th gate for the preflight → office-hours transition:

- `preflight-complete` (preflight → office-hours): `.flow/config.json` exists with required v1 fields (`linear_project_id`, `linear_project_name`, `linear_team_key`, `fda_first_setup_at`, `fda_plugin_version`) per Q12.4; structured preamble emitted per Q12.5 (`MODE / LINEAR_PROJECT_ID / LINEAR_PROJECT_NAME / REPO_ROOT / INTENT_EXISTS / INVENTORY_EXISTS / FLOWS_DIR_EXISTS / BREADCRUMB_EXISTS / GH_AUTH / LINEAR_MCP`).

Name rationale: matches the dominant `<phase>-complete` naming convention used by 5 of the existing 8 gates (`inventory-complete`, `scaffold-complete`, `story-docs-complete`, `journey-complete`, `index-complete`). The artifact-existence check grounds in `.flow/config.json` per Q7's "filesystem-artifact-existence checks, NOT LLM self-report" philosophy. Maps cleanly onto greenfield-orchestrator G1 user-confirmation gate per §3e architecture overview ("bootstrap completed; `.flow/config.json` written"). The G1 user-gate and the Q29 `preflight-complete` artifact-gate are the same gate viewed from two layers — user-confirmation UX overlay (Q29 sub-decision 5 override mechanism) on top of artifact-existence check.

Derivative re-sync follow-up: `plugins/flow-architecture/skills/_shared/artifact-gate-pattern.md:19` (the BC-6955 utility-kit derivative) faithfully echoes the original 7-bullet enumeration and `(8)` header. Sync to add the 8th bullet once BC-6955 PR #263 merges — tracked as a 1-line edit in a follow-up commit on a fresh branch or as part of any subsequent flow-architecture PR that touches the derivative.

Schema-evolution discipline reinforced: Q29 amendment 1 follows Q31 amendments 1+2 + Q21 amendment 1 + Q24 amendment 1 precedent — explicit amendment-number + audit trail in the lock entry. Future Q29 amendments would be Q29 amendment 2+.

**Q30 — Plugin manifest + directory structure (LOCKED 2026-05-06).** Plugin name: `flow-architecture`. Initial version: `0.1.0` (alpha; → `1.0.0` on first successful Brand Hub retrofit per Q8 acceptance test). Repo placement: `Brite-Nites/brite-claude-plugins/plugins/flow-architecture/` (alongside cadence + marketing + revops + workflows). Mirrors cadence structure with FDA-specific deltas. Nine sub-decisions:

1. **Name + version.** `flow-architecture` v0.1.0; semver during iteration (minor on new sub-skill/major refactor; patch on fixes); → 1.0.0 on Brand Hub dogfood pass.

2. **Directory structure.** Total **49 distinct artifacts** (excluding plugin meta files): 17 commands + 10 sub-skills + **6 shared utilities** (corrected from 5 at lock time) + 12 agents + 4 bash scripts. Tree:
   - `.claude-plugin/plugin.json` (Q30.3) + `.mcp.json` (Q30.4) + `CLAUDE.md` (Q55 — separate content design) + `LICENSE` (MIT) + `README.md`
   - `commands/` (17 files): start-project, retrofit-project, add-domain, add-sub-flow, audit, regen-index, office-hours, inventory, plan-{story,eng,design,qa,docs} (5), session-start (cloned per Q51), review (cloned per Q52), ship (cloned per Q53), retro
   - `skills/_shared/` (6 utilities): `app-classifier-pattern.md` (Q11/Q19 base), `code-evidence-collector.md` (parking lot #18 DRY: Q11 P3 + Q15.7 + Q17.2), `linear-writeback-pattern.md` (Q46), `checkpoint-pattern.md` (cribbed ce-optimize), `artifact-gate-pattern.md` (Q29 stack reference), `four-mode-framework.md` (Q48 — cribbed gstack plan-ceo-review)
   - `skills/<name>/SKILL.md` (10 sub-skills): flow-preflight (Q12), flow-inventory-codebase-scan (Q11), flow-inventory-interview (Q19), flow-inventory-add (Q20), flow-linear-scaffold (Q13), flow-legacy-cross-reference (Q14), flow-doc-author (Q15), flow-journey-author (Q16), flow-sandbox-scaffold (Q17), flow-regen-index (Q18)
   - `agents/<name>.md` (12 agents per Q21): inventory-author, codebase-inferrer, story-doc-author, journey-doc-author, fidelity-reviewer, plan-{story,eng,design,qa,docs}-reviewer (5), plan-ceo-reviewer, plan-devex-reviewer
   - `scripts/` (4 bash helpers): flow-detect-mode.sh, flow-detect-fda-shape.sh, flow-resume-breadcrumb.sh, flow-context-load.sh

3. **plugin.json content.** Mirrors cadence schema. Declares `commands` + `skills` paths only; `agents/` + `scripts/` auto-discovered at standard paths (verified against cadence + workflows). Fields: name, description, author, version, homepage, repository, license (MIT), keywords (claude-code/plugin/flow-driven-architecture/fda/linear/domain-milestones/discipline-children/ui-bearing-builds), commands (`./commands/`), skills (`./skills/`).

4. **.mcp.json content.** Empty `{"mcpServers": {}}` — reuses workflows' Linear MCP per cadence precedent (verified: cadence `.mcp.json` is also empty mcpServers; per BC-5810 § 4 + BC-5811 § 4.2, duplicate registration breaks tool routing). Plugin depends on workflows being installed for `mcp__plugin_workflows_linear-server__*` tool access. CLAUDE.md (Q55) documents this dependency.

5. **CLAUDE.md placeholder + Q55 spinoff.** Plugin-internal guidance file at `plugins/flow-architecture/CLAUDE.md` is a **distinct artifact** from Q34 (org-wide handbook page in handbook repo, different audience) and Q42 (specific skill's prompt body). Cadence has its own CLAUDE.md (14257 bytes); workflows has its own. Q30 reserves the file slot; **content design spun off as Q55** — focused pass covering plugin overview / slash command map / sub-skill orchestration map / agent dispatch matrix / quality gate stack reference / Linear MCP dependency note / pre-existing-vs-FDA-output mapping.

6. **Bash helper scripts at `scripts/` (gstack pattern), not embedded in skill bodies (cadence pattern).** Four scripts per memory's Internal architecture: `flow-detect-mode.sh` outputs `greenfield|retrofit|incremental-add|resume` (Q12 mode classification); `flow-detect-fda-shape.sh` outputs presence flags for intent.md/inventory/flows/journeys/breadcrumb; `flow-resume-breadcrumb.sh` reads `.flow-phase-state.json`; `flow-context-load.sh` invokes the above three + emits structured preamble per Q12.5. Skill bash preambles invoke via `source $CLAUDE_PLUGIN_ROOT/scripts/<helper>.sh` (gstack pattern from Q12 lock). **Reasoning:** gstack inspired the bash-preamble-as-context-injector pattern; standalone scripts mirror gstack better than embedded bash; testable in isolation; centralizes context-detection across 10 sub-skills. Cadence's embedded pattern works for 2 sub-skills with shared concerns but doesn't scale to 10.

7. **LICENSE + README.** MIT (workflows pattern; cadence omits but workflows ships one — adopting workflows convention for clarity). README.md covers overview + install + V1 surface command list + dev guide pointer to CLAUDE.md (Q55).

8. **Hooks — none for v1.** Workflows has `hooks/`; cadence doesn't; FDA doesn't need them in v1. Future v1.1+ candidates parked: pre-commit hook to run `flow-regen-index` (already in parking lot from Q18.8); post-merge hook to refresh INDEX.md after PR merge.

9. **Versioning + repo placement.** 0.1.0 → 1.0.0 on dogfood pass; semver during iteration; placement at `Brite-Nites/brite-claude-plugins/plugins/flow-architecture/`.

**Q31 — Resume breadcrumb schema `.flow-phase-state.json` (LOCKED 2026-05-06).** Per Q7: ce-optimize-derived breadcrumb + per-phase artifact markers + write-then-verify. Per Q8: resume-via-breadcrumb mandatory. Per Q12: path locked at `docs/plans/.flow-phase-state.json`; preflight detects + classifies `resume` mode. Seven sub-decisions:

1. **Top-level schema:** `version` ("1") + `mode` (greenfield/retrofit/incremental-add/resume per Q12) + `status` (in_flight/completed/abandoned) + `run_started_at` (ISO-8601, used by Q29.1 `index-complete` gate) + `last_updated` (ISO-8601, used for Q31.3 staleness) + `current_phase` + `completed_phases[]` + `in_flight_artifacts[]` (path + status, for partial-write recovery) + `domains[]` (array preserves insertion order; per-domain entries with `name` / `scaffold_log_path` / `current_sub_flow` / `completed_sub_flows[]` / `phase_status: {linear-scaffold|doc-author|journey-author: pending|in_flight|complete}`) + `overrides[]` (Q29.5 hard-gate decisions: `{gate, reason, timestamp, scope}`) + `config_snapshot` (defensive snapshot of `.flow/config.json` at run start: `linear_project_id` + `linear_project_name` + `fda_plugin_version`).

2. **Phase naming convention.** Slash-form `<phase>/<scope>` for per-domain phases (e.g., `linear-scaffold/TEAM`, `doc-author/QUO`); flat names for project-scope phases (`preflight`, `office-hours`, `inventory`, `legacy-cross-reference`, `regen-index`, `audit`).

3. **Stale breadcrumb policy (per Q12).** Three conditions trigger offer-discard `AskUserQuestion`: (a) `last_updated > 7 days` ago; (b) `status == "completed"`; (c) `status == "abandoned"`. Options: **Discard breadcrumb + start fresh** (Recommended) / **Force-resume** (override) / **Cancel**.

4. **Path location LOCKED at Q12** at `docs/plans/.flow-phase-state.json`. 3-pattern storage split observed (`.flow/config.json` committed + `.flow/scaffold-log/<domain>.md` transient + `docs/plans/.flow-phase-state.json` transient) — flagged for parking lot re-eval post-dogfood (#30); not changing in v1.

5. **Write-then-verify mechanism.** Atomic-rename + re-read + parse-verify + content-match. Helper at `scripts/flow-resume-breadcrumb.sh` wraps every breadcrumb write: write to `<path>.tmp` → atomic `mv` → cat → `python3 -c 'import json,sys; json.loads(sys.stdin.read())'` parse-verify → content-match check. Atomic rename guarantees no partial-write corruption (POSIX-guaranteed atomic on same filesystem).

6. **Concurrency / locking.** No locking in v1; documented caveat in plugin CLAUDE.md (Q55) — "don't run multiple FDA orchestrators in parallel against the same project". v1.1 PID-file lock at `.flow-phase-state.json.lock` parking lot candidate (#31's prior context — but the actual parking lot entry is for L1/L2/L3 review state). Concurrency-lock is a separate v1.1 enhancement; track if a real collision occurs.

7. **Schema migration path.** `version: "1"` field; v1.x reader is forward-tolerant within major (ignores unknown fields, treats missing optional fields as defaults); major version bump (v1 → v2) requires explicit migration script + user prompt.

**`legacy-cross-reference` two-pass render/execute pattern (clarified at lock):** Q14.3's two-pass nature uses **filesystem-derived sub-state**, NOT breadcrumb-encoded sub-state. Detection: check if `docs/plans/<retrofit>-cross-reference.md` exists with `last_reviewed != TBD` → execute mode; else → render mode. This keeps the breadcrumb's `phase_status` for `legacy-cross-reference` simple (binary pending/in_flight/complete) and pushes two-pass nuance to the filesystem signal that already exists. Cleaner separation.

**Q31 amendment 1 — `office_hours_state` extension slot (LOCKED 2026-05-07 per Q42 sub-decision 6 user lock).** Q31.1 schema extended with optional per-skill state field:
- `office_hours_state` (present when `mode=greenfield|retrofit` AND phase 2 in_flight; full schema defined in Q42 lock entry sub-decision 6) — captures interview state + L1 review state across resumes. Includes: `sections_completed[]`, `section_answers{}`, `linear_brief_snapshot`, `l1_review_status{}`, `l1_review_results{}`.

**Schema-evolution precedent established (per user lock 2026-05-07):** per-skill state extensions are added to Q31.1 schema via amendment-with-audit-trail (NOT inline-in-skill-lock). Q31 remains canonical breadcrumb spec — readers see full breadcrumb shape from Q31's lock without grepping across per-skill locks. Future amendments follow this pattern: each Q-lock that needs run-state (Q44 retro_state, Q53 ship_state, etc.) adds a slot to Q31.1 schema + amendment note here. Cost: more ceremony per skill needing run-state. Benefit: Q31 stays canonical; no schema sprawl across multiple Q-locks.

**Q31 amendment 2 — `linear_writeback_state` extension slot (LOCKED 2026-05-07 per Q46 sub-decisions 3+5+7 user locks).** Q31.1 schema extended with optional cross-skill state field for Q46 Linear writeback layer:
- `linear_writeback_state` (present when any Q46 consumer has written within run lifetime; full schema defined in Q46 lock entry sub-decisions 3+5; persists across runs until Q31.3 stale discard for cross-run audit + idempotency).
  ```json
  "linear_writeback_state": {
    "comment_ids": [
      {"issue_id": "BC-1234", "comment_id": "<uuid>", "type": "ship-summary", "signature": "...", "created_at": "<ISO-8601>"}
    ],
    "written_pairs": [
      {"issue_id": "BC-1234", "type": "plan-eng-section", "surface": "body", "run_id": "<id>", "written_at": "<ISO-8601>"}
    ],
    "warnings": [
      {"issue_id": "BC-1234", "type": "ship-summary", "warning": "<text>", "logged_at": "<ISO-8601>"}
    ]
  }
  ```
- `comment_ids[]` — claim-and-update idempotency for comment surface (Q46 sub-decision 3).
- `written_pairs[]` — within-run throttle enforcement + cross-run audit (Q46 sub-decision 5).
- `warnings[]` — clobber-warning persistence + read-context warning trail (Q46 sub-decisions 4+6).

**Schema-evolution discipline reinforced:** Q31 amendment 2 follows amendment 1 precedent. Future Q44 retro_state, Q53 ship_state, etc. additions follow the same pattern.

**Q32 — MCP and dependency requirements (LOCKED 2026-05-06).** Required MCPs: workflows Linear MCP only (`mcp__plugin_workflows_linear-server__*`) — provided via workflows-plugin dependency; FDA `.mcp.json` is empty `{}` per cadence precedent (BC-5810 § 4 + BC-5811 § 4.2 — duplicate registration breaks tool routing). Optional / unused MCPs: sequential-thinking + context7 (workflows registers; FDA doesn't depend; available transparently). External CLI deps: **bash 3.x+** (target macOS default 3.2 — Apple stopped bundling bash 4 due to GPL3; avoid associative arrays / mapfile / `${var,,}` lowercase / other bash-4-only features), **python3 3.6+** (Q31.5 JSON parse-verify), **git 2.x+** (Q12 repo root detection), **gh** soft (optional auth check). NOT required: jq (python3 handles JSON). Plugin deps: workflows plugin required (no version pin v1; v1.1 candidate if breakage). OS: macOS + Linux; POSIX filesystem (atomic rename); no Windows v1. **Q12 amended at Q32 lock 2026-05-06**: env-checks expanded to include explicit bash/python3/git version requirements (was illustrative; now exhaustive). 3-surface dep documentation: README (install), CLAUDE.md/Q55 (MCP + Dependencies sections), `/flow:preflight` runtime output. **Per-skill + per-agent MCP-usage audit (preserved for v2 spin-out tracking):** flow-preflight uses `list_projects` (limit:1); flow-linear-scaffold uses save_milestone/save_issue/save_comment/list_issues/get_issue; flow-legacy-cross-reference uses get_milestone/save_milestone; flow-regen-index uses list_issues (batched per domain); fidelity-reviewer uses get_issue; flow-doc-author/journey-author/sandbox-scaffold/inventory-interview/inventory-add use no Linear MCP. Among agents, only fidelity-reviewer + inventory-author (WebSearch/WebFetch but not MCP) need network-side tools; the 7 plan-X-reviewers + codebase-inferrer + 2 doc-authors are filesystem-only.

**Q36 — Plugin bootstrap shape (LOCKED 2026-05-07).** **Scope locked at per-project first-run experience** (per-org bootstrap parked — see #33). User explicitly confirmed scope-narrowing via AskUserQuestion. Bootstrap flow lives **embedded in `flow-preflight` (Q12)** — user confirmed embedded over dedicated skill. Seven sub-decisions:

1. **Scope clarification — per-project locked.** Q36 covers per-project first-run: detect missing `.flow/config.json`, prompt for Linear project, classify mode, write config, dispatch to orchestrator. Per-org bootstrap (PR-creation flow for landing CDR-023 + operating-standards page + templates in handbook + about-handbook) parked as v1.1 candidate (#33). v1 expects maintainer to create org-level PRs manually as one-time setup.

2. **First-run detection.** `flow-preflight` (Q12) detects `.flow/config.json` absence → first-run mode → dispatch bootstrap flow (Q36.3). `.flow/config.json` exists → already-bootstrapped → preflight reads + classifies mode → dispatch to appropriate orchestrator. No new entry point — elaboration of Q12's locked first-run path.

3. **Bootstrap flow (7 steps; step 3 split into 3a + 3b for Linear team_key resolution):**
   1. **Welcome message** — explain bootstrap scope: "I'll set up `.flow/config.json` for this project, ask which Linear project this maps to, and figure out greenfield-scaffold vs retrofit existing work."
   2. _(Reserved — see step 3a/3b for Linear resolution.)_
   3. **3a. Linear project resolution** — `AskUserQuestion` with options pulled via `mcp__plugin_workflows_linear-server__list_projects`. Format: 3-4 most-recently-active projects + "Other (search)" fallback. User selects. Capture: `project_id` (uuid), `project_name`, `team_id` (uuid, from project response).
      **3b. Team fetch** — `mcp__plugin_workflows_linear-server__list_teams` (one-time lookup; cache for session per cadence Phase 0 precedent). Match against `team_id` from 3a; extract `team_key` (e.g., `"BC"` for Brite Company). Two-step fetch is required — `list_projects` does not natively include `team_key` (verified against cadence weekly.md command source).
   4. **Mode classification interview** — combine Q12 FDA-artifact discovery + Linear-issue count signal. Concrete heuristic: no FDA artifacts + <10 Linear issues → `greenfield`; no FDA artifacts + ≥10 Linear issues → `retrofit`; FDA artifacts present + breadcrumb in_flight → `resume`; FDA artifacts present + breadcrumb absent or completed → `incremental-add`. **The 10-issue threshold is heuristic; user confirmation in step 5 is the authoritative signal**, not the threshold.
   5. **Mode confirmation** — `AskUserQuestion`: "Recommended: `<mode>`. Confirm or override?" Options: Confirm / Override (pick different mode) / Cancel.
   6. **Atomic config write** — Q31.5 atomic-rename pattern. Fields per Q12 v1 schema (5 fields): `linear_project_id`, `linear_project_name`, `linear_team_key`, `fda_first_setup_at` (ISO-8601 now), `fda_plugin_version` (read from `$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json`).
   7. **Dispatch to chosen orchestrator** — `/flow:start-project` (greenfield), `/flow:retrofit-project` (retrofit), `/flow:add-domain` or `/flow:add-sub-flow` (incremental-add), or resume the existing breadcrumb. Bootstrap exits cleanly handing off.

4. **Plugin version detection.** Read from `$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json`'s `version` field via helper at `scripts/flow-context-load.sh`: `python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json"`. python3 dep verified (Q31.5 + Q32.3 + parking lot #29 — three citations confirmed).

5. **Failure / cancellation.** Fail-closed; no partial state on disk. User cancels at any `AskUserQuestion` (3a / 5 / sub-prompt) → exit cleanly; **don't write `.flow/config.json`**; project remains pre-bootstrap. Linear API error → surface error; suggest `/flow:preflight` re-run after Linear MCP fixed. Filesystem write failure → surface; rollback any partial state. Atomic-rename + parse-verify (Q31.5) means `.flow/config.json` is either absent or fully populated — never partial.

6. **Location — embedded in `flow-preflight` (user-locked).** Bootstrap flow lives INSIDE `flow-preflight` (Q12), not a separate skill. Q12's responsibility #4 ("Linear scope confirmation + persisted config") IS the bootstrap. Trade-off acknowledged: `flow-preflight` has two code paths (fast already-bootstrapped check vs 7-step interview); v1 acceptance per user lock; refactor to dedicated `flow-bootstrap` sub-skill at v1.1 if it gets unwieldy. **Tracked in parking lot for v1.1 review.**

7. **Per-org bootstrap parking lot (#33).** Maintainer creates `Brite-Nites/handbook` + `Brite-Nites/about-handbook` PRs manually as one-time setup when the org first adopts FDA. Plugin-assisted PR creation across two external repos = v1.1+ candidate (`/flow:setup-org` hypothetical orchestrator). Defer until real demand surfaces — likely never (the FDA maintainer can hand-craft initial PRs in <1 hour).

**Q36 refinement audit trail (orchestrator → drafter B resolution, 2026-05-07).** Orchestrator session sent 6 refinements after Q36 draft. Drafter B's resolution of each (preserved for cross-session integrity):
1. **Scope narrowing user-confirm** → ESCALATED to user via `AskUserQuestion`; user answered "Lock per-project; park per-org (Recommended)". Resolved.
2. **Linear team_key resolution path** → APPLIED. Verified against cadence weekly.md: `list_projects` does NOT return `team_key`; team_key requires separate `list_teams` fetch. Q36.3 step 3 split into 3a (project) + 3b (team).
3. **Mode-list verification against Q12** → CONFIRMED HOLDS. Q12 lock at memory:56 enumerates exactly 4 modes (`greenfield` / `retrofit` / `incremental-add` / `resume`). Q36.3 step 4 already used these. No change.
4. **Fuzzy threshold definition** → APPLIED. Q36.3 step 4 now defines concrete heuristic (≥10 issues → retrofit recommendation) + explicitly notes user confirmation in step 5 is the authoritative signal, not the threshold.
5. **python3 dep verification (Q32.3 + parking lot #29)** → VERIFIED HOLDS. Memory grep confirms three citations: Q31.5:292, Q32.3:300, parking lot #29:601. Q36.4's claim was accurate. No change.
6. **Location architectural decision** → ESCALATED to user via `AskUserQuestion`; user answered "Embedded in flow-preflight (Recommended)". Resolved + parking-lot #34 captures v1.1 refactor trigger criteria.

**Status of Q36: LOCKED** as written above. All 6 refinements resolved. If session C receives orchestrator messages re-raising any of the 6 refinements, the response is "already resolved per Q36 lock entry; see refinement audit trail above for per-refinement resolution path."

**Q35 — CDR-014 amendment content (LOCKED 2026-05-07).** In-place amendment to `Brite-Nites/handbook/decisions/CDR-014-milestone-standards.md` (file path verified via gh API). Q1 lock requires "amendment, not supersession" — partitions scope alongside CDR-023 without overhauling content. Six sub-decisions:

1. **Amendment shape — in-place edits + Status section notation only.** **No front-matter `last_amended` field** — sampling CDR-013/014/016/019 confirmed NO existing CDR has `last_amended` (out of 21 CDRs in handbook); introducing the field for CDR-014 alone would break uniform convention. Status section notation + git history is sufficient audit trail.

2. **Front-matter — UNCHANGED from current.** No new fields introduced. Existing fields preserved verbatim: `cdr_id: CDR-014`, `title: "Milestone Standards (Phase Pattern)"`, `status: Accepted`, `date: 2026-04-27`, `author: holden-halford`, `category: process`, `agent_context: cdr-milestone-standards`. Title unchanged — `(Phase Pattern)` parenthetical already implies scope partition.

3. **Six specific edits:**
   - **Edit 1 (Status section notation):** append amendment line: `_Amended 2026-05-07: Scope partitioned with [CDR-023](https://github.com/Brite-Nites/handbook/blob/main/decisions/CDR-023-flow-driven-architecture.md). Phase Pattern remains the standard for non-UI-bearing builds; UI-bearing builds use Domain Pattern per CDR-023._`
   - **Edit 2 (NEW `## Scope` section between `## Status` and `## Context`):** locked option (a) — no amended-CDR precedent in handbook (sampled 4 CDRs found none); reader-friendly placement wins ("does this apply to me?" before reading Context). Section text partitions UI-bearing (CDR-023) vs non-UI-bearing (this CDR); both patterns coexist; dispatch by build type.
   - **Edit 3 (Decision intro phrase):** prepend "Within the scope defined above, " to "A Brite **Milestone** is..."
   - **Edit 4 (Pattern migrations preamble):** rewrite to "The standard **within non-UI-bearing scope** converges to Phase only..." + "**UI-bearing legacy phase-pattern milestones** follow CDR-023's `/flow:retrofit-project` instead — different migration path with cross-reference appendices, not relabel/Salesforce/etc."
   - **Edit 5 (Exceptions section — replace "None identified"):** real exception clause naming the FDA partition: "The Phase Pattern doesn't apply to UI-bearing builds — those use Domain Pattern per CDR-023. For UI-bearing legacy projects with existing Phase Pattern milestones, run `/flow:retrofit-project` instead of `/workflows:fix-milestone --migrate ...` — additive-only retrofit leaves legacy milestones in place with `## FDA migration` cross-reference appendix." + retain prior text ("Within non-UI-bearing scope, the 8-check quality bar applies uniformly...") for clarity.
   - **Edit 6 (Related section — add 2 cross-refs):** **NEW** entries: `[CDR-023](URL) — Flow-Driven Architecture for UI-Bearing Builds (the complement; partitions scope at UI-bearing vs non-UI-bearing)`; `Handbook: [flow-driven-architecture.md](URL) (Q34 — companion operating-standards page for the UI-bearing complement)`. **`[NEW]` review markers stripped before commit** — git history is the diff source-of-truth. All cross-refs use absolute GitHub URLs per Q14.2 pattern + body-level GitBook migration TODO comment in Edit 2's Scope section.

4. **Audit-trail mechanism — Status section notation + git history.** No new front-matter fields. Uniform with existing 21 CDRs.

5. **Companion `milestones.md` operating-standards amendment** at `Brite-Nites/handbook/how-we-work/operating-standards/milestones.md` (file path verified via gh API). **Front-matter bump:** `last_reviewed: 2026-04-26 → 2026-05-07` (today). **No `last_amended` field added** — sampling milestones/projects/issues/cycles confirmed NO operating-standards page has `last_amended`; introducing it would break uniform convention. **Body addition (right after lead paragraph):** new `## When this standard applies` section parallel to Q34's `## Where this fits with CDR-014` — partitions UI-bearing (CDR-023 + flow-driven-architecture.md) vs non-UI-bearing (this CDR + milestones.md). Absolute GitHub URLs + GitBook TODO comment.

6. **File paths verified via gh API:** CDR-014 at `Brite-Nites/handbook/decisions/CDR-014-milestone-standards.md`; milestones.md at `Brite-Nites/handbook/how-we-work/operating-standards/milestones.md`.

**Q35 amendment 1 — CDR-022 → CDR-023 renumber (LOCKED 2026-05-08, drafter D session per Step 2.A pre-flight catch).** Q35 originally referenced FDA CDR as "CDR-022" throughout amendment edits + companion `milestones.md` content (Status section notation, Edit 1 + Edit 4 + Edit 5 + Edit 6 cross-refs, milestones.md `## When this standard applies` section). All renumbered to CDR-023 via memory-file bulk rename 2026-05-08. Audit-trail rationale: handbook collision discovered at Step 2.A pre-flight gh-API verification — handbook already has `CDR-022-asset-taxonomy.md` (drake-mooneyham, Accepted 2026-05-06; same-day-lock as Q33). Same-day-lock conflict undetected during Q33 drafting because parking-lot-#39 cribbing-verification discipline was not yet established at 2026-05-06 (Q48 lock established the discipline at 2026-05-07; first execution-phase application caught this collision at Step 2.A pre-flight 2026-05-08). Cross-link with Q33 amendment 1 + Q34 amendment 1 — all 3 amendments share single audit-trail rationale + single rename event. Schema-discipline-faithful: amendment-with-audit-trail per Q31 amendments 1+2 + Q24 amendment 1 + Q21 amendment 1 + Q50 amendments 1+2 precedent.

**Q34 — Operating-standards page content draft (LOCKED 2026-05-06).** Lives at `Brite-Nites/handbook/how-we-work/operating-standards/flow-driven-architecture.md`. Practitioner-facing companion to CDR-023's policy framing — "how we actually use this" vs CDR-023's "why this is the rule." Length: ~1500-2000 words (matches `milestones.md` density at ~7800 bytes / ~1700 words). Six sub-decisions:

1. **Front-matter** mirrors `milestones.md` verbatim: `title: Flow-Driven Architecture` + `agent_context: operating-standards-flow-driven-architecture` + `last_reviewed: 2026-05-06` + `refresh_cadence: quarterly` + `owner: holden-halford`.

2. **Section structure — 8 H2 sections** (Override flow demoted to sub-section per `milestones.md:111` precedent — verified against source-of-truth at lock time): (a) Lead paragraph; (b) `## When to use FDA`; (c) `## The 4-tier hierarchy`; (d) `## Per-tier shape` with 4 sub-sections (Domain milestone / Sub-flow parent / Discipline children / Flow INDEX); (e) `## Templates`; (f) `## Plugin tooling`; (g) `## Quality gate` with sub-sections (`### Deterministic gates` / `### Informational signals` / `### Where the gates are invoked` / `### Override flow`); (h) `## Migration / retrofit`; (i) `## Where this fits with CDR-014`.

3. **Content scope:** here = process-level "how" (4-tier explained briefly per tier with practical guidance, "what good looks like" paragraphs, quality gate invocation patterns, migration playbook). Defer to CDR-023: policy-level "why" + decision rationale + alternatives. Defer to CDR-014 (Q35-amended): when Phase Pattern applies. Defer to plugin CLAUDE.md (Q55): specific slash command counts + sub-skill counts + agent counts (drift-tolerant).

4. **Decision content drafted (key paragraphs validated against source-of-truth):** (a) When-to-use disciplines bullet lists **5 disciplines** (story, engineering, design, QA, customer docs) per Q24:368 lock; corrected from initial 4-bullet draft. (b) 4-tier hierarchy uses verified counts: **BriteBase has 28 domains** (per `docs/product/master-flow-inventory.md` `### <DOMAIN>` headers grep); **TEAM has 8 sub-flows** (TEAM-01..TEAM-08); **QUO has 43 sub-flows** (`| QUO-` row count). **Brand Hub count deliberately dropped** — that's a legacy-milestone count (27 pre-FDA milestones), NOT an FDA-domain count; FDA-domain count for Brand Hub is determined by `/flow:retrofit-project` at runtime; embedding a number would mislead readers. (c) Templates section drops the "7 templates" count and lists 7 categories instead — actual file count is 11 (Q24 contributes 5 discipline-child variants), but counts drift; categories don't. (d) Migration section uses **explicit cutover prose** instead of opaque "policy (a)" shorthand: "Existing in-flight legacy work continues in its original Phase Pattern shape until completion; new work after the retrofit cutover goes in the new FDA structure. The cutover timestamp is recorded in `.flow-phase-state.json` so the boundary is traceable." (e) `## FDA migration` cross-reference section mechanism **preserved as drafted** — Q9:46 + Q14.2:80 both explicitly lock the section name + HTML-comment markers; verification confirmed the mechanism is twice-locked.

5. **Cross-reference pattern:** absolute GitHub URLs per Q14.2 pattern + `<!-- TODO: when handbook migrates to public GitBook docs site, replace absolute GitHub URLs with GitBook canonical URLs. -->` HTML comment. Cross-refs to CDR-023, CDR-014, templates at `handbook/about-handbook/style-guide/templates/`, plugin at `Brite-Nites/brite-claude-plugins/plugins/flow-architecture/`.

6. **Length target ~1500-2000 words.** FDA has more depth (4 tiers × multiple artifacts each) but defers details to templates / CDR-023 / plugin docs to avoid bloat — matches `milestones.md` density.

**Q34 amendment 1 — CDR-022 → CDR-023 renumber (LOCKED 2026-05-08, drafter D session per Step 2.A pre-flight catch).** Q34 originally cross-referenced FDA CDR as "CDR-022" in operating-standards page body (sub-decision 3 content scope deferral; sub-decision 5 cross-reference pattern; sub-decision 6 length target deferral). All renumbered to CDR-023 via memory-file bulk rename 2026-05-08. Cross-link with Q33 amendment 1 + Q35 amendment 1 — all 3 amendments share single audit-trail rationale (handbook collision with `CDR-022-asset-taxonomy.md`; full rationale documented in Q33 amendment 1 entry). Schema-discipline-faithful: amendment-with-audit-trail per Q50 amendments 1+2 precedent.

**Q34 amendment 2 — about-handbook subdir path correction (LOCKED 2026-05-10, drafter D session per Step 2.B pre-flight catch).** Q34 sub-decision 5 (cross-reference pattern) originally referenced templates path as `about-handbook/style-guide/templates/`. Bulk-renamed to `handbook/about-handbook/style-guide/templates/` via memory-file Edit replace_all 2026-05-10. Cross-link with Q2 amendment 1 — canonical full audit-trail rationale; about-handbook is subdirectory of handbook repo, not separate repo.

**Q33 — CDR-023 content draft (LOCKED 2026-05-06; status: Proposed).** Per Q2 lock: title `"Flow-Driven Architecture for UI-Bearing Builds"`. Per Q1 lock: introduces Domain-as-Milestone as default for UI-bearing builds; CDR-014 amended at Q35 to clarify Phase Pattern remains standard for non-UI-bearing work. Lives at `Brite-Nites/handbook/decisions/CDR-023-flow-driven-architecture.md` (handbook repo, not BriteBase). Mirrors CDR-014 structural pattern. Six sub-decisions:

1. **Front-matter:** `cdr_id: CDR-023`, `title: "Flow-Driven Architecture for UI-Bearing Builds"`, `status: Proposed` (Option A standard CDR lifecycle — transitions to Accepted post-Brand-Hub-dogfood + plugin v1.0; Option B "Accepted on multi-session interview equivalence" rejected for consistency with handbook's CDR lifecycle pattern), `date: 2026-05-06`, `author: holden-halford`, `category: process`, `agent_context: cdr-flow-driven-architecture`, `related_cdrs: [CDR-014, CDR-016, CDR-018, CDR-019]`.

2. **Section structure (TOC):** Status / Context (~3 paragraphs: BriteBase RFC backstory + Phase 3 sign-off + motivation for codification) / Decision with 10 sub-sections (4-tier hierarchy / Linear field mapping / Repo-side artifacts / Templates / Quality gate / Tooling / When-this-CDR-applies / When-CDR-014-applies-instead / Migration path / Enforcement architecture) / Consequences (Positive/Negative/Neutral) / Alternatives considered (5-row table) / References.

3. **Decision content drafted (key paragraphs):** 4-tier hierarchy (Domain → Sub-flow → Disciplines → INDEX); Linear field mapping (milestone/parent/child title formats; type:* + domain:* labels; **blockedBy chain [Story] → ([Design] || [Eng]) → [QA] → [Docs]**); repo-side artifacts (paths to intent/inventory/journeys/flows/customer-docs/`.flow/`); templates (Q22-Q28 promoted to handbook/about-handbook/style-guide/templates/); quality gate (Q29 35-gate stack reference); **tooling drift-tolerant: defers counts to plugin's own CLAUDE.md** (does NOT hardcode 17/10/12/6 counts — those drift across versions); when-applies (BriteBase, Brand Hub, future Brite tools); migration path (Brand Hub v1 dogfood + BriteBase Phase 4 manual exception); **enforcement architecture uses locked language**: "Hard gates per Q29.4 block discipline-child closure when violated; resolution requires fixing the gate condition or invoking the override flow per Q29.5 — `AskUserQuestion` with reason captured to `.flow-phase-state.json` `overrides[]`" (NOT "pre-completion hooks" which isn't locked terminology).

4. **Consequences:** 5 positive (per-flow accountability / customer-docs upstream / cross-discipline contracts explicit / Linear+docs+Figma converged / INDEX at-a-glance state) + 4 negative (Linear footprint multiplier 6 issues/sub-flow / scaffold effort 2+7N writes per domain / doc-tree expansion / multi-perspective review bootstrap ~57 reviews for Brand Hub) + 3 neutral (retrofit-vs-greenfield orchestrator distinction / strict-5 audit cost / Brand Hub dogfood acceptance gates 1.0).

5. **Alternatives considered (5-row table):** Keep Phase Pattern only / Extend Phase Pattern with custom fields / Project-per-domain (28 Linear projects) / Milestone-per-sub-flow (no domain layer) / Story doc per discipline child. Each row has rejection reason.

6. **References (absolute GitHub URLs per Q14.2 pattern):** RFC at `https://github.com/holdeeno/brite-base/blob/main/docs/designs/flow-issue-architecture.md`; operating-standards at `https://github.com/Brite-Nites/handbook/blob/main/how-we-work/operating-standards/flow-driven-architecture.md` (Q34); templates at `https://github.com/Brite-Nites/handbook/tree/main/about-handbook/style-guide/templates/`; plugin at `https://github.com/Brite-Nites/brite-claude-plugins/tree/main/plugins/flow-architecture/`; amended CDR-014 at `https://github.com/Brite-Nites/handbook/blob/main/decisions/CDR-014-milestone-standards.md` (Q35). Plus HTML comment in body: `<!-- TODO: when handbook migrates to public GitBook docs site, replace absolute GitHub URLs with GitBook canonical URLs. -->`

**Q33 amendment 1 — CDR-022 → CDR-023 renumber (LOCKED 2026-05-08, drafter D session per Step 2.A pre-flight catch).**

**Original Q33 lock content** referenced FDA CDR as **CDR-022** throughout: front-matter `cdr_id: CDR-022`, file path `decisions/CDR-022-flow-driven-architecture.md`, body content + Decision sub-sections + References absolute GitHub URL. Same-day-lock conflict undetected during Q33 drafting because parking-lot-#39 cribbing-verification discipline was not yet established at 2026-05-06 (Q48 lock established the discipline at 2026-05-07).

**Catch event:** Step 2.A pre-flight gh-API verification 2026-05-08 surfaced handbook already has `decisions/CDR-022-asset-taxonomy.md` (drake-mooneyham, Accepted 2026-05-06; same-day-lock as Q33). Drafter D (executor mode, post-design-phase-close) caught namespace collision before PR composition. **First execution-phase application of validation-first discipline against an org-level artifact namespace** — pattern extends parking-lot-#39 from external cribbed sources (gstack, workflows) to org-level namespaces (CDR numbers, template paths, file paths in shared repos).

**Renumber applied:** all "CDR-022" occurrences in memory bulk-renamed to "CDR-023" via Edit replace_all 2026-05-08. Affected lock entries: Q33 (this entry), Q34 (operating-standards page content cross-refs), Q35 (CDR-014 amendment edits + companion milestones.md amendment cross-refs), plus tertiary references in Q2 / Q14.2 / Q36 / Q41 / Q55 / Q40 / parking-lot-#33 / handoff notes. CDR-023 is next available sequentially in handbook (handbook CDR list runs CDR-001 through CDR-022 with no gaps; CDR-023 is the natural next slot).

**Status field unchanged:** Proposed (per Q33 R1 lifecycle); transitions to Accepted at plugin v1.0 ship per Q40 release sequence step 8. Date field unchanged: 2026-05-06 (drafting date doesn't change with content correction).

**Cross-link:** Q33 amendment 1 carries the canonical full audit-trail rationale; Q34 amendment 1 + Q35 amendment 1 reference this entry for shared context. All 3 amendments share single rename event 2026-05-08.

**Schema-evolution discipline reinforced:** Q33 amendment 1 follows Q31 amendments 1+2 + Q24 amendment 1 + Q21 amendment 1 + Q50 amendments 1+2 precedent — explicit amendment-number + audit trail in originating Q-lock; cross-link to companion amendments (Q34 amend 1 + Q35 amend 1) which inherit the audit-trail context. Total amendment count after Q33/Q34/Q35 amendments: **9 amendments** (Q31 amend 1+2, Q24 amend 1, Q21 amend 1, Q50 amend 1+2, Q33 amend 1, Q34 amend 1, Q35 amend 1).

**Methodology lesson recorded (parking-lot-#39 extension to org-level namespaces):** parking-lot-#39 cribbing-verification discipline applies not only to external cribbed sources (gstack, workflows, compound-engineering) but also to **org-level artifact namespaces** (CDR numbers, template paths, file paths in shared repos like handbook + about-handbook + plugin repo) that may have parallel claimants. Pre-flight verification at draft time MUST include namespace-collision checks against authoritative org artifacts. Drafter D's Step 2.A pre-flight catch is the first execution-phase application; pattern documented in parking lot #39 extension below.

**Q33 amendment 2 — about-handbook subdir path/URL correction (LOCKED 2026-05-10, drafter D session per Step 2.B pre-flight catch).** Q33 sub-decision 3 (Decision content drafted) originally referenced template path as `about-handbook/style-guide/templates/`; sub-decision 6 (References) originally referenced absolute URL `https://github.com/Brite-Nites/about-handbook/tree/main/style-guide/templates/`. Both bulk-renamed via memory-file Edit replace_all 2026-05-10: path → `handbook/about-handbook/style-guide/templates/`; URL → `https://github.com/Brite-Nites/handbook/tree/main/about-handbook/style-guide/templates/`. **Cascading effect on PR #513 shipped artifacts:** CDR-023 content + operating-standards FDA page rendered with the original (incorrect) URLs; fix-commit pushed to PR #513 branch 2026-05-10 to correct in-flight content. Cross-link with Q2 amendment 1 — canonical full audit-trail rationale.

**Q21 — Agent definitions (LOCKED 2026-05-06; expanded from 9 → 12 agents).** Three Q21.0 foundational decisions resolved at lock time: (a) **dropped `index-regenerator`** from named-agent list — Q18 is deterministic with no LLM dispatch, so it doesn't fit the named-agent pattern; (b) **promoted `fidelity-reviewer` to named agent** — used cross-cuttingly by Q13/Q15/Q16 (replacing `general-purpose` dispatch from `feedback_bulk_create_review_agents.md`); promotes packaging without changing runtime behavior; (c) **added `plan-ceo-reviewer` + `plan-devex-reviewer`** for Q54 L1/L2 perspective coverage gap (the locked 9-agent count predated Q54's full-chain lock; 9 was an early estimate). Plus **split `doc-author` into `story-doc-author` + `journey-doc-author`** at lock time — Claude Code agent definitions take a single `model:` frontmatter value; story (Q27 JTBD-with-AC) and journey (Q26 narrative-with-phases) have genuinely different templates/prompts/output-shapes that benefit from focused contracts. Net: 9 + 1 (fidelity-reviewer) + 2 (CEO + DevEx) - 1 (index-regenerator) + 1 (split doc-author into 2) = **12 named agents**.

**Cadence convention (verified `housekeeping-preflight.md`):** frontmatter has `name` + `description` + `model` + `tools`; body is prompt template + steps.

**12-agent spec:**

1. **inventory-author** — sonnet; tools: Read/Glob/Grep/WebSearch/WebFetch; invokers: Q11 P4 + Q19 P4 + Q20 domain-add; returns: markdown blob (BriteBase inventory schema).
2. **codebase-inferrer** — haiku; tools: Read/Glob/Grep/Bash (limited); invokers: Q11 P3 + Q15.7 + Q17.2 (via `_shared/code-evidence-collector.md`); returns: structured JSON `{flow_id: {found, files, tests, sandbox_url, status_inferred (NOT_STARTED/IN_PROGRESS/BUILT)}}`.
3. **story-doc-author** — sonnet; tools: Read/Glob/Grep; invokers: Q15; returns: filled markdown (Q27 conformant; validated by `verify-docs.sh`).
4. **journey-doc-author** — sonnet (v1; opus v1.1 enhancement candidate — see parking lot); tools: Read/Glob/Grep; invokers: Q16; returns: filled markdown (Q26 conformant).
5. **fidelity-reviewer** — haiku (cheap parallel); tools: Read/Glob/Grep/mcp__plugin_workflows_linear-server__get_issue (filesystem-side checks for Q15/Q16 + Linear-side for Q13); invokers: Q13 (per-issue background), Q15 (per-doc), Q16 (per-doc); returns: `{result: PASS|FAIL, findings: [string≤5], cosmetic_ignored: [string]}` <150 words.
6. **plan-story-reviewer** — sonnet; tools: Read/Glob/Grep; invokers: L3 (during scaffolding, all 5 dispatched per sub-flow) + L4 (`/flow:plan-story`); returns: `{headline, adjustments}` — headline auto-populates parent's L3 review summary section per Q23 mod 2.
7. **plan-eng-reviewer** — sonnet; tools: Read/Glob/Grep; invokers: L1 (`/flow:office-hours`) + L3 + L4 (`/flow:plan-eng`); returns: same as plan-story-reviewer.
8. **plan-design-reviewer** — sonnet; tools: Read/Glob/Grep; invokers: L1 + L2 (during inventory synthesis or `/flow:add-domain`) + L3 + L4 (`/flow:plan-design`); returns: same.
9. **plan-qa-reviewer** — sonnet; tools: Read/Glob/Grep; invokers: L3 + L4 (`/flow:plan-qa`); returns: same.
10. **plan-docs-reviewer** — sonnet; tools: Read/Glob/Grep; invokers: L3 + L4 (`/flow:plan-docs`); returns: same.
11. **plan-ceo-reviewer** — sonnet; tools: Read/Glob/Grep; invokers: L1 + L2; returns: `{headline, strategic_concerns}` — headline lands in PROJECT-INTENT.md (L1 per Q42) or domain journey doc's `## L2 review summary` section (Q26 mod 2).
12. **plan-devex-reviewer** — sonnet; tools: Read/Glob/Grep; invokers: L1 only; returns: `{headline, ergonomic_concerns}`. **Description includes early "is this developer-facing?" check** — non-developer-facing projects (most Brite projects: Brand Hub, BriteBase, internal tools) → returns minimal "not applicable for this project type" headline + skips deep analysis.

**Q54 perspective coverage matrix verified:**
- L1 (`/flow:office-hours`): CEO + Design + Eng + DX → plan-ceo-reviewer + plan-design-reviewer + plan-eng-reviewer + plan-devex-reviewer ✓
- L2 (inventory synthesis OR `/flow:add-domain`): CEO + Design → plan-ceo-reviewer + plan-design-reviewer ✓
- L3 (scaffolding OR `/flow:add-sub-flow`): ALL 5 → plan-{story,eng,design,qa,docs}-reviewer ✓
- L4 (`/flow:session-start` Step 5): SINGLE of {Story,Eng,Design,QA,Docs} → exactly 1 of plan-{story,eng,design,qa,docs}-reviewer ✓

**Meta-Q — Multi-level autoplan-shaped review pattern (FULL-CHAIN locked, light-touch rejected).** The gstack autoplan pattern recurs at 4 levels in FDA:

- **L1 PROJECT** — inside `/flow:office-hours`, after Q1-Q6 collected. Perspectives: CEO + Design + Eng + DX. Output: refined PROJECT-INTENT.md.
- **L2 DOMAIN** — during inventory synthesis OR `/flow:add-domain`, before milestone scaffolding. Perspectives: CEO + Design only (Eng/QA/Docs too coarse).
- **L3 SUB-FLOW** — during scaffolding OR `/flow:add-sub-flow`. Perspectives: ALL 5 — full autoplan analog. Output: vetted sub-flow scope informing all 5 discipline-child bodies.
- **L4 DISCIPLINE CHILD** — JIT during `/flow:session-start` Step 5. SINGLE discipline only. NOT autoplan.

Plan-X skills (Q43) are **scope-polymorphic** — same skills invoked at multiple levels. User REJECTED light-touch L2/L3 default. Bootstrap cost accepted: ~57 multi-perspective reviews for Brand Hub-shaped retrofit.

## Templates phase (Phase C) — ALL 7 LOCKED

All 7 templates locked through 2026-05-06. Modifications layer onto existing BriteBase templates where they exist; Q28 is NEW.

**Q22 — Domain-as-milestone description template (LOCKED).** 7-section template (5 required + 2 optional):
- Eyebrow link block: Spec docs / Domain journey / Anchor (PROJECT-INTENT) / Tracker
- ## Domain definition (required)
- ## Personas (primary/secondary/out-of-scope)
- ## Sub-flows in this domain (auto-regenerated table — count is whatever makes sense, no constraint)
- ## Journey (narrative link + **Narrative shape:** with NO phase count constraint — was "5-phase shape", corrected)
- ## Cross-domain dependencies (optional — omit if none)
- ## Why this domain exists (PROJECT-INTENT-grounded)
- ## Notes (optional — status caveats, free-form)

~300-450 words. Sub-flows table regenerated by `flow-linear-scaffold` + `/flow:add-sub-flow` via Linear MCP (NOT by `flow-regen-index` — milestone descriptions live in Linear). Same do-not-hand-edit rule as INDEX.md. Lives at `handbook/about-handbook/style-guide/templates/domain-milestone.md` when promoted.

**Q22 amendment 1 — about-handbook subdir path correction (LOCKED 2026-05-10, drafter D session per Step 2.B pre-flight catch).** Q22 originally referenced template promotion target as `about-handbook/style-guide/templates/domain-milestone.md`. Bulk-renamed to `handbook/about-handbook/style-guide/templates/domain-milestone.md` via memory-file Edit replace_all 2026-05-10. Cross-link with Q2 amendment 1 — canonical full audit-trail rationale; about-handbook is subdirectory of handbook repo, not separate repo.

**Q23 — Sub-flow parent issue template (LOCKED).** Adopt existing `docs/templates/issues/parent.md` as base. ~30-line target preserved. 5 modifications: (1) add Project intent link to eyebrow block; (2) add `## L3 review summary` section auto-populated by scaffolding orchestrator with per-discipline review headlines (CEO/Story/Eng/QA/Docs); (3) Children table gains Type column (`type:story|eng|design|qa|docs`); (4) Cross-links section adds Sandbox harness link, drops stale "live demo"; (5) Definition of done adds checkbox for "All discipline-quality-gates pass per /flow:audit on this parent" (stub until Q29 lock). Title format unchanged. Labels: `type:parent`, `domain:<lowercase>`.

**Q23 amendment 1 — mod 2 L3 review-headlines roster correction (LOCKED 2026-05-11 per BC-6965 /workflows:review iteration 1 fold-in).** Q23 mod 2 (lock body above) lists per-discipline review headlines as `(CEO/Story/Eng/QA/Docs)`. The canonical L3 reviewer roster across plugin CLAUDE.md § L-review pattern + the agent dispatch MATRIX + sibling orchestrator commands (`commands/start-project.md` L102, `commands/retrofit-project.md`, `commands/add-sub-flow.md`) is `(Story + Eng + Design + QA + Docs)` — CEO is L1/L2-only per the agent MATRIX (`plan-ceo-reviewer: L1, L2`; never L3) and the four-parallel L1 composition rule (CEO + Design + Eng + DevEx) does not extend to L3. This amendment corrects mod 2's roster from `CEO/Story/Eng/QA/Docs` to `Story/Eng/Design/QA/Docs`. Original mod 2 text preserved verbatim per the schema-discipline amendment pattern (cf. Q21 amendment 1, Q24 amendment 1, Q29 amendment 1, Q31 amendments 1+2, Q41 amendment 1). Caught in BC-6965 /workflows:review iteration 1 by code-reviewer P3 conf 8 via direct cross-read of memory:515 against plugin CLAUDE.md + agent MATRIX (`plan-ceo-reviewer` rows L1/L2; `plan-design-reviewer` rows L1/L2/L3/L4). Derivative re-sync: sibling orchestrators citing "per Q23 mod 2" already render the canonical Story+Eng+Design+QA+Docs roster — citations stay valid post-amendment.

**Q24 — Five discipline-child issue templates (LOCKED).** Adopt existing 5 templates at `docs/templates/issues/{story,engineering,design,qa,docs}.md` as base. EPEV format (Explore/Plan/Execute/Verify) preserved. 5 modifications across all 5: (1) Add `docs/product/intent.md` to Explore-section reading list; (2) Add "How to pick up this work" section explaining `/flow:session-start` → `/flow:plan-<discipline>` dispatch at L4; (3) Standardize labels to colon-separated `type:story|eng|design|qa|docs` + `domain:<slug>`, drop legacy `documentation`/`Engineering`/`quality`; (4) Add "Cross-discipline context" auto-populated section (sibling discipline-child summaries via Q46 layer with HTML-comment idempotency markers); (5) Add optional "Scaffolded with L3 review" pointer section. Estimates preserved (1-2h Story / 1-2d Eng / 4-8h Design / 4h QA / 2h Docs). blockedBy chains preserved per templates: **[Story]** has no blockedBy (foundation — Design frames map to AC in the story doc, Eng implements against story doc AC); **[Design]** blockedBy [Story]; **[Eng]** blockedBy [Story]; **[QA]** blockedBy [Eng] + [Design] (both must be done); **[Docs]** blockedBy [QA]. **Execution graph: [Story] → ([Design] || [Eng]) → [QA] → [Docs]** — Design and Eng parallelize AFTER Story exists, not from the start. QA structured-run comment template embedded in qa.md preserved. **Amendment for Q28 alignment:** [Docs] child template (docs.md) replaces inlined customer-doc front-matter+body spec with a pointer to `docs/templates/customer-how-to.md` (Q28) — symmetric to how [Story] child references `docs/templates/job-story.md` (Q27).

**Q25 — Flow INDEX.md schema + template (LOCKED; mod 1 amended 2026-05-06).** Adopt existing INDEX.md schema as base. 11-column table (ID/Flow/Status/Story/Parent/Eng/Design/QA/Docs/Figma/Live), 6-state status taxonomy + BLOCKED orthogonal flag, 5-emoji discipline legend (✓/🚧/⏳/❌/—), section order = master-inventory order — all preserved. 5 modifications: (1) Section headers gain explicit emoji-prefixed links to journey doc + Linear milestone, **AMENDED at Q18 lock 2026-05-06** for consistency with Story column's `[📄](link)` convention: `## <DOMAIN> — <Display name> · [📕 journey](../journeys/<domain>.md) · [📍 milestone](<linear-url>) · (<N> sub-flows)` (plain title, journey + milestone as separate emoji-prefixed dot-separated links — supersedes earlier `## [DOMAIN — Name](../journeys/<domain>.md) · [milestone](linear-url) · (<N> sub-flows)` form); (2) Add PROJECT-INTENT.md reference paragraph in header; (3) Add `generated_at` ISO timestamp + `generated_by: flow-regen-index@<version>` to front-matter on regen; (4) Codify regen-scope rule explicitly — `flow-regen-index` regenerates ONLY table row data; section headers, status notes, footnotes, ALL non-table prose preserved across regens (parser finds tables by column-header signature); (5) Use `<PROJECT_NAME>` placeholder for plugin reusability. Customer-doc URL stays implicit (one click from Story column → front-matter); revisit as 12th column in v1.1 if needed.

**Q26 — Per-domain user journey doc template (LOCKED).** Adopt existing `docs/templates/domain-journey.md` as base. **8 sections** after dropping redundant "Title + domain code" (corrected from "9 sections" via Q16 validation 2026-05-06: actual H2 count in template is 9 currently → drop Title+domain (mod 3) → 8 post-mod). 5 modifications: (1) Add `intent: docs/product/intent.md` to front-matter and "See also" section; (2) Add optional "L2 review summary" section capturing CEO + Design perspectives at L2 scope (per meta-Q lock); (3) Drop redundant "Title + domain code" section; (4) Q22 milestone template amendment — "Narrative shape:" with NO phase count constraint (corrected from earlier "5-phase shape"); (5) Remove "4-8 phases" language from template entirely — phase count is whatever fits the domain. Per-phase sub-structure preserved (persona / mindset / narrative / pain points / opportunities / job stories table). 1:1 with Linear milestone preserved. Modification 6 (per-phase last_reviewed) parked v1.1.

**Q27 — Job story doc template (LOCKED).** Adopt existing `docs/templates/job-story.md` as base. All 17 front-matter fields preserved. 7 body sections preserved. JTBD When/I want/So I can format preserved. 3-5 Gherkin AC preserved. QA history table format preserved. ~80-150 line target validated by TEAM-04 at 118 lines. 2 modifications: (1) Add `intent: ../../intent.md` to front-matter and Cross-references section; (2) Formalize optional `## Status notes` section between one-line summary and "Job story" — captures cut/pilot context, blocking dependencies, special handling. Modification 3 (`last_synced_to_linear` timestamp) parked v1.1.

**Q27 amendment 1 — add modification 4: `## Cross-domain dependencies` section (LOCKED 2026-05-26 per BC-10729 — Triage Event #3 entry #6 v1.1.x promotion).** Brand-hub iter-3 dogfood (BC-10321) surfaced ~10 cross-domain build-order blocks + gating-concentration hotspots documented only as prose in story-doc bodies (e.g., `asset-unification-02 cannot ship before creative-operations-02`; `access-governance-02 RoleGate gates asset-unification-02 + creative-operations row drag`). Downstream consumers reading those story docs cannot query "what blocks my domain" without manual grep. This amendment promotes a different "mod 3" concept to a new **modification 4** slot (parking-lot #12's `last_synced_to_linear` timestamp remains mod 3 / parked v1.1; numbering preserved):

- **Modification 4 — optional `## Cross-domain dependencies` section.** Slot position: between `## Status notes` (mod 2) and `## Job story` (Q27 body §3). Format: H2 header (`## Cross-domain dependencies`) followed by a bullet list, one bullet per cross-domain relation, each in one of two shapes:
  - `<this-flow-id> blockedBy <other-flow-id> — <one-line reason>` (build-order block; THIS sub-flow cannot ship until the OTHER ships)
  - `<this-flow-id> gates <other-flow-id> — <one-line reason>` (gating concentration; the OTHER sub-flow cannot ship until THIS ships)

  **Inclusion rule:** OPTIONAL section, same shape as `## Status notes` (mod 2) — include ONLY when the sub-flow has at least one cross-domain dependency. Sub-flows with no cross-domain coupling omit the section entirely. Self-domain dependencies (e.g., `asset-unification-02 blockedBy asset-unification-01`) are tracked via sibling story-doc front-matter `related_flows` (Q27 base template field) — NOT in this section. This section is **cross-domain only**.

  **Linear contract (1:1 mirror).** Every `blockedBy` bullet has a matching Linear `blockedBy` relation on the sub-flow parent issue; every `gates` bullet is the inverse view of a `blockedBy` on the OTHER sub-flow's parent — both directions enforced by the Q29 amendment 2 cross-ref consistency gate (`cross-domain-deps-bidirectional`). The doc-side annotation is the queryable view; the Linear-side relation is the workflow-state view; the audit gate enforces the 1:1 mapping.

  **Author responsibility.** `flow-doc-author` (Q15) extends from 8 → 9 narrative sections to cover the new optional section (skill update tracked at `plugins/flow-architecture/skills/flow-doc-author/SKILL.md` §1). When `flow-linear-scaffold` (Q13) writes `blockedBy` relations on parent issues, the corresponding doc bullet is authored by `flow-doc-author` in the same scaffold cycle to preserve 1:1 invariance.

  **Worked example** (from brand-hub iter-3 findings):

  ```markdown
  ## Cross-domain dependencies

  - asset-unification-02 blockedBy creative-operations-01 — empty-state CTA targets the intake form
  - asset-unification-02 blockedBy creative-operations-02 — pre-fill payload contract requires CreativeRequests collection
  - asset-unification-02 blockedBy access-governance-02 — role-aware empty-state copy depends on `<RoleGate>` pattern
  ```

**Rationale for promotion to canonical-template-worthy modification (not `_shared/` sibling pattern):** every UI-bearing FDA domain scaffolded against a non-trivial app surface accumulates cross-domain build-order coupling once 5+ domains land. Brand Hub surfaced ~10 distinct relations across 9 of 10 domains during iter-3. Promoting to Q27 ensures the surface is `flow-doc-author`-authored at scaffold time, not retrofitted manually per-project. The `_shared/cross-domain-deps.md` sibling-pattern alternative (BC-10729 § Option B) was considered and rejected: it would have made the surface optional-by-convention rather than optional-by-template, allowing downstream FDA consumers to silently skip the annotation without operator awareness.

**Backfill scope (Linear-side only).** This amendment ships the template change + the audit gate (Q29 amendment 2) + a real-consumer's worth of brand-hub backfill data via `save_issue` `blockedBy` relations on 5 brand-hub sub-flow parent issues covering 7 distinct cross-domain relations from iter-3 findings (asset-unification-02 × 3, analytics-dashboard-03 × 1, data-quality-migration-06 × 1, asset-content-libraries-03 × 1, asset-content-libraries-01 × 1). The brand-hub story-doc-side annotations are intentionally NOT amended in this BC — Linear-side state is the load-bearing data; doc-side annotation is the queryable view authored at scaffold time. Retroactive doc-side authoring against brand-hub's already-shipped story docs is a non-blocking follow-up tracked downstream.

**Schema-evolution discipline reinforced.** Q27 amendment 1 follows the same precedent as Q21 amendment 1 + Q23 amendment 1 + Q24 amendment 1 + Q28 amendment 1 + Q29 amendment 1 + Q31 amendments 1+2 + Q41 amendment 1 + Q42 amendment 1 + Q47 amendment 1 + Q20 amendments 1+2 — explicit amendment-number + audit trail in the lock entry. Future Q27 amendments would be Q27 amendment 3+.

**Q27 amendment 2 — add the evidence-anchor `## Status` body section to the story-doc template (2026-05-30, [BC-11983](https://linear.app/brite-nites/issue/BC-11983) WS-E precursor; cross-referenced from § Q58 amendment 2).** The brite-sites re-author (grill decision D4) introduced an FDA-additive `## Status` body section, distinct from the front-matter `status` / `status_notes`: for a `BUILT` / `IN_PROGRESS` flow it states the rollup build verdict and lists **evidence anchors** — real `path:symbol` references a reviewer can open — plus genuine per-flow open questions; for an unbuilt flow it states `NOT_STARTED — no implementation yet`. It directly serves quality-rubric **D5** (honest status) and **D10** (no fabrication) by grounding claims in openable code. This is a genuinely new body section beyond Q27's original 7 (Job story / Actor / Preconditions / Acceptance criteria / Out of scope / Cross-references / QA history) plus the two optional sections (mod 2 `Status notes`; amendment 1 mod 4 `Cross-domain dependencies`), so it is recorded as a proper amendment rather than folded silently into the Q58-amendment-2 copy-manifest entry. **Position:** after `## Out of scope / no-gos` (and after the optional `## Cross-domain dependencies` when present), before `## Cross-references`; always present. Adopted by `story-doc-author` + the seeded `docs/templates/job-story.md`; locked by `tests/run-template-alignment-vslice.sh`. Future Q27 amendments would be Q27 amendment 3+.

**Q28 amendment 1 — about-handbook subdir path correction (LOCKED 2026-05-10, drafter D session per Step 2.B pre-flight catch).** Q28 originally referenced template promotion target as `about-handbook/style-guide/templates/customer-how-to.md`. Bulk-renamed to `handbook/about-handbook/style-guide/templates/customer-how-to.md` via memory-file Edit replace_all 2026-05-10. Cross-link with Q2 amendment 1 — canonical full audit-trail rationale.

**Q28 — Customer-facing how-to template (LOCKED — NEW).** Filled the gap noted in CLAUDE.md ("no template yet"). Lives at `docs/templates/customer-how-to.md` (BriteBase) → `handbook/about-handbook/style-guide/templates/customer-how-to.md` (when promoted). Output goes to `docs/product/customer-docs/<domain>/<flow-id>.md`. **8 front-matter fields:** `flow_id`, `public_slug`, `title`, `persona`, `parent_journey`, `prerequisites` (optional), `status` (draft|published|outdated), `last_reviewed`. **5 body sections (3 required + 2 optional):** H1 + one-sentence intro / `## Before you start` (optional) / `## How to <verb-led action>` with 3-5 numbered steps + screenshots / `## Tips` (optional) / `## Common mistakes` (optional) / `## See also`. ~250-400 word body target. **Encoded tone rules in template header:** educational not specification, short sentences active voice, define jargon inline on first mention, screenshots > prose, sandbox-first capture policy. **Forbidden in body:** internal flow IDs, Linear links, component names, RBAC internals, architecture vocabulary. Screenshots co-located at `./<flow-id>-screenshots/`. Output of [Docs] discipline child workflow (Q24). **Symmetric to** `job-story.md` (Q27) being output of [Story] discipline child workflow.

## V1 user-facing surface (LOCKED — Option C "clone-and-swap" pattern)

**17 slash entries** organized by sprint phase + utilities:

- **Orchestrators + Utilities (6):** `/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow` (orchestrators), `/flow:audit`, `/flow:regen-index` (utilities). Corrected from "Orchestrators (5)" via Q30 lock 2026-05-06 — listing has always had 6 entries.
- **Think (1; design-consult deferred to v1.1):** `/flow:office-hours`
- **Plan (1):** `/flow:inventory`
- **L4 discipline planning (5):** `/flow:plan-{story,eng,design,qa,docs}`
- **Cloned inner-loop (3):** `/flow:session-start`, `/flow:review`, `/flow:ship`
- **Reflect (1):** `/flow:retro`

DEFERRED to v1.1: `/flow:design-consult` (greenfield-only, no consumer queued; future state hint = canonical Brite design-system repo at Q49).

## Internal architecture

**Sub-skills (NOT user-invocable):**
- `flow-preflight` — Q12 LOCKED
- `flow-inventory-codebase-scan` — Q11 architecture LOCKED (6-phase)
- `flow-inventory-interview` — greenfield Socratic, shares Phases 1-2 with codebase-scan via app-classifier shared utility
- `flow-inventory-add` — incremental
- `flow-linear-scaffold` — Q13 NEXT (heaviest mutation: creates milestone + parents + 5N children)
- `flow-legacy-cross-reference` — Q9 lock (additive-only annotations)
- `flow-doc-author` — per-domain story docs
- `flow-journey-author` — per-domain narrative
- `flow-sandbox-scaffold` — per-flow on-demand harness scaffolding from L4 workflows (`/flow:plan-eng` + `/flow:plan-qa` pre-flight). Locked Q17 2026-05-06 superseding original "one harness per QA-cycle target" framing — see parking lot.
- `flow-regen-index` — deterministic INDEX rebuild

**Shared utilities under `flow-architecture/_shared/`:**
- `app-classifier-pattern.md` — Q11 Phase 1 shared between codebase-scan + interview
- `four-mode-framework.md` — Q48 (cribbed from gstack plan-ceo-review). Invoked at L1/L2/L3/L4 by different callers.
- `linear-writeback-pattern.md` — Q46 cross-cutting layer. Defines: read-context convention per skill type, Linear-friendly markdown format (numbered lists per BC- precedent), idempotency via stable HTML comment markers, conflict-resolution if user manually edited, notification etiquette.
- `checkpoint-pattern.md` — cribbed from ce-optimize, breadcrumb + write-then-verify
- `artifact-gate-pattern.md` — filesystem-existence gate per phase

**Agents (9 total):**
Original 4: `inventory-author`, `codebase-inferrer`, `doc-author`, `index-regenerator`. Discipline reviewers: `plan-story-reviewer`, `plan-eng-reviewer`, `plan-design-reviewer`, `plan-qa-reviewer`, `plan-docs-reviewer`.

## Permanent artifacts the plugin manages

**In-repo (version-controlled, audited by doc-steward):**
- `docs/product/intent.md` — PROJECT-INTENT.md output of /flow:office-hours
- `docs/product/master-flow-inventory.md` — inventory output
- `docs/product/flows/<domain>/<flow-id>.md` — per-flow story docs (per Q27 template)
- `docs/product/journeys/<domain>.md` — per-domain narratives (per Q26 template)
- `docs/product/flows/INDEX.md` — regenerated cross-reference (per Q25 schema)
- `docs/product/customer-docs/<domain>/<flow-id>.md` — customer-facing how-tos (per Q28 template)
- `docs/plans/<BC>-plan.md` — per-issue execution plans (deletable post-ship)
- `docs/retros/<domain>-<YYYY-MM-DD>.md` — per-domain retros (NEW pattern from /flow:retro)
- `docs/handbook/agent-authoring.md` — lessons-learned table (existing)
- `docs/plans/.flow-phase-state.json` — orchestrator resume breadcrumb
- **`.flow/config.json`** — project-stable mapping (NEW per Q12: linear_project_id, linear_project_name, linear_team_key, fda_first_setup_at, fda_plugin_version)

**Linear (workflow state, team-visible):**
- Domain milestones (per Q22 description template)
- Sub-flow parent issues (per Q23 template)
- 5 discipline children per parent (per Q24 templates)
- parentId + blockedBy chains pre-wired by flow-linear-scaffold
- type:* + domain:* labels (workspace-level group from Cut 2)
- Plan sections appended to issue bodies via Q46 layer (idempotent)
- Cross-ref appendices on legacy milestones (retrofit only, additive-only)
- Retro summary comments on completed milestones

## Implementation reality (gstack architecture insight)

Gstack is just markdown files + bash preambles + filesystem state + Skill tool composition. No framework, no runtime. Every skill is a `SKILL.md` with frontmatter (name, description, allowed-tools, optional gbrain.context_queries) + bash preamble that bootstraps state by echoing it into LLM context + LLM-driven phases. The "magic" is the bash preamble surfacing filesystem state into LLM context.

For FDA: same pattern but with FDA-specific helpers (~5-10 bash scripts: `flow-detect-mode`, `flow-detect-fda-shape`, `flow-resume-breadcrumb`, `flow-context-load`) + Linear MCP reads in skill bodies. The closer analog is the Brite cadence plugin (5-phase orchestrator + breadcrumb + AskUserQuestion gates), not gstack itself.

## Pending questions (~25 still open at session-end 2026-05-06)

**Phase A (Sub-skill internals walk — COMPLETE 2026-05-06):**
_All 10 sub-skills locked: Q11 (codebase-scan), Q12 (preflight), Q13 (linear-scaffold), Q14 (legacy-cross-reference), Q15 (doc-author), Q16 (journey-author), Q17 (sandbox-scaffold), Q18 (regen-index), Q19 (inventory-interview greenfield), Q20 (inventory-add incremental)._

**Phase B (Agents — COMPLETE 2026-05-06):**
_Q21 locked: 12 named agents (expanded from initial 9-count estimate)._

**Phase D (Quality gates — COMPLETE 2026-05-06):**
_Q29 locked: 35-gate stack across 8 phase-transition + ~22 per-flow discipline-child + 5 cross-cutting. `/flow:audit` (Q38) is the runner._

**Phase E (Plugin meta — COMPLETE 2026-05-06):**
_Q30/Q31/Q32 locked. Q55 (Plugin CLAUDE.md content) deferred — separate task, addressable any time after Q34/Q42 land their pieces._

**Phase F (Content drafts — COMPLETE 2026-05-07):**
_Q33 (CDR-023) + Q34 (operating-standards page) + Q35 (CDR-014 amendment + companion milestones.md) all locked._

**Phase G (Bootstrap — COMPLETE 2026-05-07):**
_Q36 locked: per-project bootstrap embedded in flow-preflight; per-org bootstrap parked as v1.1+._

**Phase H (Other surface — COMPLETE 2026-05-07):**
_Q37 LOCKED 2026-05-07 (drafter C session): greenfield orchestrator phase sequence with hybrid control flow (per-domain phase 4 + globally batched phases 5-6); 8 phases / 4 gates; full audit trail in Q37 lock entry above._
_Q38 LOCKED 2026-05-07 (drafter C session): /flow:audit runner; 7 sub-decisions; closes parking lot #27 with inline-now + amend-scope-for-v1.1-extraction hybrid; full audit trail in Q38 lock entry above._
_Q47 LOCKED 2026-05-07 (drafter C session): /flow:add split with two distinct commands (Q30.2-faithful); thin orchestrators over Q20; mode classifier hard-requires incremental-add; journey-staleness warning + parking lot #19 v1.1 trajectory; full audit trail in Q47 lock entry above._

**Phase I (Ship readiness — PENDING):**
- Q40 — Production readiness checklist
- Q49 — Future canonical Brite design-system repo (v2+ tracking)

**Phase J (gstack-cribbed skills internals — PENDING):**
- Q41 — PROJECT-INTENT.md template (already structurally locked; this Q is the file format)
- Q42 — `/flow:office-hours` skill design
- Q43 — `/flow:plan-{story,eng,design,qa,docs}` skill suite
- Q44 — `/flow:retro` skill design
- Q45 — `/flow:design-consult` skill design (DEFERRED v1.1)
- Q46 — Linear-aware adaptation layer
- Q48 — Four-mode scope-review framework (shared utility)
- Q50 — Clone-and-swap scope from workflows plugin
- Q51 — `/flow:session-start` (cloned + FDA-swapped)
- Q52 — `/flow:review` (cloned + FDA-swapped)
- Q53 — `/flow:ship` (cloned + FDA-swapped)

**Q55 (spun off from Q30 lock — addressable any time after Q34/Q42 land):** Plugin CLAUDE.md content design (FDA plugin-internal guidance; distinct from Q34 + Q42).

**Phase B (Agents):**
- Q21 — 9 agent definitions (4 original + 5 discipline-reviewers)

**Phase D (Quality gates):**
- Q29 — quality-gate stack enumeration

**Phase E (Plugin meta):**
- Q30 — plugin manifest + directory structure
- Q31 — resume breadcrumb schema (`.flow-phase-state.json` fields)
- Q32 — MCP and dependency requirements

**Phase F (Content drafts the plugin produces):**
- Q33 — CDR-023 content draft
- Q34 — operating-standards page content draft
- Q35 — CDR-014 amendment content

**Phase G (Bootstrap):**
- Q36 — plugin shipping shape (how dependencies land in handbook + about-handbook repos at first install)

**Phase H (Other surface):**
- Q37 — greenfield orchestrator phase sequence (start-project specifics)
- Q38 — `/flow:audit` shape
- Q47 — `/flow:add-domain` vs `/flow:add-sub-flow` split internals

**Phase I (Ship readiness):**
- Q40 — production readiness checklist (testing, README, versioning, telemetry)
- Q49 — future canonical Brite design-system repo (v2+ tracking)

**Phase J (gstack-cribbed skills internals):**
- Q41 — PROJECT-INTENT.md template (already locked structurally; this Q is the file format)
- Q42 — `/flow:office-hours` skill design
- Q43 — `/flow:plan-{story,eng,design,qa,docs}` skill suite
- Q44 — `/flow:retro` skill design
- Q45 — `/flow:design-consult` skill design (DEFERRED v1.1)
- Q46 — Linear-aware adaptation layer
- Q48 — Four-mode scope-review framework (shared utility)
- Q50 — Clone-and-swap scope from workflows plugin
- Q51 — `/flow:session-start` (cloned + FDA-swapped)
- Q52 — `/flow:review` (cloned + FDA-swapped)
- Q53 — `/flow:ship` (cloned + FDA-swapped)

**Q37 — Greenfield orchestrator phase sequence (LOCKED 2026-05-07).** End-to-end orchestrator for `/flow:start-project` (greenfield UI-bearing build). Per Q10: 4 user-confirmation gates total. Per Q12: mode = `greenfield`. Distinguished from `/flow:retrofit-project` by skipping `flow-legacy-cross-reference` (Q14) + using `flow-inventory-interview` (Q19) instead of `flow-inventory-codebase-scan` (Q11) + 4 gates instead of 5. Seven sub-decisions:

1. **Phase sequence — 8 phases, hybrid control flow.** (1) Preflight + bootstrap via `flow-preflight` (Q12 + Q36 embedded bootstrap) — output: `.flow/config.json`; (2) Office hours via `/flow:office-hours` (Q42 — pending) — output: `docs/product/intent.md`; (3) Inventory via `flow-inventory-interview` (Q19) — output: `docs/product/master-flow-inventory.md`; (4) Linear scaffold via `flow-linear-scaffold` (Q13) **per-domain inner loop** — orchestrator iterates over N domains; per-domain footprint 2+7N writes per Q13's lock; preserves Q13.5's sub-flow-atomic failure recovery + G4's per-domain preview content; output: Linear milestones + parents + 5N children + chains + labels; (5) Doc author via `flow-doc-author` (Q15) **globally batched** — orchestrator invokes Q15 ONCE with all N domains' sub-flows; activates Q15.2's per-sub-flow internal parallelism (~30-60s wall regardless of N); output: story docs at `docs/product/flows/<domain>/*.md`; (6) Journey author via `flow-journey-author` (Q16) **globally batched** — orchestrator invokes Q16 ONCE with all N domains; activates Q16.2's per-domain internal parallelism (~60-90s wall regardless of N); output: journey docs at `docs/product/journeys/<domain>.md`; (7) Regen index via `flow-regen-index` (Q18) — output: `INDEX.md`; (8) Completion summary inline — set `status: completed` in breadcrumb (kept as explicit terminator phase per user lock for clean handoff + unambiguous resume semantics). **Greenfield SKIPS** `flow-legacy-cross-reference` (Q14) — retrofit-only.

2. **Phase order — hybrid: per-domain phase 4 + globally batched phases 5-6.** Within phase 4: orchestrator dispatches one domain's full Q13 invocation at a time (preserves Q13.4 per-domain preview semantics + Q13.5's sub-flow-atomic recovery for the highest-blast-radius mutation phase). After phase 4 completes for all domains, phase 5 invokes Q15 ONCE with all sub-flows across domains (Q15.2 internal parallel). After phase 5 completes, phase 6 invokes Q16 ONCE with all domains (Q16.2 internal parallel). Q15.8's "per-domain pipeline" within-domain ordering is preserved at the dependency level (Q15 cannot run for sub-flow X until Q13 completed sub-flow X; Q16 cannot run for domain D until Q15 completed all sub-flows in D) — implementation-wise, this is automatic because phase 5 starts only after phase 4 fully completes. **Estimated v1 wall (Brand Hub-shaped, illustrative):** depends on actual FDA-domain count (determined at `/flow:retrofit-project` runtime per Q34 / memory:636 lock — NOT 27, that's legacy-milestone count). Plausible shapes: 8 domains × ~6 SFs ≈ ~22-30 min; 15 domains × ~6 SFs ≈ ~38-50 min; 20 domains × ~6 SFs ≈ ~50-70 min. v1.1+ candidate: lift phase 4 to cross-domain parallel (loses per-domain G4 preview granularity in exchange for additional ~5-15 min wall savings).

3. **4 greenfield gates positioning at phase-transition boundaries:** **G1** (1→2): bootstrap completed; **G2** (2→3): PROJECT-INTENT.md content (post-office-hours; L1 multi-perspective review embedded); **G3** (3→4): master-flow-inventory.md content (post-inventory-interview; L2 reviews embedded per domain); **G4** (3→4 — fires alongside G3 OR after G3 if user pauses, whichever): pre-scaffold batch preview covering ALL domains' planned scaffolds (consolidates Q13.4's per-skill gate at orchestrator level — NOT N separate gates for N domains; L3 reviews embedded per sub-flow; preview content computed deterministically from inventory + parent issue numbers up-front). After G4 approval, phases 4-7 run without further orchestrator gates (Q15.6/Q16.6/Q18.8 lock 0 sync gates each). **Total: 4 user-experienced pauses. Matches Q10.**

4. **Multi-perspective L-review embedding (per Q54 lock):** L1 in phase 2 (CEO+Design+Eng+DX → L1-vetted PROJECT-INTENT.md user reviews at G2); L2 in phase 3 (CEO+Design per domain → orchestrator holds output as in-memory `state.l2_review_<domain>` for phase 6 hand-off; lands in journey doc's `## L2 review summary` section per Q26 mod 2 / Q16.7's optional read path; on crash-resume, L2 re-runs per parking lot #31 v1 acceptance — re-run cost ~2-5 min per domain); L3 in phase 4 (all 5 disciplines per sub-flow → headlines populate parent issue's `## L3 review summary` section per Q23 mod 2); L4 not orchestrator-driven (JIT during `/flow:session-start` Step 5). L-reviews fire in parallel within scope.

5. **Resume support via Q31 breadcrumb.** Orchestrator writes phase progress to `docs/plans/.flow-phase-state.json` after each phase completion: `current_phase` + `completed_phases[]` + per-domain state in `domains[]` (used during phase 4's per-domain inner loop) + `run_started_at` (used by Q29.1 `index-complete` gate) + `status: in_flight → completed` at phase 8. Resume entry: `flow-preflight` detects breadcrumb with `status: in_flight` → mode classifies as `resume` → orchestrator dispatches at `current_phase`. Phases 5/6 resume re-runs the entire phase since no per-sub-flow state is persisted (acceptable: phase 5 ~30-60s, phase 6 ~60-90s with locked parallelism). L-review state not persisted; re-runs on resume per parking lot #31.

6. **Failure handling — per-phase escalation matching sub-skill failure semantics.** Phase 1 fail-closed (Q36.5); phase 2 pause at G2 + retry; phase 3 Q19.6 interview-loop max-retry; phase 4 per-domain Q13.5 sub-flow-atomic recovery (failure isolated to one domain — orchestrator pauses inner loop for user adjudication then resumes with remaining domains); phase 5/6 log + continue per Q15.5/Q16.5 (operating at global batch scope — partial failures within Q15 or Q16 are surfaced in batch summary; orchestrator does NOT roll back on partial Q15/Q16 failure since outputs are filesystem writes reviewable via git diff + verify-docs.sh); phase 7 Q18.7 log + continue + skip-row marker; phase 8 n/a. On user halt: `status: abandoned` in breadcrumb; otherwise `status: in_flight` retains for resume.

7. **Greenfield vs retrofit comparison (relevant to Q47):** greenfield = 8 phases / 4 gates / Q19 inventory / no cross-reference / hybrid control flow; retrofit = 9 phases (insert `legacy-cross-reference` after preflight) / 5 gates (extra cross-reference review document gate per Q14.6) / Q11 inventory / Q14 cross-reference / hybrid control flow same as greenfield (per-domain phase 4-equivalent + globally batched phases 5-6). Both use office-hours (Q42 pending may decide whether retrofit always uses it or only when PROJECT-INTENT.md absent).

**Q37 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 6 refinements after Q37 draft. Drafter C's resolution of each (preserved for cross-session integrity):

1. **Phase 4-6 control flow ambiguity** → ESCALATED to user via `AskUserQuestion`; user answered "Hybrid (Recommended)". Resolved with hybrid pattern: phase 4 per-domain (preserves G4 + Q13.5) + phases 5+6 globally batched (activates Q15.2 + Q16.2 locked parallelism). Drafter C initially mis-framed as "clarification, not structural change"; orchestrator pushed back with wall-time math demonstrating ~19-35 min difference between control-flow options; reframed as architectural choice and surfaced to user. Q15.8's "per-domain pipeline" within-domain ordering preserved at dependency level (phase 5 starts only after phase 4 completes for all domains).
2. **G4 labeling vs positioning** → APPLIED. Q13.4 (memory:70) locks gate as "pre-scaffold preview" — fires before scaffolding. Drafter B's "(4→done)" notation was contradictory; sub-decision 3 amended to "(3→4)" with clarification that phases 4-7 run without further gates after G4 approval.
3. **L2 review stash mechanism** → APPLIED as clarification. Q16.7 (memory:122-124) already locks optional read path from `state.l2_review_<domain>`; per parking lot #31 v1 acceptance (memory:696), L-review state is in-memory during single invocation (NOT breadcrumb-persisted); on crash-resume, L2 re-runs (cost ~2-5 min per domain). No Q16 or Q31 amendment needed in v1. Sub-decision 4 amended with this clarification.
4. **Phase 8 framing** → ESCALATED to user via `AskUserQuestion`; user answered "Keep explicit phase 8 (Recommended)". Resolved: phase 8 retained as explicit terminator phase for clean `status: completed` handoff + unambiguous breadcrumb resume semantics. Greenfield = 8 phases / retrofit = 9 phases.
5. **Q19 vs Q11 hybrid for greenfield-with-code** → PUSHED BACK + parked. Q19.1 (memory:192-194) strictly skips Phase 3 code scan; Q36.3 step 5 (memory:314) user-override-mode handles greenfield-with-code edge case. No Q37 change. Added to parking lot v1.1: hybrid greenfield-with-code mode if dogfood reveals real gap.
6. **Cross-domain parallelism v1 wall-time premise** → PUSHED BACK on premise; structure HOLDS. Drafter B's "~2-4 hr serial" estimate inflated (assumed Q15.2's locked parallelism was disabled — it isn't). Drafter C's initial "15 FDA domains × ~6 SFs" recalc was unsourced — orchestrator caught it; corrected with multi-shape illustrative table flagged that actual count is determined at `/flow:retrofit-project` runtime per Q34 lock (memory:636). Real v1 wall ranges ~22-70 min for plausible Brand Hub shapes under the locked hybrid control flow. v1.1 cross-domain parallelism for phase 4 remains candidate.

**Validation discipline catches by orchestrator on drafter C's work (preserved for handoff integrity):**
- Caught drafter C's "clarification, not structural change" mis-framing on refinement 1 — wall-time math demonstrated it was genuinely architectural; reframed to a/b/c choice surfaced to user.
- Caught drafter C's unsourced "15 FDA domains" wall-time estimate — corrected to illustrative-only with multi-shape range and Q34 runtime determination flag preserved.

**Q38 — `/flow:audit` shape (LOCKED 2026-05-07).** The runner for Q29's 35-gate stack. Q29 already locked the gate manifest, three-section reporting format (Q29.6), verify-docs.sh integration (Q29.7), override mechanism (Q29.5), and hard/soft classification (Q29.4). Q38 fills runner gaps. Seven sub-decisions:

1. **Invocation shape — user-invocable + auto-invocable command at `/flow:audit`.** Args: `--domain=<CODE>` (filter to one domain's gates), `--flow=<DOMAIN-NN>` (one flow), `--discipline={story|eng|design|qa|docs}` (one discipline child), `--gate=<id>` (re-run one gate by stable ID; useful for fix-and-verify cycles), `--json` (machine-readable for CI), `--no-verify-docs` (skip Phase A; debugging only). Defaults: full-project markdown report. Filters compose (`--domain=TEAM --discipline=eng` → TEAM's [Eng] gates only). Flag-based args (vs positional) chosen for explicit naming + composability.

2. **Execution order — three phases, halt-aware.** Phase A: `bash scripts/verify-docs.sh` first per Q29.7 lock; if A fails, Phase B/C marked `skipped (verify-docs failed)`. Phase B: deterministic filesystem gates (Q29.2 file existence, front-matter regex, AC count, qa_status — 22 per-flow checks). Phase C: Linear MCP gates (Q29.3 cross-cutting checks including `parent-l3-summary-populated` for L3 per Q37 sub-decision 4 + Q23 mod 2; plus Q29.2 [Eng]/[Design]/[Docs] state checks). All read-only. **L-review coverage clarification:** L3 gated via Q29.3; L2 intentionally NOT gated (Q26 mod 2 locks `## L2 review summary` as optional); L1 coverage will fold in when Q41 (PROJECT-INTENT.md template) lands and tightens Q29.1's `intent-exists` required-sections list.

3. **Linear MCP batching — adopt batched `list_issues` per domain inline in v1 (hybrid resolution per user lock 2026-05-07).** Per-child `get_issue` (~125s on 50-flow project) replaced with batched `list_issues({labels: ["domain:<slug>"]})` per domain (~14s on 28-domain project). Implementation: ~10-line inline re-implementation of Q18.3's pattern in Q38. **Parking lot #27 amended scope** (NOT closed): "promote to `_shared/linear-batched-list-pattern.md` utility in v1.1 if a third caller (e.g., Q43, Q53, or Q46) also needs the pattern." Captures v1 optimization where it compounds (auto-invocation from /flow:ship + /flow:plan-{discipline}); avoids closing the parking lot prematurely; refactor to shared utility only when 3+ callers prove the DRY argument.

4. **Output format — markdown to stdout (default) + `--json` flag.** Q29.6 three-section markdown locked (Phase status table + per-flow discipline-grid + cross-cutting consistency report + Summary + Overrides). `--json` emits structured `{gates: [{id, type, status, scope, message}], summary: {hard_pass, hard_fail, soft_warn, overrides, exit_code}}` for CI scripting. **NO file write by default** (terminal-reviewable; user redirects via shell). **Linear-write behavior deferred to Q46 lock** — Q38 doesn't pre-decide whether `/flow:audit` results route through Q46's Linear writeback layer or stay strictly local. Q46 design will resolve this dependency; until then, Q38 emits stdout-only.

5. **Auto-invocation from other skills.** Called by `/flow:ship` (Q53 — pending) as ship-readiness check; hard-gate failures halt the ship. Called by `/flow:plan-{discipline}` (Q43 — pending) pre-completion, scope-filtered to that discipline child. **NOT called by orchestrators** (Q1-Q37) — orchestrators have their own per-phase artifact-existence gates per Q7's locked filesystem-artifact-existence semantics (memory:41-42). Auto-invocation from `/flow:session-start` (Q51) explicitly rejected — frequency × Linear MCP cost (~14s) is non-trivial; user can run `/flow:audit` explicitly when they want a project-health snapshot.

6. **Exit codes for CI / scripting.** 0 = all hard gates pass (overrides counted as pass per Q29.5 lock); 1 = any unoverridden hard gate fails; 2 = verify-docs.sh failed (Phase B+C skipped); 64 = invalid args (`os.EX_USAGE` convention). Soft-gate failures don't affect exit code (informational only). Override-counts-as-pass behavior documented explicitly in plugin CLAUDE.md (Q55) — relies on sub-decision 7's stale-override detection to surface override accumulation. **`--strict` flag (exit 1 on any overrides present, regardless of pass/fail) deferred to v1.1 parking lot** if dogfood reveals override accumulation as a problem.

7. **Stale-override detection — extension to Q29.5.** On audit run, scan breadcrumb's `overrides[]` (schema: `{gate, reason, timestamp, scope}` per Q31.1 lock memory:284 — timestamps captured) for: (a) entries with timestamp older than 30 days; (b) entries where the underlying gate condition has changed (e.g., overridden gate was "file missing" but file now exists). Both surface in audit Overrides section as "**Stale overrides — re-evaluate**" subsection with reason. Does NOT auto-clear — override removal is a deliberate user action via interactive prompt or manual breadcrumb edit. 30-day staleness threshold is arbitrary first cut; tune via dogfood.

**Q38 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 6 refinements + 1 additional flag after Q38 draft. Drafter C's resolution of each:

1. **Q46 dependency on Linear-write** → APPLIED (a) defer. Drafter C's "Linear writes are handled by /flow:ship per Q46 layer" mis-cited Q46 as locked when it's pending. Sub-decision 4 amended: Q38 doesn't pre-decide Linear-write behavior; Q46 lock will resolve.
2. **Q7 citation verification** → CONFIRMED HOLDS. Q7 (memory:41-42) explicitly locks "Gates are filesystem-artifact-existence checks, NOT LLM self-report." Sub-decision 5's NOT-from-orchestrators basis is sound.
3. **overrides[] timestamp schema verification** → CONFIRMED HOLDS. Q29.5 (memory:250) locks `{gate, reason, timestamp}` capture; Q31.1 (memory:284) extends to `{gate, reason, timestamp, scope}`. Sub-decision 7's (a) staleness check buildable as designed.
4. **Parking lot #27 promotion** → ESCALATED to user via `AskUserQuestion`; user answered with hybrid: adopt batched pattern inline in Q38 v1 + amend parking lot #27 scope to "promote to `_shared/linear-batched-list-pattern.md` utility in v1.1 if a third caller also needs the pattern." Captures v1 wall-time savings without closing parking lot prematurely. Drafter C's initial "DRY of Q18.3's already-locked pattern" framing was overstated — Q18.3 inlines the batching pattern, not exposes it as a shared utility; ~10-line re-implementation in Q38 is the actual cost.
5. **`--strict` flag exit code** → APPLIED (b). Document override-counts-as-pass in plugin CLAUDE.md (Q55) + rely on sub-decision 7's stale-override detection. `--strict` parking lot v1.1.
6. **`--gate=<id>` filter** → APPLIED. Sub-decision 1 extended; reuses existing filter pattern.
7. **(Additional flag) Q29.2 L-review coverage verification** → RESOLVED. L3 covered via Q29.3 `parent-l3-summary-populated`; L2 intentionally NOT gated (Q26 mod 2 locks the section as optional); L1 awaits Q41 lock. No Q29 amendment needed; sub-decision 2 clarified.

**Validation discipline catches by orchestrator on drafter C's work (preserved for handoff integrity):**
- Caught drafter C's Q46-as-locked mis-citation in sub-decision 4 — corrected to deferred.
- Caught drafter C's "DRY of Q18.3's already-locked pattern" overstatement in sub-decision 3 — Q18.3 inlines the batching, not extracted as utility; user lock resolved with hybrid (inline now, amend parking lot for future extraction).

**Q38 sub-decision 4 deferred-decision resolution (LOCKED 2026-05-07 per Q46 lock; user-confirmed):** Stays strictly local in v1. /flow:audit emits stdout markdown + `--json` only; no Linear writeback in v1. `audit-concerns` marker type registered in Q46's `_shared/linear-writeback-pattern.md` enum but UNUSED in v1; reserved for v1.1 `--linear-surface[=parent|milestone]` flag promotion (Q38 amendment territory). Most reversible architectural choice — preserves Q38's "stdout-only by default" framing exactly; avoids notification spam from auto-invocations (auto-fires from /flow:ship + /flow:plan-{discipline} per Q38 sub-decision 5; routing those to Linear would generate ~5+ comments per ship cycle per sub-flow). /flow:ship already routes ship-summary as the team-facing checkpoint; audit-concerns is developer-internal pre-flight. **No Q38 sub-decision 4 amendment needed in v1** — the deferred decision resolved as "stay local"; v1.1 will require Q38 amendment 1 to add `--linear-surface` flag if dogfood reveals demand.

**Q47 — `/flow:add` split (add-domain vs add-sub-flow) (LOCKED 2026-05-07).** Q20 (memory:206-220) locks the lightweight inventory-append skill with two modes (sub-flow-add + domain-add) "dispatched by caller." Q47 governs the orchestrator-layer above Q20. Q30.2 (memory:262) already locks two distinct commands: `/flow:add-domain` + `/flow:add-sub-flow`. Seven sub-decisions:

1. **Invocation contract — two distinct commands per Q30.2 lock; thin orchestrators over Q20.** `/flow:add-domain` (whole new domain with N sub-flows) and `/flow:add-sub-flow` (one new flow under existing domain). Both auto-invoke `flow-preflight` (Q12) first as Phase 0. Args:
   - `/flow:add-sub-flow [<DOMAIN>|<DOMAIN-NN>] [--title=<text>]` — three positional forms map to Q20.1's input contract (memory:208 — Q20 takes target domain as INPUT, auto-suggests flow_id NN per Q20.2): (a) no positional → Q20 prompts for domain interactively + auto-suggests flow_id; (b) `TEAM` → pre-fills domain; Q20.2 auto-suggests flow_id; (c) `TEAM-09` → pre-fills both; Q20.4 hard-rejects if duplicate. Q47 maps positional args to Q20's input API.
   - `/flow:add-domain` — no positional args (interactive only — domain code + display name + Q19-mini interview).
   
   Single command with subcommand was rejected (Q30.2 already enumerates two distinct slash entries; reopening would re-litigate Q30).

2. **Phase sequences — both commands share preflight + Q20 + downstream skills with different downstream sets.**
   - `/flow:add-sub-flow` (lightweight, **5 phases**): (1) preflight (Q12) → (2) Q20 sub-flow-add → (3) `flow-linear-scaffold` per-sub-flow (1 parent + 5 children + 1 children-summary comment + milestone description refresh = 7 writes) → (4) `flow-doc-author` (1 story doc; Q15) → (5) `flow-regen-index` (Q18). **Skips flow-journey-author per user lock 2026-05-07** — see sub-decision 5.5 for the journey-staleness warning mechanism. ~3-5 min wall.
   - `/flow:add-domain` (heavier, **6 phases**): (1) preflight → (2) Q20 domain-add (Q19-mini interview) → (3) `flow-linear-scaffold` per-domain (1 milestone + N parents + 5N children = 2+7N writes) → (4) `flow-doc-author` per-domain (N story docs, Q15.2 internal parallelism) → (5) `flow-journey-author` (1 journey doc, Q16) → (6) `flow-regen-index`. ~10-30 min wall depending on N sub-flows.
   - **Both skip Q14 legacy-cross-reference** — incremental-add isn't a retrofit operation. **Mirrors Q37's hybrid control flow degenerated to N=1 domain**: phase 3 is "per-domain inner loop" with N=1, phases 4-5 are "globally batched" with N=1 (degenerate but consistent).

3. **Mode classifier integration — hard-require `incremental-add` mode from preflight; clear error redirects otherwise.** Per Q36.3 step 4 (memory:313): `incremental-add` = FDA artifacts present + breadcrumb absent or completed. Error redirects:
   - `greenfield` (no FDA artifacts) → "Project not yet initialized. Use `/flow:start-project` first."
   - `retrofit` (FDA artifacts absent + ≥10 Linear issues) → "Project has legacy work. Use `/flow:retrofit-project` to retrofit FDA shape, then `/flow:add-*` for incremental additions."
   - `resume` (breadcrumb in_flight) → "Existing orchestrator run in flight at `docs/plans/.flow-phase-state.json`. Options: (a) resume via re-invocation of the original orchestrator (preflight will detect mode=resume); (b) manually discard by deleting the breadcrumb file; (c) wait until breadcrumb auto-stales (>7 days inactive per Q31.3) for AskUserQuestion-driven discard. Stale-breadcrumb auto-discard only fires after 7 days OR status=completed/abandoned per Q31.3 — does not apply to fresh in_flight breadcrumbs."
   - `incremental-add` → proceed.
   
   `--force-incremental-add` flag for v1: bypasses mode check; surfaces warning + audit-log entry. Auto-redirect (run the recommended command instead of erroring) was rejected as too magical.

4. **Shared layer boundary with Q20 — Q47 thin orchestrator above Q20's locked inventory skill.**
   - **Q20 owns** (per its lock memory:206-220): inventory append mechanics, flow ID auto-suggestion (Q20.2), idempotency hard-reject on duplicate (Q20.4), within-skill confirmation gate (Q20.6), `state.inventory_changed = true` flag emission (Q20.7).
   - **Q47 owns**: preflight invocation + mode-classifier integration (sub-decision 3), downstream skill chain dispatch (sub-decision 2), breadcrumb writes for resume support + audit trail (sub-decisions 6 + 7), INDEX regen trigger (Q47 reads Q20's `state.inventory_changed` flag and dispatches `flow-regen-index`).
   - Q47 NEVER edits inventory directly — always delegates to Q20.

5. **User-confirmation gates — within-skill only; 2 gates per command from sub-skill locks.** Both commands have **2 gates** (per refinement 2 correction): Q20.6 within-skill confirmation (inventory append review) + Q13.4 pre-scaffold preview (Linear writes review per memory:70 — "1 mandatory gate (pre-scaffold preview)" — no trivial-preview suppression in lock; fires regardless of N). Q20.6 + Q13.4 do NOT collapse — they serve different review purposes (inventory content vs Linear scaffold preview); user can edit between them. **Q10 (memory:48) is explicitly mode-aware** — locks 5/4 retrofit/greenfield budgets; silent on incremental-add. Q47 doesn't amend Q10; it derives incremental-add's gate count from underlying sub-skill locks (Q20.6 + Q13.4 = 2 gates per command).

5.5. **Journey-staleness warning for /flow:add-sub-flow (per user lock 2026-05-07).** At completion of /flow:add-sub-flow's regen-index phase, emit warning:
   > "Sub-flow `<DOMAIN-NN>` added. Journey doc at `docs/product/journeys/<domain>.md` may need narrative refresh — the new sub-flow is in inventory + Linear + story doc but not yet woven into the journey narrative. Run `flow-journey-author --force` when ready (will regenerate from scratch; back up hand-edits first), or wait for v1.1 selective-re-author mode (parking lot #19)."
   
   Captures known stale state without forcing destructive --force regeneration. v1.1 trajectory: parking lot #19 extended to flow-journey-author + new `/flow:journey-refresh` command (selective-re-author mode preserves hand-edits while refreshing only the new sub-flow's row + relevant phase narrative).

6. **Resume support — breadcrumb scoped to single-add operation.** Use Q31 breadcrumb pattern with mode-specific simplification: `mode: incremental-add`, `current_phase: preflight|q20|linear-scaffold|doc-author|journey-author|regen-index`, single-domain entry in `domains[]` (N=1 for /flow:add-domain; for /flow:add-sub-flow, the entry references the existing domain plus new sub-flow). Stale breadcrumb policy per Q31.3 (>7 days → offer discard). Breadcrumb path remains `docs/plans/.flow-phase-state.json` per Q31.4 lock — same path as start-project / retrofit-project breadcrumbs. **Single-orchestrator-at-a-time caveat per Q31.6 v1**: concurrent /flow:add-* + /flow:start-project not supported in v1.

7. **Failure recovery — per-phase escalation matching sub-skill semantics; breadcrumb captures abandoned runs (per user lock 2026-05-07).** **Phase 0** (preflight) fail-closed (Q36.5). **Phase 1** (Q20) hard-reject on duplicate per Q20.4: write breadcrumb at phase 1 entry → on hard-reject, mark `status: abandoned` with `reason: 'duplicate detected (Q20.4)'` for audit trail. Consistent with Q31 lifecycle (Q31.3 accommodates abandoned status — future preflight offers discard); diverges from Q36.5's "no partial state" (which applies to bootstrap config-json, NOT breadcrumbs — different concerns). **Phase 2** (linear-scaffold) per Q13.5 sub-flow-atomic recovery (transient retry / permanent abort + AskUserQuestion). **Phase 3** (doc-author) per Q15.5 log + continue. **Phase 4** (journey-author, /flow:add-domain only) per Q16.5 log + continue. **Phase 5** (regen-index) per Q18.7 skip-row + marker. On user halt: `status: abandoned` in breadcrumb. Resume on next preflight run picks up at last `current_phase`.

**Q47 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 6 refinements after Q47 draft. Drafter C's resolution of each:

1. **Journey-author for /flow:add-sub-flow** → ESCALATED to user via `AskUserQuestion`; user answered "Skip + warning (Recommended)" — accepting drafter C's pushback on parking lot #19 dependency. Drafter C verified Q26 (memory:440) creates known stale state when sub-flow added without journey refresh; Q15.3/Q16.3 lock skip-if-exists+--force with no selective re-author in v1; parking lot #19 (memory:684) tracks selective-re-author for flow-doc-author only. Lock outcome: skip in v1 + emit warning at completion (text user-supplied verbatim); v1.1 trajectory extends parking lot #19 to flow-journey-author + adds `/flow:journey-refresh` command.
2. **Q13.4 gate count for N=1** → APPLIED. Q13.4 (memory:70) locks "1 mandatory gate (pre-scaffold preview)" with no suppress-when-trivial exception. Both commands have 2 gates (Q20.6 + Q13.4), not 1+2 as drafter C originally drafted.
3. **Hard-reject breadcrumb commit** → ESCALATED to user via `AskUserQuestion`; user answered "Write + mark abandoned (Recommended)" — consistent with Q31 lifecycle pattern (every run leaves a breadcrumb). Q36.5's fail-closed applies to bootstrap config-json, not breadcrumbs (different concerns). Q31.3 accommodates abandoned status — future preflight offers discard naturally.
4. **Q20.2 fallthrough citation** → APPLIED. Drafter C's citation pointed at Q20.2 (which covers flow_id NN auto-suggestion only) when Q20.1 is the relevant lock (input contract takes target domain as parameter). Sub-decision 1 amended to spell out 3 positional invocation forms with correct Q20.1 citation.
5. **Q12 stale-breadcrumb error message** → APPLIED. Drafter C's error message for `resume` mode pointed at Q31.3 stale-breadcrumb option, but Q31.3 only triggers for >7 days OR completed/abandoned status — does NOT apply to fresh in_flight breadcrumbs. Sub-decision 3's error message clarified with three actionable options (resume / manual delete / wait for auto-stale).
6. **Q10 mode-awareness** → CONFIRMED. Q10 (memory:48) explicitly mode-aware ("5 pauses for retrofit / 4 for greenfield"); silent on incremental-add. Sub-decision 5 framing holds. Minor clarification: incremental-add gate count derives from sub-skill locks (Q20.6 + Q13.4), not a top-level budget.

**Validation discipline catches by orchestrator on drafter C's work (preserved for handoff integrity):**
- Caught drafter C's Q13.4 gate undercount in sub-decision 5 — N=1 doesn't suppress the gate; both commands have 2 gates.
- Caught drafter C's Q20.2 misdirected citation in sub-decision 1 — Q20.1 is the input contract; Q20.2 is the flow_id NN auto-suggestion only.
- Caught drafter C's stale-breadcrumb error message imprecision in sub-decision 3 — Q31.3 doesn't fire for fresh in_flight breadcrumbs.

**Q47 amendment 1 — arithmetic correction for /flow:add-sub-flow write count + memory:70 citation typo (LOCKED 2026-05-11 per BC-6965 /workflows:review iteration 1 fold-in).** Q47 sub-decision 2 enumerates 4 write items for the per-sub-flow incremental-add footprint — "1 parent + 5 children + 1 children-summary comment + milestone description refresh = 7 writes" — but the arithmetic sums to 8, not 7. Reconciliation against Q13 lock (memory:80) per-domain formula `2 + 7N` (where the `2` = 1 milestone create + 1 milestone description refresh, and the `7N` = per-sub-flow 1 parent + 5 children + 1 children-summary): for incremental add-sub-flow against an existing domain with N=1 sub-flow and no new milestone create, the actual count is `7 × 1` (per-sub-flow group) + `1` (milestone description refresh) = **8 writes**. Q47 sub-decision 2's stated total of 7 omitted the milestone refresh from the sum. This amendment corrects the stated total from `= 7 writes` to `= 8 writes`. The orchestrator file at `plugins/flow-architecture/commands/add-sub-flow.md` is updated derivatively (write count + Phase 5 terminator artifact list); the BC-6965 issue body's What/AC sections retain the original "= 7 writes" text — re-syncing them is a Linear-side follow-up tracked as a non-blocking item. Original Q47 sub-decision 2 text preserved verbatim per schema-discipline amendment pattern (cf. Q21 amendment 1, Q24 amendment 1, Q29 amendment 1, Q31 amendments 1+2, Q41 amendment 1, Q23 amendment 1 above). Second correction in this amendment: Q47 sub-decision 5 (memory:769) cites `memory:70` for Q13.4 sub-decision text; line 70 is the start of Q12, not Q13. The correct citation is `memory:80` for the Q13 lock header or `memory:88` for the Q13.4 sub-decision exact line. Derivative `commands/add-sub-flow.md` L171 carries the correct `memory:88` citation post-fix. Caught in BC-6965 /workflows:review iteration 1 by code-reviewer P2 conf 8 (arithmetic) + P3 conf 9 (citation typo) via direct memory:752/memory:80/memory:88 reading. Both corrections are faithful-echo precedent (BC-6955 task-3 source-of-truth pattern, 3rd surface) and schema-discipline amendment pattern (Q31 amendments 1+2 precedent, 6th amendment-numbered correction across the canon).

**Q41 amendment 1 — about-handbook subdir path correction (LOCKED 2026-05-10, drafter D session per Step 2.B pre-flight catch).** Q41 originally referenced template promotion target as `about-handbook/style-guide/templates/project-intent.md` (sub-decision body) AND CDR-013's existing project-brief templates at `about-handbook/style-guide/templates/project-brief-build.md` (sub-decision 1). Both bulk-renamed to `handbook/about-handbook/style-guide/templates/...` via memory-file Edit replace_all 2026-05-10. Cross-link with Q2 amendment 1 — canonical full audit-trail rationale.

**Q41 — PROJECT-INTENT.md template (LOCKED 2026-05-07).** Foundational anchor doc for FDA projects. Output of Q42 `/flow:office-hours` (pending). Referenced by Q22 milestone description eyebrow + Q26 mod 1 + Q27 mod 1 + Q11/Q19 Phase 0 + Q29.1 `intent-exists` gate + Q37 sub-decision 4 L1 review routing. **Q41 is genuinely greenfield template work** — Q22/Q26/Q27 all extend existing BriteBase templates; intent.md template doesn't exist yet (CLAUDE.md doc map flags the gap). Lives at `docs/templates/project-intent.md` (BriteBase) → `handbook/about-handbook/style-guide/templates/project-intent.md` (promoted per Q2). Output goes to `docs/product/intent.md`. Seven sub-decisions:

1. **Greenfield template — no existing base; build fresh.** CDR-013's existing project-brief templates at `handbook/about-handbook/style-guide/templates/project-brief-build.md` and `project-brief-workstream.md` are LINEAR-side (Project description briefs), NOT repo-side anchor docs. Q41 creates a fresh repo-side template using established conventions (front-matter shape, eyebrow blockquote disclaimer, section-headers + minimal body guidance). Single command, no slash subcommand variant — Q41 is a template artifact, not an orchestrator.

2. **Front-matter schema — 6 fields, adapted for project-level scope:**
   - `title: <Project Display Name>` — matches Linear project name
   - `agent_context: project-intent` — discoverability tag (matches operating-standards pattern memory:630; single per-project doc, no slug suffix needed)
   - `last_reviewed: <ISO-8601>` — bumped on every meaningful edit per doc-steward convention
   - `linear_project_id: <UUID>` — sourced from `.flow/config.json` (Q12 lock memory:57); cross-link
   - `linear_project_name: <name>` — sourced from `.flow/config.json`; for human reference
   - `l1_reviewed: <ISO-8601 | null>` — when L1 multi-perspective review fired (Q37 sub-decision 4 routing); null until office-hours runs
   
   **Dropped fields with reasoning** (one-line rationale comment in template footer per orchestrator note):
   - `refresh_cadence` (operating-standards pattern) — intent is foundational; review is project-driven not calendar-driven; explicit cadence would invite stale "quarterly bumps with no real review"; intent.md is regenerated by `/flow:office-hours` mechanically, not steward-driven calendar bump
   - `owner` — Linear project lead (queryable via linear_project_id) is authoritative; duplicate field invites drift

3. **Body section structure — 7 sections, all required (per user lock 2026-05-07).** Length target ~200-500 words / 1-2 pages. Anchor-doc shape (punchy, not novel).

   **H1:** `# <Project Display Name> — Project Intent`
   
   **Doc-type blockquote** (matches Q26 pattern):
   > "This is the project intent doc. It anchors every flow in this project — the inventory, every story doc, every journey doc, every milestone description references it. Edit deliberately; it shapes downstream work. **Do not hand-edit the L1 review summary section** — `/flow:office-hours` regenerates it."
   
   **Sections (in order, all required):**
   1. **`## Mission`** (~50-100 words) — one paragraph. What we're building, for whom, why this matters.
   2. **`## Target users`** (~50-100 words) — primary + secondary personas. Cross-link to `docs/product/personas/<role>.md` for each named persona.
   3. **`## Problem we're solving`** (~50-100 words) — what's broken now or what gap exists. Concrete, not abstract. Maps to CDR-013 Build Brief's "Problem" section (parallel cross-substrate).
   4. **`## Success criteria`** (3-5 bullets) — how we'll know we delivered. Concrete metrics or outcomes; no "high quality" hand-waving. Maps to CDR-013 Build Brief's "Outcome (done condition)" section.
   5. **`## Out of scope`** (3-5 bullets) — explicit non-goals. Prevents scope creep; gives `flow-inventory-*` skills boundary signal. Maps to CDR-013 Build Brief's "Scope (Out)" sub-list.
   6. **`## Constraints`** (per user lock 2026-05-07: REQUIRED for all projects) — technical / business / regulatory / contractual constraints that shape decisions. Brite-specific reality justifies required-for-all: multi-tenant isolation (CLAUDE.md) + future HIPAA/SOC2 trajectory + mobile-responsive constraint = Constraints essentially always populated. Body content "None material" acceptable for projects without material constraints (explicit artifact > inferred-from-omission). Conditional `regulatory_scope` front-matter (rejected option) would add value-conditional gate complexity for marginal benefit.
   7. **`## L1 review summary`** (always present; body auto-populated by Q42) — see sub-decision 5.
   
   **Optional `## See also`** at end — cross-references to CDR-023, operating-standards FDA page, persona docs, **CDR-013 Build Brief as parallel Linear-side artifact** (see sub-decision 7), related ADRs.

4. **Required-sections enumeration for Q29.1 `intent-exists` gate (binding contract).** Q29.1 (memory:227) currently locks "exists with required sections (per Q41 — pending)." Q41 lock fills the placeholder. Gate checks (hard, block-with-override per Q29.4):
   - File exists at `docs/product/intent.md`
   - Front-matter has all 6 fields populated: `title`, `agent_context: project-intent`, `last_reviewed` (valid ISO-8601), `linear_project_id`, `linear_project_name`, `l1_reviewed` (ISO-8601 or null literal)
   - H1 present + matches `# <text> — Project Intent` regex
   - Doc-type blockquote present (regex match on opening words)
   - Required body sections present (regex `^## (Mission|Target users|Problem we're solving|Success criteria|Out of scope|Constraints|L1 review summary)$` — all 7 required)
   - `## See also` NOT gated (optional)
   
   **Soft gates (warn, don't block):** word count outside 200-500 range — relaxed from earlier hard floor per user lock 2026-05-07. Soft warn message: "intent.md is shorter than typical anchor-doc range (200-500 words); consider expanding after inventory work clarifies thinking." Other soft gates: `last_reviewed` >180 days stale; L1 review summary still showing "Not yet reviewed" placeholder when called from `/flow:start-project` G2 gate. **Word count is heuristic; section-regex check is the real shape contract** — orchestrator should help users iterate toward clarity (via office-hours → inventory cycle), not gatekeep on having clarity upfront.

5. **L1 review summary section format — mirrors Q26 mod 2 (L2 summary) + Q23 mod 2 (L3 summary).** Structure:
   ```markdown
   ## L1 review summary
   
   _Generated by `/flow:office-hours` on <ISO-8601>. Do not hand-edit — re-run `/flow:office-hours` to refresh._
   
   ### CEO perspective
   <one-paragraph headline from plan-ceo-reviewer agent per Q21:400>
   
   ### Design perspective
   <one-paragraph headline from plan-design-reviewer agent per Q21:397>
   
   ### Engineering perspective
   <one-paragraph headline from plan-eng-reviewer agent per Q21:396>
   
   ### Developer-experience perspective
   <one-paragraph headline from plan-devex-reviewer agent per Q21:401>
   ```
   
   Auto-populated by Q42 office-hours after L1 multi-perspective review fires (Q37 sub-decision 4). Q42 writes the section atomically per Q31.5 write-then-verify pattern (flagged as Q42 input requirement). Q41 template ships with placeholder body: `_Not yet reviewed — pending `/flow:office-hours` run._` so Q29.1 structural gate passes from day 1; content fills in when L1 runs.

6. **Length target — ~200-500 words / 1-2 pages.** Calibrated against existing templates: Q22 domain milestone (~300-450 words inline), Q27 job story (~80-150 lines / ~1 page), Q26 domain journey (~290-450 lines / ~5 pages), Q34 operating-standards page (~1500-2000 words). Intent.md sits between Q22 and Q34 — anchor-doc favors brevity; readers should scan it in <2 min. **Soft warn at >500 words** ("too verbose"); **soft warn at <100 words** ("underspecified"; relaxed from hard floor per user lock — section-regex check enforces shape, word count is heuristic). Hard floor would block /flow:start-project G2 prematurely at the exact moment users need iterative clarification.

7. **Cross-references — incoming + outgoing.**
   
   **Incoming (intent.md referenced from):**
   - Q22 domain-milestone description eyebrow link block — "Anchor (PROJECT-INTENT)" entry per memory:423
   - Q26 domain-journey front-matter `intent: ../intent.md` per Q26 mod 1 (memory:440)
   - Q27 job-story front-matter `intent: ../../intent.md` per Q27 mod 1 (memory:442)
   - Q11 Phase 0 + Q19 Phase 0 — both inventory skills read intent.md as priority filter (memory:50, 192)
   - Q29.1 phase-transition gate `intent-exists` (memory:227)
   
   **Outgoing (intent.md links to):**
   - Persona docs at `docs/product/personas/<role>.md` (each named persona in Target users section)
   - CDR-023 + operating-standards FDA page (in optional See also section)
   - **CDR-013 Build Brief as parallel Linear-side artifact** (see cross-substrate framing below)
   - Linear project URL (sourced from linear_project_id) — implicit, not body-linked
   
   **Cross-substrate framing (CDR-013 vs Q41 — verified via gh API 2026-05-07):**
   - CDR-013 Build Brief: Linear Project description, ~500-1000 words, Pitch-shaped (Problem / Outcome / Appetite / Solution sketch / Scope / Risks / Open questions), audience = team stakeholders
   - Q41 intent.md: repo-side `docs/product/intent.md`, ~200-500 words, anchor-doc shaped (Mission / Target users / Problem / Success criteria / Out of scope / Constraints / L1 review summary), audience = downstream FDA skills + flow authors
   - Same project, different substrate. Field overlap: Problem (both), Outcome ≈ Success criteria, Scope (Out) ≈ Out of scope. Distinct: Q41 has Mission + Target users + L1 review summary (FDA-anchor specific); CDR-013 has Appetite + Solution sketch + Open questions (Pitch-execution specific).
   - Q42 office-hours likely uses Linear Build Brief as input context to author intent.md — bridge between team-Pitch and FDA-anchor. **No content duplication** — same intent at two substrates with different framings.

**Q41 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 5 refinements after Q41 draft. Drafter C's resolution of each:

1. **Constraints optional vs required** → ESCALATED to user via `AskUserQuestion`; user answered "Required for all (Recommended)" — Brite multi-tenant + future HIPAA/SOC2 + mobile-responsive (CLAUDE.md) means Constraints essentially always populated; CDR-013 Build Brief's "Risks & rabbit holes" is non-conditional parallel cross-substrate; "None material" body content is a useful explicit artifact, not rote-noise gap; conditional regulatory_scope field rejected as Q29.1 value-conditional complexity for marginal benefit.
2. **<100-word hard floor** → ESCALATED to user via `AskUserQuestion`; user answered "Soft warn (Recommended)" — section-regex check is the real shape contract; word count is heuristic; hard floor blocks early-stage greenfield exactly when users need /flow:start-project's iterative cycle to clarify intent (chicken-and-egg risk: gatekeeping clarity at the moment users need the orchestrator to help them clarify).
3. **L1 reviewer agent names** → CONFIRMED HOLDS. Verified Q21 directly: plan-ceo-reviewer (memory:400), plan-design-reviewer (memory:397), plan-eng-reviewer (memory:396), plan-devex-reviewer (memory:401). Q21:400 explicitly names PROJECT-INTENT.md as L1 destination. Distinction preserved: agent name (`plan-devex-reviewer`) vs section heading (`### Developer-experience perspective`).
4. **File path consistency** → CONFIRMED HOLDS. Verified `docs/product/intent.md` against Q12:55, Q26 mod 1 (memory:440), Q15.1:92, memory:486. Two paths in draft, both correct + distinct: TEMPLATE at `docs/templates/project-intent.md`; OUTPUT at `docs/product/intent.md`.
5. **CDR-013 compatibility** → APPLIED clarification. Verified via gh API: CDR-013 mandates Linear Project briefs (Build / Workstream), NOT repo-side intent docs. Q41 intent.md is complementary, not conflicting — different substrate, different audience, partial field overlap. Sub-decision 7 amended to enumerate CDR-013 Build Brief as parallel Linear-side artifact in See also; cross-substrate framing added explaining the relationship.

**Validation discipline catches by orchestrator on drafter C's work (preserved for handoff integrity):**
- Drafter C's draft was largely structurally sound; orchestrator surfaced two architectural choices (Constraints scope + word floor) that drafter C had flagged as risks but not escalated.
- Orchestrator's CDR-013 compatibility check caught a potential cross-substrate gap that drafter C hadn't pre-emptively addressed; verification via gh API confirmed complementary-not-conflicting; cross-substrate framing now explicit.

**Q42 — `/flow:office-hours` skill design (LOCKED 2026-05-07).** Q41 (just locked) provides binding output spec; Q42 produces it. Q37 sub-decision 4 routes L1 multi-perspective review through Q42 → intent.md. CDR-013 Build Brief is parallel Linear-side artifact; Q42 hybrid input consumes it as pre-fill context. Closes Q37 phase 2 longest-pending dependency. Seven sub-decisions:

1. **Invocation contract — user-invocable + auto-invoked at `/flow:office-hours`.** User-invocable for greenfield + retrofit + standalone refresh. Auto-invoked by `/flow:start-project` (Q37 phase 2) and `/flow:retrofit-project` (when intent.md absent — per Q37 sub-decision 7). Args: `--linear-context={auto|skip|force}` (CDR-013 Build Brief input control); `--refresh` (regenerate L1 review section only without re-running interview).

   **Defaults decision tree** (per refinement 3 lock):
   
   | State | Q42 behavior |
   |---|---|
   | intent.md absent + no `--refresh` | Full interview + L1 review (default greenfield path) |
   | intent.md absent + `--refresh` | Error: "No intent.md to refresh; run without `--refresh` first to author it." |
   | intent.md exists, L1 body matches placeholder regex, no `--refresh` | Full interview + L1 review (treats placeholder as "L1 not run") |
   | intent.md exists, real L1 content, no `--refresh` | No-op skip + message: "intent.md complete with L1 review at `<l1_reviewed>` — use `--refresh` to regenerate L1 review only" |
   | intent.md exists, any L1 state, `--refresh` | Skip interview; re-run 4 perspective agents on existing body; rewrite L1 section; bump `l1_reviewed`; atomic-write |
   | `--linear-context=force` AND Linear Brief absent/non-CDR-013-shape | Error per sub-decision 2 (regardless of intent.md state) |
   | Breadcrumb mode=resume (mid-interview crash) | Q31.3 stale check fires; preflight handles resume per sub-decision 6 |

2. **Input contract — hybrid (Linear Build Brief context + interview gap-filling) per Q41 sub-decision 7 hypothesis.** Three modes via `--linear-context` flag:
   - **`auto` (default):** preflight via `mcp__plugin_workflows_linear-server__get_project` (using `linear_project_id` from `.flow/config.json` per Q12); if Linear Brief description has CDR-013 shape (`Problem` + `Outcome` sections regex-detected), parse + use as pre-fill context for **all 4 overlapping Q41 sections** per user lock 2026-05-07:
     - CDR-013 `Problem` → Q41 `Problem we're solving`
     - CDR-013 `Outcome (done condition)` → Q41 `Success criteria`
     - CDR-013 `Scope (Out)` sub-list → Q41 `Out of scope`
     - CDR-013 `Risks & rabbit holes` → Q41 `Constraints`
     
     Other Q41 sections (`Mission`, `Target users`, L1 review summary) gap-filled by interview. Pre-fill content offered as Approve / Edit / Replace per section (sub-decision 3); user is final validator on imprecise mappings (e.g., Risks ≠ Constraints exactly). Brite-specific reasoning: CDR-013 Briefs reliably populate Risks + Scope sections during dogfood; pre-fill saves real interview time.
   - **`skip`:** force pure-interview; ignore Linear context. Useful for projects in Linear-but-not-yet-in-CDR-013-shape, or sensitive content the user wants interview-mediated.
   - **`force`:** require Linear Build Brief CDR-013-shape; error if absent ("Linear Build Brief at `<linear_url>` doesn't match CDR-013 Build shape; populate per CDR-013 first OR run with `--linear-context=auto|skip`"). Useful for orgs with strict CDR-013 compliance.
   
   **Honest pushback considered:** could parse non-CDR-013 Linear descriptions heuristically; rejected because heuristic parsing of unknown-shape briefs would mislead users into thinking the system understood content it didn't. Strict CDR-013-shape detection or fall-through is cleaner.

3. **Interview shape — sequential `AskUserQuestion`, one section at a time + final-review step per refinement 4 lock.** Matches user feedback memo (memory:710 — "one question per turn — strict"). Six interview steps map 1:1 to Q41's six substantive sections (L1 review summary auto-populated separately per sub-decision 4). Per-section UX:
   - Display Q41 section description ("how we'll know we delivered" for Success criteria, etc.) as context
   - If `--linear-context=auto` produced pre-fill content for this section, show it as starting draft + offer Approve / Edit / Replace
   - Otherwise: free-text input prompt with Q41 length guidance ("3-5 bullets" for Success criteria, "~50-100 words" for Mission)
   - **Per-section validation per refinement 5 lock:** when input doesn't meet shape guidance (Mission <50 words; Success criteria <3 or >5 bullets; etc.), surface soft-warn `AskUserQuestion`: "<Section> is <metric>; expected <range>. Continue anyway? [Yes / Revise]". User retains final call per Q41's locked soft-warn discipline. Hard validation only on structural failures (no body content at all → re-prompt with required-content message).
   
   **Final-review step** (per refinement 4 lock — matches Q19 Phase 5 + Q20.6 within-skill confirmation precedents): after all 6 sections complete, fire final-review `AskUserQuestion`: "Review proposed intent.md content. Approve to proceed to L1 review / Edit specific section / Cancel." Edit option re-prompts that section's input with current value pre-filled. Loop back through final-review until user approves or cancels.
   
   Front-matter fields auto-populated (NOT interview-asked): `title` from Linear project name; `agent_context: project-intent`; `last_reviewed: <today ISO-8601>`; `linear_project_id` + `linear_project_name` from `.flow/config.json`; `l1_reviewed: null` (filled by sub-decision 4).

4. **L1 review dispatch — fires AFTER interview completes + final-review approves, BEFORE Q42 hands off to Q37 G2 gate.** Q42 invokes 4 perspective agents (`plan-ceo-reviewer`, `plan-design-reviewer`, `plan-eng-reviewer`, `plan-devex-reviewer` per Q21:396-401) via Agent tool with `run_in_background: true` for parallel execution. Each agent receives:
   - Q41 template for shape reference
   - All 6 interview-completed sections (Mission / Target users / Problem / Success criteria / Out of scope / Constraints)
   - Optional Linear Build Brief snapshot (if `--linear-context=auto|force` consumed it)
   - Perspective-specific framing prompt (e.g., plan-ceo-reviewer's prompt focuses on strategic concerns; plan-devex-reviewer's prompt has the early "is this developer-facing?" check per Q21:401)
   
   Each agent returns `{headline, perspective_specific_concerns_field}` — field name varies per Q21:396-401: `strategic_concerns` / `adjustments` / `adjustments` / `ergonomic_concerns`. Q42 collects 4 headlines + formats into Q41 sub-decision 5's L1 review summary section structure (4 sub-headings: CEO / Design / Engineering / Developer-experience). devex agent's "non-applicable" minimal headline preserved for non-dev-facing Brite projects (Brand Hub, BriteBase consumer surface, etc.).
   
   **Concerns disposition** (per refinement 6 lock): Q42 writes concerns to `docs/plans/l1-concerns-<ISO-8601>.md` (transient run artifact; follows docs/plans convention from CLAUDE.md doc map; deletable post-ship). Format: 4 H2 sections (one per perspective: CEO / Design / Engineering / Developer-experience) with full concerns content from agent return value. UX message before G2 hand-off: "L1 review surfaced <N> concerns across 4 perspectives — review at `docs/plans/l1-concerns-<timestamp>.md` before approving G2." Headlines persist in intent.md `## L1 review summary` section; concerns persist separately for user review. Q46 Linear writeback (v1.1) may supersede with Linear-comment routing — parking lot candidate.
   
   Wall: ~30-60s for the 4 parallel agents (haiku/sonnet mix; longest single-agent dominates).

5. **Atomic write semantics — final-atomic-write only, NOT incremental.** Interview answers persist to breadcrumb's `office_hours_state` (sub-decision 6) during the conversation. **intent.md is written ONCE — after all interview sections complete + final-review approved + L1 review fires + L1 headlines populate.** Single atomic write per Q31.5 pattern (write to `<path>.tmp` → atomic `mv` → parse-verify).
   
   **Reasoning (push back on incremental fill):** Q11/Q19 Phase 0 read intent.md as priority filter (memory:50, 192). If Q42 wrote incrementally (template + partial sections), Q11/Q19 reading mid-interview would see placeholder body — misleading inventory generation. Final-atomic-write means intent.md either doesn't exist (interview in flight) or fully populated (interview + L1 complete) — never partial. Q41's placeholder strategy is for the L1 review summary section specifically (template ships with L1 placeholder so Q29.1 structural gate can pass before office-hours runs the L1 review); NOT for incremental section writes during interview.

6. **Resume support — per-section interview state in breadcrumb extension; Q31 amendment 1 records the schema slot.** Q31 breadcrumb extended with `office_hours_state` field for `mode=greenfield|retrofit` runs in phase 2 (per user lock 2026-05-07 with Q31 amendment 1 audit trail — see Q31 lock entry):
   ```json
   "office_hours_state": {
     "sections_completed": ["Mission", "Target_users", "Problem"],
     "section_answers": { "Mission": "<text>", "Target_users": "<text>", ... },
     "linear_brief_snapshot": "<text or null>",
     "l1_review_status": { "ceo": "pending|complete", "design": "pending|complete", ... },
     "l1_review_results": { "ceo": "<headline or null>", ... }
   }
   ```
   On crash mid-interview, preflight detects breadcrumb (mode=resume per Q12), dispatches Q42 with state. Q42 reads `sections_completed`, skips populated sections via stored answers (offering user "preserve / edit / re-do" per section as confirmation), resumes interview from first incomplete. After all sections complete + final-review approves, fires L1 review (skipping perspectives marked complete with stored results). After all L1 perspectives complete, atomic-writes intent.md.
   
   Stale-breadcrumb policy per Q31.3 (>7 days inactive → offer discard).
   
   **Schema discipline rationale (per user lock):** Q31 stays canonical breadcrumb spec; per-skill state extensions get amendment notes at Q31's lock entry. Sets precedent for future Q44 retro_state, Q53 ship_state, etc. — each adds a slot to Q31.1 + amendment note. Avoids schema sprawl across multiple Q-locks.

7. **Cribbing scope from gstack — partial transfer.** gstack's `office-hours/` skill (memory:646 — top-level skill at repo root, NOT plugins/<name>/) is the inspiration source. **Transfer cleanly:**
   - Interview pacing pattern (one-question-at-a-time)
   - Multi-perspective dispatch concept (gstack inspires Q21 agent design)
   - Sequential `AskUserQuestion` UX for section-by-section review
   
   **Adapt for FDA:**
   - Output target: gstack outputs design-consultation context (freeform); Q42 outputs Q41-conformant repo-side anchor doc (binding contract, regex-checkable structure)
   - L1 review integration: gstack has separate skills for plan-ceo-review / plan-design-review / plan-devex-review; FDA bundles into Q42 via Agent dispatch of plan-{ceo,design,eng,devex}-reviewer agents (Q21 agent definitions, NOT separate skills — per Q21:400-401 invocation context)
   - CDR-013 hybrid input: gstack-native (no CDR-013 analog); FDA-specific addition for Brite context
   - Q31 breadcrumb persistence: gstack has its own state model; FDA uses unified Q31 breadcrumb extended with `office_hours_state` (Q31 amendment 1)
   - Plugin packaging: Q42 lives at `plugins/flow-architecture/skills/flow-office-hours/SKILL.md` per Q30.2 lock (NOT top-level dir like gstack)
   
   **NOT transferred:** gstack's design-consultation interview branches (gstack steers toward design + code patterns; FDA Q42 outputs project-level anchor, NOT design choices). v1.1 candidate: add design-system-requirements branch if Brand Hub dogfood reveals gap.

**Q42 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 6 refinements after Q42 draft. Drafter C's resolution of each:

1. **CDR-013 → Q41 pre-fill mapping coverage** → ESCALATED to user via `AskUserQuestion`; user answered "All 4 overlapping pairs (Recommended)" — Brite-specific reasoning holds: CDR-013 Briefs reliably populate Risks + Scope during dogfood; pre-fill saves real interview time; "Risks ≠ Constraints exactly" semantic gap mitigated by per-section Approve/Edit/Replace UX (user is final validator).
2. **Q31 amendment scope** → ESCALATED to user via `AskUserQuestion`; user answered "Q31 amendment with audit trail (Recommended)" — schema discipline wins: Q31 stays canonical; readers see full breadcrumb shape without grep across per-skill locks. Q31 amendment 1 written + sets precedent for Q44/Q53 etc. additions.
3. **Defaults decision tree** → APPLIED. Full tree spelled out as table in sub-decision 1; covers 7 states including --refresh-with-absent-intent.md edge case drafter C had missed.
4. **Back-revise mechanics** → APPLIED (b). Verified Q19.7 (memory:204) + Q20.6 establish FDA-conventional final-review-AskUserQuestion pattern. Sub-decision 3 amended with final-review step after all 6 sections.
5. **Per-section validation failure** → APPLIED (b). Matches Q41's locked soft-warn discipline (sub-decision 6 of Q41). Hard rejection at validation level would override Q41's word-count lock; sub-decision 3 amended with soft-warn AskUserQuestion pattern.
6. **Concerns disposition** → APPLIED (a). Q21:396-401 specifies concerns field shape (varies per agent: strategic_concerns / adjustments / adjustments / ergonomic_concerns). Concerns persist to `docs/plans/l1-concerns-<ISO-8601>.md` (follows CLAUDE.md docs/plans convention; transient run artifact; deletable post-ship). Q46 Linear writeback (v1.1) may supersede.

**Validation discipline catches by orchestrator on drafter C's work (preserved for handoff integrity):**
- Caught drafter C's narrow CDR-013 pre-fill mapping (only 2 of 4 overlapping pairs); orchestrator surfaced via Q41 sub-decision 5's earlier finding; user lock extended to all 4 pairs.
- Caught drafter C's Q31 amendment scope ambiguity (drafter C flagged but didn't escalate); orchestrator forced explicit precedent decision; user lock established schema-discipline pattern for future Q44/Q53.
- Caught drafter C's missing edge case in defaults (--refresh + absent intent.md); orchestrator surfaced via decision-tree completeness check.
- Caught drafter C's unspecified back-revise mechanics + validation-failure handling; orchestrator filled UX-spec gaps.
- Caught drafter C's unspecified concerns disposition (Q21 produces them; Q41 doesn't destinationize them); orchestrator surfaced spec gap; user lock established docs/plans convention.

**Q42 amendment 1 — AskUserQuestion free-text-via-Other shape for the 6-section interview (LOCKED 2026-05-18 per BC-9028 dogfood-surface fix).** Q42 sub-decision 3 (Interview shape) originally specified "free-text input prompt with Q41 length guidance shown inline" for sections without `--linear-context` pre-fill — see body above. The orchestrator surface that the spec targets is `AskUserQuestion`, which is multi-choice-with-automatic-`Other`-fallback (API contract: 2-4 user-facing options + Other for free-text capture; this amendment prescribes 1-2 drafted options of that 2-4 ceiling); it has no pure free-text mode. BC-6998 iter-1 dogfood on Brand Hub surfaced the mismatch at Phase 2 Step 3: the operator either had to (a) fabricate 2-4 representative multi-choice options per section + the Other fallback (option-set drift risk; iter-1 went with this path and the option sets were operator-inferred, not user-driven — captured in `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md` § Bugs surfaced P3), or (b) violate the gate-respect contract by collapsing the 6 sections into fewer calls. Path (a) is fabricated content; path (b) breaks the gate-respect contract (`plugins/flow-architecture/skills/_shared/gate-respect.md` once promoted; cf. cadence `skills/_shared/gate-respect.md`). This amendment locks the canonical free-text-via-Other shape for each per-section `AskUserQuestion` turn:

1. Each per-section interview presents **one** `AskUserQuestion` with 1-2 representative drafted options. The options are scoped to common low-cost actions the user might legitimately pick — e.g., `Skip this section (use template default)`, `Use the linked PRD content as-is`, `Match the Linear Build Brief snapshot` — NOT a hallucinated draft of the user's project intent.
2. The Recommended option is biased **toward `Other`** (i.e., `Other` is the canonical pick for content-bearing input; the drafted options exist to surface low-cost escape hatches, not to anchor the user on boilerplate). Mark exactly one drafted option as `(Recommended)` only when the section legitimately admits a no-content default (e.g., Constraints' Q41-locked `None material` body); otherwise leave all drafted options unmarked and let the user reach `Other` for free-text entry.
3. The Q41 length guidance (e.g., "~50–100 words" for Mission, "3–5 bullets" for Success criteria) renders in the `AskUserQuestion` prompt body so it is visible alongside both the drafted options and the `Other` free-text slot.
4. Per-section validation (refinement 5 soft-warn loop) fires identically against whichever path the user takes — drafted-option pick OR `Other` free-text. The Approve/Edit/Replace pre-fill UX (when `--linear-context=auto` produced content for the section) layers above this shape: pre-fill present → 3-option `AskUserQuestion` (Approve / Edit / Replace) with `Edit` and `Replace` both routing into the `Other` free-text slot — `Edit` pre-fills with the existing value, `Replace` starts from scratch.

**Why this is preserved as an amendment rather than a sub-decision 3 rewrite.** Schema-discipline amendment pattern (cf. Q21 amendment 1, Q23 amendment 1, Q24 amendment 1, Q29 amendment 1, Q31 amendments 1+2, Q47 amendment 1) keeps the original sub-decision 3 prose verbatim above and records the spec-vs-runtime delta as an audit-trail addition. Original sub-decision 3 phrasing ("free-text input prompt with Q41 length guidance shown inline" — final bullet of the per-section UX list) is preserved as the audit-trail record of what was locked at 2026-05-07. This amendment supersedes the runtime contract; sub-decision 3's pure-free-text phrasing no longer governs implementation.

**Derivative correction.** `plugins/flow-architecture/commands/office-hours.md` § Interview shape (Q42 sub-decision 3) per-section UX block is corrected derivatively in the same commit per the BC-6000 same-commit-bump rule. Plugin version bumped 1.0.6 → 1.0.7. No agent file, sub-skill, or other command body references the old shape — the spec lives only in the design-rationale Q42 entry + the office-hours.md command body.

**Cross-link:** BC-9028 (this issue) — origin; BC-6998 (Brand Hub dogfood iter-1) — surface; `brand-hub-dogfood-findings.md` § Bugs surfaced P3 — diagnostic trail; `feedback_no_condensed_shortcuts_in_skill_specs.md` + `feedback_interview_chunking.md` — sibling disciplines (don't invent shortcuts when spec prescribes one-question-at-a-time; single-assumption-per-question).

**Schema-evolution discipline reinforced:** Q42 amendment 1 follows Q31 amendments 1+2 + Q21/Q23/Q24/Q29/Q47 amendments 1 + Q33/Q34/Q35 amendments 1 + Q49/Q50 amendments + Q2/Q22/Q28/Q41 amendments 1 precedent — explicit amendment-number + audit trail in originating Q-lock; AskUserQuestion-shape constraint discovered at dogfood time on a real orchestrator surface (not at lock time) drives the amendment, consistent with the orchestrator-vs-drafter validation-first cycle (cf. Q50 amendments 1+2 caught at downstream consumer drafting; Q23/Q29/Q47 amendments caught at /workflows:review iteration; this amendment caught at /flow:retrofit-project iter-1 dogfood). Future Q42 amendments would be Q42 amendment 2+.

**Q46 — Linear-aware adaptation layer (LOCKED 2026-05-07).** Cross-cutting writeback pattern at `_shared/linear-writeback-pattern.md` (Q30.2 placeholder). **Critical scope clarification:** Q46 covers post-scaffold ongoing Linear writes only — initial scaffolding (Q13) and legacy migration (Q14) stay direct. Resolves Q38 sub-decision 4 deferred decision; establishes pattern for Q43 / Q44 / Q53 consumers. Seven sub-decisions:

1. **Scope — post-scaffold ongoing writes only.**
   - **In Q46 scope (v1):** /flow:ship body-section + comment writes (Q53 pending); /flow:retro comment writes on completed milestones (Q44 pending); /flow:plan-{discipline} body-section appends on discipline-child issues (Q43 pending).
   - **In Q46 scope (v1.1 candidates):** Q42 L1 concerns Linear routing (parked per Q42 sub-decision 4); /flow:audit Linear surfacing via `--linear-surface` flag (Q38 amendment territory — see sub-decision 7 + Q38 deferred-decision resolution note).
   - **NOT in Q46 scope:** Q13 initial scaffold writes (direct via sub-skill); Q14 legacy `## FDA migration` section (direct via Q14 with HTML markers — precursor pattern that Q46 generalizes; Q14 stays as-is); Q13.3 fidelity-review body retries (Q13.3's inline pattern).

2. **Body-section idempotency — generalized HTML-comment markers per writeback type, hyphenated format matching Q14.2 lock (memory:80) per orchestrator catch.**
   - Marker shape: `<!-- FDA-WRITEBACK-<type>-START -->` / `<!-- FDA-WRITEBACK-<type>-END -->`. Type values are kebab-case (`ship-summary`, `retro-summary`, `plan-eng-section`). Example: `<!-- FDA-WRITEBACK-ship-summary-START -->`. Hyphenated throughout; consistent with Q14.2's `FDA-MIGRATION-START`/`-END` precedent.
   - Marker namespace stays separate (`FDA-WRITEBACK-*` vs `FDA-MIGRATION-*`); no collision.
   - Re-write of same `<type>` on same issue: replaces content between markers (idempotent; re-run safe).
   - First write: appends section to issue/milestone body or creates new comment with markers.
   
   **Canonical type registry at `_shared/linear-writeback-pattern.md` (per refinement 3 lock):** v1 enum: `ship-summary`, `retro-summary`, `plan-story-section`, `plan-eng-section`, `plan-design-section`, `plan-qa-section`, `plan-docs-section`, `audit-concerns` (registered but UNUSED in v1 per Q38 deferred-decision resolution — reserved for v1.1 `--linear-surface` flag promotion). v1.1 candidates: `l1-concerns` (per Q42 sub-decision 4 parking lot). **Adding a type requires editing the registry file + amendment note in Q46's lock entry** (mirrors Q31 amendment pattern). Q46 **rejects unknown types** with error: `"Unknown writeback type '<value>'. Valid types: <enum>. To add a new type, amend Q46 + register at _shared/linear-writeback-pattern.md."` Forces deliberate type proliferation; catches typos/drift.

3. **Comment idempotency — claim-and-update via signature line + breadcrumb-stored comment ID. Q31 amendment 2 records the schema slot.**
   - Each Q46 comment opens with signature: `_Generated by /flow:<skill> for <issue-id> on <ISO-8601>_`
   - On write: list_comments(issue_id) → match by signature regex → on match: save_comment {id, body:...}; on miss: save_comment {issueId, body:...} + record entry in breadcrumb's `linear_writeback_state.comment_ids[]`.
   - Re-runs idempotent — same signature → same comment updated.
   - Cross-run resilience: comment IDs persist in breadcrumb until Q31.3 stale discard.
   
   **Q31 amendment 2 — `linear_writeback_state` extension slot (LOCKED 2026-05-07 per Q46 sub-decisions 3+5+7 user locks):** follows Q42 amendment 1 precedent. See Q31 lock entry for the explicit schema extension note.

4. **Conflict resolution — clobber-with-warning (per user lock 2026-05-07); content-between-markers replaced; outside markers preserved.**
   - Body writeback: Q46 reads current body via `get_issue` → locates `<type>` markers → replaces content between them on `save_issue`. Content outside markers preserved verbatim.
   - User hand-edits **inside markers**: clobbered on re-run. Q46 emits warning to stdout: `"Detected user-edited content inside <type> markers on <issue-id>. Q46 will replace this content. To preserve user edits, move them outside the markers."` Warning persists in `linear_writeback_state.warnings[]` (Q31 amendment 2).
   - User hand-edits **outside markers**: preserved untouched.
   - Comments: hand-edits to Q46-created comment bodies clobbered on re-run (signature match dedupes). User-created comments (no signature match) untouched.
   - **Machine-managed-region contract** is the explicit framing: markers signal user-edits-out-of-bounds; warning is loud (stdout + breadcrumb persistence). NOT a transactional lock — Linear MCP doesn't support that; best-effort with warning.
   - **v1.1 candidate (parking lot):** fail-and-prompt detection via hashed last-content comparison + AskUserQuestion mid-run; promote if Brand Hub dogfood reveals real edit-loss incidents.

5. **Notification etiquette — per-consumer batching (per refinement 4 lock); Q46-enforced within-skill throttle.**
   - **Within-skill batching:** per-consumer concern, NOT Q46-enforced. Q46 stays a thin write executor — caller passes one (issue_id, type, content) tuple per intended write; Q46 doesn't merge/rebalance. Consumer locks (Q53 ship, Q44 retro, Q43 plan-X) decide their own batching strategy. Convention documented in plugin CLAUDE.md (Q55): "Prefer single parent comment with sub-sections per child when writes target sibling issues sharing a parent." Q55 enumerates the convention; consumers cite it in their respective sub-decisions.
   - **Within-skill throttle:** Q46-enforced via `linear_writeback_state.written_pairs[]` (Q31 amendment 2 schema). Q46 checks `(issue_id, type, run_id)` before write; rejects duplicate writes within same run. Re-attempts with same (issue_id, type) update the existing write rather than creating a new one (idempotency layer redundant with sub-decisions 2+3, but explicit at Q46 layer for safety).
   - **Cross-skill throttle:** NO global throttle in v1 — each skill responsible for its own batch. **v1.1 candidate (parking lot):** cross-skill notification rate-limiter if Brand Hub dogfood reveals comment-spam patterns.

6. **Read-context conventions — paginated + rate-limit-aware + stale-read warning.**
   - **Pagination:** Q46 read calls (`list_comments`, `get_issue` with relations) use explicit pagination params; default page size 50; paginate until end-of-list signal.
   - **Rate-limit handling:** 1 retry with 2s backoff per Q13.5 transient pattern; on second fail, log + continue with possibly stale data (warning persisted in `linear_writeback_state.warnings[]`).
   - **Stale-read tolerance:** read at write start + read at write end; if `updatedAt` changed between (race condition with another writer — possible if user edits in Linear UI mid-run), surface warning + skip the write: `"Issue <issue-id> was modified during Q46 write (started <t1>, modified <t2>); skipping to avoid clobbering external edits. Re-run /flow:<skill> to retry."` Skip recorded in breadcrumb.
   - **NOT a transactional lock** — best-effort given Linear MCP API constraints.

7. **Cross-skill consumer registry + Q38 deferred-decision resolution.** Q46's interface — single function callable by consumers:
   ```
   linear_writeback({
     issue_id: string,
     type: WritebackType,           // enum from _shared/linear-writeback-pattern.md
     surface: 'body' | 'comment',
     content: string,
     signature?: string,            // required for surface='comment'
     breadcrumb_path: string,
     warn_on_clobber?: boolean      // default true
   }) → { result: 'created' | 'updated' | 'skipped', issue_url, warnings: string[] }
   ```
   
   **v1 consumers:**
   - `/flow:ship` (Q53 pending) → ship-summary body section on parent + comments on completed children
   - `/flow:retro` (Q44 pending) → retro-summary comment on completed milestone
   - `/flow:plan-{discipline}` (Q43 pending) → plan-X-section body section on discipline-child
   
   **Q38 sub-decision 4 deferred-decision resolution (per user lock 2026-05-07):** **Stays strictly local in v1** — `/flow:audit` emits stdout + `--json` only; no Linear writeback. Most reversible architectural choice. `audit-concerns` marker type registered in Q46's `_shared/linear-writeback-pattern.md` enum but UNUSED in v1; reserved for v1.1 `--linear-surface[=parent|milestone]` flag promotion (Q38 amendment territory). Preserves Q38's "stdout-only by default" framing; avoids notification spam from auto-invocations (auto-fires from /flow:ship + /flow:plan-{discipline} per Q38 sub-decision 5; routing those to Linear would generate ~5+ comments per ship cycle per sub-flow). /flow:ship already routes ship-summary as the team-facing checkpoint; audit-concerns is developer-internal pre-flight.
   
   **v1.1 candidates (parking lot):** Q42 L1 concerns Linear routing (per Q42 sub-decision 4 punt); `--linear-surface` flag for /flow:audit (Q38 amendment territory).

**Q46 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 5 refinements + Q38 deferred-decision weight. Drafter C's resolution:

1. **Clobber-with-warning vs fail-and-prompt** → ESCALATED to user via `AskUserQuestion`; user answered "Clobber-with-warning (Recommended)" — machine-managed-region contract is clear; warning is loud (stdout + breadcrumb persistence); fail-and-prompt is parking-lot v1.1 candidate; AskUserQuestion mid-run is heavyweight UX cost for unproven need.
2. **Q14.2 marker format verification** → ORCHESTRATOR CAUGHT REAL INCONSISTENCY. Drafter C's draft used space-separated markers (`<!-- FDA-WRITEBACK <type> START -->`); Q14.2 (memory:80) uses hyphenated (`FDA-MIGRATION-START`). Apply correction: hyphenated `FDA-WRITEBACK-<type>-START`/`-END` matching Q14.2 precedent.
3. **Type enum extensibility** → APPLIED. Canonical registry at `_shared/linear-writeback-pattern.md`; reject unknown types with helpful error; adding types requires amendment note in Q46 lock entry (mirrors Q31 amendment pattern). Forces deliberate type proliferation.
4. **Batching heuristic ownership** → APPLIED (a) per-consumer. Q46 stays thin write executor; consumer locks (Q53/Q44/Q43) own batching strategy; convention documented in Q55 plugin CLAUDE.md. Within-skill throttle stays Q46-enforced via written_pairs[].
5. **Q31 amendment 2 schema completeness** → APPLIED. Schema augmented with `written_pairs[]` (resume-safe within-run throttle + cross-run audit) + `warnings[]` (clobber-warning persistence). See Q31 lock entry for the explicit amendment note.
6. **Q38 deferred-decision** → ESCALATED to user via `AskUserQuestion`; user answered "Stay strictly local in v1 (Recommended)" — most reversible; preserves Q38 framing; audit-concerns enum slot reserved for v1.1 promotion.

**Validation discipline catches by orchestrator on drafter C's work (preserved for handoff integrity):**
- **Caught drafter C's Q14.2 marker format inconsistency** — space-separated vs Q14.2's hyphenated; would create namespace confusion. Apply correction.
- Surfaced 3 spec gaps drafter C left implicit: type enum extensibility (no canonical registry); batching heuristic ownership (Q46 vs consumer); Q31 amendment 2 schema completeness (missing throttle state for resume safety).

**Q43 — `/flow:plan-{discipline}` suite (LOCKED 2026-05-07).** Five distinct slash entries (`/flow:plan-story`, `/flow:plan-eng`, `/flow:plan-design`, `/flow:plan-qa`, `/flow:plan-docs`) per Q30.2. Heavy consumer of Q46 (writes plan-X-section to discipline-child body via locked type registry); dispatches Q21's plan-X-reviewer agents at L4 single-perspective scope per meta-Q lock memory:413-414; fills Q24 EPEV "Plan" sub-section. Cited by Q24 mod 2's "How to pick up this work" section. Seven sub-decisions:

1. **Invocation contract — five distinct commands per Q30.2 lock; thin orchestrators.** Each command corresponds 1:1 to its discipline-child issue type (per Q24 templates) and dispatches its matching plan-X-reviewer agent (per Q21:396-401). Args:
   - Positional `<discipline-child-issue-id>` (e.g., `BC-1234`) — optional; falls through to issue resolution per sub-decision 3
   - `--refresh` — bypass Q43's error-if-populated layer (sub-decision 6); triggers Q46's clobber-with-warning per Q46 sub-decision 4
   - User-invocable for ad-hoc plan refresh; auto-invoked by `/flow:session-start` (Q51 — pending) per Q24 mod 2
   
   Single command with `--discipline=` arg rejected: Q30.2 already locks 5 distinct commands; discipline-specific framing is critical to L4 single-perspective semantics. Following Q30.2.

2. **Phase sequence — 4 phases, lightweight (~30-90s wall total).**
   - **(1) Preflight + context gathering** (~5-15s): load `.flow/config.json`; resolve target issue via Linear `get_issue`; fetch parent issue body + sibling discipline children via `list_issues`; locate story doc path via parent title regex parse + domain label; load story doc + parent body into agent context window.
   - **(2) Reviewer agent dispatch** (~20-60s): single Agent invocation of plan-X-reviewer (sonnet per Q21); receives Q24 template + story doc + parent body + sibling summaries + relevant codebase context (agent uses Read/Glob/Grep per Q21:396 tool spec).
   - **(3) Plan section formatting** (~1s): transform reviewer's `{headline, adjustments}` return into plan-X-section markdown per sub-decision 5.
   - **(4) Q46 linear_writeback** (~1-3s): single `linear_writeback({type: "plan-X-section", surface: "body"})` call; Q46 handles marker management + idempotency + clobber-warning.

3. **Issue resolution + mode classifier integration — runs in any FDA mode where target issue exists.**
   - **Issue ID resolution priority:**
     - (a) explicit positional arg (highest priority)
     - (b) breadcrumb's `domains[N].current_sub_flow` where N matches the active domain (per Q31.1 locked schema memory:284 — `current_sub_flow` IS locked as a per-domain entry field within `domains[]`, not a top-level field) if `mode=resume` AND breadcrumb's `current_phase` indicates a per-sub-flow phase (e.g., `linear-scaffold/<DOMAIN>` per Q31.2 phase naming)
     - (c) parse current git branch name for `BC-XXXX` reference
     - (d) `AskUserQuestion` fallback with list of recently-active discipline-X children from Linear
   - **Verification:** confirm resolved issue has matching `type:<discipline>` label per Q24 mod 3 (memory:436) standardized labels; if mismatch (e.g., `/flow:plan-eng` against issue with `type:design` label), error with redirect: `"Issue <id> has type:design label; use /flow:plan-design instead."`
   - **Mode classifier:** Q43 runs in any FDA mode (`greenfield`/`retrofit`/`incremental-add`/`resume`); not mode-gated like Q47. Pre-flight verifies issue exists + has correct discipline label + has parent (warn on orphan, continue).

4. **Reviewer agent dispatch — single perspective per command (per meta-Q L4 lock memory:413-414).**
   - `/flow:plan-story` → plan-story-reviewer agent
   - `/flow:plan-eng` → plan-eng-reviewer agent
   - `/flow:plan-design` → plan-design-reviewer agent
   - `/flow:plan-qa` → plan-qa-reviewer agent
   - `/flow:plan-docs` → plan-docs-reviewer agent
   - **L4 = SINGLE discipline only per meta-Q lock**; NOT autoplan (NOT all-5-perspectives). Q42 L1 dispatches 4-in-parallel; Q13 scaffold L3 dispatches all-5; Q43 L4 dispatches 1.
   - Agent context package: Q24 discipline-specific template (story.md / engineering.md / design.md / qa.md / docs.md from `docs/templates/issues/` — plugin-shipped versions with Q24 mods 1-5 + amendment 1 baked in); story doc at `docs/product/flows/<domain>/<flow-id>.md`; parent issue body (post-Q23 mod 2 with `## L3 review summary` if scaffolded); 4 sibling discipline children summaries (title-only — discipline carried in title prefix `[Story]`/`[Eng]`/`[Design]`/`[QA]`/`[Docs]` per Q24 templates' locked title format `<DOMAIN-NN> [<Discipline>] <Inventory title>` verified via filesystem read 2026-05-07 — sibling listing's title alone signals discipline + state.type from get_issue); discipline-relevant codebase paths (e.g., `src/components/<feature>/` for Eng; sandbox harness path for QA; persona docs for Story).
   - Returns `{headline, adjustments}` per Q21:396-401 spec.

5. **Plan section format + Q24 amendment 1 (template marker pre-population).**
   - Plan section content uses Q24's locked EPEV format (Explore/Plan/Execute/Verify). /flow:plan-X writes content to "Plan" sub-section of discipline-child body, between Q46 markers.
   - **Q24 amendment 1 (LOCKED 2026-05-07 per Q43 sub-decision 5; see Q24 amendment 1 entry below):** Q24's 5 discipline-child templates pre-populate empty Q46 markers in the Plan sub-section. Without this, Q46's first-write would append at body end (per Q46 sub-decision 2 default) — wrong location. Templates updated to include 5 discipline-specific placeholder strings:
     - story.md: `_Plan not yet generated. Run \`/flow:plan-story <issue-id>\` to populate._`
     - engineering.md: `_Plan not yet generated. Run \`/flow:plan-eng <issue-id>\` to populate._`
     - design.md: `_Plan not yet generated. Run \`/flow:plan-design <issue-id>\` to populate._`
     - qa.md: `_Plan not yet generated. Run \`/flow:plan-qa <issue-id>\` to populate._`
     - docs.md: `_Plan not yet generated. Run \`/flow:plan-docs <issue-id>\` to populate._`
     
     Stable substring `Plan not yet generated` used for "is section populated" regex detection — matches all 5 variants.
     
     Markers wrapping placeholder:
     ```markdown
     ## Plan
     <!-- FDA-WRITEBACK-plan-<discipline>-section-START -->
     _Plan not yet generated. Run `/flow:plan-<discipline> <issue-id>` to populate._
     <!-- FDA-WRITEBACK-plan-<discipline>-section-END -->
     ```
   - Format of generated content (between markers): reviewer's `headline` → primary plan paragraph (~100-200 words); reviewer's `adjustments` → bullet list under `**Refinements:**` sub-heading (3-7 bullets typical).
   - Length target: ~150-400 words per discipline (Eng/Design plans typically longer; QA/Docs plans more concise). No hard floor; soft warn at <50 words.
   - Parallel to Q24 mod 4's existing "Cross-discipline context" markers (already locked) — Q24 amendment 1 adds Plan-section markers using the same pattern.

6. **Q46 integration + refresh semantics + double-layer safety (per refinement 4 lock).**
   - Single `linear_writeback({issue_id: <child-id>, type: "plan-<discipline>-section", surface: "body", content: <formatted-plan>, breadcrumb_path, warn_on_clobber: true})` call per /flow:plan-X invocation.
   - Q46 type registry already includes all 5 plan-X-section types per Q46 sub-decision 2 v1 enum — no Q46 amendment needed.
   - **Double-layer safety (intentional composition):**
     - **Q43 layer (caller-side):** before Q46 runs, Q43 reads issue body via `get_issue`; if Plan section's content between markers does NOT contain stable substring `Plan not yet generated` (i.e., plan already populated) AND `--refresh` flag absent, error: `"Plan section already populated for <issue-id>. Use --refresh to regenerate (will trigger Q46 clobber-with-warning)."` Avoids accidental re-writes of valid plans.
     - **Q46 layer (executor-side):** if `--refresh` bypasses Q43 layer, Q46's clobber-with-warning fires per Q46 sub-decision 4 user lock — warns about user edits inside markers.
     - Each layer catches a different failure mode: Q43 prevents accidental re-writes; Q46 catches in-marker user edits. Documented in plugin CLAUDE.md (Q55) alongside Q46 batching convention.
   - Within-skill throttle: 1 write per (issue_id, type) per run via Q46's `written_pairs[]` (Q31 amendment 2). Single-write skill — throttle is no-op.

7. **Resume / failure recovery + auto-invocation contract + Q43 → Q51 dependency direction (per refinement 6 clarification).**
   - **Resume:** Q43 doesn't write breadcrumb state — minimal skill (~30-90s wall total); crash recovery is just re-run. Reads existing breadcrumb (if mode=resume) for `domains[N].current_sub_flow` issue ID context but doesn't write back. NO new Q31 amendment needed (unlike Q42's amendment 1 + Q46's amendment 2). Lightweight posture preserved.
   - **Failure recovery:** Phase 1 (preflight) errors → fail-closed with helpful message. Phase 2 (agent dispatch) errors → retry once with 2s backoff (Q13.5 transient pattern); on second fail, abort with `"plan-<discipline>-reviewer agent failed twice; check agent definition or re-run later"`. Phase 3 (formatting) errors → impossible (deterministic transform). Phase 4 (Q46 writeback) errors → Q46 surfaces via its own warning/error semantics; /flow:plan-X surfaces to user.
   - **Auto-invocation contract:** Q43 specifies HOW Q43 behaves when called from any caller (positional arg → resolution → dispatch). **Dependency direction is Q43 → Q51, NOT Q51 → Q43:** Q43 lands first; Q51's eventual lock (when /flow:session-start cloned-and-swapped) cribs the invocation contract from Q43. Q43 doesn't depend on Q51's lock; Q51 will depend on Q43's lock when deciding WHETHER + WHEN to call /flow:plan-X in Step 5 per Q24 mod 2.

**Q24 amendment 1 — Plan-section Q46 markers in 5 discipline-child templates (LOCKED 2026-05-07 per Q43 sub-decision 5).** Q24's 5 discipline-child templates (`docs/templates/issues/{story,engineering,design,qa,docs}.md`) updated to pre-populate empty Q46 markers in the Plan sub-section. Without this amendment, Q46's first-write would append at body end (Q46 sub-decision 2 default) — wrong location for Plan content. Templates include 5 discipline-specific placeholder strings:
- story.md: `_Plan not yet generated. Run \`/flow:plan-story <issue-id>\` to populate._` wrapped by `<!-- FDA-WRITEBACK-plan-story-section-START -->` / `<!-- FDA-WRITEBACK-plan-story-section-END -->`
- engineering.md: same pattern with `plan-eng-section` markers
- design.md: same pattern with `plan-design-section` markers
- qa.md: same pattern with `plan-qa-section` markers
- docs.md: same pattern with `plan-docs-section` markers

Stable substring `Plan not yet generated` used for "is section populated" regex detection — matches all 5 variants. Sets up Q43's double-layer safety (sub-decision 6): caller-side error-if-populated checks for placeholder substring presence.

**Cross-link:** Q24 amendment 1 is required for Q43 sub-decision 5 to function. See Q43 lock entry above for the consumer specification.

**Schema-evolution discipline reinforced:** Q24 amendment 1 follows Q31 amendments 1+2 precedent — explicit amendment-number + audit trail in both originating Q-lock (Q43) and target Q-lock (Q24). Future Q-lock-driven template amendments follow this pattern. **Future v1.1 candidate:** if Q44 retro skill or Q53 ship skill needs new template sections, those amendments would be Q24 amendment 2+, etc.

**Q43 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 6 refinements after Q43 draft. Drafter C's resolution of each:

1. **`current_sub_flow` field in Q31** → PUSHED BACK on orchestrator's claim. Verified Q31.1 (memory:284 directly): `current_sub_flow` IS locked as a per-domain entry field within `domains[]`. Orchestrator missed nested location. Sub-decision 3 fallback (b) stands; path corrected to `domains[N].current_sub_flow`. No Q31 amendment 3 needed.
2. **Q24 title format verification** → CONFIRMED via filesystem read of all 5 templates. Title format `<DOMAIN-NN> [<Discipline>] <Inventory title>` carries discipline prefix; sibling listing's title alone signals discipline. Sub-decision 4's "title-only summaries" framing holds.
3. **Q24 amendment 1 audit trail format** → APPLIED procedural pattern. Q24 amendment 1 entry written above (parallel to Q31 amendment 1+2 pattern); cross-link between Q24 entry + Q43 entry; explicit amendment number; audit trail in both places.
4. **Double-layer safety documentation** → APPLIED. Sub-decision 6 amended with explicit Q43-layer (caller-side error-if-populated) + Q46-layer (executor-side clobber-with-warning) framing. Q55 flagged to enumerate this pattern alongside Q46 batching convention.
5. **5 distinct placeholder strings per template** → APPLIED. Each Q24 template gets discipline-specific placeholder; stable substring `Plan not yet generated` used for regex detection. Sub-decisions 5 + 6 amended.
6. **Q43 → Q51 dependency direction** → APPLIED clarification. Sub-decision 7 explicitly notes Q43 → Q51 (not Q51 → Q43); Q43 lands first; Q51 cribs invocation contract.

**Validation discipline catches by orchestrator on drafter C's work:**
- Surfaced Q24 amendment 1 procedural concern (drafter C didn't apply Q31-amendment-precedent format initially); orchestrator forced explicit audit trail in both Q24 entry + Q43 entry.
- Surfaced 5-distinct-placeholder spec gap (drafter C had generic `<discipline>` token); orchestrator forced per-template substitution.
- Surfaced Q43 → Q51 dependency-direction ambiguity; orchestrator clarified Q43 lands first.

**Validation discipline catches by drafter C on orchestrator's work (preserved for handoff integrity):**
- **Pushed back on refinement 1's claim that `current_sub_flow` isn't in Q31.1 schema** — verified directly at memory:284: field IS locked as a per-domain entry within `domains[]`. Orchestrator missed nested location; honest push-back with citation. Q31 amendment 3 NOT needed.

**Q48 — Four-mode scope-review framework (LOCKED 2026-05-07).** Cross-cutting shared utility at `_shared/four-mode-framework.md` (Q30.2 placeholder; cribbed from gstack `plan-ceo-review` per memory:475). Verified via `gh api repos/garrytan/gstack/contents/plan-ceo-review/SKILL.md` 2026-05-07 — drafter C initially cribbed an imagined verdict-axis taxonomy (APPROVED/ADJUSTED/REWORK/CLARIFY); orchestrator caught the divergence; gh API verification revealed gstack's actual scope-axis taxonomy. Framework establishes the **shared review-outcome contract** that Q21's 7 four-mode reviewer agents implement and Q42/Q43/Q13/consumers parse.

**Critical clarification:** "Four-mode" labels the **OUTCOME taxonomy** (4 discrete scope-intervention recommendations a single agent returns), NOT the L-scoping (which is Q54's WHEN-and-how-many-parallel-agents). Orthogonal axes — L-scope (Q54) determines invocation context + parallel agent count; four modes (Q48) determine WHAT each agent returns.

Seven sub-decisions:

1. **The four modes — scope-axis taxonomy verbatim from gstack source (verified via gh API 2026-05-07).** Each reviewer agent returns exactly one mode per invocation:
   - **`SCOPE_EXPANSION`** — agent recommends expanding the plan/proposal's scope; "dream bigger". Used when current scope feels under-ambitious for the opportunity.
   - **`SELECTIVE_EXPANSION`** — agent recommends holding overall scope but cherry-picking specific expansions. Hybrid: keep core + add specific high-value items.
   - **`HOLD_SCOPE`** — agent recommends keeping scope as-is; focus on execution rigor. Default for sound plans where the question is "execute well" not "rethink scope".
   - **`SCOPE_REDUCTION`** — agent recommends stripping scope to essentials. Used when current scope feels over-ambitious or unfocused.
   
   Modes mutually exclusive — agent picks one based on scope-perspective assessment. Naming uses ALL_CAPS_WITH_UNDERSCORES matching gstack source convention.

2. **L-scope orthogonality (per Q54 meta-Q lock memory:409-417).** Four-mode framework is per-AGENT-invocation:
   - L1 PROJECT (4 perspectives: CEO+Design+Eng+DX) → 4 mode returns; Q42 office-hours composes
   - L2 DOMAIN (2 perspectives: CEO+Design) → 2 mode returns; flow-inventory-interview / flow-add-domain composes
   - L3 SUB-FLOW (5 perspectives: all 5) → 5 mode returns; Q13 flow-linear-scaffold composes
   - L4 DISCIPLINE CHILD (1 perspective: single discipline) → 1 mode return; Q43 /flow:plan-X consumes
   
   Composition rules per consumer per L-scope (NOT framework concern — consumer locks own composition):
   - L1 (Q42 office-hours): 4 mode returns → headlines populate intent.md `## L1 review summary` section per Q41 sub-decision 5; concerns persist to docs/plans/l1-concerns-<ISO-8601>.md per Q42 sub-decision 4
   - L2 (per Q26 mod 2): 2 mode returns → headlines populate journey doc `## L2 review summary` section
   - L3 (per Q23 mod 2): 5 mode returns → headlines populate parent issue body `## L3 review summary` section per Q13 scaffold
   - L4 (Q43): 1 mode return → headline populates discipline-child Plan-section content per Q43 sub-decision 5

3. **Interface signature — closed-enum context per refinement 6 lock; shared spec at `_shared/four-mode-framework.md`.**
   ```typescript
   review_input = {
     subject: string,
     perspective: 'ceo' | 'design' | 'eng' | 'qa' | 'docs' | 'story' | 'devex',
     scope_level: 'L1' | 'L2' | 'L3' | 'L4',
     context: {                                       // closed enum; new fields require Q48 amendment
       q41_template?: string,
       story_doc?: string,
       parent_issue?: string,
       sibling_summaries?: string[],
       linear_brief_snapshot?: string,
       custom_framing?: string
     }
   }
   
   review_output = {
     mode: 'SCOPE_EXPANSION' | 'SELECTIVE_EXPANSION' | 'HOLD_SCOPE' | 'SCOPE_REDUCTION',
     headline: string,                                // soft-warn at <50 words per Q41 discipline; one-paragraph summary
     expansions?: string[],                           // present iff mode ∈ {SCOPE_EXPANSION, SELECTIVE_EXPANSION}
     reductions?: string[],                           // present iff mode == SCOPE_REDUCTION
     rigor_focus?: string[],                          // present iff mode == HOLD_SCOPE
     rationale?: string[],                            // optional; explanation for chosen mode
     adjustments?: string[],                          // REFRAMED per refinement 7 lock — see sub-decision 4
     strategic_concerns?: string[],                   // plan-ceo-reviewer specific (Q21:400)
     ergonomic_concerns?: string[]                    // plan-devex-reviewer specific (Q21:401)
   }
   ```
   
   Closed enum for context fields (Q46 type-registry-pattern parallel); new fields require Q48 amendment with audit trail. Soft-warn on headline <50 words per refinement 5 lock (matches Q41's locked soft-warn discipline at Q41 sub-decision 6).

4. **Mode-specific return field rules + `adjustments[]` reframe (per refinement 7 user lock 2026-05-07).**
   - `SCOPE_EXPANSION`: `mode` + `headline` + `expansions[]` (1-5 specific scope additions to consider)
   - `SELECTIVE_EXPANSION`: `mode` + `headline` + `expansions[]` (cherry-picks; 1-3 entries) + optional `rationale[]` (why hold overall)
   - `HOLD_SCOPE`: `mode` + `headline` + optional `rigor_focus[]` (1-5 execution-rigor concerns for the held scope)
   - `SCOPE_REDUCTION`: `mode` + `headline` + `reductions[]` (1-5 specific scope strippings)
   
   **`adjustments[]` reframe (refinement 7 user lock):** Q21 originally locked `adjustments[]` as plan-X-reviewer return field under implicit verdict-axis assumption ("specific refinements" for the ADJUSTED verdict). Under scope-axis taxonomy, `adjustments[]` semantically reframed as **"tactical execution refinements within whatever scope mode is recommended"** — coexists with mode-specific fields per agent. Coherent across all 4 modes:
   - HOLD_SCOPE + adjustments = "scope right; here are within-scope tactical edits"
   - SCOPE_REDUCTION + adjustments = "strip these features [reductions]; refactor these tactical bits [adjustments]"
   - SCOPE_EXPANSION + adjustments = "expand to add [expansions]; also refine these tactical bits [adjustments]"
   - SELECTIVE_EXPANSION + adjustments = "cherry-pick these [expansions]; refine these tactical bits [adjustments]"
   
   **Backward compat preserved:** Q43 sub-decision 5's existing consumption ("reviewer's adjustments → bullet list under `**Refinements:**` sub-heading") works unchanged under reframed semantic. No Q43 amendment needed.
   
   Perspective-specific fields (`strategic_concerns`, `ergonomic_concerns`) coexist with scope-axis fields per agent — plan-ceo-reviewer in HOLD_SCOPE mode populates `headline` + `rigor_focus` + optionally `strategic_concerns`.

5. **Q21 amendment 1 — add scope-axis fields to 7 four-mode reviewer agents (LOCKED 2026-05-07 per Q48 sub-decision 5; cross-link below).** Q21 (memory:384-401) currently locks reviewer agents returning `{headline, adjustments}` (5 plan-X-reviewers) or `{headline, strategic_concerns}` (plan-ceo-reviewer) or `{headline, ergonomic_concerns}` (plan-devex-reviewer) — under implicit verdict-axis assumption. Q48 amendment 1 adds:
   - **New required field:** `mode: 'SCOPE_EXPANSION' | 'SELECTIVE_EXPANSION' | 'HOLD_SCOPE' | 'SCOPE_REDUCTION'` on all 7 four-mode reviewer agents
   - **New optional fields:** `expansions: string[]`, `reductions: string[]`, `rigor_focus: string[]`, `rationale: string[]`
   - **Existing field reframed:** `adjustments[]` semantic shifts from verdict-axis "ADJUSTED-verdict refinements" to scope-axis "tactical execution refinements within scope mode" (per refinement 7 user lock)
   - **Existing fields preserved:** `headline`, `strategic_concerns` (CEO), `ergonomic_concerns` (DevEx) per Q21 lock
   - Each agent's prompt updated to include scope-axis classification guidance: "Pick exactly one mode based on scope-perspective assessment. SCOPE_EXPANSION = current scope under-ambitious; SELECTIVE_EXPANSION = hold core + cherry-pick high-value additions; HOLD_SCOPE = scope right, focus on execution rigor; SCOPE_REDUCTION = strip to essentials."
   - **Excluded from amendment (3 of 12):** fidelity-reviewer (Q21:394 — uses distinct `{result: PASS|FAIL, findings, cosmetic_ignored}` shape; NOT a scope-review agent), inventory-author + codebase-inferrer + story-doc-author + journey-doc-author (Q21:391-394 — author/inferrer agents with distinct return shapes; not four-mode reviewers). **Amendment scope: 7 of 12 agents.**
   - **Schema-evolution discipline reinforced:** Q21 amendment 1 follows Q31 amendments 1+2 + Q24 amendment 1 precedent — explicit amendment-number + audit trail in both originating Q-lock (Q48) and target Q-lock (Q21).

6. **Cribbing scope from gstack plan-ceo-review — partial transfer (verbatim phrases verified via gh API 2026-05-07).**
   - **Transfer cleanly:**
     - 4-mode scope-axis taxonomy (SCOPE_EXPANSION/SELECTIVE_EXPANSION/HOLD_SCOPE/SCOPE_REDUCTION) — verbatim names
     - **Founder-mode framing (verbatim from gstack source):** "CEO/founder-mode plan review. Rethink the problem, find the 10-star product, challenge premises, expand scope when it creates a better product."
     - Mode-specific field shape (expansions for expansion modes, reductions for reduction, rigor_focus for hold)
   - **Adapt for FDA:**
     - L-scoping integration: gstack's plan-ceo-review is single-perspective; FDA composes 1-5 perspectives at L1-L4 → consumer locks (Q42, Q13, Q43, Q47) own composition
     - Q46 writeback compatibility: FDA-specific output destinations (Linear issue bodies, journey docs, intent.md sections) routed through Q46 layer per consumer locks
     - Per-perspective specialization: gstack has plan-ceo-review / plan-design-review / plan-devex-review as separate skills; FDA bundles all 7 perspectives into Q21 named agents that share the four-mode contract
     - Plugin packaging: Q48 lives at `plugins/flow-architecture/skills/_shared/four-mode-framework.md` per Q30.2 (NOT top-level dir like gstack)

7. **Composition rules (revised from original verdict-axis draft) + framework primitive vs wrapper.**
   - **Framework is a SHARED CONTRACT (spec), NOT executable code or wrapper.** Q21 reviewer agents IMPLEMENT the contract (each agent prompt includes mode-classification guidance + return shape per sub-decisions 3+4). Consumer skills (Q42, Q43, Q13, Q47) PARSE the contract (each consumer extracts `mode` + relevant fields from agent return).
   - **Q21 agents and Q43 dispatcher relationship:** Q21 agents = framework implementers (return four-mode shape); Q43 dispatcher = framework consumer (parses mode, formats into Plan-section content per Q43 sub-decision 5); neither wraps the other; both reference the shared spec at `_shared/four-mode-framework.md`.
   - **Per-consumer composition rules (out of Q48 scope; documented in consumer locks):** Q42 L1 4-parallel; Q47/inventory-interview L2 2-parallel; Q13 L3 5-parallel; Q43 L4 1-single.
   - **Cross-consumer convention (revised under scope-axis):** **all 4 modes are valid scope recommendations**; **no hard-fail composition rule**. Genuine disagreement (e.g., L1 = CEO:SCOPE_EXPANSION + DevEx:SCOPE_REDUCTION) is "team disagreement worth surfacing" — consumer renders both in summary; user resolves at next gate. **No CLARIFY semantics** — agents form scope opinion even with limited info; questions can be embedded in `rationale[]` field but don't pause composition. This dissolves refinement 2's original verdict-axis composition concerns (REWORK hard-fail / CLARIFY blocking).

**Q21 amendment 1 — scope-axis fields on 7 four-mode reviewer agents (LOCKED 2026-05-07 per Q48 sub-decision 5).** Adds `mode` (required) + `expansions[]` / `reductions[]` / `rigor_focus[]` / `rationale[]` (mode-specific) to 7 of Q21's 12 agents:
- plan-story-reviewer, plan-eng-reviewer, plan-design-reviewer, plan-qa-reviewer, plan-docs-reviewer (the 5 plan-X-reviewers per Q21:395-399)
- plan-ceo-reviewer (Q21:400)
- plan-devex-reviewer (Q21:401)

**Existing `adjustments[]` field reframed** (per refinement 7 user lock): semantic shifts from verdict-axis "ADJUSTED-verdict refinements" to scope-axis "tactical execution refinements within scope mode." Q43 sub-decision 5's consumption unchanged. **Existing perspective-specific fields preserved** per Q21 lock: `strategic_concerns` (CEO), `ergonomic_concerns` (DevEx).

**Excluded from amendment (5 of 12 agents):** inventory-author (Q21:391), codebase-inferrer (Q21:392), story-doc-author (Q21:393), journey-doc-author (Q21:394), fidelity-reviewer (Q21:394 — distinct `{result, findings, cosmetic_ignored}` return shape; NOT scope-review).

**Cross-link:** see Q48 lock entry sub-decision 5 for the consumer rationale + scope-axis taxonomy reference.

**Schema-evolution discipline reinforced:** Q21 amendment 1 follows Q31 amendments 1+2 + Q24 amendment 1 precedent — explicit amendment-number + audit trail in both originating Q-lock (Q48) and target Q-lock (Q21). Future Q-lock-driven Q21 amendments would be Q21 amendment 2+.

**Q48 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 8 refinements (6 in first pass + 2 in second pass after refinement 1 catch). Drafter C's resolution of each:

1. **gstack mode names verification** → CRITICAL CATCH BY ORCHESTRATOR. Drafter C initially cribbed imagined verdict-axis taxonomy (APPROVED/ADJUSTED/REWORK/CLARIFY); orchestrator forced gh API verification; gstack actual taxonomy revealed scope-axis (SCOPE_EXPANSION/SELECTIVE_EXPANSION/HOLD_SCOPE/SCOPE_REDUCTION). Q48 fully redrafted with gstack-faithful taxonomy. Validation-first cycle saved a fundamentally wrong lock.
2. **Composition rules architectural escalation** → MOOTED under scope-axis taxonomy. Original verdict-axis options (REWORK hard-fail / CLARIFY block) didn't apply to scope-axis taxonomy. New composition under scope-axis: all 4 modes valid; team disagreement surfaces, doesn't block. No user escalation needed.
3. **Q21 amendment scope (agent count)** → PUSHED BACK on orchestrator's count. Verified Q21 (memory:384, 410, 265): 12 agents not 10. Orchestrator acknowledged stale recall; original "7 of 12" framing correct.
4. **Perspective enum completeness** → CONFIRMED via Q21:395-401. All 7 enum values match agent names.
5. **Headline word floor** → APPLIED soft-warn at <50 words; matches Q41's locked soft-warn discipline at Q41 sub-decision 6.
6. **Context object extension model** → APPLIED closed enum; matches Q46 type-registry pattern; new fields require Q48 amendment.
7. **adjustments[] semantic homelessness** → ESCALATED to user via `AskUserQuestion`; user answered "Reframe (Recommended)" — preserve field with new semantic ("tactical execution refinements within scope mode"); Q43 backward-compat preserved.
8. **Founder-mode framing verification** → CONFIRMED via earlier gh API read. All four phrases verbatim from gstack source: "founder-mode" / "rethink the problem" / "find the 10-star product" / "challenge premises". Sub-decision 6 framing locked verbatim.

**Validation discipline catches (preserved for handoff integrity):**

*By orchestrator on drafter C's work:*
- **CRITICAL — gstack mode-name divergence** — drafter C cribbed imagined verdict-axis taxonomy (APPROVED/ADJUSTED/REWORK/CLARIFY) thinking it was gstack-faithful; orchestrator forced gh API verification; gstack actual taxonomy is scope-axis (SCOPE_EXPANSION/SELECTIVE_EXPANSION/HOLD_SCOPE/SCOPE_REDUCTION). Without orchestrator's catch, Q48 would have shipped fundamentally wrong. Methodology lesson: drafter recall of cribbed source material is unreliable; always verify via gh API or repo read BEFORE drafting (see parking lot #39).
- Surfaced `adjustments[]` semantic homelessness under taxonomy redo (refinement 7); user-locked reframe.
- Surfaced `founder-mode` framing verification (refinement 8); confirmed verbatim.

*By drafter C on orchestrator's work:*
- Pushed back on refinement 3's count claim ("10 agents") with Q21 lock citation (12 agents); orchestrator acknowledged stale recall.
- Demonstrated mutual error-correction value of validation-first cycle: orchestrator caught critical taxonomy error; drafter C caught count error; both improved final lock.

**Q44 — `/flow:retro` skill design (LOCKED 2026-05-07).** Per-domain retrospective skill. Output: `docs/retros/<domain>-<YYYY-MM-DD>.md` (canonical filesystem artifact per memory:493) + Linear comment via Q46 `retro-summary` type (already in Q46 v1 enum). gstack `retro/SKILL.md` source verified via gh API 2026-05-07 per parking lot #39 — partial inspirational transfer only; gstack's time-windowed/commit-based engineering-retro shape doesn't fit FDA's scope-bounded per-domain pattern. Seven sub-decisions:

1. **Invocation contract — `/flow:retro [<DOMAIN>]`.**
   - Positional `<DOMAIN>` (e.g., `TEAM`) — optional; falls through to "most-recently-completed domain" detection (Linear: milestone with newest `state.type=completed` transition) → `AskUserQuestion` fallback if ambiguous (multiple domains closed back-to-back)
   - User-invocable; **manual-only trigger per sub-decision 2 user lock**; no auto-invocation hooks in v1
   - Plugin-shipped command per Q30.2 lock (Reflect category, 1 command)

2. **Trigger semantics — manual only in v1 (per user lock 2026-05-07).** User explicitly runs `/flow:retro [<DOMAIN>]` when ready. No auto-invocation from Q53 `/flow:ship` in v1 — preserves user control over timing + avoids Q53 coupling. **v1.1 candidates parked (parking lot #40):** auto-from-ship hook when /flow:ship detects "last sub-flow in domain shipping"; opt-in `--auto-on-ship` flag in `.flow/config.json` for per-project preference.

3. **Scope — single-domain only in v1 (per user lock 2026-05-07).** v1 retros are per-domain milestone close — matches memory:493 permanent artifact path `docs/retros/<domain>-<YYYY-MM-DD>.md` + Linear milestone-as-unit semantics. **v1.1 candidate parked (parking lot #41):** `--cross-domain [<window>]` flag for time-windowed comparison across multiple completed milestones (e.g., `/flow:retro --cross-domain 30d` adds gstack-style trends-vs-prior comparison).

4. **Output target — Q46 `retro-summary` as COMMENT surface; filesystem markdown is canonical.**
   - **Filesystem (canonical):** `docs/retros/<domain>-<YYYY-MM-DD>.md` per memory:493 lock — full retro content (~500-1500 words depending on domain size).
   - **Linear (team summary):** single Q46 `linear_writeback({type: 'retro-summary', surface: 'comment'})` call on the closed milestone. Comment includes signature line per Q46 sub-decision 3 + brief executive summary (~150-300 words) + link back to filesystem markdown.
   - **NOT body surface** — Q22 milestone description structure (Sub-flows table, Personas, Journey link) doesn't reserve a retro slot; adding retro to body would clutter Q22 + conflict with Q22's regen pattern. Comment is lighter + retro-appropriate.
   - **v1.1 candidate parked (parking lot #42):** Q22 amendment 1 to add retro-summary body marker section if Brand Hub dogfood reveals body-surface preference for Linear-side retro visibility.

5. **Participants — AI-only synthesis from artifacts; user reviews + edits before commit.**
   - Q44 is AI-driven synthesis (NOT team retro facilitation). Inputs: story docs at `docs/product/flows/<domain>/*.md`; parent issues + discipline children via Linear; plan-X-section content from discipline-child bodies (Q43 / Q24 amendment 1 markers); journey doc at `docs/product/journeys/<domain>.md`; QA history rows from story doc front-matter; Q46 ship-summary content from prior /flow:ship runs (when Q53 locks).
   - Agent generates draft retro markdown → user reviews via final-review `AskUserQuestion` (Q19 Phase 5 + Q20.6 + Q42 sub-decision 3 final-review pattern) → user Approves / Edits inline / Cancels.
   - Optional user-input prompt post-synthesis: "Anything to add that the agent might not have caught from artifacts?" — captures human qualitative observations not in Linear/filesystem.
   - **v1.1 candidate parked (parking lot #44):** team retro facilitation features (multi-participant input collection, voting, synthesis from multi-perspective notes) if dogfood reveals AI-only synthesis is insufficient for team-driven retros.

6. **Format convention — partial gstack inspirational transfer per parking lot #39 honest cribbing assessment.** gstack retro source verified via `gh api repos/garrytan/gstack/contents/retro/SKILL.md` 2026-05-07 (1701 lines).
   
   **Verbatim section headers cribbed from gstack** (cited at gstack `retro/SKILL.md` Step 14 narrative output):
   - `## Summary` (analog of gstack's "Summary Table"; FDA's table = sub-flow IDs + status + duration)
   - `## Trends vs Prior Retros` (analog of gstack's "Trends vs Last Retro"; v1 single-domain → first-retro skips section; v1.1 cross-domain expansion via parking lot #41)
   - `## Focus & Highlights` (verbatim gstack header; FDA's = best sub-flow shipping moment + top discipline-cross-pollination)
   - `## What worked` (verbatim from gstack "what they shipped" + "what you did well")
   - `## Where to level up` (verbatim from gstack "where to level up")
   
   **FDA-specific sections (NOT in gstack):**
   - `## Per-discipline highlights` — sub-sections for Story / Eng / Design / QA / Docs successes + gaps from sub-flow shipping
   - `## Cross-references` — links to milestone (Linear URL) + journey doc + sub-flow story docs + discipline-child issues
   - `## Open questions` — surface unresolved items for next-domain consideration
   
   **NOT transferred from gstack** (time-windowed/commit-based/personal — don't fit per-domain scope):
   - Tweetable summary (commit-based + per-week)
   - Time & Session Patterns (time-windowed git activity)
   - Shipping Velocity (commit-volume metrics)
   - Code Quality Signals + Test Health (gstack-git-metric-based)
   - Plan Completion mining `/ship` JSONL logs (gstack-specific; FDA equivalent = consume Q46 `written_pairs[]` from prior runs — **v1.1 candidate parking lot #43**)
   - Your Week / Team Breakdown (personal/per-contributor — FDA scope is process-focused)
   
   **Honest cribbing assessment (per parking lot #39):** gstack retro is **LOOSELY INSPIRATIONAL** for FDA, not directly cribbable. Time-windowed engineering-retro shape doesn't map onto scope-bounded milestone-retro shape. Transfer is structural section names only (5 verbatim headers) + general framing. Most metrics + args don't transfer.

7. **Q46 integration — single `linear_writeback` call per /flow:retro invocation.**
   ```
   linear_writeback({
     issue_id: <milestone_id>,
     type: 'retro-summary',
     surface: 'comment',
     content: <executive-summary + link to docs/retros/<domain>-<YYYY-MM-DD>.md>,
     signature: '_Generated by /flow:retro for <DOMAIN> milestone on <ISO-8601>_',
     breadcrumb_path: <breadcrumb_path>,
     warn_on_clobber: true
   })
   ```
   - Q46 `retro-summary` type already registered in v1 enum (Q46 sub-decision 2) — no Q46 amendment needed
   - Signature line + claim-and-update idempotency per Q46 sub-decision 3 — re-running /flow:retro updates existing comment rather than creating new one
   - Comment content: brief (~150-300 words) executive summary + link to filesystem markdown for full content
   - Within-skill throttle: 1 write per (issue_id, type) per run via Q46's `written_pairs[]` (Q31 amendment 2). Single-write skill — throttle is no-op.
   - Per-consumer batching (Q46 sub-decision 5): N/A — Q44 is single-write skill.
   - Conflict resolution: Q46 clobber-with-warning fires per Q46 sub-decision 4 if user hand-edited inside markers.

**Q44 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 2 architectural escalations (trigger + scope) + parking-lot-#39-discipline application requirement. Drafter C's resolution:

1. **Pre-draft gstack source verification (parking lot #39 application)** → APPLIED. gh API read of `repos/garrytan/gstack/contents/retro/SKILL.md` BEFORE drafting any sub-decisions. Captured verbatim section headers + acknowledged gstack retro's time-windowed/commit-based shape doesn't transfer to FDA's per-domain scope-bounded shape. Honest cribbing assessment baked into sub-decision 6: 5 verbatim section header transfers + 7 NOT-transferred features explicitly enumerated.
2. **Trigger semantics (sub-decision 2)** → ESCALATED to user via `AskUserQuestion`; user answered "Manual only in v1 (Recommended)" — preserves user control + avoids Q53 coupling; v1.1 auto-from-ship parked.
3. **Scope (sub-decision 3)** → ESCALATED to user via `AskUserQuestion`; user answered "Single-domain only in v1 (Recommended)" — matches Q44 task description + Linear milestone-as-unit semantics; v1.1 cross-domain parked.
4. Output target (sub-decision 4) → APPLIED comment-surface only with strong rationale (Q22 body conflict avoidance); v1.1 body-marker parking lot.
5. Participants (sub-decision 5) → APPLIED AI-only synthesis with final-review pattern; v1.1 team retro facilitation parking lot.
6. Format convention (sub-decision 6) → APPLIED partial transfer per parking lot #39; verbatim 5 section headers cribbed; explicit NOT-transferred enumeration.
7. Q46 integration (sub-decision 7) → APPLIED single linear_writeback call; comment surface; retro-summary type already registered.

**Validation discipline catches (preserved for handoff integrity):**

*Parking lot #39 first post-Q48 application (Q44 was the test case):*
- gh API verification BEFORE drafting prevented Q48-style fabricated-cribbing error. Drafter C captured gstack retro's actual shape (time-windowed/commit-based/engineering-focused) and HONESTLY assessed transfer scope as "loosely inspirational" rather than claiming direct cribbing fidelity. 5 verbatim section headers cribbed; 7 NOT-transferred features enumerated. Methodology working as designed per parking lot #39 lock.

**Q50 — Clone-and-swap scope from workflows plugin (LOCKED 2026-05-07).** Foundation lock for Q51/Q52/Q53 cloned commands. Workflows plugin v3.29.4 source verified via gh API 2026-05-07 per parking lot #39 with extra rigor (3 downstream cloned-skill locks depend on this scope). Reconciles memory:26 sketch with Q30.2 locked FDA surface enumeration. Seven sub-decisions:

1. **Source verification — workflows plugin v3.29.4 structure enumerated via gh API 2026-05-07** (per parking lot #39).
   - **Manifest** (`.claude-plugin/plugin.json`): name=workflows, version=3.29.4, commands=`./commands/`, skills=`./skills/`
   - **MCPs** (`.mcp.json`): 3 MCPs registered — `sequential-thinking` (npx stdio), `linear-server` (https mcp.linear.app/mcp), `context7` (https mcp.context7.com/mcp). FDA depends transitively per Q30.4 + Q32 locks.
   - **24 commands:** analytics, architecture-decision, audit-trail, bug-report, code-review, create-plugin, deployment-checklist, fact-check, flywheel-metrics, onboarding-checklist, project-start, promote-precedent, report-issue, retrospective, review, scope, security-audit, session-start, setup-claude-md, ship, smoke-test, sprint-planning, tech-stack
   - **24 skills:** _shared, agent-browser, best-practices-audit, brainstorming, code-quality, compound-learnings, create-issues, executing-plans, find-skills, frontend-design, git-worktrees, handbook-drift-check, post-plan-setup, precedent-search, python-best-practices, react-best-practices, refine-plan, setup-claude-md, systematic-debugging, testing-strategy, ui-ux-pro-max, verification-before-completion, web-design-guidelines, writing-plans
   - **_shared utilities:** skills/_shared/ (5 files: anti-slop-guardrails, observability, output-formats, trigger-registry.json, validation-pattern); commands/_shared/ (2 files: company-context-template, trait-doc-templates)
   - **15 agents:** accessibility-reviewer, architecture-reviewer, cdr-compliance-reviewer, claude-md-generator, code-reviewer, data-reviewer, diff-triage, issue-creator, performance-reviewer, plan-refiner, post-plan-orchestrator, python-reviewer, security-reviewer, test-quality-reviewer, typescript-reviewer
   - **Hooks:** hooks.json

2. **Three-way classification — CLONE / REUSE / OUT-OF-SCOPE.**
   
   **CLONE (FDA-swapped variants in flow-architecture plugin) — 3 commands:**
   - `commands/session-start.md` → FDA's `/flow:session-start` per Q51 (pending) — FDA-swap dispatches L4 plan-X-reviewers per Q24 mod 2 + Q43 dispatcher
   - `commands/review.md` → FDA's `/flow:review` per Q52 (pending) — FDA-swap surfaces Q29 quality-gate stack + Q46 writeback
   - `commands/ship.md` → FDA's `/flow:ship` per Q53 (pending) — FDA-swap uses Q46 ship-summary type, Q44 retro coordination, Q43 plan completion checks
   
   **REUSE (transparent passthrough; FDA depends on workflows being installed) — 6 items per user lock 2026-05-07:**
   - `skills/git-worktrees/` (memory:26 stale reference "worktree" corrected to actual name)
   - `skills/executing-plans/`
   - `skills/verification-before-completion/`
   - `commands/code-review.md` (memory:26 didn't specify command vs skill; clarified as command)
   - `skills/brainstorming/` (per sub-decision 3 user lock — memory:26's "clone brainstorming" superseded)
   - `skills/writing-plans/` (per sub-decision 3 user lock — memory:26's "clone writing-plans" superseded)
   
   **OUT-OF-SCOPE (NOT consumed by FDA core skills) — 17 commands + 16 skills + 15 agents:** all workflows artifacts not on clone/reuse lists. FDA users may invoke independently (e.g., `/workflows:bug-report`, `/workflows:security-audit`); FDA-cloned skills don't dispatch them. v1 stance: FDA stays focused; broader workflows surface accessible to users via direct invocation but not woven into FDA orchestrators.

3. **`brainstorming` + `writing-plans` REUSE both (per user lock 2026-05-07).** Memory:26's early sketch said clone both; Q30.2's locked FDA surface enumeration (10 sub-skills) excluded them; user lock confirmed Q30.2 is authoritative. Reasoning per user lock:
   - "Q30.2's locked FDA surface is the load-bearing argument — it already excluded flow-brainstorming + flow-writing-plans from the 10-sub-skill enumeration; sub-decision 3 confirms that lock explicitly rather than introducing new scope."
   - "Q43's actual mechanics (sub-decision 4 dispatches plan-X-reviewer agents directly; sub-decision 5 formats from {mode, headline, expansions/reductions/rigor_focus/adjustments}) means writing-plans is NOT on the path producing FDA plan-X-section content. The 'format-specific' argument for cloning writing-plans doesn't survive Q43's locked design."
   - FDA-cloned session-start (Q51) prepares FDA-specific context (intent.md / story doc / parent issue / sibling discipline children) BEFORE invoking workflows skills via Skill tool. Less duplication; clearer separation; smaller FDA surface.
   - **v1.1 candidates parked:** flow-brainstorming clone (parking lot #46) if dogfood reveals FDA-context miscalibration; flow-writing-plans clone (parking lot #47) if dogfood reveals format-specificity gap.

4. **Plugin dependency mechanism — FDA depends on workflows via 3 channels.**
   - **MCP routing (transitive):** FDA's `.mcp.json` is empty `{}` per Q30.4; depends on workflows for `mcp__plugin_workflows_linear-server__*` tool routing. Cross-ref BC-5810 § 4 + BC-5811 § 4.2 — duplicate MCP registration breaks tool routing.
   - **Skill invocation (Skill tool):** FDA-cloned commands invoke workflows skills via `Skill: workflows:<skill-name>` (e.g., `Skill: workflows:git-worktrees` from FDA session-start). Workflows must be installed; FDA cannot polyfill.
   - **Command invocation (slash):** FDA-cloned commands may invoke workflows commands as nested calls (e.g., FDA `/flow:ship` invoking `/workflows:code-review`).
   - **No plugin-manifest dependency declaration:** Q30.3 lock did NOT include explicit `dependencies:` field (Claude Code plugin schema doesn't have one). Documented dependency lives in CLAUDE.md (Q55) per Q30.5 + Q32 locks. Runtime failure if workflows isn't installed — flow-preflight env-check (Q12) is the safety net.

5. **FDA-swap semantics for cloned commands — what changes from workflows source.** Cloned commands are NEW files in flow-architecture (e.g., `plugins/flow-architecture/commands/session-start.md`) — NOT modifications to workflows source. Clone preserves verbatim structure where possible; swaps the following:
   - **Linear field references:** workflows uses generic Linear (any project + any issue); FDA-clones reference FDA-shaped milestones (Q22), parent issues (Q23), discipline children (Q24)
   - **Plan output format:** FDA-clones use FDA's plan-X-section format (Q43 + Q24 amendment 1 markers via Q46 writeback)
   - **Narrative-doc references:** FDA-clones additionally read intent.md (Q41), story doc (Q27), journey doc (Q26), parent issue body
   - **Q46 writeback routing:** workflows writes Linear updates directly via MCP; FDA-clones route through Q46's `linear_writeback({type, surface, content})` per Q46 sub-decision 7
   - **Quality-gate references:** workflows references its own checks; FDA-clones reference Q29's 35-gate stack via `/flow:audit` (Q38)
   - **Step numbering preserved (corrected per Q50 amendment 1 — see below):** workflows session-start has **9 steps (Step 0 through Step 8)** verified gh API 2026-05-07 + re-verified during Q51 drafting; FDA clone preserves 9-step structure with **Step 6 (Write Plan) augmented to dispatch L4 plan-X-reviewer per Q24 mod 2 + Q43 alongside workflows writing-plans skill (REUSED per Q50 sub-decision 3); Step 5 (Brainstorm) preserved verbatim per Q50 sub-decision 3 REUSE lock**
   - **Telemetry block:** workflows has telemetry-log.sh hook; FDA-clones MAY preserve identical block (no-op if FDA-specific telemetry not configured) or strip — strip stance per Q30 plugin-meta lock (no telemetry config in v1)

6. **"NO modifications to workflows in v1" — confirmed lock + upstream-update tracking.** Per memory:26 + Q3 + Q4:
   - FDA never edits files in `plugins/workflows/`
   - FDA never proposes PRs to workflows for FDA-specific needs in v1
   - **Upstream-update drift:** workflows is at v3.29.4 today (gh API verified 2026-05-07); future workflows updates may change cloned-source content. FDA-cloned skills DRIFT from upstream over time. v1 stance: accept drift; FDA-cloned content is its own artifact post-clone.
   - **Drift-detection for cloned commands (v1.1 candidate per parking lot #45):** periodic gh API check of workflows commands' content hashes vs FDA-clone's source-comment-recorded hash; surface drift warnings. Not v1 because cloned content stability is a known acceptable cost.
   - Q4's v2 stance ("FDA → /workflows:project-start handoff") may revisit this; v1 stays independent.

7. **Three-way cribbing taxonomy — FDA-native vs gstack-inspired vs workflows-cloned.** Q44 lock acknowledged 3 distinct cribbing patterns; Q50 makes the trichotomy explicit and locks for future Q-locks:
   - **FDA-native (the majority):** Q37 / Q38 / Q47 / Q43 (and many sub-skills Q11-Q20) — designed from scratch for FDA semantics; no external source crib
   - **gstack-inspired (loose transfer):** Q42 office-hours (cribs gstack `office-hours` skill but adapts heavily); Q44 retro (cribs gstack `retro` 5 verbatim section headers but adapts time-windowed → scope-bounded); Q48 four-mode framework (cribs gstack `plan-ceo-review` taxonomy verbatim — verified post-Q48-near-miss). Source = `repos/garrytan/gstack`; cribbing scope = "structural inspiration, not directly cribbable"
   - **workflows-cloned (full crib with FDA-swap):** Q51 / Q52 / Q53 — cribs workflows command files verbatim; FDA-swap per sub-decision 5. Source = `repos/Brite-Nites/brite-claude-plugins/plugins/workflows/`; cribbing scope = "full structure preserved, specific fields swapped"
   - **Cribbing discipline (parking lot #39 applies to ALL cribbed Qs):** verify source via gh API BEFORE drafting; honest assessment of transfer scope; explicit enumeration of what transfers vs adapts. Q44 lock entry first applied this discipline successfully; Q48 near-miss precedent showed why it's necessary; Q50 + Q51/Q52/Q53 continue applying.

**Q50 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 1 architectural escalation (sub-decision 3) + parking-lot-#39-extra-rigor application requirement. Drafter C's resolution:

1. **Pre-draft workflows source verification (parking lot #39 application with EXTRA rigor — Q50 is foundation for 3 cloned-skill locks)** → APPLIED. gh API reads of workflows plugin v3.29.4 contents BEFORE drafting any sub-decisions. Captured verbatim 24 commands + 24 skills + 15 agents + manifest + MCPs + step structure of session-start/review/ship. Memory:26 stale references corrected: "worktree" → "git-worktrees"; "code-review" clarified as command. Q30.2 surface authority verified against actual workflows contents.
2. **`brainstorming` + `writing-plans` clone vs reuse (sub-decision 3)** → ESCALATED to user via `AskUserQuestion`; user answered "REUSE both (Recommended)" — Q30.2 surface authority load-bearing; Q43's locked mechanics show writing-plans NOT on plan-X-section path; FDA-cloned session-start prepares context before invoking workflows skills.
3. Sub-decisions 1, 2, 4, 5, 6, 7 → APPLIED with strong rationale; verbatim source citations in sub-decision 1; three-way cribbing taxonomy locked in sub-decision 7; "no modifications to workflows in v1" confirmed in sub-decision 6.

**Validation discipline catches (preserved for handoff integrity):**

*Parking lot #39 second application (Q50 — extra-rigor since foundation for 3 downstream locks):*
- gh API verification of workflows plugin v3.29.4 BEFORE drafting prevented memory:26-stale-reference propagation into Q51/Q52/Q53 locks. Drafter C surfaced 2 stale references in memory:26 ("worktree" → "git-worktrees"; "code-review skill" → command); user-locked corrections via supersedure note. Three-way cribbing taxonomy locked for future cribbed Qs.
- Q30.2 surface authority validated against workflows actual contents — confirmed Q30.2 supersedes memory:26's earlier brainstorming/writing-plans clone sketch.

**Q50 amendment 1 — sub-decision 5 step count + step-swap-location corrections (LOCKED 2026-05-07 per Q51 sub-decision 7 user lock).**

**Original Q50 sub-decision 5 text (incorrect; preserved here for audit trail):**
> "Step numbering preserved: workflows session-start has 8 steps (verified gh API 2026-05-07); FDA clone preserves 8-step structure with Step 5 swapped to dispatch L4 plan-X-reviewer per Q24 mod 2 + Q43"

**Two errors caught during Q51 drafting via gh API re-grep:**
1. **Step count error:** "8 steps" — INCORRECT. Workflows session-start has 9 steps (Step 0 through Step 8) confirmed via `grep '^## Step [0-9]+:' /tmp/wf-session-start.md` 2026-05-07.
2. **Step-swap-location error:** "Step 5 swapped to dispatch L4 plan-X-reviewer" — INCORRECT. Step 5 in workflows is "Brainstorm (Objective Complexity Check)" — invokes `brainstorming` skill conditionally per workflows source. Per Q50 sub-decision 3 user lock, brainstorming is REUSED (NOT cloned/swapped). Step 6 in workflows is "Write Plan" — that's where workflows invokes `writing-plans` skill. Q24 mod 2's locked text (memory:436) says only "/flow:session-start → /flow:plan-<discipline> dispatch at L4" — does NOT pin a specific step. Natural FDA-swap site is **Step 6 (Write Plan)** because that's where workflows produces plan content; FDA augments with /flow:plan-X discipline-specific dispatch alongside writing-plans output.

**Corrected sub-decision 5 text** (in-place edit applied to Q50 sub-decision 5):
> "Step numbering preserved (corrected per Q50 amendment 1 — see below): workflows session-start has **9 steps (Step 0 through Step 8)** verified gh API 2026-05-07 + re-verified during Q51 drafting; FDA clone preserves 9-step structure with **Step 6 (Write Plan) augmented to dispatch L4 plan-X-reviewer per Q24 mod 2 + Q43 alongside workflows writing-plans skill (REUSED per Q50 sub-decision 3); Step 5 (Brainstorm) preserved verbatim per Q50 sub-decision 3 REUSE lock**"

**Cross-link:** see Q51 lock entry sub-decision 7 for the validation-discipline catch + correction rationale.

**Schema-evolution discipline reinforced:** Q50 amendment 1 follows Q31 amendments 1+2 + Q24 amendment 1 + Q21 amendment 1 precedent — explicit amendment-number + audit trail in originating Q-lock (Q51) and target Q-lock (Q50). Sets precedent that drafter-C-self-catches via downstream re-verification get formal amendment treatment (NOT inline-correction-without-amendment), per user lock 2026-05-07.

**Methodology lesson (extends parking lot #39):** Re-verification at downstream draft catches upstream errors. Q51 caught Q50 sub-decision 5's step-count + step-swap-location errors via gh API re-grep. Apply parking-lot-#39 discipline AT EACH cribbed-content lock, not just first cribbing. Prior locks can be wrong; downstream re-verification catches drift between lock-time understanding and verified source truth.

**Q51 — `/flow:session-start` (cloned + FDA-swapped) (LOCKED 2026-05-07).** Cloned from workflows v3.29.4 commands/session-start.md; applies Q50 sub-decision 5's 7-axis FDA-swap framework. Workflows source verified via gh API during Q50 + re-verified during Q51 drafting (drafter-C-self-catch caught Q50 sub-decision 5 errors — see Q50 amendment 1 above). Seven sub-decisions:

1. **Source baseline + drift-recording header.** Cloned from `repos/Brite-Nites/brite-claude-plugins/plugins/workflows/commands/session-start.md` at workflows v3.29.4. FDA-clone HTML-comment header records source SHA + version per Q50 sub-decision 6 drift-acceptance posture + parking lot #45 v1.1 drift-detection prerequisite:
   ```markdown
   <!-- Cloned from workflows v3.29.4 (commands/session-start.md) on 2026-05-07. Drift-detection per parking lot #45. -->
   ```

   **Amendment 1 — `Upstream-SHA:` backfill (BC-7060, 2026-05-12).** Header text augmented with `Upstream-SHA: <40-hex-blob>.` between the clone date and the parking-lot reference, operationalizing Q40 sub-decision 7's "SHAs captured in HTML-comment headers" requirement (line ~1864) and parking lot #45's drift-detection contract. SHA reflects the upstream blob at the latest commit ≤ 2026-05-08. Live form (per schema-discipline amendment pattern, plugin CLAUDE.md § Methodology notes item 4):
   ```markdown
   <!-- Cloned from workflows v3.29.4 (commands/session-start.md) on 2026-05-07. Upstream-SHA: 607c18cd3e126b588aacf7ec0ade5e2927481259. Drift-detection per parking lot #45. -->
   ```

2. **9-step structure preservation (NOT 8 — Q50 amendment 1 corrects).** Workflows session-start has Step 0 through Step 8 = 9 steps total. FDA-clone preserves all 9 step numbers + verbatim step titles where possible. Per-step FDA-swap mapping in sub-decision 3.

3. **Per-step FDA-swap classification** (per Q50 sub-decision 5's 7-axis framework):

   | Step | Workflows title | FDA classification | FDA-swap details |
   |---|---|---|---|
   | 0 | Verify Prerequisites | **Preserved + augment** | Workflows checks Linear+sequential-thinking+Context7. FDA augments: also runs `flow-preflight` (Q12) for `.flow/config.json` + FDA-artifact discovery + mode classification |
   | 1 | Environment Setup | **Preserved + augment** | Workflows reads CLAUDE.md+auto-memory. FDA augments: additionally reads `intent.md` (Q41) if exists + checks for `.flow-phase-state.json` breadcrumb (Q31 path) |
   | 2 | Company Context | **Preserved verbatim** | Reuses workflows commands/_shared/company-context-template.md transparently |
   | 3 | Query Linear for Open Issues | **FDA-swap (Linear field references)** | Workflows lists generic Linear issues. FDA-swap filters by FDA labels: `type:story\|eng\|design\|qa\|docs` + `domain:<slug>` per Q24 mod 3; presents only FDA discipline-child issues |
   | 4 | Read Issue Details | **FDA-swap (Narrative-doc references)** | Workflows reads issue body. FDA-swap additionally reads: parent issue body (with `## L3 review summary` per Q23 mod 2); story doc at `docs/product/flows/<domain>/<flow-id>.md` (Q27); journey doc at `docs/product/journeys/<domain>.md` (Q26) |
   | 5 | Brainstorm (Objective Complexity Check) | **Preserved verbatim (REUSED)** | Per Q50 sub-decision 3 user lock — `brainstorming` skill REUSED transparently. Workflows complexity criteria apply unchanged. Typically skips for well-scoped FDA discipline-child work. |
   | 6 | Write Plan | **FDA-swap + augment (Plan output format)** | Workflows invokes writing-plans skill (REUSED per Q50). FDA augments: AFTER writing-plans produces `docs/plans/<issue-id>-plan.md`, **dispatch `/flow:plan-{discipline}` (Q43) per Q24 mod 2** to produce discipline-specific plan-X-section content via Q46 writeback. Two-artifact output: general execution plan (file) + discipline-specific plan (Linear issue body via Q46 markers). |
   | 7 | Set Up Worktree | **Preserved verbatim (REUSED)** | `git-worktrees` skill REUSED per Q50 sub-decision 2 |
   | 8 | Execute | **Preserved verbatim** | No FDA-specific dispatch in this step |

4. **Step 6 L4 plan-{discipline} dispatch — Q43 contract integration.** Step 6 (NOT Step 5 — Q50 amendment 1 corrects) is the FDA-swap site. Mechanism:
   - After workflows writing-plans skill produces `docs/plans/<issue-id>-plan.md`
   - Q51 detects discipline label on current issue: parse `type:<discipline>` from issue's labels
   - Q51 dispatches `/flow:plan-<discipline> <issue-id>` (e.g., `/flow:plan-eng BC-1234`)
   - Q43 handles per its locked 4-tier issue resolution chain (sub-decision 3): positional arg passed → no fallback needed
   - Q43 returns; Q51 proceeds to Step 7 worktree setup

5. **Issue resolution — Q51 pre-resolves; Q43 doesn't fall back in this path.** Q51's Step 3 (Linear query) + Step 4 (read details) already resolve a specific issue ID. Q51 passes issue ID to Q43 as explicit positional arg in Step 6 dispatch. Q43's locked 4-tier fallback (positional → breadcrumb → branch → AskUserQuestion) is unused in this path because Q51 always provides positional arg. Q43's fallback chain remains for direct user invocation of `/flow:plan-X` outside session-start context. **Edge case:** if user picks "no issue today, just exploring" at Step 3, Q51 SKIPS Step 6 plan dispatch; user can later run /flow:plan-X directly with Q43's fallback active.

6. **Resume support — Q51 doesn't write breadcrumb state.** Matches Q43's locked lightweight no-breadcrumb posture (Q43 sub-decision 7). Q51's full session-start sequence is interactive + user-paced; crashes mid-session don't justify per-skill resume state. Existing orchestrator breadcrumb (per `mode=resume` from Q12) is READ by Q51 in Step 1 augmentation but not WRITTEN by Q51. **No Q31 amendment 3 needed for Q51.** Pattern parallel to Q43.

7. **Q50 sub-decision 5 amendment 1 — corrections recorded with formal audit trail (per user lock 2026-05-07).** See Q50 amendment 1 entry above. Two drafter-C errors caught during Q51 drafting via gh API re-grep:
   - "8 steps" → "9 steps (Step 0 through Step 8)"
   - "Step 5 swapped to dispatch L4 plan-X-reviewer" → "Step 6 (Write Plan) augmented to dispatch L4 plan-X-reviewer alongside workflows writing-plans; Step 5 (Brainstorm) preserved verbatim per REUSE lock"
   
   Schema-discipline-faithful: amendment-with-audit-trail mirrors Q31 amendments 1+2 + Q24 amendment 1 + Q21 amendment 1 precedent. Future readers see Q50's corrected content + audit trail.

**Q51 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 1 architectural escalation (Q50 amendment treatment) + parking-lot-#39-discipline application requirement. Drafter C's resolution:

1. **Source re-verification (parking lot #39 discipline at downstream lock)** → APPLIED. Workflows session-start.md gh API re-fetched + grepped for step structure. Caught Q50 sub-decision 5's two errors (step count + swap location). Validation-discipline catch by drafter C on drafter C's own prior work — re-verification at downstream draft catches upstream errors.
2. **Q50 amendment 1 treatment (sub-decision 7)** → ESCALATED to user via `AskUserQuestion`; user answered "Q50 amendment 1 with audit trail (Recommended)" — schema-discipline precedent matters; Q50's incorrect text gets in-place corrected + amendment audit trail records original incorrect text + correction rationale.
3. Sub-decisions 1-6 → APPLIED with strong rationale; verbatim source citations + Q50 7-axis FDA-swap framework applied per-step; Q43 dispatcher integration spelled out at Step 6.

**Validation discipline catches (preserved for handoff integrity):**

*By drafter C on drafter C's own prior work (rare meta-catch — validation cycle on inherited drafter-C error):*
- **Caught Q50 sub-decision 5 step-count error** — "8 steps" → actual 9 steps via gh API re-grep
- **Caught Q50 sub-decision 5 step-swap-location error** — "Step 5 swapped" → actual Step 5 is Brainstorm (REUSED); Step 6 is the FDA-swap site for plan dispatch
- **Caught orchestrator's Step 5 claim (parroted Q50 error in prompt)** — pushed back with workflows source citation; orchestrator acknowledged + locked Q50 amendment 1 treatment
- **Methodology lesson reinforced:** parking-lot-#39 discipline applies AT EACH cribbed-content lock, not just first cribbing. Prior locks can be wrong; downstream re-verification catches drift between lock-time understanding and verified source truth (extends parking lot #39 with this principle).

**Q52 — `/flow:review` (cloned + FDA-swapped) (LOCKED 2026-05-07).** Cloned from workflows v3.29.4 commands/review.md; applies Q50 sub-decision 5's 7-axis FDA-swap framework. Workflows source RE-VERIFIED via gh API 2026-05-07 per parking-lot-#39 extension methodology (don't inherit Q50). 354 lines; 9-step structure (Step 0-8) confirmed. Lighter FDA-swap profile than Q51 — workflows review is workflow-generic; FDA-process-compliance is /flow:audit's job (Q38), not /flow:review's. No Q50 amendment 2 needed (Q50 didn't claim review.md step count). Seven sub-decisions:

1. **Source baseline + drift-recording header.** Cloned from `repos/Brite-Nites/brite-claude-plugins/plugins/workflows/commands/review.md` at workflows v3.29.4 (re-verified gh API 2026-05-07 per parking-lot-#39 extension). FDA-clone HTML-comment header per Q50 sub-decision 6 + parking lot #45:
   ```markdown
   <!-- Cloned from workflows v3.29.4 (commands/review.md) on 2026-05-07. Drift-detection per parking lot #45. -->
   ```

   **Amendment 1 — `Upstream-SHA:` backfill (BC-7060, 2026-05-12).** Header text augmented with `Upstream-SHA: <40-hex-blob>.` per Q51 sub-decision 1 amendment 1 pattern, operationalizing Q40 sub-decision 7. Live form:
   ```markdown
   <!-- Cloned from workflows v3.29.4 (commands/review.md) on 2026-05-07. Upstream-SHA: a0ca0778e9c5629efff226e26fe1505eb05c2446. Drift-detection per parking lot #45. -->
   ```

2. **9-step structure preservation (Step 0 through Step 8).** Workflows review.md has 9 steps verified via gh API re-grep 2026-05-07. FDA-clone preserves all 9 step numbers + verbatim step titles where possible. Per-step FDA-swap mapping in sub-decision 3.

3. **Per-step FDA-swap classification — predominantly PRESERVED VERBATIM (lighter FDA-swap than Q51 session-start).**

   | Step | Workflows title | FDA classification | FDA-swap details |
   |---|---|---|---|
   | 0 | Verify Agent Dispatch | **Preserved verbatim** | Workflows verifies Task tool works; FDA-clone unchanged |
   | 1 | Self-Verification | **Preserved + PASSIVE-context augment (per refinement 4 lock)** | Workflows checks plan steps + tests + build + own diff. FDA augments: also reads `intent.md` (Q41) + story doc (Q27) + parent issue body (with `## L3 review summary` per Q23 mod 2) and provides as PASSIVE context for the human reviewer. **Q52 does NOT enforce alignment between diff and AC/success-criteria** — active alignment-checks overlap with /flow:audit's gates and belong in Q38 (cribbing-fidelity boundary preserved). Main verification (tests/build/diff) preserved. |
   | 2 | Diff Triage | **Preserved verbatim** | workflows-generic diff analysis |
   | 3 | Simplify Pass | **Preserved verbatim** | workflows simplification pattern |
   | 4 | Select & Launch Review Agents | **Preserved + PLAN-CONTEXT augment (per refinement 2 user lock 2026-05-07)** | **REUSED — workflows-plugin agents (15 per Q50 enumeration; distinct from Q21's 12 FDA agents).** Channel 2 dependency per Q50 sub-decision 4: invoked via `Skill: workflows:*` pattern. FDA depends on workflows being installed. **FDA augment:** reviewer-agent prompts include plan-X-section content read from discipline-child issue body via Q46 markers (READ pattern); reviewers see "what was planned vs what was implemented." ~10 lines per agent prompt to inject plan context. Tier 1 (always: code-reviewer, security-reviewer, performance-reviewer) + Tier 2 stack-conditional + Tier 3 opt-in agents all receive plan context. |
   | 5 | Collect & Classify Findings | **Preserved verbatim** | P1/P2/P3 severity merging unchanged |
   | 6 | Validate Findings | **Preserved verbatim** | workflows validation pattern |
   | 7 | Fix Loop (P1s Only) | **Preserved verbatim** | workflows P1-fix iteration |
   | 8 | Final Report | **Preserved + ship-link swap** | Workflows ends with "Ready for `/workflows:ship` when you are." FDA-clone swaps to "Ready for `/flow:ship` when you are." (per FDA's cloned ship per Q53 — pending) |
   
   **3 FDA-touched steps** (1, 4, 8) out of 9. Steps 0, 2, 3, 5, 6, 7 preserved verbatim. Cribbing-fidelity preserved on workflow-generic patterns; FDA-specific augments at narrative-context entry (Step 1) + plan-context for reviewers (Step 4) + ship-link swap (Step 8).

4. **/flow:review and /flow:audit boundary — INDEPENDENT in v1 (per user lock 2026-05-07).** Strong consensus (drafter C lean (b) + orchestrator lean (b) + user lock (b)). Two functions with overlapping vocabulary but distinct purposes:
   - **/flow:review (Q52, this lock):** workflows-cloned code-review-agent dispatch + diff triage + simplification + P1/P2/P3 findings classification. Reviews CODE CHANGES on a branch.
   - **/flow:audit (Q38):** FDA-native filesystem-existence + Linear-state gate runner. Checks 35-gate FDA-process-compliance stack. NOT code review.
   
   v1: /flow:review and /flow:audit stay separate. User runs /flow:audit explicitly when wanting FDA-process-compliance checks. Cribbing-fidelity preserved (workflows /workflows:review has no audit-equivalent pre-flight); Q52 stays a clean clone; Q38 evolution doesn't unintentionally drift Q52.
   
   **Q55 plugin CLAUDE.md documentation requirement (added per user lock):** explicit /flow:audit vs /flow:review boundary documentation. CLAUDE.md addition: "/flow:audit runs FDA-process-compliance gates; /flow:review runs code-review agents on diff. Distinct purposes. /flow:audit auto-invokes before /flow:ship; /flow:review is invoked when the user wants diff-level review."
   
   **v1.1 parking lot candidate (#48):** `--audit-preflight` flag for /flow:review if Brand Hub dogfood reveals users want bundled coverage.

5. **Q46 writeback — NONE in v1; explicit v1.1 upgrade path documented (per refinement 3 lock).** Workflows /workflows:review outputs findings to stdout/markdown report at Step 8 Final Report. FDA-clone preserves stdout-only output in v1. Q46 type registry NOT extended (v1 enum stays at 8 types per Q46 sub-decision 2: ship-summary, retro-summary, plan-{story,eng,design,qa,docs}-section, audit-concerns).
   
   **v1.1 upgrade path (parking lot #49 — sequenced explicitly per schema-discipline precedent):**
   1. Q46 amendment 3 (third Q46-side amendment after Q31 amendment 1 + Q31 amendment 2 — note: Q46 amendment numbering is Q46-side, distinct from Q31 amendments which Q46 sub-decision 3 + 7 record) adds `review-summary` to type registry
   2. Q52 amendment 1 routes Step 8 Final Report through `linear_writeback({type: 'review-summary', surface: 'comment'})` instead of stdout-only
   3. Both amendments follow Q31/Q24/Q21/Q50 amendment-with-audit-trail precedent
   
   Promote if Brand Hub dogfood reveals Linear surface for review findings is valued.

6. **Q43 plan-X-section read coordination — AUGMENT IN V1 (per refinement 2 user lock 2026-05-07).** Step 4 reviewer-agent prompts augmented with plan-X-section content from discipline-child issue body. READ pattern (not write — Q46 sub-decision 5 throttle N/A for read-only access).
   - Q52 reads discipline-child body via `get_issue` in Step 4 setup
   - Parses plan-X-section content between `<!-- FDA-WRITEBACK-plan-<discipline>-section-START/END -->` markers per Q43 sub-decision 5
   - Injects plan-X-section content into reviewer-agent prompts: `"Plan context (what was planned for this discipline child): <plan-X-section content>. Diff: git diff BASE...HEAD"`
   - Reviewers see "what was planned vs what was implemented" — catches implementation-diverges-from-plan issues
   - **Cost:** ~10 lines per agent prompt across Tier 1 always + Tier 2/3 conditional agents
   - **Step 1 augment already established the deviation pattern** (Q52 reads FDA artifacts as PASSIVE context); Step 4 augment is degree not kind
   - **v1.1 parking lot candidate (#50):** retire plan-context augment if dogfood reveals reviewers don't benefit (e.g., plan-X-section content too generic/short to add signal)

7. **Auto-invocation contract + Q52 → Q53 dependency direction.**
   - **User-invocable:** primary invocation pattern; user runs `/flow:review [fast|thorough|comprehensive]` per workflows args (preserved verbatim per sub-decision 3 Step 4a)
   - **Auto-invocable from Q53 /flow:ship pre-flight:** Q53 (pending) MAY invoke /flow:review as ship-readiness check. Q52 doesn't pre-decide this; Q53's lock will specify.
   - **Forward-looking dependency direction:** Q52 → Q53 (Q52 lands first; Q53 cribs Q52 invocation contract). Pattern parallel to Q43 → Q51 + Q51 → Q53.
   - **NOT auto-invoked from /flow:audit (Q38):** boundary preserved per sub-decision 4 lock.

**Q52 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 5 refinements + parking-lot-#39-extension re-verification application requirement. Drafter C's resolution:

1. **Source re-verification (parking-lot-#39 extension at Q52 lock)** → APPLIED. Workflows review.md gh API re-fetched + grepped. Q50 made no specific step-count claims about review.md (only session-start was claimed) — **no Q50 amendment 2 needed**. Re-verification still mandatory per Q51 methodology lesson; surfaced 9-step structure + Step 4 reviewer agents (workflows-plugin's 15 agents) + Step 8 ship-link.
2. **/flow:review and /flow:audit boundary (sub-decision 4)** → ESCALATED to user via `AskUserQuestion`; user answered "Independent in v1 (Recommended)" — strong consensus (drafter C + orchestrator + user all leaning b); cribbing-fidelity + clear separation; v1.1 parking-lot for --audit-preflight flag.
3. **Plan-X-section read coordination (sub-decision 6)** → ESCALATED to user via `AskUserQuestion`; user answered "Augment in v1 (Recommended)" — quality win is real (catches divergence-from-plan issues); Step 1 augment already established deviation pattern; cost is low (~10 lines per agent prompt); deferral would be speculative-rather-than-evidence-based.
4. **Review-summary v1.1 upgrade path (refinement 3)** → APPLIED in sub-decision 5. Q46 amendment 3 + Q52 amendment 1 sequence locked in parking lot #49 per schema-discipline precedent.
5. **Step 1 augment specifics (refinement 4)** → APPLIED PASSIVE context semantic. Q52 reads + provides; does NOT enforce alignment. Active checks belong in Q38. Cribbing-fidelity boundary preserved.
6. **Step 4 agent terminology (refinement 5)** → APPLIED clarification. "workflows-plugin agents (15 per Q50 enumeration; distinct from Q21's 12 FDA agents)" + Channel 2 dependency cited.

**Validation discipline catches (preserved for handoff integrity):**

*Parking-lot-#39-extension third application (Q52 — re-verification at downstream lock):*
- Workflows review.md gh API re-fetched + grepped at Q52 drafting; Q50 made no specific claim about review.md step count, so no Q50 amendment caught. Re-verification methodology applied as discipline regardless. Pattern: even when re-verification doesn't catch errors, it confirms source truth and prevents stale-recall propagation.
- **Honest assessment of FDA-swap profile:** Q52 is significantly LIGHTER swap than Q51 — 3 FDA-touched steps (1, 4, 8) out of 9 vs Q51's per-step swap classification. Cribbing-fidelity argument load-bearing because /flow:review is workflow-generic code-review tool; FDA-process-compliance is /flow:audit's job. Boundary preserved cleanly.

**Q50 amendment 2 — TRANSITIVE REUSE category for skills/agents invoked via preserved-step content (LOCKED 2026-05-07 per Q53 drafter-C catch).** Q50 sub-decision 2 originally classified workflows artifacts as DIRECT REUSE (skills FDA-cloned commands explicitly orchestrate as primary purpose) or OUT-OF-SCOPE. Q53 re-verification surfaced a classification gap: workflows ship.md Steps 4/5/6 invoke 3 workflows skills via preserved-verbatim step content; workflows review.md Step 4 (Q52 lock) invokes 15 workflows agents via preserved-verbatim step content. Both patterns are TRANSITIVE REUSE — invoked indirectly through cloned-command step preservation, NOT through direct FDA orchestration.

**Original Q50 sub-decision 2 REUSE list (6 items; preserved here for audit trail):**
> "git-worktrees skill + executing-plans skill + verification-before-completion skill + code-review command + brainstorming skill + writing-plans skill"

**Two classification gaps caught at Q53 lock (2026-05-07):**
1. **3 workflows skills used in Q53 ship.md preserved Steps 4/5/6:** `compound-learnings` (Step 4), `best-practices-audit` (Step 5), `handbook-drift-check` (Step 6). Q50 sub-decision 2 implicitly classified these as OUT-OF-SCOPE; reality is TRANSITIVE REUSE.
2. **15 workflows agents used in Q52 review.md preserved Step 4** (code-reviewer, security-reviewer, performance-reviewer + Tier 2/3 conditional per Q21 enumeration; 15 total per Q50 sub-decision 1). Q50 sub-decision 2 implicitly classified as OUT-OF-SCOPE; Q52 lock cited "REUSED" creating drift; reality is TRANSITIVE REUSE.

**Corrected Q50 sub-decision 2 classification (in-place edit applied above):**

REUSE category split into two sub-categories:
- **DIRECT REUSE (6 items per original lock):** skills FDA-cloned commands EXPLICITLY orchestrate as primary purpose. Listed unchanged from original Q50 lock.
- **TRANSITIVE REUSE (3 skills + 15 agents per Q50 amendment 2):** skills/agents invoked via preserved-step content in cloned commands. New sub-category formalizes the pattern.
  - 3 skills (Q53 ship.md preserved Steps 4/5/6): `compound-learnings`, `best-practices-audit`, `handbook-drift-check`
  - 15 agents (Q52 review.md preserved Step 4): all 15 workflows-plugin agents per Q50 sub-decision 1 enumeration

**Cross-link:** Q53 lock entry sub-decision 3 + Q52 lock entry sub-decision 3 Step 4 reference TRANSITIVE REUSE per this amendment.

**Schema-evolution discipline reinforced:** Q50 amendment 2 follows Q50 amendment 1 + Q31 amendments 1+2 + Q24 amendment 1 + Q21 amendment 1 precedent. Drafter-C catch at downstream re-verification (parking-lot-#39 extension methodology working as designed for second time at Q53 lock after Q51's Q50 amendment 1).

**Methodology lesson reinforced:** parking-lot-#39 extension caught Q50 errors at TWO downstream locks now (Q51 → Q50 amendment 1 step-count + step-swap-location; Q53 → Q50 amendment 2 transitive-reuse-classification). Pattern: heavily-cited foundation locks (Q50 is foundation for 3 downstream cloned-skill locks) accumulate errors that surface during downstream consumer drafting. Re-verification at each consumer lock is the discipline.

**Q53 — `/flow:ship` (cloned + FDA-swapped) (LOCKED 2026-05-07).** Cloned from workflows v3.29.4 commands/ship.md; applies Q50 sub-decision 5's 7-axis FDA-swap framework. Convergence point — touches Q38 audit pre-flight + Q46 ship-summary writeback (primary consumer) + Q43 plan completion + Q44 retro coordination + Q42 L1 concerns + Q42 intent.md upstream + Q22-Q27 narrative artifacts. Workflows source RE-VERIFIED via gh API 2026-05-07 per parking-lot-#39 extension; caught Q50 sub-decision 2 classification gap → Q50 amendment 2 above.

**Heaviest swap profile of the 3 cloned commands (Q51 + Q52 + Q53):** 7 FDA-touched steps (1, 2, 3, 4, 5, 6, 8) out of 9. Steps 0, 7 preserved verbatim. Reasoning: Q53 is the inner-loop convergence point where most FDA-specific patterns (audit pre-flight, Q46 writeback, plan-X verification, retro coordination, FDA-shaped PR description) all integrate.

Seven sub-decisions:

1. **Source baseline + drift-recording header.** Cloned from `repos/Brite-Nites/brite-claude-plugins/plugins/workflows/commands/ship.md` at workflows v3.29.4 (re-verified gh API 2026-05-07 per parking-lot-#39 extension). FDA-clone HTML-comment header per Q50 sub-decision 6 + parking lot #45:
   ```markdown
   <!-- Cloned from workflows v3.29.4 (commands/ship.md) on 2026-05-07. Drift-detection per parking lot #45. -->
   ```

   **Amendment 1 — `Upstream-SHA:` backfill (BC-7060, 2026-05-12).** Header text augmented with `Upstream-SHA: <40-hex-blob>.` per Q51 sub-decision 1 amendment 1 pattern, operationalizing Q40 sub-decision 7. Live form:
   ```markdown
   <!-- Cloned from workflows v3.29.4 (commands/ship.md) on 2026-05-07. Upstream-SHA: a22fd5dae19065c499a1202a03120324a68fe2ce. Drift-detection per parking lot #45. -->
   ```

2. **9-step structure preservation (Step 0 through Step 8).** Workflows ship.md has 9 steps verified via gh API re-grep 2026-05-07. FDA-clone preserves all 9 step numbers + verbatim step titles. Per-step FDA-swap mapping in sub-decision 3.

3. **Per-step FDA-swap classification — heaviest swap profile (7 of 9 steps FDA-touched).**

   | Step | Workflows title | FDA classification | FDA-swap details |
   |---|---|---|---|
   | 0 | Verify GitHub CLI | **Preserved verbatim** | gh CLI prerequisite check unchanged |
   | 1 | Pre-Ship Checks | **Preserved + AUDIT pre-flight + PLAN-X verification augments** | Workflows pre-ship checks (clean state + tests + build + branch) preserved. **FDA augment 1 (per Q38 sub-decision 5):** invokes `/flow:audit --domain=<DOMAIN>` (scope-filtered via Q24 mod 3 label parse) as ship-readiness pre-flight; halts ship on exit 1 (unoverridden hard fail) or exit 2 (verify-docs fail) per Q38 sub-decision 6; soft-gate warnings surfaced but don't halt. **FDA augment 2 (per Q43 sub-decision 5):** verifies plan-X-section content for shipping discipline-child is non-placeholder via Q46 markers READ pattern; regex check for "Plan not yet generated" stable substring; halts ship if still placeholder with redirect to `/flow:plan-<discipline>`. Q53-specific gate (NOT a Q29 gate); v1.1 parking-lot to extend Q29 with plan-X-section discipline-completion gate. |
   | 2 | Create Pull Request | **Preserved + FDA-swap (PR description content)** | `gh pr create` mechanics preserved. PR description SWAPPED per Q50 sub-decision 5 axis 1 (Linear field references): references FDA-shaped milestone (Q22) + sub-flow parent (Q23) + 5 discipline children (Q24); links to story doc (Q27) + journey doc (Q26) + intent.md (Q41). PR title format remains workflows-faithful (concise imperative under 70 chars). |
   | 3 | Update Linear | **FDA-swap (Q46 routing per axis 4) — PRIMARY Q46 ship-summary consumer** | Workflows direct Linear MCP comment write. **FDA-swap:** comment write routed through `linear_writeback({issue_id: <discipline-child-id>, type: 'ship-summary', surface: 'comment', content: <PR-link + summary>, signature: '_Generated by /flow:ship for <issue-id> on <ISO-8601>_', breadcrumb_path, warn_on_clobber: true})` per Q46 sub-decision 7. Q46 ship-summary type already in v1 enum per Q46 sub-decision 2 — no Q46 amendment. Surface=comment (mirrors workflows Step 3 #2). Status move + PR attachment NOT Q46-routed (direct Linear MCP per workflows pattern). Per Q46 sub-decision 5 batching: typical /flow:ship is per-issue invocation = 1 issue × 1 type = single Q46 write per invocation. Per Q46 sub-decision 3 signature dedupe: re-running /flow:ship updates existing ship-summary comment idempotently. |
   | 4 | Compound Learnings | **Preserved verbatim (TRANSITIVE REUSE per Q50 amendment 2)** | `compound-learnings` skill REUSED transparently via Skill tool. Q50 amendment 2 formalizes this transitive-reuse classification. |
   | 5 | Best Practices Audit | **Preserved verbatim (TRANSITIVE REUSE per Q50 amendment 2)** | `best-practices-audit` skill REUSED transparently. Q50 amendment 2 inclusion. |
   | 6 | Handbook Drift Check | **Preserved verbatim (TRANSITIVE REUSE per Q50 amendment 2)** | `handbook-drift-check` skill REUSED transparently. Q50 amendment 2 inclusion. |
   | 7 | Worktree Cleanup | **Preserved verbatim** | git worktree remove unchanged |
   | 8 | Session Close | **Preserved + RETRO-NOTIFICATION augment (per user lock 2026-05-07 sub-decision 7)** | Workflows Session Close summary preserved (PR / Linear / Learnings / Audit / Handbook). **FDA augment:** detect "is this the last sub-flow in domain?" via Linear query (all sibling sub-flows in milestone completed?); if yes, append soft notification to summary: "This shipped the last sub-flow in `<DOMAIN>`. Consider running `/flow:retro <DOMAIN>` when ready." Preserves Q44 manual-only lock per parking lot #40; lightweight UX win at zero coupling cost. |

4. **Q38 /flow:audit pre-flight integration (CONVERGENCE 1; per Q38 sub-decision 5 lock).** Q53 Step 1 augment invokes `/flow:audit --domain=<DOMAIN>` after workflows pre-ship checks succeed. Halts ship on exit 1 or 2 per Q38 sub-decision 6; soft-gate warnings surface but don't halt. Q38 sub-decision 5 already locks Q53 ship as auto-invoker — Q53 confirms + concretizes the integration point.

5. **Q46 ship-summary writeback (CONVERGENCE 2; PRIMARY Q46 consumer) — Step 3 swap.** Single linear_writeback per /flow:ship invocation. Surface=comment. Q46 ship-summary type already registered (Q46 sub-decision 2 v1 enum) — no Q46 amendment. Idempotent re-run via signature dedupe. Status + PR-attachment stay direct Linear MCP. Q53 is the heaviest Q46 consumer of all FDA skills (primary writeback path).

6. **Q43 plan-X-section verification (CONVERGENCE 3) — Step 1 augment via Q46 markers READ pattern.** Q53 verifies discipline-child's plan-X-section is populated before allowing ship; halts on placeholder content. Q53-specific gate in v1; v1.1 parking-lot candidate to extend Q29 with plan-X-section as discipline-completion gate (then /flow:audit covers it; Q53 verification becomes redundant). New parking lot entry below.

7. **Q44 retro coordination at Step 8 (CONVERGENCE 4) — soft notification (per user lock 2026-05-07).** Step 8 detects "last sub-flow in domain?" via Linear query (all sibling sub-flows completed?). If yes, soft notification appended to Session Close summary: "Consider running `/flow:retro <DOMAIN>` when ready." Preserves Q44 sub-decision 2 manual-only lock + parking lot #40 v1.1 deferral of auto-trigger; doesn't auto-fire retro; lightweight UX win at zero coupling cost. **NOT auto-invocation; NOT Q44 amendment.** Soft notification only.

**Convergences 5 + 6 (no Q53-side action):**
- **Q42 L1 concerns Linear routing (Q42 sub-decision 4 v1.1 parking lot):** Q53 doesn't directly consume Q42 output; doesn't pre-decide. Stays v1.1.
- **Q42 office-hours upstream (intent.md exists pre-ship):** Q53 relies on /flow:audit's `intent-exists` gate (Q29.1) to enforce intent.md existence + L1 review summary populated via Q53 Step 1 augment 1 audit pre-flight. Q53 doesn't redundantly check; trusts /flow:audit per sub-decision 4.

**Plan completion data emission for Q44 (Q44 sub-decision 6 / parking lot #43 implication):** Q53 emits plan-X-section read state into Q46's `linear_writeback_state.written_pairs[]` (Q31 amendment 2). v1.1 promotion of Q44 cross-skill-state mining (parking lot #43) would consume this. Q53 v1 doesn't add explicit emission beyond standard Q46 throttle bookkeeping.

**Telemetry block:** workflows ship.md has telemetry-log.sh hooks at start + end (Step 8 ends with `bash $BRITE_ROOT/scripts/telemetry-log.sh end ship <outcome>`). FDA-clone STRIPS per Q50 sub-decision 5 axis 7 (no telemetry config in v1).

**Q53 refinement audit trail (orchestrator → drafter C resolution, 2026-05-07).** Orchestrator session sent 6 convergence concerns + parking-lot-#39-extension re-verification application requirement. Drafter C's resolution:

1. **Source re-verification (parking-lot-#39 extension at Q53 lock)** → APPLIED. Workflows ship.md gh API re-fetched + grepped. **CRITICAL CATCH:** Q50 sub-decision 2 classification gap surfaced — Q53 ship.md Steps 4/5/6 invoke 3 workflows skills not in Q50 REUSE list. Plus retroactive Q52 implication: Q52 Step 4 invokes 15 workflows agents not classified. Q50 amendment 2 written above to formalize TRANSITIVE REUSE category.
2. **Convergence 1 (Q38 audit pre-flight)** → APPLIED in sub-decision 4. Q38 sub-decision 5 already locks Q53 as auto-invoker; Q53 Step 1 augment concretizes invocation point + exit-code handling.
3. **Convergence 2 (Q46 ship-summary writeback)** → APPLIED in sub-decision 5. Single Q46 write per invocation; surface=comment; ship-summary type already registered.
4. **Convergence 3 (Q43 plan-X verification)** → APPLIED in sub-decision 6. Q53-specific gate via Q46 markers READ pattern; halts ship on placeholder content. Q29 amendment v1.1 parking-lot.
5. **Convergence 4 (Q44 retro coordination)** → ESCALATED to user via `AskUserQuestion`; user answered "Soft notification (Recommended)" — preserves Q44 manual-only lock; lightweight UX win.
6. **Convergences 5 + 6 (Q42 L1 + intent.md)** → No Q53 action; stays per existing Q42 sub-decision 4 v1.1 + Q38 audit pre-flight handles intent.md.

**Validation discipline catches (preserved for handoff integrity):**

*Parking-lot-#39-extension fourth application (Q53 — re-verification at downstream lock; SECOND major catch after Q51's Q50 amendment 1):*
- Workflows ship.md gh API re-fetched at Q53 drafting; **caught Q50 sub-decision 2 TRANSITIVE REUSE classification gap** affecting both Q53 (3 skills) AND retroactively Q52 (15 agents). Q50 amendment 2 written; TRANSITIVE REUSE sub-category formalized.
- **Methodology lesson reinforced:** parking-lot-#39 extension caught Q50 errors at TWO downstream locks now. Pattern: heavily-cited foundation locks accumulate errors at downstream consumer drafting. Re-verification AT EACH consumer lock is the discipline; even when Q52 didn't catch errors (negative result), Q53 did (positive result). Both outcomes are valid uses of the methodology.
- **Honest Q53 swap-profile assessment:** heaviest of the 3 cloned commands (7 of 9 steps FDA-touched). Reasoning: Q53 is inner-loop convergence point where audit + writeback + plan-verification + retro-coordination + FDA-shaped PR description all integrate. Cribbing-fidelity preserved on workflow-generic patterns (Steps 0, 7 + transitive-reuse Steps 4/5/6); FDA-specific augments at every other step.

**Q55 — Plugin CLAUDE.md content design (LOCKED 2026-05-08, drafter D session).** Cross-cutting documentation close that fills the file slot reserved at Q30.5 (memory:276). Consolidates 5 Phase-J cross-cutting documentation requirements (memory:1787) + Q30.5 base scope + 6 misc per-Q callbacks accumulated across the locked Q-stack. FDA-native synthesis from locked Qs — no external cribbing; sibling-precedent verification (cadence CLAUDE.md @ 14257 bytes / 7 H2 sections via gh API 2026-05-08; workflows has NO CLAUDE.md / 404) done as defensive parking-lot-#39 application. Seven sub-decisions:

1. **Audience scope — both plugin maintainers AND LLM-context readers; single file, dual audience.** Q30.5 (memory:276) calls it "plugin-internal guidance file ... distinct artifact from Q34 (org-wide handbook page) and Q42 (specific skill's prompt body)." Cadence sibling precedent confirms dual purpose: CLAUDE.md auto-loaded into LLM context when plugin is active, AND read by future maintainers extending the plugin. Single file with sections that serve both audiences (operational sections for LLM dispatch + methodology for v1.1+ Q-locks). Sibling artifact distinction preserved: Q34 = handbook practitioner reference; Q33 = decision rationale (CDR-023); README.md (Q30.7) = installer/user guide; Q55 = LLM context + maintainer reference.

2. **Section structure — 13 H2 sections (user lock 2026-05-08 per refinement 1).** Expanded from cadence's 7 to match FDA's larger surface area + 5 cross-cutting documentation requirements that benefit from discoverable headings. Locked structure:
   1. **Plugin overview** — what FDA is + plugin's role + Brand Hub dogfood context (Q8)
   2. **Surface map** — commands by role + sub-skills + agents + _shared utilities (drift-tolerant per sub-decision 4)
   3. **Workflows plugin dependency** — REQUIRED prerequisite + 3-channel mechanism (Q50 sub-decisions 4-6)
   4. **MCP + dependencies** — workflows linear-server + bash 3.x+ + python3 3.6+ + git 2.x+ + gh soft (Q32 + parking lot #29)
   5. **Bootstrap + first-run** — flow-preflight embedded bootstrap (Q36) + `.flow/config.json` schema + per-org prerequisite (parking lot #33)
   6. **Quality gate stack reference** — Q29 35-gate stack overview + override mechanics + override-counts-as-pass (Q38 sub-decision 6)
   7. **L-review pattern** — L1/L2/L3/L4 scoping (Q54) + four-mode framework outcome contract (Q48; **cross-cutting requirement #3**)
   8. **Boundaries** — `/flow:audit` vs `/flow:review` (Q52 sub-decision 4; **cross-cutting requirement #5**) + orchestrators vs utilities vs cloned commands + office-hours vs retro + sandbox-scaffold vs handoff agents
   9. **Q46 writeback layer** — type registry + idempotency markers + **double-layer safety** (Q43 caller-side + Q46 executor-side; **cross-cutting requirement #2**) + **batching convention** (Q46 sub-decision 5; **cross-cutting requirement #1**)
   10. **Concurrency caveat** — single-orchestrator-at-a-time (Q31.6 lock memory:298)
   11. **Methodology notes ("How this plugin evolves") — user-locked in CLAUDE.md per refinement 2** — validation-first cycle + parking-lot-#39 + extension + **three-way cribbing taxonomy** (Q50 sub-decision 7; **cross-cutting requirement #4**) + schema-discipline amendment pattern
   12. **Pre-existing-vs-FDA-output mapping** — what artifacts FDA creates vs already exists in BriteBase/Brand Hub repos
   13. **See also** — pointers to CDR-023 + operating-standards FDA page + templates + parking lot reference
   
   Reversibility: 13 H2 → consolidate to 9-10 in v1.1 if dogfood reveals over-fragmentation; going 7 → 13 mid-stream is harder. **v1.1 parking lot candidate:** consolidation pass post-Brand-Hub dogfood if findability gains don't materialize.

3. **Length target — ~15000-18000 bytes (~2700-3300 words); soft warn >20000 bytes; HARD stop-loss >25000 bytes (per refinement 5 user lock).** Calibration: cadence CLAUDE.md = 14257 bytes (gh API verified 2026-05-08); Q34 operating-standards = ~1500-2000 words; BriteBase root CLAUDE.md = ~5500 words (skews high). FDA plugin CLAUDE.md sits between cadence + BriteBase root. **Stop-loss extraction paths if >25000 bytes (cadence + 75%):** (a) extract section 11 methodology notes to `plugins/flow-architecture/docs/methodology.md`; (b) per-area split — `CLAUDE.md` (overview + surface) / `DEPENDENCIES.md` (sections 3-5) / `METHODOLOGY.md` (section 11). Gives v1.1+ maintainers concrete trigger + path forward when section creep happens; soft warn alone may be ignored across multiple v1.x updates.

4. **Drift-tolerant references — categories + representative examples + source-of-truth pointers; NO top-level counts; HYBRID format per refinement 3 user resolution.** Q34 sub-decision 4 (memory:392) deferred "specific slash command counts + sub-skill counts + agent counts (drift-tolerant)" to plugin CLAUDE.md. Resolution applies different formats to Q30.5's locked terminology:
   - **"Slash command MAP"** (categorical prose) — list by role with examples + source-of-truth pointer to `commands/` directory + `plugin.json`
   - **"Sub-skill orchestration MAP"** (categorical prose) — list by orchestration role (preflight/inventory/scaffold/author/regen) with examples + pointer to `skills/<name>/SKILL.md`
   - **"Agent dispatch MATRIX"** (literal 2D table per refinement 3) — rows=agents, columns=L-scope (L1/L2/L3/L4) + invoker (skill/command) + return-shape; cells=presence indicator + dispatch context. The "matrix" word in Q30.5 is deliberate (vs "map" twice); literal tabular format genuinely helps LLM-context readers answer "which agent fires from which invoker." Source-of-truth pointer to `agents/<name>.md`.
   
   Pattern: don't assert "FDA has 17 commands" (drifts); say "Commands organized by role: orchestrators (e.g., /flow:start-project, /flow:retrofit-project), utilities (e.g., /flow:audit, /flow:regen-index), planning (e.g., /flow:plan-{discipline}), cloned-inner-loop (e.g., /flow:session-start, /flow:review, /flow:ship), reflect (/flow:retro). See `commands/` for current set."

5. **Cross-reference convention — HYBRID (absolute GitHub URLs cross-repo + relative paths same-repo) + GitBook migration TODO comment.** Adopts Q14.2 / Q33 / Q34 / Q35 absolute-URL pattern but relaxes for same-repo refs. **Per refinement 4 verification:** path math from `plugins/flow-architecture/CLAUDE.md` (top-level under plugin dir per Q30.2 memory:265) to `plugins/workflows/` resolves as `../workflows/` — confirmed correct. **Defensive observation:** cadence CLAUDE.md uses NO markdown links at all (gh API verified zero `](http`/`](../`/`](/plugins` matches 2026-05-08); FDA's hybrid is INTENTIONAL DIVERGENCE from cadence's link-free style — FDA has cross-cutting documentation requirements that need cross-refs (boundaries, methodology, three-way cribbing examples). Specific cross-refs:
   - **Absolute URLs (cross-repo):** CDR-023, operating-standards FDA page, templates (about-handbook), gstack/compound-engineering external sources
   - **Relative paths (same-repo):** workflows plugin (`../workflows/`), other Brite plugins under `plugins/`
   - **GitBook TODO comment** (per Q33/Q34 pattern): `<!-- TODO: when handbook migrates to public GitBook docs site, replace absolute GitHub URLs with GitBook canonical URLs. -->`

6. **Methodology preservation — "How this plugin evolves" section in CLAUDE.md (user lock 2026-05-08 per refinement 2).** Plugin CLAUDE.md preserves four operational disciplines for v1.1+ work:
   - **Validation-first cycle** — orchestrator → drafter → orchestrator → drafter's-own-prior-work (4-level catch pattern from interview design; design-essential for future Q-locks)
   - **Parking-lot-#39 + extension** — gh API verify cribbed source BEFORE drafting + re-verify at EACH cribbed-content lock (Q51 + Q53 caught Q50 errors via this discipline)
   - **Three-way cribbing taxonomy (Q50 sub-decision 7; cross-cutting requirement #4)** — FDA-native / gstack-inspired / workflows-cloned with locked examples
   - **Schema-discipline amendment pattern** — amendment-with-audit-trail in BOTH originating Q-lock + target Q-lock; original incorrect text preserved when applicable. Precedents: Q31 amend 1+2, Q24 amend 1, Q21 amend 1, Q50 amend 1+2
   
   Reasoning: v1.1+ work introduces new cribbings (parking lot #46 flow-brainstorming, #47 flow-writing-plans, #45 drift-detection); without preserved discipline, errors recur. Schema-discipline amendments are LIVE — parking lot #51 queues Q29 amendment 1 territory; #49 queues Q46 amend 3 / Q52 amend 1 sequence. Cadence Gotchas section serves analogous purpose for cadence-internal evolution; precedent supports. **v1.1 candidate parking lot:** if methodology bloats CLAUDE.md past R5 stop-loss (25000 bytes), extract to `plugins/flow-architecture/docs/methodology.md`; don't pre-extract.

7. **Cross-cutting documentation requirements enumeration — 5 Phase-J + Q30.5 base scope + 6 misc per-Q callbacks; total 12 distinct content destinations mapped to 13 sections.** Memory:1787 authoritative on the 5 cross-cutting count.
   
   **5 cross-cutting requirements (Phase J locks):**
   1. **Q46 batching convention** (memory:974, 1727) → CLAUDE.md section 9
   2. **Q43 double-layer safety** (memory:1081, 1107) → CLAUDE.md section 9
   3. **Q48 four-mode taxonomy** (memory:1119-1232) → CLAUDE.md section 7
   4. **Q50 three-way cribbing taxonomy** (memory:1390-1394) → CLAUDE.md section 11
   5. **Q52 /flow:audit vs /flow:review boundary** (memory:1505-1513) → CLAUDE.md section 8
   
   **Base content per Q30.5 (memory:276):** plugin overview + slash command map + sub-skill orchestration map + agent dispatch matrix + quality gate stack reference + Linear MCP dependency note + pre-existing-vs-FDA-output mapping → CLAUDE.md sections 1, 2, 6, 4, 12
   
   **Misc per-Q callbacks (NOT counted in "the 5"; base-scope additions):**
   - Q30.4 workflows MCP dependency (memory:274) → section 4
   - Q31.6 concurrency caveat (memory:298) → section 10
   - Q32 MCP + Dependencies sections (memory:330) → section 4
   - Q38 override-counts-as-pass (memory:670) → section 6
   - Parking lot #29 python3 dependency (memory:1707) → section 4
   - Parking lot #33 per-org bootstrap prerequisite (memory:1710) → section 5
   
   **Acceptance test for CLAUDE.md authoring:** at write-time, drafter or LLM verifies via grep that every cross-cutting requirement (#1-#5) has dedicated heading or sub-section + every misc callback resolves to its mapped section.
   
   **Forward-compatibility:** CLAUDE.md does NOT pre-decide v1.1+ surface — references parking lot for deferred items (parking lot #45/#46/#47/#48/#49/#50/#51 etc.) rather than enumerating them as plugin features. Preserves Q55 reversibility.

**Q55 refinement audit trail (orchestrator → drafter D resolution, 2026-05-08).** Orchestrator session sent 5 refinements after Q55 draft. Drafter D's resolution of each:

1. **Section count (architectural escalation)** → ESCALATED to user via `AskUserQuestion`; user answered "13 H2 sections (Recommended)" — drafter + orchestrator strong consensus locked. Reversibility preserved via v1.1 consolidation parking lot.
2. **Methodology placement (architectural escalation)** → ESCALATED to user via `AskUserQuestion`; user answered "Keep in CLAUDE.md (Recommended)" — drafter + orchestrator strong consensus locked. Cadence Gotchas precedent supports; methodology is LIVE for v1.1+ Q-locks happening inside plugin's own evolution. R5 stop-loss extraction is the v1.1 escape hatch if creep happens.
3. **Q30.5 MAP/MATRIX terminology verification** → APPLIED hybrid resolution. Memory:276 uses lowercase "map / map / matrix" — deliberate word choice; two "maps" categorical, one "matrix" tabular. Sub-decision 4 amended: agent dispatch as literal 2D table (rows=agents × columns=L-scope+invoker+return-shape); commands map + sub-skills map as categorical prose with role + examples + pointers.
4. **Relative path resolution verification** → CONFIRMED. Q30.2 (memory:265) lists CLAUDE.md as top-level file at plugin root; cadence sibling at `plugins/cadence/CLAUDE.md` confirmed via gh API; path `../workflows/` correctly resolves from `plugins/flow-architecture/CLAUDE.md`. Defensive observation surfaced: cadence uses NO markdown links at all (gh API verified zero matches); FDA's hybrid link convention is INTENTIONAL DIVERGENCE based on cross-cutting documentation cross-ref needs. Sub-decision 5 amended with the divergence flag.
5. **Length stop-loss mechanism** → APPLIED. Sub-decision 3 amended with concrete 25000-byte threshold + two extraction paths (methodology-only OR per-area split). Soft-warn at 20000 + hard stop-loss at 25000 gives v1.1+ maintainers explicit trigger + path forward.

**Validation discipline catches (preserved for handoff integrity):**

*By orchestrator on drafter D's work:*
- Surfaced Q30.5 MAP/MATRIX terminology nuance (refinement 3) — drafter D had treated "map/matrix" interchangeably as metaphorical; orchestrator forced verification; deliberate "matrix" vs "map" distinction holds; sub-decision 4 amended with hybrid format resolution
- Surfaced length stop-loss specification gap (refinement 5) — drafter D's soft-warn-only spec was insufficient for v1.1+ maintainer guidance; sub-decision 3 amended with concrete threshold + extraction paths
- Confirmed strong consensus on architectural calls (refinements 1+2) but pushed for user lock on both — drafter D had flagged both as escalation candidates; orchestrator confirmed escalation worth despite consensus

*By drafter D on drafter D's own draft:*
- Defensive parking-lot-#39 application even without external cribbing — sibling-precedent gh API verification of cadence CLAUDE.md (14257 bytes / 7 H2 sections) + workflows (404, no CLAUDE.md) prevented sibling-precedent assumption errors
- Caught cadence link-free convention via secondary gh API grep (zero `](http`/`](../`/`](/plugins` matches); flagged FDA's hybrid as intentional divergence in sub-decision 5 lock entry rather than silently diverging

**Methodology lesson (D session first lock):** Defensive sibling-precedent verification at parking-lot-#39 rigor pays off even for FDA-native synthesis content. Cadence's link-free style would have been an unstated assumption silently inherited; explicit verification surfaces the divergence as a deliberate choice. Pattern: when authoring LLM-context guidance derived from sibling plugins, verify sibling-precedent structure + conventions even if no formal cribbing relationship exists.

**Q55 status: LOCKED 2026-05-08 (drafter D session).** Cross-cutting documentation close complete. All 5 Phase-J cross-cutting documentation requirements + Q30.5 base scope + 6 misc per-Q callbacks mapped to 13 H2 sections. Ready for downstream CLAUDE.md authoring (post-interview implementation phase, not Q55 scope).

**Q40 — Production readiness checklist (LOCKED 2026-05-08, drafter D session).** Phase I close. v1.0 release gate that fills Q8's "successful Brand Hub retrofit" gap-definition and consolidates the release sequence + status flips + drift-detection baseline + design-rationale archive. FDA-native synthesis from locked Qs — no external cribbing; sibling-precedent verification (cadence has NO production-readiness analog; workflows has `/workflows:deployment-checklist` for code-project deploys at different scope per gh API 2026-05-08) done as defensive parking-lot-#39 application per Q55 R4 lesson. Seven sub-decisions:

1. **Form factor — static checklist document at `plugins/flow-architecture/docs/production-readiness.md`; NO runtime command in v1 (user lock 2026-05-08 per refinement 1).** v1 simplicity wins: v1.0 release is one-shot or few-shot during alpha → 1.0 ramp; runtime tooling for one-time gate is over-engineering. Most criteria delegate to existing runners (`/flow:audit` for FDA-process-compliance per Q38; `npm run build/lint/test` for code-project quality). Cadence has no analog (gh API verified 2026-05-08 — no readi/release/product/check command); workflows `deployment-checklist.md` is for code-project deploys (different concern; not on Q40 cribbing path). **v1.1 parking lot candidate:** promote to `/flow:check-readiness` runtime command if v1.x release cycles reveal re-running gates is friction.

2. **Location — `plugins/flow-architecture/docs/production-readiness.md` (NEW directory; flat file at plugin docs root).** Aligns with Q55 R5 stop-loss extraction destination (`plugins/flow-architecture/docs/methodology.md`) — same parent directory; consistent v1.x extraction pattern. Maintainer-facing artifact (not LLM-context); CLAUDE.md inclusion would mix audience purposes. Handbook is wrong audience (org-wide; Q40 is plugin-internal release concern). Memory IS the design-spec (Q40 lock entry); rendered file is implementation artifact — same pattern as Q33/Q34/Q35 where memory locks content design + rendered files land later.

3. **Checklist content — 12 criteria across 4 categories.**

   **Category A: Design phase complete (closes interview)**
   1. All 54 active Q-numbers (Q1-Q55 minus deleted Q39) have lock entries in memory, including **6 locked amendments** (Q31 amend 1+2, Q24 amend 1, Q21 amend 1, Q50 amend 1+2 — count corrected from C handoff arithmetic error per drafter D R5 catch). Q45 + Q49 are deferral-tracking locks confirming v1.1+ / v2+ deferral with explicit promotion criteria; Q40 + Q55 are substantive design locks. Verified: 51 locked / 1 pending at Q40 lock open; 52 locked / 2 pending (Q45, Q49) at Q40 lock close.
   2. Memory file archived to `plugins/flow-architecture/docs/design-rationale.md` (preserves interview design rationale + amendment audit trails post-v1.0)

   **Category B: Implementation complete (plugin code shipped per locked specs)**
   3. Plugin manifest + directory structure per Q30 — `commands/` (17 entries) + `skills/` (10 sub-skills + 6 `_shared/` utilities) + `agents/` (12 agents) + `scripts/` (4 helpers) + `LICENSE` + `README.md` + `CLAUDE.md` per Q55
   4. CLAUDE.md authored per Q55 spec — 13 H2 sections; all 5 cross-cutting documentation requirements have dedicated headings; size between 15000-25000 bytes per Q55 sub-decisions 3+5
   5. README.md authored per Q30.7 (verified at memory:280 per drafter D R2 fact-check) — overview + install + V1 surface command list + dev-guide pointer to CLAUDE.md

   **Category C: Org prerequisites landed (handbook + about-handbook PRs)**
   6. handbook PR merged: CDR-023 (status: Proposed; Q33 lock content rendered) + CDR-014 amendment (Q35 in-place edits + companion `milestones.md` amendment) + operating-standards FDA page (Q34 content rendered)
   7. about-handbook PR merged: Q22-Q28 promoted templates + Q41 PROJECT-INTENT.md template (file paths per Q2 lock)

   **Category D: Dogfood + version flip (closes v1.0)**
   8. Brand Hub retrofit dogfood succeeds per Q8 (concrete definition in sub-decision 4)
   9. Drift-detection baseline recorded — workflows v3.29.4 SHAs captured in HTML-comment headers of cloned commands per Q50 sub-decision 6 + parking lot #45 v1.1 prerequisite (FDA-clones at `plugins/flow-architecture/commands/{session-start,review,ship}.md` carry source SHA + clone date)
   10. Plugin version bumped per Q30.1: 0.1.0 → 1.0.0 in `plugin.json`
   11. CDR-023 status flip per Q33 R1: Proposed → Accepted (handbook PR amendment with Status section notation per Q35 pattern)
   12. **Post-v1.0 re-triage** of parking lot per refinement 4 distinction (NOT pre-implementation triage; that's Phase 1 close territory outside Q40 release sequence). Re-triage based on Brand Hub dogfood findings: promote items revealed as v1.1-pulling-forward; drop items revealed as not-actually-needed; verify no v1 blockers were misclassified

   **Implicitly excluded (NOT v1.0 blockers; v1.1 parking lot candidates per user lock 2026-05-08 R3):**
   - Telemetry (Q30.8 — none for v1)
   - Hooks (Q30.8 — none for v1)
   - Per-org bootstrap PR-creation orchestrator (parking lot #33 v1.1)
   - **Test surface** — explicit v1 stance: Brand Hub dogfood IS the integration test. Bash + schema-validation tests are parking lot v1.1 candidates (#52-#55 added per Q40 R3 user lock — see parking lot below). Promotion criteria: any v1.x release introduces schema regression OR adds 3+ new skills/agents/utilities (which increases edit frequency on schemas).

4. **Q8 "successful" definition — concrete acceptance criteria for Brand Hub retrofit dogfood.** Q8 (memory:48) locks the acceptance test but doesn't define "successful." Q40 fills:

   A Brand Hub `/flow:retrofit-project` run is **SUCCESSFUL** when:
   - All 9 retrofit phases complete without unrecovered failures (Q37 retrofit phase sequence with `legacy-cross-reference` inserted per Q14)
   - 5 user-confirmation gates fire as expected (Q10 retrofit gate budget)
   - Outputs match locked schemas:
     - `docs/product/intent.md` per Q41 template
     - `docs/product/master-flow-inventory.md` per Q11 codebase-scan output (Brand Hub determines its own FDA-domain count at runtime per memory:1758 — NOT pinned to BriteBase's 28 nor legacy-milestone count of 27)
     - `docs/product/flows/<domain>/<flow-id>.md` per Q27 (one per sub-flow)
     - `docs/product/journeys/<domain>.md` per Q26 (one per domain)
     - `docs/product/flows/INDEX.md` per Q25
     - Linear milestones + parents + 5N children chain per Q22-Q24 + Q13 scaffold
     - Cross-reference appendices on legacy milestones per Q14 + Q9
   - `/flow:audit` against retrofitted Brand Hub returns exit 0 (all hard gates pass per Q38 sub-decision 6)
   - `npm run build && npm run lint && npm test` pass on Brand Hub repo (FDA shouldn't break consumer builds)
   - Failure modes encountered during dogfood are documented at `plugins/flow-architecture/docs/design-rationale.md` (memory archive) for v1.1+ refinement

5. **v1.0 release sequence — strict order of operations + dual-event triage distinction (per refinement 4 user lock 2026-05-08).**

   **TRIAGE EVENT #1 (pre-implementation, at Q40 lock close — Phase 1 close activity, OUTSIDE Q40 release sequence):**
   - Verify no v1 blockers escaped to parking lot
   - Audit numbering consistency (currently #1-#55 with disorder noted at memory:1916 — cosmetic, future cleanup)
   - Cosmetic disorder cleanup
   - Maps to outer-loop Phase 1 close TaskList items

   **Q40 RELEASE SEQUENCE (post-Q40-lock; gates v1.0 ship):**
   1. Design phase complete (memory locks Q1-Q55 with 6 amendments) — **DONE at Q40 lock close**
   2. handbook PR (CDR-023 + CDR-014 amendment + ops-standards page) — Category C item 6
   3. about-handbook PR (Q22-Q28 + Q41 templates) — Category C item 7
   4. Plugin code implementation (commands + sub-skills + agents + utilities + scripts per Q30 + Q55 CLAUDE.md authored + README authored) — Category B
   5. Brand Hub retrofit dogfood per Q8 + sub-decision 4 — Category D item 8
   6. Drift-detection baseline recorded — Category D item 9 (CAN run alongside step 4 since SHAs captured at clone time)
   7. Plugin version bump 0.1.0 → 1.0.0 — Category D item 10
   8. CDR-023 status flip Proposed → Accepted — Category D item 11
   9. **TRIAGE EVENT #2 (post-v1.0, post-dogfood)** + memory archive — Category A item 2 + Category D item 12 (closes interview artifacts; re-triage based on dogfood findings, NOT the same as Triage Event #1)

   Reasoning for ordering:
   - handbook + about-handbook PRs land BEFORE plugin code so plugin can reference live URLs (per Q34/Q35 absolute-URL convention)
   - Plugin code lands BEFORE dogfood so retrofit has something to invoke
   - Dogfood lands BEFORE version flip so 1.0.0 reflects validated state
   - Version flip lands BEFORE CDR-023 Accepted so status reflects shipped reality
   - Memory archive + post-v1.0 re-triage land LAST — preserves design-rationale at terminal state + incorporates dogfood learnings

6. **v1.0 / v1.1 boundary — no parking lot items are v1.0 blockers; new Q-locks for surprises preserve schema-discipline.** Strict policy: parking lot exists as the deferral mechanism. If an item became v1.0-critical, it would have been escalated to a Q-lock during the interview, not parked. Audit step at Triage Event #1 verifies this contract holds at release time. Reverse direction: if dogfood (Category D item 8) reveals a parking lot item is actually v1.0-blocking, escalate via NEW Q-lock (Q56+) rather than silently bypass; preserves design-rationale audit trail per schema-discipline pattern. Pushback considered: pre-define "blocking-vs-non-blocking" classification on parking lot entries? Rejected — every existing entry has explicit "v1.1 candidate / v2+ tracking / deferred" framing already; reclassifying all 55 entries (post-Q40 R3 additions of #52-#55) with blocking-vs-non-blocking field is busywork. Audit-at-release-time is the right discipline.

7. **Drift-detection baseline (parking lot #45 v1.1 prerequisite) — capture at clone time, NOT at v1.0 release.** Per Q50 sub-decision 6 + parking lot #45: cloned commands (Q51/Q52/Q53) carry HTML-comment headers recording "Cloned from workflows v3.29.4 (commands/<X>.md) on 2026-05-07. Drift-detection per parking lot #45." Q40 closes the loop:
   - The headers ARE the baseline; SHAs captured at clone time per Q51/Q52/Q53 sub-decision 1 lock
   - Q40 verifies headers are present in v1.0 plugin code (Category D item 9 acceptance check)
   - v1.1 drift-detection runtime tooling consumes these headers
   - v1.0 ships with baseline IN PLACE but no runtime checker yet — that's parking lot #45's territory
   
   **Verification command at v1.0:** `grep -l "Cloned from workflows v3.29.4" plugins/flow-architecture/commands/*.md` → must return 3 files (session-start, review, ship); other commands FDA-native (no header).

**Q40 refinement audit trail (orchestrator → drafter D resolution, 2026-05-08).** Orchestrator session sent 5 refinements after Q40 draft. Drafter D's resolution of each:

1. **Form factor (architectural escalation)** → ESCALATED to user via `AskUserQuestion`; user answered "Static doc only (Recommended)" — drafter + orchestrator + user strong consensus locked. v1 simplicity preserved via Brand-Hub-dogfood-as-integration-test framing; runtime command parking lot v1.1 candidate.
2. **Q30.7 reference verification** → CONFIRMED via grep at memory:280. Q30 has 9 sub-decisions; Q30.7 is "LICENSE + README" with README.md spec ("MIT pattern + overview + install + V1 surface + CLAUDE.md pointer"). Sub-decision 3 Category B item 5 reference holds. No gap; no Q56 needed.
3. **Test surface (architectural escalation)** → ESCALATED to user via `AskUserQuestion`; user answered "No test surface for v1 (Recommended)" with EXPLICIT v1.1 parking lot framing (resolves R3's implicit-vs-explicit concern). Sub-decision 3 implicit-exclusion list amended to enumerate 4 specific items added to parking lot as #52-#55. Promotion criteria locked: any v1.x release introduces schema regression OR adds 3+ new skills/agents/utilities.
4. **Dual-event triage distinction** → APPLIED. Sub-decision 5 amended with explicit Triage Event #1 (pre-implementation, Phase 1 close, OUTSIDE Q40 release sequence) vs Triage Event #2 (post-v1.0 re-triage, Category D item 12, INSIDE Q40 release sequence). Conflation in original draft eliminated; both events now distinct in lock entry.
5. **Active-Q-count framing + 6-amendment correction** → APPLIED with PARTIAL PUSH-BACK on inherited error. User's R5 framing inherited C handoff arithmetic error ("5 amendments"); drafter D grep -c verified 6 amendment lock-entry headers exist in memory; explicit list at memory:1796 (now 1884 post-Q55-insert) had 6 entries despite intro saying 5. C handoff text corrected at memory:1884 with audit-trail note preserving the catch. Q40 Category A item 1 records "6 locked amendments" correctly.

**Validation discipline catches (preserved for handoff integrity):**

*By orchestrator on drafter D's work:*
- Surfaced Q30.7 reference verification need (refinement 2) — drafter D had cited Q30.7 without re-verifying; orchestrator forced grep-back-to-source; verified holds (Q30.7 exists with README spec)
- Surfaced test-surface implicit-exclusion gap (refinement 3) — drafter D's "doesn't apply" framing was implicit-rejection; orchestrator forced explicit decision; user lock with v1.1 parking lot framing resolves
- Surfaced dual-event triage conflation (refinement 4) — drafter D conflated pre-implementation triage (Phase 1 close) with post-v1.0 re-triage (Category D item 12); orchestrator forced split; both events now distinct
- Surfaced active-Q-count precision opportunity (refinement 5) — drafter D's "Q1-Q55" framing was imprecise; user's more-precise framing surfaced an inherited C handoff arithmetic error in the process

*By drafter D on orchestrator's work + drafter D's own work:*
- **Caught C handoff arithmetic error inherited into orchestrator's R5 framing** (validation-first discipline: 6 amendments, not 5; grep -c returned 6 amendment lock-entry headers; explicit list always had 6 entries) — drafter D push-back rejected inherited count; corrected memory:1884 with audit-trail note. Pattern: even orchestrator-corrected framings can carry inherited errors when their source artifact has the error baked in. Validation-first applies bidirectionally + transitively (inherited errors propagate through refinement chains until someone re-counts at the source).
- **Defensive parking-lot-#39 R4 application** — sibling-precedent gh API verification of cadence (no analog) + workflows (`deployment-checklist.md` at different scope) prevented form-factor-precedent-assumption errors. Caught workflows deployment-checklist as inspirational-only (not on Q40 cribbing path), reinforcing the three-way cribbing taxonomy's "different scope → not on cribbing path" classification beyond just FDA-native vs gstack-inspired vs workflows-cloned.

**Methodology lesson reinforced (D session):** validation-first discipline is bidirectional + transitive. Drafter catches orchestrator inheritance; orchestrator catches drafter recall; both catch their own prior work via re-verification. Inherited errors propagate through refinement chains until someone re-counts at the source artifact — this is the parking-lot-#39 extension principle applied to internal-process artifacts (memory file itself), not just external cribbing.

**Q40 status: LOCKED 2026-05-08 (drafter D session).** Phase I substantive design lock complete. v1.0 release gate defined; Q8 "successful" gap filled; release sequence + status flips + drift-detection baseline + design-rationale archive all sequenced. Remaining design work: Q45 + Q49 deferral-tracking locks (lightweight; can batch). Phase 1 close after that.

**Q45 — `/flow:design-consult` v1.1 deferral lock (LOCKED 2026-05-08, drafter D session — TRACKING-ONLY).** Confirms Q1 deferral (memory:481, 487) with explicit promotion criteria. NOT a substantive design lock. Original framing: "greenfield-only; no consumer queued; future state hint = canonical Brite design-system repo at Q49."

**Status:** DEFERRED v1.1.

**Promotion criteria (any one triggers v1.1 design work):**
1. v1.x dogfood reveals design-exploration gap not covered by `/flow:office-hours` (Q42) or `/flow:plan-design` (Q43 + plan-design-reviewer per Q21:397)
2. gstack design-consultation interview branches (Q42 sub-decision 7 NOT-transferred per memory:924) become valuable enough to crib — apply parking-lot-#39 verification at v1.1 design-time per Q50 three-way cribbing taxonomy
3. Consumer queues that needs design-consultation skill separate from project-intent (Q42) and discipline planning (Q43) — current state has no consumer

**Cross-references:**
- Q1 lock (memory:481, 487) — original deferral
- Q42 sub-decision 7 (memory:918-924) — gstack design-consultation NOT-transferred branches
- Q21 plan-design-reviewer (memory:397) — overlap concern that drove deferral
- Parking lot #9 / Q49 lock entry below — future-state cross-link to canonical Brite design-system repo
- BriteBase `docs/design-system.md` (memory:1864) — 477-line single-product reference; "way more mature than gstack design-consultation output"

**Pre-conditions:** none specific. v1.1 candidate triggered by any single promotion criterion above.

**Q45 status: LOCKED 2026-05-08 (drafter D session) — DEFERRAL-TRACKING.**

**Q49 — Canonical Brite design-system repo v2+ tracking lock (LOCKED 2026-05-08, drafter D session — TRACKING-ONLY).** Elevates parking lot #9 (memory:1887) to formal Q-lock entry. NOT a substantive design lock; v2+ scope (NOT v1.1; NOT a v1.0 blocker).

**Status:** v2+ tracking.

**Pre-conditions (must hold BEFORE v2+ design work begins):**
1. Brand Hub retrofit succeeds per Q8 v1.0 acceptance gate (Q40 sub-decision 4) — must happen FIRST
2. Brand Hub design-system reaches stability post-retrofit (independent design-system maturity)
3. Second product (likely BriteBase post-Phase-4 stabilization) reaches design-system maturity independently

**Promotion criteria (any one triggers v2+ design work after pre-conditions hold):**
1. Cross-product theming/token-sharing demand surfaces (vs current single-product reference at BriteBase `docs/design-system.md` per memory:1864)
2. Second Brite product launches that needs design-system sharing with first

**Cross-references:**
- Parking lot #9 (memory:1887) — original entry; this Q49 lock formalizes the v2+ tracking
- Q22-Q28 promoted templates pattern in `handbook/about-handbook/style-guide/templates/` (per Q2 lock memory:35) — analogous shared-asset extraction pattern
- BriteBase `docs/design-system.md` (memory:1864) — 477-line current single-product reference; extraction source if v2+ design proceeds
- Q45 lock entry above — `/flow:design-consult` evolves to "pull from canonical + customize" pattern when Q49 promotes to v2+ design

**v2+ design scope sketch (NOT designed in v1):** new repo at `Brite-Nites/brite-design-system/` (or similar) housing tokens + Brite* primitives + theming layer; FDA `/flow:design-consult` (Q45 v1.1 if landed) extends to "pull from canonical Brite design-system + customize for project context." Token-sharing convention + component library extraction pattern + cross-product CI for design-system regression.

**Q49 status: LOCKED 2026-05-08 (drafter D session) — DEFERRAL-TRACKING.**

**Q49 amendment 1 — `Brite-Nites/brite-design-system` repo already exists (LOCKED 2026-05-10, drafter D session per Step 2.B pre-flight catch).** Q49 lock content + parking-lot #9 origin both framed canonical Brite design-system repo as "future" / "v2+" — claimed extraction from BriteBase docs/design-system.md as the v2+ design work. **Step 2.B pre-flight enumeration `gh api orgs/Brite-Nites/repos --paginate` 2026-05-10 surfaced** that `Brite-Nites/brite-design-system` already EXISTS at `https://github.com/Brite-Nites/brite-design-system` (created 2026-02-03; description: "Shared component library and design token system for all Brite brands. shadcn/ui, Tailwind v4, Radix — Issues tracked in Linear"). Q49's "v2+ future canonical" framing is partially obsolete — the repo exists, but Q49's pre-conditions (Brand Hub retrofit succeeds + design-system stability + second product launches needing sharing) still apply for v2+ design work. **Updated v2+ scope sketch:** instead of "extract BriteBase docs/design-system.md + Brite* primitives into NEW repo", the v2+ work becomes "evaluate alignment of FDA design-system needs with existing `Brite-Nites/brite-design-system` repo + augment if needed." Status remains v2+ tracking (NOT promoted to v1.1) because pre-conditions still gate. Cross-link with parking-lot #9 origin reference + Q45 lock entry. **Methodology note:** this is the second factual claim in memory invalidated by Step 2.B pre-flight reality-check (the first being about-handbook subdirectory finding); both surfaced via `gh api orgs/Brite-Nites/repos --paginate` enumeration as part of parking-lot-#39 namespace-collision discipline.

**Q45 + Q49 audit trail (orchestrator → drafter D batch resolution, 2026-05-08).** Both surfaced as single AskUserQuestion batch (per-Q for individual promotion-criteria edits if needed). User answered "Confirm v1.1 deferral" + "Confirm v2+ deferral" — strong drafter+orchestrator+user consensus on both. **Tracking-only locks; NOT substantive design** — lock entries serve as audit-trail formalization of decisions already implicit in prior locks (Q1 deferred Q45; parking lot #9 placed Q49 at v2+). Pre-draft parking-lot-#39 lite verification done (memory grep for `/flow:design-consult` + `design-system repo` mentions; no missed cross-references; no external cribbing required for deferral locks).

## Validated handbook conventions (verified 2026-05-06/07 during interview)

Empirically-verified handbook structure facts. Reusable across Q-passes that author/amend handbook content or interact with Linear MCP. Centralized here to avoid re-grep cycles in future sessions.

1. **CDR file path convention:** `Brite-Nites/handbook/decisions/CDR-NNN-<slug>.md` (gh API verified — sampled CDR-013 / CDR-014 / CDR-016 / CDR-019; all match).
2. **CDR front-matter schema (verified across 4 sampled CDRs):** `cdr_id` / `title` / `status` (Proposed/Accepted/...) / `date` / `author` / `category` (process/tech/...) / `agent_context`. **NO `last_amended` field** in any of the 21 CDRs in the handbook (sampling at lock time confirmed uniform absence).
3. **Operating-standards file path:** `Brite-Nites/handbook/how-we-work/operating-standards/<topic>.md` (gh API verified — milestones, projects, issues, cycles, lifecycle, hierarchy, labels, sizing, documents, enforcement, processes-and-rituals, initiatives, README all present).
4. **Operating-standards front-matter schema (verified milestones / projects / issues / cycles):** `title` / `agent_context: operating-standards-<topic>` / `last_reviewed: <ISO-8601>` / `refresh_cadence: quarterly` / `owner: holden-halford`. **NO `last_amended` field** in any sampled operating-standards page.
5. **`milestones.md` operating-standards structure (~7800 bytes; ~150 lines):** 18 H2/H3 sections. `## Quality gate` (line 84) has 4 sub-sections: `### Deterministic checks (block-with-override)` / `### Informational signals (never block)` / `### Where the gate is invoked` / `### Override flow` (line 111). **Override flow is a sub-section under Quality gate, NOT a peer ## section.** This precedent informed Q34's structure (8 H2 sections with `### Override flow` demoted under `## Quality gate`).
6. **CDR-014 structure (~150 lines; 16 H2/H3 sections):** Status / Context / Decision (with sub-sections: Linear field mapping / Description template / Pattern migrations / Quality gate / Enforcement architecture / Retro-fix agents / Build order) / Alternatives considered / Consequences (Positive / Negative) / Exceptions (currently "None identified") / Related. Standard CDR shape.
7. **BriteBase master-flow-inventory shape:** front-matter `last_reviewed` only; status block enumerating 6-state taxonomy + BLOCKED orthogonal flag; numbered top-level groupings (`## 1. PLATFORM FOUNDATIONS`, etc.); per-domain section `### <DOMAIN> — <Display name> (<N> flows)` with metadata line `Status map: <map> | Journey: <BC>`; per-domain table columns `# / Flow / Status / Notes`; **Status column intentionally blank** on initial landing.
8. **BriteBase domain count: 28** (grep `^### [A-Z]+ — ` against `docs/product/master-flow-inventory.md` returns 28). Domain codes: AUTH / TNT / TEAM / CLI / PROP / APPT / SURV / TMPL / QUO / QLIFE / CPUB / PDF / HAND / WO / SCHED / SA / CREW / MOBILE / BOM / PROD / PKG / INV / STRIKE / RENEW / BILL / DASH / LR / INTEG.
9. **TEAM domain: 8 sub-flows** (TEAM-01 through TEAM-08). QUO domain: **43 sub-flows** (`grep -E "^\| QUO-"` returns 43).
10. **Brand Hub "27" disambiguation:** that count is **LEGACY-milestone count from pre-FDA state**, NOT FDA-domain count. Post-retrofit FDA-domain count for Brand Hub is determined at runtime by `/flow:retrofit-project` — embedding any number in handbook content is misleading. Drafter B's Q34 originally said "Brand Hub has 27" before validating; correction landed before lock.
11. **Linear MCP project response shape:** `mcp__plugin_workflows_linear-server__list_projects` returns `{id, name, status, owner (= project.lead.name or null)}`. **Does NOT include `team_key`** — team_key requires a separate `mcp__plugin_workflows_linear-server__list_teams` fetch (cadence Phase 0 precedent: "one-time `list_teams` lookup of `'Brite Company'`"). This shape was verified against `plugins/cadence/commands/weekly.md` source.
12. **Plugin .mcp.json conventions:** Cadence registers empty `{"mcpServers": {}}` and depends on workflows plugin's Linear MCP per BC-5810 § 4 + BC-5811 § 4.2 (duplicate registration breaks tool routing). Workflows plugin registers 3 MCPs: `sequential-thinking` (npx stdio) + `linear-server` (https mcp.linear.app/mcp) + `context7` (https mcp.context7.com/mcp). FDA mirrors cadence's empty-mcpServers approach (Q30.4 lock).

## Critical references for the interview

- `Brite-Nites/handbook/how-we-work/operating-standards/` (external, gh API) — projects.md (CDR-013), milestones.md (CDR-014), issues.md (CDR-016), labels.md (CDR-018), hierarchy.md (CDR-019), lifecycle.md (CDR-021)
- `Brite-Nites/brite-claude-plugins/plugins/cadence/` (external) — closest analog plugin pattern (5-phase + breadcrumb + AskUserQuestion gates)
- `Brite-Nites/brite-claude-plugins/plugins/workflows/` (external) — clone source for session-start, brainstorming, writing-plans, review, ship
- `EveryInc/compound-engineering-plugin/plugins/compound-engineering/skills/` (external) — `lfg/SKILL.md` (orchestrator pattern), `ce-optimize/SKILL.md` (resume pattern). Path is `plugins/compound-engineering/skills/<name>`, NOT top-level.
- `garrytan/gstack` (external) — INSPIRATION source. Skills are TOP-LEVEL DIRS at repo root (office-hours/, plan-ceo-review/, plan-eng-review/, plan-design-review/, plan-devex-review/, autoplan/, qa/, retro/, review/, ship/, land-and-deploy/, design-consultation/, document-release/). NOT a plugins/<name>/ structure.
- `docs/designs/flow-issue-architecture.md` (in brite-base) — RFC + Phase 2 pilot review section (2026-05-06)
- `docs/handbook/agent-authoring.md` (in brite-base) — 8 lessons-learned rows
- `docs/product/master-flow-inventory.md` (in brite-base) — example inventory; 11-column INDEX schema validated in TEAM section
- `docs/templates/{job-story,domain-journey}.md` + `docs/templates/issues/{parent,story,engineering,design,qa,docs}.md` (in brite-base) — existing templates that Q22-Q27 modify
- `docs/design-system.md` (in brite-base) — 477 lines; way more mature than gstack design-consultation output
- `docs/product/journeys/team.md` (in brite-base) — example domain journey, 446 lines
- `docs/product/flows/INDEX.md` (in brite-base) — 64 lines, schema validated by TEAM section

Brand Hub Linear project: id `61d8cd9b-67ba-4e62-b474-81d9ccf36d31`, lead Sarah Cullen.

## Linear MCP gotchas to remember

- `estimate` field rejects fractional values with misleading `auth_invalid` error. Use integers only (1, 2, 3, 5, 8).
- Markdown bullet parser drops items in long lists. Use numbered lists for >3 items, items >15 words, or items with BC-XXXX references.
- BC- prefix = Brite Company team; this repo uses BC-XXXX, NOT BRI-XXXX.
- `get_issue` doesn't return `blockedBy` by default — pass `includeRelations: true` if needed.

## Parking lot follow-ups

1. Re-evaluate workflows plugin split (inner-loop vs outer-loop) once FDA mature
2. Wire FDA → /workflows:project-start handoff in v2 (Q4 Option A)
3. Retrofit cadence plugin to artifact-existence gates (from Q7 Superpowers research)
4. Audit existing orchestrator skills for `disable-model-invocation: true`
5. BC-6774 (backfill-vs-greenfield doc) blocks Phase 4 LR warm-up — separate from this interview
6. Issue-level cross-reference annotations (deferred from Q9, v1.1+)
7. `--auto-accept-priors` flag for `flow-inventory-codebase-scan` Phase 5 confirmation interview at scale (v1.1)
8. Standalone `/flow:review-{project,domain,sub-flow}` skills for re-running multi-perspective review at any layer (v1.5+)
9. Canonical Brite design-system repo (Q49) — extract BriteBase's docs/design-system.md + Brite* primitives into shared repo, /flow:design-consult evolves to "pull from canonical + customize" (v2+). **Formalized at Q49 lock 2026-05-08 (drafter D session) — see Q49 lock entry above for full v2+ tracking with 3 pre-conditions + 2 promotion criteria + cross-references. This parking lot entry preserved as origin reference; Q49 lock is the canonical formalization.**
10. Graduation criteria for FDA-cloned vs workflows skills (post-dogfood) — needs explicit enumeration
11. Per-phase `last_reviewed` timestamps in journey doc (Q26 mod 6) — v1.1
12. `last_synced_to_linear` timestamp in story-doc front-matter (Q27 mod 3) — v1.1
13. Customer-doc URL as 12th INDEX column (Q25 pushback) — v1.1 if real usage shows the click is annoying
14. `.flow/config.json` future fields: `preferred_mode_override`, `app_classifier_cache`, `last_inventory_regen_at`, `linear_team_id` (UUID) — v1.1+
15. `flow-legacy-cross-reference` Tier 3 LLM fallback wall-time — re-measure once skill is built. Theoretical ~10s assumes unlimited concurrency; realistic ~5-15s assuming fan-out caps at 6-10 concurrent + most milestones hit Tier 2. v1 perf-tuning detail.
16. **Q22-Q28 template file edits outstanding in BriteBase `docs/templates/`.** Not blocking v1 since plugin ships fresh templates with modifications baked in (Brand Hub gets templates from plugin, not BriteBase). Becomes load-bearing only if/when BriteBase adopts the FDA plugin (post-Phase-4, not v1). Caught during Q15 validation 2026-05-06.
17. **Q27 mod 1 (`intent: ../../intent.md` field addition) specifically not in `docs/templates/job-story.md`.** 1-line edit if/when it becomes urgent. Sub-finding of #16; called out separately because it's the specific case Q15.1's deterministic substitution depends on.
18. **`_shared/code-evidence-collector.md` DRY shared utility** — between Q11 Phase 3 (`flow-inventory-codebase-scan` deterministic code scan) and Q15.7 (`flow-doc-author` retrofit code-evidence). Both use Glob/Grep/Read for the same shapes; extract once, consume from both. v1.1 refactor candidate.
19. **v1.1 "selective re-author" mode + `/flow:journey-refresh` command — extended scope per Q47 lock 2026-05-07.** Originally tracked for `flow-doc-author` (preserve existing body content, refresh deterministic front-matter only when scaffold output changes — useful when new BC numbers land but narrative is hand-edited). **Q47 sub-decision 5.5 extension**: same selective-re-author concern applies to `flow-journey-author` (narrative-heavy doc with expected manual editing; --force regeneration would clobber hand-edits). v1.1 expansion: (a) extend selective-re-author mode to flow-journey-author (refresh only the new sub-flow's row in job-stories table + relevant phase narrative); (b) add `/flow:journey-refresh` command (currently NOT in Q30.2's 17-command list — Q30 amendment territory; v1.1 +1 to 18 commands). Q47 v1 emits warning text at /flow:add-sub-flow completion documenting the gap.
20. **`flow-sandbox-scaffold` original framing was TEAM-precedent-based.** The "one harness per QA-cycle target" line in early "Internal architecture" notes reflected the Phase 2 BriteBase pilot where only TEAM-04 (the chosen pilot) got a harness; the other 7 sub-flows didn't. For production v1 (Brand Hub-shaped retrofit), the per-flow on-demand semantic at L4 (Q17 lock 2026-05-06) is correct: every flow with [Eng] or [QA] work gets a harness. If Brand Hub dogfood reveals the per-flow footprint is actually wasteful (most flows never need a sandbox harness because QA happens in-app), reconsider the choice — file as v1.1 perf-tuning issue.
21. **`flow-regen-index --force-upgrade-headers` flag (v1.1).** Auto-upgrades legacy INDEX.md section headers to Q25 mod 1's amended schema (adds `[📕 journey]` + `[📍 milestone]` emoji-prefixed links). Currently flagged via Q18.4 post-regen soft-warning; manual upgrade is the v1 path. Implement when (a) ≥3 user complaints surface OR (b) Brand Hub dogfood reveals manual upgrade is too tedious for 27+ domains.
22. **Q25 mod 1 amended at Q18 lock 2026-05-06** to use emoji-prefixed link convention (`[📕 journey]` + `[📍 milestone]`) for consistency with Story column's `[📄](link)` convention. The actual `docs/product/flows/INDEX.md` file's existing TEAM + QUO section headers don't yet match the amended schema (parking lot #16 territory — outstanding template-file edits in BriteBase). Brand Hub gets the amended schema fresh from the plugin; BriteBase's INDEX.md upgrades manually post-Phase-4 if needed.
23. **Flow ID padding convention beyond 99 flows.** v1 uses 2-digit zero-pad matching existing pattern (`TEAM-08`, `AUTH-11`). No domain hits 100 in v1; defer to v1.1+ if the issue surfaces. Likely change: `<DOMAIN>-001` 3-digit pad once any domain crosses 99 flows.
24. **Notes column default content for `flow-inventory-add` (Q20.1).** For sub-flow-add: default is user-provided free-form context (route hints, component names, scope refs) — matches Q11 retrofit Notes content type; empty acceptable. For domain-add: inherits Q19's scope-priority tag pattern (`mvp` / `nice-to-have` / `post-launch`). One-sentence clarification could land in Q20.1 itself; tracked here for v1.1 docs polish.
25. **`[DEPRECATED]` marker support is out of scope for Q20.** Per CLAUDE.md: "If deprecated, mark `[DEPRECATED]`, don't delete." That's a separate operation (probably future `/flow:deprecate-flow` skill). Track here so the deprecation operation isn't lost from the design — needed eventually for retiring legacy flow IDs without violating the "never rename existing IDs" rule. v1.1+ design candidate.
26. **`journey-doc-author` model upgrade from sonnet to opus (v1.1).** Q21 locks sonnet for v1; journey docs are narrative-heavier and longer-context (TEAM precedent: 447 lines) so opus may produce higher-quality output. Defer the upgrade until v1.1 quality issues surface during Brand Hub dogfood. Cost trade-off: opus is more expensive per token; for a cross-domain authoring run (28 domains × ~60-90s × N tokens), the cost difference is meaningful. Re-measure once v1 is in-flight.
27. **`linear-children-match` gate batch optimization — amended scope per Q38 lock 2026-05-07.** Q29.3 originally locked per-child `get_issue` (~125s on 50-flow project) with v1.1 deferral to batched `list_issues({labels: ["domain:<slug>"]})` per domain (~14s on 28-domain project). **Q38 sub-decision 3 hybrid resolution (user-locked 2026-05-07):** adopt batched pattern **inline in Q38 v1** (captures ~111s savings during Brand Hub dogfood; auto-invocation from /flow:ship + /flow:plan-{discipline} compounds the savings). **Parking lot reframed (NOT closed):** promote to `_shared/linear-batched-list-pattern.md` shared utility in v1.1 IF a third caller (e.g., Q43 plan-{discipline}, Q53 ship, Q46 Linear writeback) also needs the pattern. Three-callers DRY threshold avoids premature extraction. Pattern reference: Q18.3's inline batching (Q18 itself uses it inline, not as shared utility — that's the v1 baseline two callers).
28. **HTTP HEAD on figma URLs (v1.1 candidate, Q29.2 [Design]).** Q29.2 locks the figma-field-populated check (regex match for node-id URL); HTTP HEAD against the URL would catch dead Figma links but may not work for private frames (Figma auth required). Track for evaluation if real usage shows broken-figma-link drift. Skip if HEAD requires auth — the regex check is sufficient as the v1 floor.
29. **`python3` dependency for Q31.5 write-then-verify helper.** Helper invokes `python3 -c 'import json,sys; json.loads(...)'` to verify breadcrumb JSON parses cleanly post-write. Add to plugin CLAUDE.md (Q55) as required dependency alongside `bash`, `git`, `gh`. python3 is pre-installed on macOS; Linux dev environments should have it; document the requirement explicitly so Brand Hub dogfood doesn't surface as a missing-dep failure.
30. **3-pattern FDA-state storage split.** `.flow/config.json` (committed; project-stable mapping) + `.flow/scaffold-log/<domain>.md` (transient idempotency cache) + `docs/plans/.flow-phase-state.json` (transient run state). Three locations for FDA-internal state. Locked across Q12 + Q13 + Q31 — not changing in v1 (would re-open Q12's path lock + Q13's log-location lock). **Potential consolidation:** `.flow/` root for committed config + `.flow/state/` (or `.flow/runtime/`) for transient state. Re-evaluate post-Brand-Hub-dogfood if the split feels awkward; don't churn the locks until empirical signal.
31. **L1/L2/L3 review state not captured in `.flow-phase-state.json`'s `phase_status` (Q31.1).** Per Q31 schema, per-domain `phase_status` covers `linear-scaffold` / `doc-author` / `journey-author` — not the multi-perspective review phases (L1 in office-hours, L2 during inventory synthesis, L3 during scaffolding). On crash mid-multi-perspective-review, resume re-runs the whole review phase. v1 acceptance: L-reviews are minutes-scale (not hours-scale like full scaffolding); re-running 5-perspective L3 takes ~2-5 min, acceptable. v1.1 candidate: extend `phase_status` with optional `review_status: { l1: {...}, l2: {...}, l3_per_subflow: {...} }` if dogfood reveals re-running reviews is a real pain point (e.g., user crashed during the 25th of 28 L3 reviews and re-running all 25 wastes 50+ min).
32. **macOS bash 3.2 constraint as authoring guideline (Q32).** Every helper script in `scripts/` ships with explicit shebang + comment header documenting the constraint:
   ```bash
   #!/usr/bin/env bash
   # Target: bash 3.2 (macOS default — Apple stopped bundling bash 4 due to GPL3).
   # Avoid: associative arrays, mapfile, ${var,,} lowercase, other bash-4-only features.
   ```
   Reinforces the constraint at the point of authoring; future contributors don't accidentally introduce bash-4 syntax that breaks macOS dev environments. Apply across all 4 helper scripts (flow-detect-mode, flow-detect-fda-shape, flow-resume-breadcrumb, flow-context-load) + any v1.1+ additions.

33. **Per-org FDA bootstrap (v1.1+ candidate).** When a Brite-Nites org first adopts FDA, the deps land manually: maintainer creates PRs in `Brite-Nites/handbook` covering (a) CDR-023 + operating-standards FDA page in `decisions/` + `how-we-work/operating-standards/` and (b) Q22-Q28 + Q41 templates in `about-handbook/style-guide/templates/` subdirectory. **Updated 2026-05-10 per Q2 amendment 1:** about-handbook is a subdirectory of the handbook repo, NOT a separate `Brite-Nites/about-handbook` repo (original parking-lot text incorrectly framed as separate-repo PR; corrected inline to reflect actual handbook structure verified via gh API). Plugin-assisted PR creation orchestrator (`/flow:setup-org` hypothetical) parked as v1.1 candidate per Q36 user lock. Defer until real demand surfaces (likely never — maintainer can hand-craft initial PRs in <1 hour for a one-time operation). v1 stance: CLAUDE.md (Q55) documents the prerequisite that handbook (including about-handbook subdirectory) deps must exist before plugin runs.
34. **`flow-preflight` two-code-path acceptance (Q36 user lock).** Q36 locked bootstrap embedded in `flow-preflight` (vs. dedicated `flow-bootstrap` sub-skill). User accepted the trade-off: `flow-preflight` has two code paths (fast already-bootstrapped check vs 7-step interview). Refactor to dedicated `flow-bootstrap` sub-skill at v1.1 if the embedded approach gets unwieldy in real usage. Trigger criteria for the refactor: (a) `flow-preflight` SKILL.md exceeds ~500 lines with bootstrap-specific content dominating; (b) bootstrap flow needs additional sub-skills it can't easily compose from inside preflight; (c) testing `flow-preflight` requires bootstrap-flow stubs that complicate the test surface.

35. **Fail-and-prompt clobber detection for Q46 marker regions (v1.1 candidate per Q46 sub-decision 4 user lock 2026-05-07).** Q46 v1 uses clobber-with-warning for user edits inside `<!-- FDA-WRITEBACK-<type>-START/END -->` markers. v1.1 enhancement: Q46 hashes last-known Q46-written content (stored in `linear_writeback_state.last_content[]`); reads current marker content; if hash mismatch → AskUserQuestion "Detected user edit inside <type> markers; overwrite / preserve / abort?" Promote if Brand Hub dogfood reveals real edit-loss incidents. Cost: more breadcrumb schema (last_content hashes); AskUserQuestion mid-run interrupts flow. Trade against the unproven concern that machine-managed-region contract isn't loud enough.

36. **`--linear-surface` flag for /flow:audit (Q38 amendment 1 territory; v1.1 candidate per Q46 sub-decision 7 + Q38 deferred-decision resolution 2026-05-07).** v1: /flow:audit stays strictly local (stdout + `--json` only); no Linear writeback. v1.1: add `--linear-surface[=parent|milestone]` flag (requires Q38 amendment 1) routing audit findings through Q46 as `audit-concerns` body-section or comment on chosen surface. `audit-concerns` marker type already registered in Q46's `_shared/linear-writeback-pattern.md` enum but unused in v1 — reserved for this promotion without further Q46 amendment needed. Promote if Brand Hub dogfood reveals team-visibility demand for audit findings.

37. **Q42 L1 concerns Linear routing (v1.1 candidate per Q42 sub-decision 4 + Q46 sub-decision 7).** v1: Q42 L1 review concerns persist to `docs/plans/l1-concerns-<ISO-8601>.md` (filesystem only); headlines populate intent.md L1 review summary section. v1.1: Q46 routes concerns to Linear via new `l1-concerns` marker type as comment on Linear project's parent issue or milestone. Requires Q46 type registry amendment (add `l1-concerns` to enum) + Q42 amendment to call linear_writeback() in addition to filesystem write. Promote if dogfood reveals team-visibility demand for L1 perspective concerns.

38. **Cross-skill notification rate-limiter for Q46 (v1.1 candidate per Q46 sub-decision 5 user lock 2026-05-07).** Q46 v1 has no global cross-skill throttle — each skill responsible for its own batch; Q55 plugin CLAUDE.md documents the convention ("prefer single parent comment with sub-sections per child when writes target sibling issues sharing a parent"). v1.1 enhancement: Q46 enforces global rate-limiter (e.g., max N writes per Linear issue per N-minute window) regardless of which skill initiates. Promote if Brand Hub dogfood reveals comment-spam patterns despite per-consumer batching discipline. Linear's notification cost amplifies with multi-skill coordination — global throttle is the floor.

39. **Cribbed-content lock-prerequisite — verify source via gh API or repo read BEFORE drafting (methodology note added per Q48 lock 2026-05-07 user lock; extended per Q51 lock 2026-05-07 user lock).** Q48 near-miss revealed drafter recall of cribbed source material is unreliable: drafter C cribbed an imagined verdict-axis taxonomy (APPROVED/ADJUSTED/REWORK/CLARIFY) for the four-mode framework when gstack's actual taxonomy is scope-axis (SCOPE_EXPANSION/SELECTIVE_EXPANSION/HOLD_SCOPE/SCOPE_REDUCTION). Orchestrator forced verification; gh API read of `repos/garrytan/gstack/contents/plan-ceo-review/SKILL.md` revealed the divergence; Q48 fully redrafted. Without verification, Q48 would have locked fundamentally wrong. **Apply this discipline to all future cribbings:**
   - **Q44** (`/flow:retro` skill design) — APPLIED 2026-05-07 (gh API verification of gstack `retro/SKILL.md` confirmed time-windowed/commit-based shape; Q44 honestly cribbed only 5 verbatim section headers + enumerated 7 NOT-transferred features; methodology working as designed)
   - **Q50** (clone-and-swap scope from workflows plugin) — APPLIED 2026-05-07 with EXTRA RIGOR (foundation for 3 downstream cloned-skill locks; gh API verification of workflows v3.29.4 manifest + 24 commands + 24 skills + 15 agents + MCPs; surfaced 2 stale memory:26 references corrected via supersedure note)
   - **Q51** (cloned session-start) — APPLIED 2026-05-07 with RE-VERIFICATION at downstream lock (caught Q50 sub-decision 5's step-count + step-swap-location errors via gh API re-grep; Q50 amendment 1 written; methodology lesson: prior locks can be wrong; downstream re-verification catches drift between lock-time understanding and verified source truth)
   - **Q52, Q53** (cloned review + ship — pending) — verify workflows source AT EACH lock, not just inherit Q50/Q51 verifications
   - **Any future cribbing from gstack / compound-engineering / workflows / external sources** — verification step is mandatory pre-draft; not optional
   - **Validation-first cycle catches errors mid-flight at multiple levels** — orchestrator → drafter (Q48); drafter → orchestrator (Q43 refinement 1 push-back); drafter → drafter's own prior work (Q51 catching Q50 errors). All three patterns are design-essential.
   - **Drafter recall ≠ source truth** — this is the operational lesson; build verification into the drafter habit before any cribbed content reaches the lock
   - **Re-verification AT EACH cribbed-content lock (Q51 extension 2026-05-07):** parking-lot-#39 discipline applies AT EACH lock, not just first cribbing. Inheriting prior verifications is faster but loses re-verification's catch capability. When in doubt, re-grep.
   - **Org-level namespace extension (D session 2026-05-08, first execution-phase application):** parking-lot-#39 discipline extends beyond external cribbed sources (gstack / workflows / compound-engineering) to **org-level artifact namespaces** that may have parallel claimants — CDR numbers, template paths, file paths in shared repos (handbook + about-handbook subdirectory + plugin repo). Drafter D Step 2.A pre-flight gh-API verification caught CDR-022 collision (handbook's `CDR-022-asset-taxonomy.md` was Accepted 2026-05-06 same-day as Q33's FDA CDR-022 lock); resulted in Q33/Q34/Q35 amendments 1 renumbering FDA CDR to CDR-023 + 24 cross-reference updates throughout memory. **Methodology lesson:** pre-flight verification at draft time MUST include namespace-collision checks against authoritative org artifacts via gh API (`repos/<org>/<repo>/contents/<path>` enumeration); same-day or parallel-session collisions are real risk for high-frequency artifact namespaces.
   - **Repo-existence + subdirectory-vs-repo extension (D session 2026-05-10, second execution-phase application — Step 2.B pre-flight catch):** the namespace-collision discipline applies not only to (a) external cribbed sources and (b) parallel-claimant collisions but also to (c) **assumed-existing org-level artifacts that don't actually exist** AND (d) **assumed-separate repos that are actually subdirectories of larger repos**. Drafter D Step 2.B pre-flight `gh api repos/Brite-Nites/about-handbook` returned 404; subsequent enumeration `gh api orgs/Brite-Nites/repos --paginate` confirmed `about-handbook` is a subdirectory of the existing `handbook` repo (not a separate org-level repo as memory had assumed since Q2 lock 2026-05-06). Same enumeration also surfaced `Brite-Nites/brite-design-system` already exists (created 2026-02-03), invalidating Q49's v2+ "future canonical repo" framing. Resulted in Q2 amend 1 + Q22 amend 1 + Q28 amend 1 + Q41 amend 1 + Q33 amend 2 + Q34 amend 2 + Q49 amend 1 + parking-lot #33 inline correction. **Methodology lesson:** `gh api orgs/<org>/repos --paginate` enumeration at pre-flight is a cheap reality-check that surfaces both subdirectory-vs-repo confusion AND repo-already-exists assumptions — both are factually-wrong-claims that propagate through downstream lock content (e.g., absolute URLs, parking-lot framings) when not verified. Apply this `--paginate` enumeration as standard pre-flight ALONGSIDE the `repos/<org>/<repo>/contents/` collision check; together they cover (a) namespace collision + (b) repo-existence + (c) repo-vs-subdirectory + (d) repo-already-exists patterns.

40. **Auto-trigger /flow:retro from /flow:ship hook (v1.1 candidate per Q44 sub-decision 2 user lock 2026-05-07).** Q44 v1 is manual-only. v1.1 enhancement: when /flow:ship (Q53 — pending) detects "this is the last sub-flow in domain shipping", auto-invoke /flow:retro. Captures retro at peak-momentum moment when team context is freshest. Cost: Q53 needs awareness of "domain-last-sub-flow" detection logic (query Linear for `state.type=completed` count vs `domains[N].completed_sub_flows[]` length); couples Q44 to Q53 lock. Could be opt-in via `.flow/config.json` field `auto_retro_on_ship: true` to avoid surprising users who don't want auto-retros. Promote if Brand Hub dogfood reveals user discipline gaps (forgot to run retro / momentum lost between ship + retro).

41. **Cross-domain comparison via --cross-domain time-window flag (v1.1 candidate per Q44 sub-decision 3 user lock 2026-05-07).** Q44 v1 is single-domain only. v1.1 enhancement: `/flow:retro --cross-domain [<window>]` flag (e.g., `/flow:retro --cross-domain 30d`) compares all completed milestones over time window. Adds gstack-style trends-vs-prior comparison (per gstack retro `Trends vs Last Retro` section). Output: cross-domain comparison markdown at `docs/retros/cross-domain-<YYYY-MM-DD>.md` + Linear comment routing TBD (likely on a project-level surface; not per-milestone). Cost: extra args + dual-mode logic; agent needs to handle both scope semantics. Promote if user dogfood requests longitudinal retro view across domains.

42. **Q22 amendment 1: retro-summary body marker section (v1.1 candidate per Q44 sub-decision 4 user lock 2026-05-07).** Q44 v1 routes Linear retro to comment surface only (Q22 milestone description doesn't reserve a retro slot). v1.1 enhancement: Q22 amendment 1 adds `## Retro summary` section with empty `<!-- FDA-WRITEBACK-retro-summary-START -->` / `<!-- FDA-WRITEBACK-retro-summary-END -->` markers (parallel to Q24 amendment 1 Plan-section pattern); /flow:retro Linear writeback shifts from `surface: 'comment'` to `surface: 'body'`. Promote if Brand Hub dogfood reveals body-surface preference for Linear-side retro visibility (more discoverable than scrolling through milestone comments).

43. **"Plan Completion" cross-skill-state mining for Q44 retros (v1.1 candidate per Q44 sub-decision 6 user lock 2026-05-07).** gstack retro reads `~/.gstack/projects/$SLUG/*-reviews.jsonl` for ship-time plan completion data. FDA equivalent: Q44 mines Q46's `linear_writeback_state.written_pairs[]` (Q31 amendment 2) from prior runs to determine plan-X-section completion percentage per discipline-child. Excluded from v1 because cross-skill-state mining is broader scope than Q44 alone (would need Q43/Q53/etc. lock awareness). Promote when Q53 ships + dogfood reveals plan-completion-tracking value for retros.

44. **Team retro facilitation features for Q44 (v1.1 candidate per Q44 sub-decision 5 user lock 2026-05-07).** Q44 v1 is AI-only synthesis from artifacts (no team retro facilitation). v1.1 enhancement: multi-participant input collection (each team member submits "what worked / level up" notes); voting on top items; synthesis from multi-perspective notes → consolidated retro. Cost: significant UX expansion; multiple AskUserQuestion rounds; per-participant input gathering. Promote if dogfood reveals AI-only synthesis is insufficient for team-driven retros (users want to facilitate via Q44 instead of just summarize).

45. **Drift-detection for cloned workflows commands (v1.1 candidate per Q50 sub-decision 6 user lock 2026-05-07).** Q50 v1 accepts drift between FDA-cloned commands (Q51/Q52/Q53) and upstream workflows source (currently v3.29.4). v1.1 enhancement: periodic gh API check of `repos/Brite-Nites/brite-claude-plugins/plugins/workflows/commands/{session-start,review,ship}.md` content hashes vs FDA-clone's source-comment-recorded hash (each FDA-clone's HTML-comment header would record "Cloned from workflows v3.29.4 SHA <hash>"); surface drift warnings via flow-preflight check or dedicated `/flow:audit-clone-drift` command. Cost: implementation + scheduled invocation surface. Promote if Brand Hub dogfood reveals workflows updates are causing FDA-clone behavior drift (e.g., workflows session-start gains a Step 9 that FDA-clone misses).

    **Promoted to advisory CI guard via BC-7060 (2026-05-12).** Implementation: `plugins/flow-architecture/scripts/check-clone-drift.sh` + advisory `clone-drift-check` job in `.github/workflows/validate-plugin.yml` (continue-on-error: true). Script reads each clone's `Upstream-SHA:` header (per Q51/Q52/Q53.1 amendment 1), resolves current upstream blob SHA via `git rev-parse origin/main:...`, classifies drift as trivial (≤5 lines + whitespace-only → WARN, exit 0) vs substantive (FAIL, exit 1). Companion regression test at `plugins/flow-architecture/tests/test-clone-drift.sh` exercises all three classifier paths on every PR via the `vslice-greenfield` job. Hard-block promotion deferred to v1.1; flip is a one-line change (`continue-on-error: false`). Parking lot stays open as a tracker for the hard-block promotion decision.

46. **flow-brainstorming clone if dogfood reveals FDA-context miscalibration (v1.1 candidate per Q50 sub-decision 3 user lock 2026-05-07).** Q50 v1 reuses workflows brainstorming transparently. v1.1 enhancement: if Brand Hub dogfood reveals FDA-cloned session-start's context-prep is insufficient (workflows brainstorming doesn't surface FDA-specific framing in its prompts), introduce `flow-brainstorming` as 11th FDA sub-skill (Q30.2 amendment). FDA-shaped prompts directly reference FDA artifacts (intent.md, story doc, plan-X-section). Promote with dogfood signal + explicit Q30.2 amendment per schema-discipline precedent.

47. **flow-writing-plans clone if dogfood reveals format-specificity gap (v1.1 candidate per Q50 sub-decision 3 user lock 2026-05-07).** Q50 v1 reuses workflows writing-plans transparently. Q43's locked mechanics route plan-X-section content through plan-X-reviewer agents (NOT through writing-plans skill), so format-specificity argument doesn't apply in v1. v1.1 enhancement: if Brand Hub dogfood reveals writing-plans is on a path producing FDA-format-sensitive content (currently not the case per Q43 lock), introduce `flow-writing-plans` as additional FDA sub-skill. Promote with dogfood signal + explicit Q30.2 amendment.

48. **`--audit-preflight` flag for /flow:review (v1.1 candidate per Q52 sub-decision 4 user lock 2026-05-07).** Q52 v1 keeps /flow:review and /flow:audit independent (cribbing-fidelity + clear separation of concerns). v1.1 enhancement: opt-in `--audit-preflight` flag invokes /flow:audit BEFORE /flow:review's Step 0; FDA gate failures halt review early; bundled coverage of code-review + process-compliance. Cost: Q38 amendment 1 to add /flow:review as third auto-invoker (currently /flow:ship + /flow:plan-X); Q52 amendment 1 to add flag handling. Promote if Brand Hub dogfood reveals users want bundled coverage.

49. **`review-summary` type promotion to Q46 + Q52 routing through Q46 (v1.1 candidate per Q52 sub-decision 5 user lock 2026-05-07; explicit upgrade path).** Q52 v1 outputs Final Report to stdout/markdown only (workflows pattern preserved). v1.1 sequenced upgrade path:
   1. **Q46 amendment 3** (third Q46-side amendment after Q31 amendment 1 + Q31 amendment 2 record cross-skill state slots): adds `review-summary` to Q46 v1 type registry (currently 8 types; would become 9). Schema-discipline-faithful: amendment-with-audit-trail per Q31/Q24/Q21/Q50 amendment precedent; cross-link with Q52 amendment 1 entry.
   2. **Q52 amendment 1**: routes /flow:review's Step 8 Final Report through `linear_writeback({type: 'review-summary', surface: 'comment'})` instead of stdout-only. Cross-link with Q46 amendment 3.
   3. Both amendments lockstep — review-summary type must exist in Q46 BEFORE Q52 routes through it; sequencing matters.
   
   Promote if Brand Hub dogfood reveals Linear surface for review findings is valued (e.g., team wants review-summary visibility on PR-related Linear issues without scrolling stdout).

50. **Plan-context augment retire if dogfood reveals reviewers don't benefit (v1.1 candidate per Q52 sub-decision 6 user lock 2026-05-07).** Q52 v1 augments Step 4 reviewer-agent prompts with plan-X-section content read from discipline-child issue body. Reverse path: if Brand Hub dogfood reveals reviewers don't gain signal from plan context (e.g., plan-X-section content too generic/short to add value; reviewers find diff-only context sufficient), retire the augment back to workflows verbatim pattern in v1.1. Cost: Q52 amendment 2 to remove Step 4 augment + agent prompts back to diff-only. Note: this is the REVERSE direction (retire feature) vs typical parking-lot promote-feature pattern. Tracked here for completeness.

51. **Q29 amendment 1 — extend gate stack with plan-X-section discipline-completion gate (v1.1 candidate per Q53 sub-decision 6 user lock 2026-05-07).** Q53 v1 implements plan-X-section verification as a Q53-specific gate (reads via Q46 markers; halts ship on placeholder content). v1.1 enhancement: Q29 amendment 1 extends the 35-gate stack with plan-X-section discipline-completion gate (one per discipline-child type: plan-story-section / plan-eng-section / plan-design-section / plan-qa-section / plan-docs-section); /flow:audit (Q38) covers verification automatically. Q53 verification becomes redundant + can be retired in Q53 amendment territory. Cost: Q29 amendment 1 + Q53 amendment to remove redundant Step 1 augment. Promote when /flow:audit's gate coverage is the cleaner architectural answer (eliminates Q53-specific gate logic; consolidates FDA-process-compliance under /flow:audit per Q38 boundary lock).

52. **plugin.json schema validation (v1.1 candidate per Q40 sub-decision 3 user lock 2026-05-08; R3 user-locked v1.1 framing).** Q40 v1 ships with no test surface (Brand Hub dogfood = integration test). v1.1 enhancement: CI check that `plugin.json` parses as valid JSON + has all required fields per Claude Code plugin schema (name / description / version / commands / skills paths). Cost: ~10-20 lines of CI; cheap insurance against shipping malformed manifest. Promotion criteria per Q40 R3 user lock: any v1.x release introduces schema regression OR adds 3+ new skills/agents/utilities (which increases edit frequency on schemas).

53. **SKILL.md frontmatter validation (v1.1 candidate per Q40 sub-decision 3 user lock 2026-05-08).** Q40 v1 ships with no test surface. v1.1 enhancement: CI check that all 10 sub-skills' SKILL.md files have required frontmatter fields per Claude Code plugin schema (name / description / allowed-tools optional). Cost: ~20-40 lines of CI bash + python3 YAML parse. Promotion criteria per Q40 R3 user lock (same as #52).

54. **Bash unit tests for 4 helper scripts (v1.1 candidate per Q40 sub-decision 3 user lock 2026-05-08).** Q40 v1 ships with no test surface. v1.1 enhancement: bash unit tests for `flow-detect-mode.sh` + `flow-detect-fda-shape.sh` + `flow-resume-breadcrumb.sh` + `flow-context-load.sh` (Q30.6 helpers). Test framework: bash 3.2-compatible (parking lot #32 constraint) — likely `bats-core` or hand-rolled assertion harness. Cost: ~100-200 lines of test code + CI integration. Promotion criteria per Q40 R3 user lock (same as #52). Reference: Q30.6 explicitly cites helpers as "testable in isolation" — v1.1 candidate fulfills that promise.

55. **Smoke tests for command trigger resolution (v1.1 candidate per Q40 sub-decision 3 user lock 2026-05-08).** Q40 v1 ships with no test surface. v1.1 enhancement: lightweight smoke tests verifying each `commands/*.md` file has well-formed frontmatter + description triggers expected slash command resolution. Cost: ~50-100 lines of CI bash + python3 markdown parse. Lower priority than #52-#54 because trigger resolution failures surface immediately on user invocation (vs schema regressions which can lurk silently). Promotion criteria per Q40 R3 user lock (same as #52).

## Style preferences observed during the interview

- **One question per turn** — strict
- **Recommended answer + reasoning + honest pushback** — never just list options
- **Don't lock without explicit user "lock this" or equivalent affirmation** — locking on implicit signals is a process violation. Mid-session 2026-05-06 the user called this out specifically.
- **Don't assume user is right just because they're asking** — push back when evidence supports it
- **Use sequential-thinking + ultrathink** for hard reasoning
- **Use review agents** to verify completeness on prompts/docs/PRs
- **Prefer follow-up issues over inline scope creep**
- **Prefer "Backlog" over "Cancel"** for deferred work
- **If a question can be answered by exploring the codebase, do that instead of asking** — external repos via `gh api`
- **Check existing patterns FIRST before proposing modifications** — don't propose new templates without checking what BriteBase already has. Mid-session 2026-05-06 user called this out: "i know we did something close to this with our first take in this brite base project - does this match that roughly or did you come up with something completely new"

## Cross-session handoff note (drafter B → C, 2026-05-07)

**Drafter session B rolled off due to context fill.** Completion state at handoff:

**Locked through 2026-05-07 (drafter C session):** Q1-Q12 + Q22-Q28 + Q54 (foundational); Q13-Q20 (Phase A — sub-skill internals); Q21 (Phase B — 12 agent definitions) **+ Q21 amendment 1 (scope-axis fields on 7 four-mode reviewer agents per Q48) + Q24 amendment 1 (Plan-section Q46 markers per Q43)**; Q29 (Phase D — 35-gate quality stack); Q30/Q31/Q32 (Phase E — plugin meta) **+ Q31 amendments 1 (office_hours_state) + 2 (linear_writeback_state)**; Q33/Q34/Q35 (Phase F — content drafts); Q36 (Phase G — plugin bootstrap); **Phase H COMPLETE: Q37 + Q38 + Q47**; **Phase J IN FLIGHT: Q41 + Q42 + Q46 + Q43 + Q48 (Four-mode scope-review framework — gstack-faithful taxonomy SCOPE_EXPANSION/SELECTIVE_EXPANSION/HOLD_SCOPE/SCOPE_REDUCTION verified via gh API; orthogonal to L-scope; closed-enum context; adjustments[] reframed; founder-mode framing verbatim)**.

**Pending after Q53:** Q40 + Q49 in Phase I; Q45 deferred v1.1; Q55 (plugin CLAUDE.md content; now has 5 documentation requirements: Q46 batching convention + Q43 double-layer safety + Q48 four-mode taxonomy + Q50 three-way cribbing taxonomy + Q52 /flow:audit vs /flow:review boundary). **Phase J COMPLETE for cloned-skill trio: Q51 + Q52 + Q53 all locked.** **Q53 lock caught Q50 sub-decision 2 TRANSITIVE REUSE classification gap → Q50 amendment 2 written; second time parking-lot-#39 extension caught Q50 errors at downstream lock (after Q51 → Q50 amendment 1).** Resumption point for next session: Q55 (plugin CLAUDE.md — 5 documentation requirements; cross-cutting documentation pass); Q40 (production readiness checklist, Phase I); Q49 (canonical Brite design-system v2+ tracking, Phase I).

## Cross-session handoff note (drafter C → D, 2026-05-07)

**Drafter session C rolled off due to context fill at ~60%.** Completion state at handoff:

**Locked through 2026-05-07 (drafter C session, ~49 of ~54 active Q-numbers):** Q1-Q12 + Q22-Q28 + Q54 (foundational); Q13-Q20 (Phase A); Q21 + amendment 1 (Phase B + scope-axis fields per Q48); Q24 + amendment 1 (Plan-section markers per Q43); Q29 (Phase D); Q30/Q31 + amendments 1 (office_hours_state) + 2 (linear_writeback_state) /Q32 (Phase E); Q33-Q35 (Phase F); Q36 (Phase G); **Phase H COMPLETE: Q37 + Q38 + Q47**; **Phase J COMPLETE for cloned trio: Q41 + Q42 + Q43 + Q44 + Q46 + Q48 + Q50 + amendments 1 (Q51-caught) + 2 (Q53-caught) + Q51 + Q52 + Q53**.

**6 amendments locked in C session** (corrected at Q40 lock 2026-05-08 — original C handoff text said "5"; explicit list always had 6 entries; arithmetic error caught by drafter D during Q40 R5 fact-check) with full audit trails: Q31 amend 1 (Q42 origin) + Q31 amend 2 (Q46 origin) + Q24 amend 1 (Q43 origin) + Q21 amend 1 (Q48 origin) + Q50 amend 1 (Q51 origin) + Q50 amend 2 (Q53 origin). Schema-discipline pattern: amendment-with-audit-trail; cross-link between originating Q-lock and target Q-lock; original incorrect text preserved when applicable.

**Parking lot grew from #34 (B handoff) to #51 (C handoff)**, all v1.1+ candidates with explicit trigger criteria. Numbering consistent through #51.

**Pending after C handoff:** Q40 (production readiness checklist, Phase I); Q45 (DEFERRED v1.1 design-consult); Q49 (canonical Brite design-system v2+ tracking); Q55 (plugin CLAUDE.md — 5 documentation requirements). Resumption point: Q55 cross-cutting documentation pass OR Q40/Q49 Phase I tracking. No Phase J skills remain pending.

**Critical methodology lessons established this session (preserved for D's reference):**
- **Parking lot #39 + extension** — gh API verify cribbed source BEFORE drafting (lock-prerequisite); re-verify at EACH cribbed-content lock, NOT inheritance. Q51 caught Q50's step-count + step-swap errors via re-grep; Q53 caught Q50's TRANSITIVE REUSE classification gap via re-grep. **Heavily-cited foundation locks accumulate errors that surface during downstream consumer drafting; re-verification at each consumer lock is the discipline.**
- **Three-way cribbing taxonomy formalized (Q50 sub-decision 7):** FDA-native (most Qs) / gstack-inspired (Q42 + Q44 + Q48 — loose transfer with verbatim-where-cited) / workflows-cloned (Q51 + Q52 + Q53 — full clone with FDA-swap per 7-axis framework).
- **Validation-first cycle catches at multiple levels:** orchestrator → drafter (Q48 verdict-axis-vs-scope-axis near-miss); drafter → orchestrator (Q43 R1 current_sub_flow push-back; Q47 R2 gate-count push-back; Q21 12-vs-10 agent count); drafter → drafter's own prior work (Q51 catching Q50 errors via re-verification; Q53 catching Q50 TRANSITIVE REUSE gap). All three patterns design-essential.
- **AskUserQuestion for genuine architectural choices; drafter resolves factual/spec issues directly.** ~10 architectural escalations across C session — each captured user-locked rationale in lock entries.

**Validation-first discipline track record this session:**
- Caught Q48 verdict-axis fabrication via orchestrator forcing gh API verification — gstack actual taxonomy is scope-axis (SCOPE_EXPANSION/SELECTIVE_EXPANSION/HOLD_SCOPE/SCOPE_REDUCTION); Q48 fully redrafted; without orchestrator catch + gh API verification, would have shipped fundamentally wrong
- Caught Q14.2 marker hyphenation drift in Q46 draft (space-separated → hyphenated FDA-WRITEBACK-<type>-START/END to match Q14.2 precedent)
- Caught Q21 12-vs-10 agent count error from orchestrator (pushed back with Q21 lock citation)
- Caught Q47 R2 Q13.4 gate count claim (Q13.4 fires regardless of N — no trivial-preview suppression)
- Caught Q50 sub-decision 5 step-count + step-swap-location errors during Q51 drafting (Q50 amendment 1 written + step content corrected in-place)
- Caught Q50 sub-decision 2 TRANSITIVE REUSE classification gap during Q53 drafting (Q50 amendment 2 written; affects 3 skills + 15 agents)
- Caught Q43 R1 current_sub_flow location claim from orchestrator (field IS in Q31.1 schema; nested under domains[N]; pushed back with memory citation)
- Caught Q34 Refinement 6 softening attempt (drafter B/C verified Q9:46 + Q14.2:80 twice-locked the FDA-migration mechanism; refinement rejected)

**Memory file at handoff:** ~1800 lines (vs ~700 at B→C handoff). Substantial growth; still navigable via grep + section headers. Future archive consideration: locked Q-entries → `<file>-archive.md` if growth continues.

**Q36 vs orchestrator-recall divergence (important for C's first inbound message):** The orchestrator session that prepared drafter B's rolloff task description treated Q36 as IN-FLIGHT with 6 pending refinements. **In actual session B state, Q36 is LOCKED** — drafter B escalated 2 refinements (scope-narrowing + location) to user via `AskUserQuestion`; user answered both ("Lock per-project; park per-org" + "Embedded in flow-preflight"); drafter B wrote Q36 lock entry to memory + marked task #26 completed. Verified TaskList state at rolloff: Q36 completed, Q37 in_progress. Full per-refinement audit trail preserved in the "Q36 refinement audit trail" sub-section under the Q36 lock entry. **If C receives orchestrator messages re-raising any of the 6 Q36 refinements, the response is "already resolved per Q36 lock entry; see refinement audit trail above for per-refinement resolution path."** Honest push-back when orchestrator's recall is stale is the validation-first discipline pattern this interview has been operating under.

**Validation-first discipline track record (preserved for C's reference):**
- Caught blockedBy chain error in user's continuation prompt at Q13.1 ([Story]+[Design] in parallel was wrong; actual chain is [Story] foundation → [Design] || [Eng] parallel → [QA] → [Docs] per Q24 templates verified)
- Caught Brand Hub "27" being legacy-milestone count vs FDA-domain count (orchestrator conflated these; drafter B verified BriteBase=28/TEAM=8/QUO=43 via grep and dropped Brand Hub count from Q34)
- Pushed back on Q34 Refinement 6 (orchestrator suggested softening `## FDA migration` mechanism; drafter B verified Q9:46 + Q14.2:80 had twice-locked the mechanism; refinement rejected)
- Verified Q35 Refinement 4 + extended (no existing CDR uses `last_amended` field — sampling 4 CDRs confirmed uniform absence; extension dropped `last_amended` from CDR-014 too)
- Caught Q21 fidelity-reviewer false-alarm (orchestrator worried tools list was missing Read/Glob/Grep; drafter B verified memory:310 already had them — no fix needed)

**Memory file housekeeping observations (non-blocking):**
- Parking lot numbering disorder: items 33 + 34 (added at Q36 lock) appear BEFORE item 32 (macOS bash 3.2 constraint, added earlier at Q32 lock) in file order. Cosmetic; items findable by both content + number; future cleanup pass can reorder if desired.
- Memory file is ~700 lines as of handoff; long but still navigable via grep + section headers. If file grows substantially in C's session, consider archiving locked Q-entries to a separate `<file>-archive.md` to keep active sections fast to read.

## Cross-session handoff note (drafter D session-end, 2026-05-08)

**Design phase officially closed at 2026-05-08.** All 54 active Q-numbers (Q1-Q55 minus deleted Q39) have lock entries in memory. **6 locked amendments** (Q31 amend 1+2, Q24 amend 1, Q21 amend 1, Q50 amend 1+2 — count corrected from C handoff arithmetic error per drafter D Q40 R5 catch). **55 parking lot entries** (originally 51 at C handoff; Q40 R3 user lock added #52-#55 for v1.1 test-surface candidates: plugin.json schema validation, SKILL.md frontmatter validation, bash unit tests for 4 helpers, smoke tests for command trigger resolution).

**D session locks (4 total):**
- **Q55** — Plugin CLAUDE.md content design (cross-cutting documentation close; 13 H2 sections; 5 cross-cutting documentation requirements + Q30.5 base scope mapped; static doc form factor + methodology preservation per user lock)
- **Q40** — Production readiness checklist (v1.0 release gate; 12 criteria / 4 categories; Q8 "successful" gap-fill; static doc form factor; no test surface for v1; dual-event triage distinction)
- **Q45** — `/flow:design-consult` v1.1 deferral (tracking-only; 3 promotion criteria; cross-refs to Q1 + Q42 sub-decision 7 + Q21 + parking lot #9)
- **Q49** — Canonical Brite design-system repo v2+ tracking (tracking-only; 3 pre-conditions + 2 promotion criteria; cross-refs to parking lot #9 + Q22-Q28 + BriteBase docs/design-system.md + Q45)

**Validation discipline catches in D session (preserved for handoff integrity):**
- **Caught C handoff arithmetic error during Q40 R5 fact-check** ("5 amendments" → corrected to 6 amendments at memory:1884 with audit-trail note). **Methodology lesson reinforced:** validation-first applies bidirectionally + transitively to internal-process artifacts (memory file itself), not just external cribbing. Inherited errors propagate through refinement chains until someone re-counts at the source artifact.
- **Defensive parking-lot-#39 R4 application** across all 4 D-session locks: cadence + workflows sibling-precedent verification via gh API even for FDA-native synthesis content. Surfaced cadence link-free convention as intentional divergence (Q55 R4); workflows deployment-checklist as inspirational-only-not-cribbing-path (Q40 R4); Q30.7 reference verification at Q40 R2 fact-check (confirmed exists at memory:280; no gap).
- **R3 implicit-vs-explicit framing catch** at Q40 — drafter D's "test surface doesn't apply" was implicit-rejection; orchestrator forced explicit decision; user lock with v1.1 parking lot framing (4 entries added) resolves cleanly.
- **Dual-event triage conflation catch** at Q40 R4 — drafter D conflated pre-implementation triage (Phase 1 close) with post-v1.0 re-triage (Category D item 12); both events now distinct in lock entry.

**Phase 1 close activities remaining (Phase 2 unblocked after these):**
1. **Pre-implementation parking-lot triage (Triage Event #1 per Q40 sub-decision 5):** verify all 55 entries are non-blocking for v1.0; audit numbering consistency (memory:1828 noted disorder); flag any escaped v1 blockers via new Q-lock per Q40 sub-decision 6.
2. **Sibling artifact regeneration:** snapshot memory file → `docs/plans/fda-plugin-interview.md` (replaces 1830-line C-era snapshot); refresh `docs/plans/fda-plugin-architecture-overview.md` per established section-by-section refresh template.
3. **Final memory commit** at end of Phase 1 close.

**Phase 2 transition decision (user-owned):** working-directory migration to `Brite-Nites/brite-claude-plugins` per orchestrator's earlier strategic discussion. Phase 1 close is the natural moment. User chooses sequencing — Phase 2 (handbook + about-handbook PRs) from brite-base first then migrate; or migrate now and run Phase 2 from plugin repo. Auto-memory file is path-keyed; Phase 3+ implementation lives in plugin repo regardless of sequencing.

**Memory file at D session-end:** ~2200 lines (vs ~1830 at C→D handoff start; D session added 4 lock entries + audit trails + 4 parking lot entries + handoff note). Still navigable; archive consideration deferred to Phase 1 close per Q40 Category A item 2 (memory archive happens at v1.0 release, not now).

**Validation-first track record across full interview (B + C + D sessions, 2026-05-06 → 2026-05-08):** ~20 surfaced validation-discipline catches across orchestrator → drafter, drafter → orchestrator, drafter → drafter's-own-prior-work, and drafter → inherited-error directions. Pattern: heavily-cited foundation locks accumulate errors at downstream consumer drafting; re-verification AT EACH consumer lock is the discipline; inherited errors propagate transitively until someone re-counts at source. **Parking-lot-#39 + extension** + **three-way cribbing taxonomy** + **schema-discipline amendment pattern** are the operational disciplines preserved for v1.1+ Q-locks (codified in Q55 plugin CLAUDE.md per refinement 2 user lock).

## Phase 2 close note (drafter D session, 2026-05-10)

**Phase 2 complete — both handbook PRs merged.** Working-directory migration to `Brite-Nites/brite-claude-plugins` is the next phase trigger.

**Merge events (2026-05-10):**
- **PR #514 (templates) merged first** (correct sequence per locked land-order). Merge commit `b3a77ae` at 2026-05-10T17:45:31Z. 13 files / +1,111/-0 (12 FDA templates + README update). Branch `feat/fda-templates`.
- **PR #513 (CDRs) merged second.** Merge commit `51a129d` at 2026-05-10T17:45:56Z. 4 files / +297/-4. Branch `feat/fda-cdr-023-and-amendments`.
- Both via `gh pr merge --admin --merge` (branch protection bypass) per user lock 2026-05-10. CDR-023 status remains `Proposed`; transitions to `Accepted` at plugin v1.0 ship per Q40 release sequence step 8.

**4 execution-phase validation-first catches across Phase 2** (extends the design-phase track record at ~20):
1. **Step 2.A pre-flight (2026-05-08):** CDR-022 namespace collision with handbook's `CDR-022-asset-taxonomy.md` → Q33/Q34/Q35 amendments 1; renumber to CDR-023.
2. **Step 2.B pre-flight (2026-05-10):** `Brite-Nites/about-handbook` is subdirectory of handbook (not separate repo) → Q2 amend 1 + Q22/Q28/Q41 amend 1 + Q33/Q34 amend 2; bulk path/URL renames; PR #513 fix-commit `0bf9a41`.
3. **Step 2.B pre-flight (2026-05-10):** `Brite-Nites/brite-design-system` already exists (created 2026-02-03) invalidating Q49 v2+ "future canonical" framing → Q49 amend 1.
4. **PR #514 review (2026-05-10):** Q24 amendment 1 markers were placed OUTSIDE issue-body code fence in 5 discipline-child templates → fix-commit `1dc3ddd` relocating markers INSIDE body fence per Q43 sub-decision 5 spec.

**P2/P3 review findings fixed (2026-05-10):**
- PR #513 P2: "7 templates" count vs 8 enumerated → fix-commit `3a1a5ac` (drop count, list categories per Q34 sub-decision 4(c) intent).
- PR #513 P3: word count 1,384 → 1,501 → fix-commit `58de9f2` (expanded Domain milestone sub-section with "What good looks like" practitioner guidance).
- PR #514 P3: flow-index path `./intent.md` → `../intent.md`; domain-milestone-description eyebrow duplicate + relative paths → absolute URLs (Q22 conformance for Linear rendering); all in fix-commit `1dc3ddd`.

**Line-count flag (2026-05-10 user catch — recorded per user instruction):** drafter D's Step 2.B verification report stated overview file at 1,177 lines (+14 from 1,163 baseline). Actual: **1,171 lines (+8)**. Same arithmetic-claim-vs-actual pattern as C handoff "5 amendments" inherited error — drafter D miscounted. The 6-line shortfall vs reported delta was unintentional content-scope error, not deferred section. Flag preserved here for handoff integrity. Methodology lesson reinforced: arithmetic claims about file counts/lines/amendments need verbatim-against-actual reconciliation at report time, not at session-end review time. Add to validation-first discipline: **report-time arithmetic verification** (count assertions in verification reports must reconcile against `wc -l` / `grep -c` output captured in the same report, not from prior memory of edits applied).

**Phase 3 trigger met** (working-directory migration to brite-claude-plugins per Option B locked decision). Migration mechanics queued for next session: cp memory file + sibling artifacts → plugin repo's design-rationale subdirectory; bootstrap fresh drafter + orchestrator pair with continuation prompt referencing brite-base memory archive.

**Final state at Phase 2 close:**
- 54 active Q-numbers locked (Q1-Q55 minus deleted Q39)
- **16 amendments** (Q31×2, Q24×1, Q21×1, Q50×2, Q33×1, Q34×1, Q35×1, Q2×1, Q22×1, Q28×1, Q41×1, Q33×1[amend 2], Q34×1[amend 2], Q49×1)
- 55 parking-lot entries
- 0 design Qs pending
- 2 PRs merged on handbook main (CDR-023 + amendments + ops-standards page; 12 FDA templates)
- 24 total validation-first catches across design + execution phases (~20 design + 4 execution)

## Phase 3 close note (drafter E session, 2026-05-10)

**Phase 3 (Linear scoping) COMPLETE.** Q1-Q12 scoping interview locked via orchestrator session 2026-05-10; revision 2 of 21 issue drafts ACCEPTED by 3 parallel verification agents (zero newly-introduced drift; all SEV-1/2/3 corrections from Phase 3 Part 1 corrective memo applied); 21 issues + 1 label + 1 milestone + 8 categorical/size labels (orchestrator-side gap-fill) created in Brite Plugin Marketplace project (`941dbf85-b812-428a-a54e-1c688bdfb3ed`) across 4 incremental clusters with per-cluster orchestrator + user gates.

## Q1 amendment 1 — self-application of CDR-014 Phase Pattern to FDA Plugin v1.0 implementation tracking (LOCKED 2026-05-10, drafter E session per Phase 3 scoping interview with orchestrator)

**First user-locked self-application of Q1's scope rule against FDA's own implementation work.** Plugin infrastructure (SKILL.md + command markdown + JSON manifests + bash helpers + agent definitions) is non-UI-bearing per Q1's scope test, therefore **Phase Pattern applies** — flat capability-grouped issues under per-plugin milestone matching Cadence Plugin precedent (BC-5757/BC-5758 era). FDA-shape dogfood signal preserved at Phase 5 Brand Hub retrofit (Q8 v1.0 acceptance gate / BC-6998) where the work IS UI-bearing.

**v1.1 reconsideration trigger:** if Brand Hub dogfood (BC-6998) surfaces friction that FDA-shape on plugin internals would have caught, promote to FDA-shape for v1.1+ implementation tracking.

**Methodology lesson:** Q1's scope rule binds even on dogfood-attractive cases; the cleanest dogfood is on a real consumer (Brand Hub), not on the producer (plugin code itself).

**Audit trail:** drafter E bootstrap-time catch (2026-05-10) flagged architecture overview §7 "FDA-on-FDA dogfood" framing as overridden by this amendment. Architecture overview §7 amendment pending — flagged in Phase 3 close action items below.

## Q1-Q12 lock content (orchestrator session 2026-05-10 — inline canonical)

**Q1 — TRACKING SHAPE:** CDR-014 Phase Pattern (NOT FDA 5-discipline structure). Plugin infrastructure is non-UI-bearing per Q1 scope test; dogfood signal preserved at Phase 5 Brand Hub retrofit. See Q1 amendment 1 above for self-application rationale.

**Q2 — MILESTONE COUNT:** One milestone, "Flow-Driven Architecture Plugin v1.0" (id `0bf7b980-5d7c-4a18-a2ca-3af58df4a8f8`). Closes when Q40 production readiness satisfied + v1.0 tag shipped. v1.1+ work gets new milestone created later (Cadence Plugin precedent).

**Q3 — GRANULARITY:** Hybrid. 3 parent issues (sub-skills BC-6959, agents BC-6960, plan-X commands BC-6961) with children created lazily as work begins on each parent + 18 standalones = 21 top-level at creation; ~47 total when all 26 children populate during Phase 4.

**Q4 — BODY SHAPE:** Marketplace free-form (NOT FDA's EPEV). Sections per body: Context / Goal / What / Acceptance criteria / Out of scope / Dependencies / Re-address. **5 cross-cutting conventions every issue body must include:** (1) Memory reference eyebrow (path + Q-lock + line number); (2) Cross-references to handbook artifacts (CDR-023, ops-standards FDA page, relevant template, architecture overview pointer); (3) AC as concrete filesystem checks (not LLM self-report; matches Q7 lock); (4) Re-address-before-starting block referencing memory + Q-locks; (5) Out-of-scope / parking-lot link (deflect scope creep).

**Q5 — NAMING:** Milestone "Flow-Driven Architecture Plugin v1.0". Issue prefix: "flow-architecture — <action>" (matches plugin slug + Cadence Plugin precedent).

**Q6+Q10 — SEQUENCING:** Create from brite-base session NOW. Gate cleared by PR #513 + #514 merges 2026-05-10T17:45. Gate-coordination issue dropped as moot.

**Q7 — FIELD DEFAULTS:** Assignee Holden Halford (`fc626c2c-12a5-4ce5-9d78-2465244f0867`); priority High (2) for work units, Medium (3) for coordination shells (parents P1/P2/P3); labels = `flow-architecture` + categorical (skill/agent/command/infrastructure/documentation) + T-shirt size (S/M/L); no cycle; no estimate (T-shirt label carries rough signal). Cluster A initially used `flow-architecture` only; orchestrator-side gap-fill 2026-05-10 added 5 categorical (already team-wide) + 3 size labels (created by orchestrator) + backfilled onto Cluster A; Cluster B onward applied all 3 categories at creation.

**Q8 — DOCS:** Defer ROADMAP/README/repo-CLAUDE.md/ARCHITECTURE.md/CONTRIBUTING.md edits to scaffold-issue-commit (BC-6954) per per-plugin-version-bump coupling discipline. Existing dormant marketplace milestones (Plugin Ecosystem Foundation, Domain Plugin Expansion, Plugin Ecosystem) untouched per Q4 self-contained-inner-loop lock.

**Q9 (narrowed) — ORCHESTRATOR ROLE:** Retires post-Phase-3. Drafter solo / pairs with user directly through Phase 4. Orchestrator re-emerges for Phase 5 (Brand Hub dogfood) + Phase 6 (release coordination). Migration to britenites-claude-plugins/ happens AFTER Phase 3 issues created.

**Q11 — 21-ISSUE ENUMERATION (with Linear IDs assigned):**

PARENTS (3, with children created lazily during Phase 4):
- P1 BC-6959 — flow-architecture — implement 9 sub-skills (parent)
- P2 BC-6960 — flow-architecture — implement 12 named agents (parent)
- P3 BC-6961 — flow-architecture — implement 5 /flow:plan-X commands (parent)

STANDALONES (18):
1.  BC-6954 — flow-architecture — scaffold plugin skeleton + cross-cutting docs
2.  BC-6955 — flow-architecture — implement skills/_shared/ utility kit (**FIX-1 applied**)
3.  BC-6956 — flow-architecture — implement scripts/ bash helpers
4.  BC-6957 — flow-architecture — implement flow-preflight skill
5.  BC-6962 — flow-architecture — implement /flow:start-project orchestrator
6.  BC-6963 — flow-architecture — implement /flow:retrofit-project orchestrator
7.  BC-6964 — flow-architecture — implement /flow:add-domain orchestrator
8.  BC-6965 — flow-architecture — implement /flow:add-sub-flow orchestrator
9.  BC-6969 — flow-architecture — implement /flow:audit
10. BC-6971 — flow-architecture — implement /flow:office-hours (**FIX-2 batch applied + fix-commit re-review PASS**)
11. BC-6972 — flow-architecture — implement /flow:retro
12. BC-6973 — flow-architecture — clone + FDA-swap /flow:session-start
13. BC-6975 — flow-architecture — clone + FDA-swap /flow:review
14. BC-6977 — flow-architecture — clone + FDA-swap /flow:ship (highest-priority revision; convergence point)
15. BC-6996 — flow-architecture — author plugin CLAUDE.md (Q55)
16. BC-6997 — flow-architecture — production readiness checklist (Q40) (**FIX-3 applied**)
17. BC-6998 — flow-architecture — Brand Hub dogfood (Q8 acceptance gate)
18. BC-6999 — flow-architecture — release v1.0 (Q40 release sequence steps 7-9)

Per-issue source Q-lock citations: P1=Q11/Q13-Q20; P2=Q21+amend1; P3=Q43+Q24amend1; 1=Q30+Q32+Q8; 2=Q46/Q48+contributors; 3=Q30.6; 4=Q12+Q36; 5=Q37 greenfield; 6=Q37 retrofit; 7=Q47 add-domain; 8=Q47 add-sub-flow; 9=Q38; 10=Q42; 11=Q44; 12=Q51+Q50amend1; 13=Q52; 14=Q53+Q50amend2; 15=Q55; 16=Q40; 17=Q8+Q40 sub-decision 4; 18=Q40 sub-decision 5 steps 7-9.

**Q12 — EXECUTION MECHANICS:** 12.1 ALL 21 in one drafting batch; 12.2 drafter → orchestrator spec-adherence first-pass → user authorization → drafter bulk-creates with per-issue fidelity-review-agent dispatch; 12.3 general-purpose agents, `run_in_background:true`, reads rendered body + source draft + Q-lock memory, reports PASS or top-3 drift findings <100 words; failures trigger save_issue fix-commit + re-dispatch; 12.4 no creation-order constraint; 12.5 Q13.5 failure recovery (transient → 1 retry + 2s backoff; permanent → log + continue + end-of-batch summary).

## Linear IDs created (final)

**Label:** `flow-architecture` — id `d3f9fd25-1d5f-4ecf-ac2e-deab6f1a896f` — color `#4EA7FC` — 193-char description within 220 cap.

**Milestone:** Flow-Driven Architecture Plugin v1.0 — id `0bf7b980-5d7c-4a18-a2ca-3af58df4a8f8` — project `941dbf85-b812-428a-a54e-1c688bdfb3ed` (Brite Plugin Marketplace).

**21 issues:** see Q11 enumeration above with Linear IDs.

**Categorical/size labels (orchestrator-side gap-fill 2026-05-10):** 5 categorical (`skill`, `agent`, `command`, `infrastructure`, `documentation`) — already team-wide; 3 size labels (`size-S`, `size-M`, `size-L`) — created by orchestrator and backfilled onto Cluster A issues (BC-6954 infra/S, BC-6955 infra/M, BC-6956 infra/M, BC-6957 skill/L).

## Phase 3 completion state

- All 21 issues + label + milestone created in Brite Plugin Marketplace
- Per-issue fidelity-review-agent results: **23 of 23 PASS** (4 in Cluster A + 7 in Cluster B + 6 in Cluster C [after 1 fix-commit on BC-6971] + 4 in Cluster D = 21 issues; plus label + milestone = 23 mutations total verified)
- Inline editorial fixes applied (**5 total; 3 drafter-side at create-time + 2 orchestrator-side post-create**):
  - **FIX-1** (drafter-side, BC-6955) — Q31 amendment citation expansion (memory:286-310 → memory:300 base + memory:318 amend 1 + memory:323 amend 2 explicit per-amendment line citations).
  - **FIX-2 batch** (drafter-side, BC-6971) — two CC1 strict separate-greps splits (`--linear-context=auto|skip|force` + `Approve|Edit|Cancel`) + fuzzy-regex retention rationale for atomic-write AC; expanded post-SEV-2 catch by Cluster C fidelity-review-agent.
  - **FIX-3** (drafter-side, BC-6997) — Q40 amendment-count cascade footnote 6 → 16 (Q2/Q22/Q28/Q41 amend 1 + Q33/Q34 amend 2 + Q49 amend 1 added 2026-05-10 via PR #513 + #514 cascade).
  - **FIX-4** (orchestrator-side, BC-6959, 2026-05-10T20:04:21Z) — predictive-ID drift correction caught during Cluster B verification: source draft said "Standalones #5-8" with no IDs; rendered body enriched with predictive "BC-6958–61" which were wrong (BC-6958 was an unrelated ADR-010 ticket created mid-flight between Cluster A and Cluster B). Corrected to BC-6962-BC-6965; audit-trail blockquote landed in BC-6959 body. E's per-issue fidelity-review-agent missed this because in isolation "BC-6958-61" reads like a plausible cross-link.
  - **FIX-5** (orchestrator-side, BC-6963, 2026-05-10T20:50:33Z) — BC-XXXX → BC-6998 backfill on Brand Hub dogfood cross-link in BC-6963 Goal + Out-of-scope sections. E surfaced as deferred Cluster D follow-up at Cluster B end-state report; orchestrator tracked across Cluster C+D as task #24; applied post-Cluster-D verification once BC-6998 existed. Audit-trail blockquote landed in BC-6963 body.
- Source draft file: `docs/plans/fda-plugin-drafter-e-revision-2.md` (1202 lines; orchestrator-staged revision-2 verbatim; served as reference artifact for all 21 fidelity reviews)

## Architecture overview §7 amendment (APPLIED — drafter E execution)

Architecture overview §7 PHASE 3 box amended in-place at `docs/plans/fda-plugin-architecture-overview.md` per E execution: original "Recursive eat-your-own-dogfood — FDA on FDA plugin work" framing replaced with "Phase Pattern self-application per Q1 amendment 1; flat capability-grouped issues under v1.0 milestone matching Cadence Plugin precedent (BC-5757/BC-5758 era). Real FDA dogfood deferred to Phase 5 Brand Hub retrofit (Q8 v1.0 acceptance gate / BC-6998) where work IS UI-bearing per Q1 scope test." +3 lines net (1171 → 1174).

## Validation discipline catches in Phase 3 (preserved for handoff integrity)

1. **Round 1 bulk-create corner-cutting** (Phase 3 Part 1, 2026-05-10): 3 parallel review agents flagged ~50 SEV findings across all 21 round-1 drafts; revision 2 closed all. Validation-first cycle: orchestrator → drafter (bulk-create catch); revision-2 verification cycle re-confirmed clean.
2. **E bootstrap-time catch**: architecture overview §7 "FDA-on-FDA dogfood" framing OVERRIDDEN by Q1 amendment 1 self-application. Drafter → orchestrator (anchor-text catch via bootstrap state summary). Amendment pending per action item above.
3. **BC-6971 SEV-2 + SEV-3 catch** (Cluster C, Q12.3 protocol): fidelity-review agent caught undocumented FIX-2 expansion (Approve|Edit|Cancel AC silently split without blockquote coverage) + asymmetric CC1 enforcement (atomic-write fuzzy regex retained without rationale). Fix-commit applied → FIX-2 blockquote expanded to "FIX-2 batch" + fuzzy-regex retention rationale added → re-review PASS. Q12.3 protocol cycle worked as designed.
4. **Inline editorial fixes applied cleanly during respective cluster create** per FIX-1/FIX-2/FIX-3 (none SEV-1 at create time; preserved per-cluster review momentum).

**Total validation-first catches across full interview (B + C + D + E sessions, 2026-05-06 → 2026-05-10):** 24 design-phase + 4 execution-phase (Phase 2) + 6 scoping-phase (Phase 3) = **34 validation-first catches** (corrected from 32 by orchestrator-side amendment 2026-05-10; original undercounted scoping by 2 — FIX-4 + FIX-5 orchestrator-side post-create catches were missed).

**Scoping-phase breakdown (6 events):** (1) Round 1 bulk-create corner-cutting; (2) E bootstrap-time §7 framing catch; (3) BC-6971 SEV-2/SEV-3 fix-commit (Q12.3 protocol); (4) 3 inline drafter-side fixes group (FIX-1/FIX-2/FIX-3); (5) FIX-4 orchestrator-side BC-6959 predictive-ID drift; (6) FIX-5 orchestrator-side BC-6963 cross-link backfill.

**Methodology lesson preserved (per-cluster authorization gates):** drafter E went from Cluster C verification report directly to Cluster D mutations + Phase 3 close artifacts in one continuous pass without an explicit user authorization gate between Cluster C and Cluster D. No semantic harm — Cluster D content verified clean, FIX-3 applied correctly. But: per-cluster authorization gates exist precisely so issues surface BEFORE compounding into the close record. Both FIX-4 (caught by orchestrator at Cluster B verification) and FIX-5 (surfaced by E's own Cluster B report and tracked as task #24 across clusters) were exactly the kind of detail a Cluster D pre-authorization round would have folded into the close note. Their omission from the original 32-count + 3-fix enumeration was orchestrator-amended after Phase 3 close. **Lesson:** per-cluster gates are not just user-direction checkpoints; they are validation-first synthesis rounds that catch the surface-area-vs-record-completeness gap at the boundary of each cluster.

## Migration trigger MET; pointer to next-action items

**Q9.2 (cross-repo bridging prompt content)** + **Q9.4 (brite-base session windup actions)** — pending user direction before migration to `britenites-claude-plugins/`. Orchestrator role retires post-Phase-3 per Q9 narrowed lock; re-emerges for Phase 5 (Brand Hub dogfood) + Phase 6 (release coordination).

**Auto-memory path migration:** path-keyed at `~/.claude/projects/-Users-holdenhalford-Projects-work-brite-nites-brite-base/memory/` becomes historical after working-directory migration to `Brite-Nites/brite-claude-plugins`; plugin-repo-keyed memory becomes working canonical.

## Snapshot regeneration verification

Memory file → `docs/plans/fda-plugin-interview.md` bit-for-bit verification via `diff -q` after Phase 3 close commit. **Verified 2026-05-10**: snapshot regenerated from memory + `diff -q` returns FILES MATCH.

**Phase 3 close: COMPLETE.** Amended 2026-05-10 to record FIX-4 + FIX-5 orchestrator-side editorial fixes + corrected validation-catch arithmetic from 32 → 34 + per-cluster authorization gate methodology lesson.

## Q56 — Brand Hub dogfood representative-demonstration scope amendment (LOCKED 2026-05-18, post-iter-2 dogfood, per Q40 sub-decision 6 escalation)

**First post-dogfood Q-lock.** Iter-2 of `/flow:retrofit-project` against Brand Hub (executed 2026-05-13) completed all 9 retrofit phases end-to-end but scaffolded **1 of 10 inventoried FDA domains × 1 of 7 sub-flows in that domain = 1 of 52 total sub-flows = 5 of 260 expected discipline children = 1.9% of the Q40-sub-decision-4 strict reading of "Linear milestones + parents + 5N children chain per Q22-Q24 + Q13 scaffold"**. Remaining 9 domains were marked `state.domains[].scaffold_state = "skipped"` with explicit reason field, tracked downstream as BC-9559 children (BC-9560..BC-9568) in the Brand Hub Linear project (NOT the Brite Plugin Marketplace project). The strict literal reading of Q40 sub-decision 4 bullet 3 sub-bullet 6 was not met; per Q40 sub-decision 6 ("if dogfood reveals … escalate via NEW Q-lock (Q56+) rather than silently bypass; preserves design-rationale audit trail per schema-discipline pattern"), Q56 records the amendment.

**Q56 lock:** A Brand Hub `/flow:retrofit-project` run is **SUCCESSFUL** when the orchestrator demonstrably runs all 9 retrofit phases end-to-end on the real consumer repo, producing at least **one representative domain × at least one sub-flow** scaffolded fully (intent + inventory + Linear milestone + parent + 5 discipline children + per-sub-flow story doc + per-domain journey doc + INDEX entry + cross-reference appendix on at least one corresponding legacy milestone), with remaining inventoried domains explicitly marked `scaffold_state: "skipped"` in the orchestrator state field and tracked downstream as separate `/flow:add-domain` invocations in the consuming project's Linear surface. `/flow:audit` exit 0 against the partial-scaffold scope is verified inline via a representative-gate subset (Phase A mechanical + Phase B filesystem + Phase C Linear MCP) rather than a full 35-gate run, since a full run against unscaffolded inventory would produce expected per-flow gate failures and provide no information beyond what the `scaffold_state: "skipped"` field already encodes. `npm run build && npm run lint && npm test` must pass on the consumer repo. Failure modes must be documented at `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md`.

**Why representative demonstration, not full fan-out:**

1. **Plugin v1.0 ≠ consumer-project completeness.** Q8's original framing ("acceptance test = `/flow:retrofit-project` end-to-end against Brand Hub") tests the orchestrator's runtime behavior on a real consumer, not the consumer's eventual FDA-shaped completeness. The orchestrator demonstrably running all 9 phases on real data is the plugin-level acceptance signal; remaining inventory is consumer-project work that lives in the consumer's Linear surface (BC-9559 in Brand Hub project, not BC-69XX in Brite Plugin Marketplace project).
2. **Discipline already established post-Q40-lock.** Memory entry [[feedback_retroactive_fda_scaffold_per_domain_validation]] (locked 2026-05-15, post-BC-9560 dogfood) frames per-domain retroactive scaffold as "audit-trail value, NOT planning value" and prescribes per-domain validation gates before batch authorization. ~37 Linear records per domain × N domains scales to hundreds of retroactive issues; gating plugin v1.0 on full fan-out conflates plugin-release with consumer-product cadence.
3. **Plugin staying on 0.x stalls real consumers.** Per CLAUDE.md § Plugin overview ("ships pre-1.0 on the `0.x` cache-propagation series per the BC-6000 same-commit bump rule and flips to `1.0.0` only after Brand Hub `/flow:retrofit-project` succeeds end-to-end"), the 0.x series signals not-yet-validated. Iter-2 validated the orchestrator's end-to-end behavior; tagging 1.0.0 unblocks downstream marketplace consumers without waiting on Brand Hub's separately-owned product backlog.
4. **Q40 sub-decision 6 already accommodates this path.** The Q56+ escalation pattern was explicitly locked at Q40 for exactly this case ("if dogfood reveals a parking lot item is actually v1.0-blocking, escalate via NEW Q-lock"); Q56 follows the prescribed pattern rather than silently bypassing or stalling on full fan-out.

**Original Q40 sub-decision 4 text (preserved verbatim per schema-discipline amendment pattern — Q35 16-amendment precedent):**

```
4. Q8 "successful" definition — concrete acceptance criteria for Brand Hub retrofit dogfood.
   Q8 (memory:48) locks the acceptance test but doesn't define "successful." Q40 fills:

   A Brand Hub /flow:retrofit-project run is SUCCESSFUL when:
   - All 9 retrofit phases complete without unrecovered failures (Q37 retrofit phase sequence
     with `legacy-cross-reference` inserted per Q14)
   - 5 user-confirmation gates fire as expected (Q10 retrofit gate budget)
   - Outputs match locked schemas:
     - docs/product/intent.md per Q41 template
     - docs/product/master-flow-inventory.md per Q11 codebase-scan output (Brand Hub
       determines its own FDA-domain count at runtime per memory:1758 — NOT pinned to
       BriteBase's 28 nor legacy-milestone count of 27)
     - docs/product/flows/<domain>/<flow-id>.md per Q27 (one per sub-flow)
     - docs/product/journeys/<domain>.md per Q26 (one per domain)
     - docs/product/flows/INDEX.md per Q25
     - Linear milestones + parents + 5N children chain per Q22-Q24 + Q13 scaffold
     - Cross-reference appendices on legacy milestones per Q14 + Q9
   - /flow:audit against retrofitted Brand Hub returns exit 0 (all hard gates pass per Q38 sub-decision 6)
   - npm run build && npm run lint && npm test pass on Brand Hub repo (FDA shouldn't break
     consumer builds)
   - Failure modes encountered during dogfood are documented at
     plugins/flow-architecture/docs/design-rationale.md (memory archive) for v1.1+ refinement
```

**Iter-2 dogfood verdict against the (now-amended) Q56 lock:**

| AC | Status | Evidence |
|---|---|---|
| AC1 — All 9 phases complete | **PASS** | iter-2 log in `brand-hub-dogfood-findings.md` § Iteration 2; Phases 1-9 all `PASS` with artifact paths recorded |
| AC2 — 5 gates fire | **PARTIAL → PASS under Q56** | All 5 gate points reached and adjudicated in-session; multi-session pause behavior re-verifiable on future BC-9559 child runs |
| AC3 — Outputs match schemas | **PASS** | 5 `test -f` probes all exit 0; Q41 + Q26 + Q27 shapes verified for scaffolded scope |
| AC4 — `/flow:audit` exit 0 | **DEFERRED → PASS under Q56 representative-subset** | Inline Phase A + Phase B + Phase C audit subset run at Phase 9; all sampled gates pass for scaffolded scope. Full 35-gate run deferred to BC-9559 children completion (separate consumer-project work) |
| AC5 — build/lint/test exit 0 | **PASS** | `npm run build && npm run lint && npm test` all exit 0 on Brand Hub repo |
| AC6 — 5N children clean | **PARTIAL → PASS under Q56 representative-demonstration** | 1 milestone (`FDA: asset-foundation`) + 1 parent (BC-9376) + 5 discipline children (BC-9377-9381) all parentId-linked; 26 legacy milestones cross-referenced with `## FDA migration` appendices. Remaining 51 sub-flows + 9 domains tracked as BC-9559 children (BC-9560..BC-9568) in Brand Hub project |
| AC7 — Failure modes documented | **PASS** | `brand-hub-dogfood-findings.md` exists with full iter-1 + iter-2 log + bug enumeration |

**Methodology lesson preserved:** the iter-2 mid-run scope reduction (10 domains → 1) should have been a user-authorized AskUserQuestion gate per [[feedback_no_unauthorized_scope_reduction]] (locked 2026-05-15) rather than an orchestrator-side auto-descope rationalized in audit-trail. Q56 retroactively legitimizes the scope choice with audit trail; the discipline going forward is unchanged — mid-orchestrator scope reductions require user gates, not after-the-fact Q-locks.

**Q56 sub-decision 1 — forward-looking discipline commitment (LOCKED 2026-05-18 per independent code-review feedback on PR #322).** Q56 is being authored AS retroactive paperwork for an already-occurred descope. To prevent this pattern from becoming routine, future Q56-style scope-amendment Q-locks **must be authored before the violating action, not after**, when the action is foreseeable. Concretely: if an orchestrator is mid-run and detects that a locked AC cannot be met under current scope (e.g., iter-2 detected at Phase 5 that scaffolding all 52 sub-flows would exceed the dogfood session budget), the orchestrator must (1) halt at the next user-confirmation gate, (2) surface the AC-conflict via AskUserQuestion with options [continue full scope / amend AC via new Q-lock / abort], (3) only proceed after explicit user authorization. Retroactive Q-locks are reserved for cases where the descope was genuinely unforeseeable (e.g., dogfood revealed a parking-lot item is v1.0-blocking — Q40 sub-decision 6's literal intent). Q56 itself violates this discipline; the discipline lock prevents the second occurrence. **Q56 sub-decision 1 promotion criterion:** if any future Q56+-style retroactive AC amendment is authored without an antecedent user-authorized gate, file as a NEW Q-lock with explicit reference to this sub-decision and re-evaluate whether the escalation pattern is being abused.

**Audit trail:** Q56 authored 2026-05-18 by orchestrator post-state-audit (sequential-thinking + Linear MCP re-verification + brand-hub-dogfood-findings.md re-read). Triggered by user instruction "continue work on the Flow-Driven Architecture Plugin v1.0" 2026-05-18; BC-6998 confirmed live `In Progress` (not `Done` as findings doc § "Iteration 2 outcome summary" line 191 prematurely claimed — likely auto-reverted on PR #316 merge per [[gotcha_github_auto_close_linear_state]]). Q56 unblocks BC-6998 close → BC-6999 release sequence (version bump 0.2.24 → 1.0.0 + handbook CDR-023 Proposed → Accepted flip + memory archive + Triage Event #2 + git tag `flow-architecture@v1.0.0`).

**v1.1 reconsideration trigger:** if downstream marketplace consumers report that the representative-demonstration interpretation of "successful Brand Hub retrofit" misled them about plugin maturity (e.g., adopting the plugin expecting full retrofit support, then discovering partial-fan-out is the canonical post-v1.0 state), promote a Q56 amendment redefining the v1.x acceptance gate for "completeness-of-consumer" vs "completeness-of-orchestrator" — the two are deliberately decoupled in Q56 but a future reconciliation may be warranted.

## Q57 — v1.1 release-gate scope: defer /flow:deprecate-legacy to v1.2; ship v1.1 on the dogfood-bug cohort + full dogfood (no feature requirement) (LOCKED 2026-05-20, per BC-10651 open-question resolution)

**Second post-v1.0 Q-lock (first v1.1-cycle lock).** Q56 was the most recent lock at v1.0 ship; Q57 is the next sequential Q-number and the first authored inside the v1.1 release cycle. The lock formalizes the v1.1 release-gate scope decision the user made resolving BC-10651's Open question ("does v1.1's release gate warrant a NEW Q-lock the way Q40 defined v1.0's?"). The user's two-part answer: (1) release criteria stay in the lightweight `production-readiness.md` checklist — NO full Q40-style 12-criterion gate; (2) a focused Q57 lock formalizes the scope deferral per the Q56 precedent + Q40 sub-decision 6 "formalize, don't bypass." Authored as BC-10652 step 3 (design-rationale archive refresh).

**Canonical lock text (transcribed verbatim from the BC-10651 user-decision comment dated 2026-05-20, per the schema-discipline amendment pattern):**

> **Q57 — v1.1 release-gate scope: defer /flow:deprecate-legacy to v1.2; ship v1.1 on the dogfood-bug cohort + full dogfood (no feature requirement).**
>
> **Context.** The v1.1 milestone's stated completion gate was "dogfood-bug cohort (BC-9026 / BC-9027 / BC-9028 / BC-9971 / BC-10302) + at least one new feature (BC-10219)." By v1.1 release time the bug cohort had shipped (plugin 1.0.4→1.0.8) and been validated end-to-end by the full Brand Hub iter-3 dogfood (BC-10321: 10 domains / 51 sub-flows / 255 discipline children, AC met EXACTLY). BC-10219 (/flow:deprecate-legacy) had not started.
>
> **Decision (2026-05-20).** Drop the feature requirement from the v1.1 gate. v1.1 ships on the validated bug-cohort + dogfood alone. BC-10219 moves to a new v1.2 milestone (retitled [v1.2]); BC-10652 release no longer blocks on it.
>
> **Rationale.** v1.1's substance is complete and validated; BC-10219 is an additive Low-priority feature whose inclusion would delay shipping the validated fixes by a multi-day build. Mirrors Q56's "formalize and ship — don't stall a release waiting on more scope" + don't conflate plugin-release cadence with feature-build cadence.
>
> **Reversibility trigger (mirror Q56 sub-decision 5).** If a consumer needs /flow:deprecate-legacy before v1.2 lands — e.g., BC-10234 (brite-base FDA-shape sweep) elects the tooling-assisted path that requires the command — re-prioritize BC-10219 as a v1.1.x patch rather than waiting for the v1.2 cut.
>
> **Sub-decision — release rigor.** v1.1 release criteria live in the lightweight production-readiness.md checklist, NOT a full Q40-style gate. v1.1 is maintenance-grade (no new methodology surface). This Q57 lock formalizes only the scope deferral, not a criteria gate.

**Number reconciliation note (authoring-time, NOT part of the verbatim lock).** The verbatim lock cites the iter-3 dogfood as **10 domains / 51 sub-flows / 255 discipline children** — the full fan-out including the `crm-sync` domain (the 10th, Salesforce-only-close domain scaffolded per BC-9564, impl deferred). BC-10651's body cites the **without-crm-sync** subset (9 domains / 46 sub-flows / 230 children); the delta is exactly `crm-sync` (1 domain × 5 sub-flows × 5 disciplines = 25 children). Both figures are correct for their stated scope; the Q57 verbatim 10/51/255 is the canonical headline (crm-sync scaffolded, impl deferred). See `production-readiness.md` § v1.1 Category B + Category C BC-9564 disposition.

**Schema-discipline / lock-canon note.** Q57 follows the Q56 new-Q-lock precedent (a fresh Q-number for a scope decision the original gate did not anticipate) rather than the amendment-with-audit-trail pattern (which extends an existing Q-lock). It is the second post-v1.0 Q-lock and the 22nd+ entry in the FDA interview lock/amendment canon (Q56 was the most recent at v1.0 ship). The two v1.1 schema amendments shipped earlier in the cycle — **Q42 amendment 1** (BC-9028, AskUserQuestion free-text-via-Other shape; this file § Q42 amendment 1) and **Q20 amendment 1** (BC-9971, inventory-only-domain re-scaffold branch; this file § Q20 amendment 1) — were authored under the amendment-with-audit-trail pattern at PR #326 / #327 respectively and are already recorded above. Q57 does not renumber or supersede them.

**Audit trail:** Q57 authored 2026-05-20 transcribing the user-decision comment on BC-10651 (Open question RESOLVED 2026-05-20). Triggered by the v1.1 release cut (BC-10652). Q57 records the scope deferral that lets BC-10652 ship without BC-10219; BC-10219 (/flow:deprecate-legacy) re-homed to the v1.2 milestone. Companion artifacts: `production-readiness.md` § v1.1 (lightweight 4-category checklist) + `triage-event-3-2026-05-20.md` (post-v1.1 parking-lot re-triage).

## Q58 — Project-side verify-docs.sh ecosystem ships as plugin templates copied at `/flow:retrofit-project` Phase 1 (LOCKED 2026-05-22, per BC-11029 iter-2 dogfood gap; A/B/C decision with Option C as planned end-state)

**Third post-v1.0 Q-lock + first authored inside the v1.2 release cycle.** Q57 was the v1.1 release-gate scope deferral; Q58 is the next sequential Q-number and the first authored against v1.2 work. Triggered by [BC-11029](https://linear.app/brite-nites/issue/BC-11029) (filed 2026-05-21) recording the verify-docs.sh-ecosystem gap surfaced during the **second-ever** `/flow:retrofit-project` dogfood — brite-roster [PR #8](https://github.com/Brite-Nites/brite-roster/pull/8) (merged 2026-05-20). PR #8's title literally framed the gap: "FDA retrofit + verify-docs.sh ecosystem foundation." Iter-1 (Brand Hub) did not surface this because brite-base already had the toolchain in place; the gap only shows up on a first-time retrofit into a project without brite-base-style scaffolding.

### Canonical lock text

> **Q58 — Project-side verify-docs.sh ecosystem ships as plugin templates copied at `/flow:retrofit-project` Phase 1.**
>
> **Context.** The `flow-architecture` plugin owns the FDA doc-tree authoring layer (`docs/product/intent.md`, `master-flow-inventory.md`, `flows/`, `journeys/`, `personas/`, per-domain scaffold logs) — `/flow:retrofit-project` produces these cleanly. The plugin did NOT own the verification toolchain consumer projects need to KEEP that doc tree maintainable (`scripts/verify-docs.sh` + `regenerate-flow-index.{sh,mts}` + `verify-linear-references.mts` + `lib/{fda-title,linear-graphql}.mts` + `normalize-fda-frontmatter.mjs` + `.flow/scaffold-log/<domain>.md`). The iter-2 dogfood proved that every future FDA adopter would re-author the same ~1,426 lines of bash + .mts; brite-roster did it by hand, modeled on brite-base.
>
> **Decision (2026-05-22).** The plugin now ships `plugins/flow-architecture/templates/{scripts,.flow}/` carrying the canonical reference impl of the verify-docs.sh ecosystem. `/flow:retrofit-project` Phase 1 grows a templates-scaffold step (between `.flow/config.json` write and the Phase 1 terminal breadcrumb write) that copies the templates into the consumer project + sed-substitutes 4 placeholders + `chmod +x`'s the `.sh` files.
>
> **Path A / B / C evaluation:**
>
> - **Option A — Templates + copy-on-retrofit (CHOSEN for v1.2).** Plugin ships canonical impl as `templates/`; orchestrator copies. Tracks the brite-base + brite-roster precedent. Simplest path; fastest to ship; consumer-owns the script post-copy per Q29.7. **Disadvantage:** bug fixes in the canonical impl require each consumer to re-run `/flow:retrofit-project --overwrite-scripts` (or hand-port).
> - **Option B — Plugin-internal command (no project-side files).** Ship `/flow:verify-docs` as a plugin command that runs verification logic against the project's filesystem. **Rejected.** Loses npm-run-verify-docs integration (`bash scripts/verify-docs.sh` is hook-callable + CI-callable + dev-workflow-native; a slash command isn't); harder to customize per-project. Backwards step on `npm run` integration the brite-roster + brite-base precedent already established.
> - **Option C — Hybrid (plugin-owned logic + thin project wrapper).** Plugin ships the actual logic in `plugins/flow-architecture/scripts/`; retrofit installs a 6-line `scripts/verify-docs.sh` wrapper in the project that `exec`s the plugin script. **Planned end-state; deferred to v1.x / v2.** When Option C ships, the migration cost is bounded: each project's `scripts/verify-docs.sh` becomes a 6-line `exec` wrapper around the plugin script; bug fixes propagate via plugin version bump rather than per-project edits. Option A is exercised by ≥2 retrofits before Option C migration; Q58 records the trigger.
>
> **Q29.7 reconciliation.** Q29.7 locks "verify-docs.sh is consumer-project-owned … leverage existing infrastructure rather than duplicating it." Q58 PRESERVES Q29.7's consumer-project-ownership semantics — the on-disk `scripts/verify-docs.sh` is still consumer-owned and consumer-editable after retrofit. Q58 specifies the canonical TEMPLATE SOURCE (where the consumer gets it from), not the OWNERSHIP (which stays with the consumer per Q29.7). The verify-docs.sh-is-not-duplicated semantics remain: the consumer has exactly one copy under their `scripts/`; the plugin ships the canonical template, never a runtime executable.
>
> **Placeholder substitution at scaffold-time.** Four placeholders are sed-substituted by the orchestrator during the Phase 1 templates-scaffold step:
>
> | Placeholder | Substituted from | Used in |
> |---|---|---|
> | `<LINEAR_PROJECT_ID>` | `.flow/config.json` `linear_project_id` | `scripts/lib/linear-graphql.mts` (`PROJECT_ID` export) |
> | `<LINEAR_ORG_SLUG>` | parsed from Linear project URL via `mcp__plugin_workflows_linear-server__get_project` | `scripts/regenerate-flow-index.mts` (`LINEAR_ORG` constant — used for parent-cell link rendering) |
> | `<PROJECT_NAME>` | `.flow/config.json` `linear_project_name` | `scripts/regenerate-flow-index.mts` (`HEADER_BODY` text) |
> | `<EXPECTED_FDA_ISSUE_COUNT>` | literal `0` (count gate disabled by default) | `scripts/verify-linear-references.mts` (`EXPECTED_FDA_ISSUE_COUNT` constant; the count gate is a no-op when `0`) |
>
> Placeholder substitution avoids a Q12 `.flow/config.json` schema amendment to add new fields (e.g., `linear_workspace_slug`). Trust boundary: MCP responses + `.flow/config.json` values are treated as data; they cross into shell only via discrete `sed -e` argv arguments (never `bash -c` strings or unquoted `$(...)`).
>
> **Idempotency design.** Default behavior: per-file check (`test -f` each of the 9 target paths); HALT Phase 1 if ANY exists; orchestrator emits the conflict list and exits. `--overwrite-scripts` flag (orchestrator CLI) bypasses the check + writes all 9 unconditionally. No diff prompts in v1.2; v1.3 candidate.
>
> **Brite-roster vs brite-base divergences observed at template authoring time** (the canonical template resolves these as follows):
>
> 1. `LINEAR_ORG = "brite-nites"` (brite-roster + brite-base both hardcode) → `<LINEAR_ORG_SLUG>` placeholder.
> 2. `BRITE_ROSTER_PROJECT_ID = "9c305022-..."` (brite-roster) vs equivalent constant in brite-base → `<LINEAR_PROJECT_ID>` placeholder.
> 3. `EXPECTED_PHASE_4_COUNT = 240` (brite-roster) → `<EXPECTED_FDA_ISSUE_COUNT>` placeholder with default `0` (gate disabled). Consumer bumps to their expected count once known.
> 4. `FDA_DOMAINS = new Set(["IDN", "LSM", ...])` 12-domain brite-roster set → empty set + comment block instructing population per project's `master-flow-inventory.md`. Empty set = label-hygiene gate disabled (no-op).
> 5. `normalize-fda-frontmatter.mjs` 219 lines of brite-roster-specific parent-issue / display-name / status-override tables → ~80-line TODO skeleton with empty data tables; ships as opt-in one-shot migration tooling, not a runtime ecosystem dependency. Exits with `status: "no-op"` when tables are empty.
> 6. `HEADER_BODY` brite-roster narrative + 14-domain order in `regenerate-flow-index.mts` → `<PROJECT_NAME>` substitution + neutral 3-line section-order paragraph that reads correctly for any project.
> 7. Cross-repo path exclusion in `verify-docs.sh`'s internal-link check (brite-roster excludes 9 specific sibling-repo names) → generic `\.\./` cross-repo exclusion suitable for any project; consumer tightens if they cross-link into specific sibling repos.
>
> **Out-of-scope for v1.2 (deferred):**
>
> - **`/flow:start-project` parity.** Greenfield orchestrator does not get the templates-scaffold step in v1.2. File sibling BC after Q58 ships. Rationale: BC-11029 surfaced during retrofit; greenfield has not been dogfooded against this gap; doubling integration surface in one PR is unwarranted.
> - **brite-roster + brite-base swap to plugin-provided versions.** Both stay on their hand-authored copies until ≥1 more retrofit dogfoods the templates path. Sibling BCs filed post-Q58 ship.
> - **Option C migration.** Trigger: Option A exercised by ≥2 retrofits + the documented consumer pain (re-running `--overwrite-scripts` after a plugin bug fix is not ergonomic). v1.x or v2 candidate.
> - **Pre-commit hook integration.** Per-project concern; the `verify-docs.sh` script is hook-callable today, wiring via husky/lefthook is consumer-side.
> - **Adding new checks to `verify-docs.sh` itself.** Q58 ships the EXISTING impl. New checks (decision-trace freshness, ADR cross-references, etc.) are separate v1.x feature issues.

### Sub-decision 1 — `templates/` schema discipline

The 9 template files under `plugins/flow-architecture/templates/` are the canonical schema reference for the verify-docs.sh ecosystem. Changes to the templates require:

1. **Bump plugin version** in the same commit (BC-6000 same-commit discipline) — both `plugins/flow-architecture/.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json`.
2. **Re-run the `tests/run-verify-docs-ecosystem-vslice.sh` harness** before merging — asserts no `<PLACEHOLDER>` strings appear outside `templates/`, no `brite-roster` / `brite-nites` references leak into the templates, all 9 files have canonical homes.
3. **Document divergence** if amending one template-side file requires amending the orchestrator's substitution flow in `commands/retrofit-project.md` Phase 1 — schema-discipline amendment pattern (cf. Q31 amendment precedents).

### Sub-decision 2 — Idempotency reversibility

Re-running `/flow:retrofit-project` on a project that already has the templates is THE expected steady state once a project has been retrofitted. The default error-if-exists semantics intentionally bias toward consumer-side modification preservation. The `--overwrite-scripts` flag is the ONLY in-orchestrator path to re-install templates; a consumer wanting a per-file diff or selective overwrite is expected to `git checkout` the relevant files locally + re-run.

### Sub-decision 3 — Migration trigger for Option C (planned end-state)

Q58 commits to Option A for v1.2; Option C remains planned end-state. The migration trigger for Option C lands a new Q-lock (future) when ANY of the following becomes true:

1. **≥2 plugin bug fixes** require coordinated per-consumer re-runs of `/flow:retrofit-project --overwrite-scripts` to propagate; consumer report friction.
2. **≥3 retrofits** have run against the templates without operator-driven hand-editing of the substitution output — confirms the templates are mature enough for plugin-side ownership.
3. **A consumer explicitly requests** the Option C wrapper-call pattern in a BC.

When the trigger fires, the Q58-successor Q-lock captures: (1) the migration recipe (each consumer's `scripts/verify-docs.sh` becomes a 6-line `exec` wrapper); (2) deprecation of the templates directory (or its retention as schema reference); (3) backwards-compatibility window for consumers still on the Option A copy.

### Version + milestone

- **Plugin version:** 1.1.1 → 1.2.0 (minor bump). Q57 locked v1.1 = maintenance-only; shipping a substantive new feature (templates + Phase 1 integration) inside v1.1 would violate that scope discipline. The minor bump signals the new capability to consumers.
- **Milestone:** BC-11029 moves from v1.1 milestone → v1.2 milestone (`aac7eb53-4636-4e13-898d-b72375ddc5a9`). Joins [BC-10219](https://linear.app/brite-nites/issue/BC-10219) (`/flow:deprecate-legacy` orchestrator).

### Schema-discipline / lock-canon note

Q58 follows the Q56 / Q57 new-Q-lock precedent (a fresh Q-number for a scope decision the original gate did not anticipate) rather than the amendment-with-audit-trail pattern. It is the 3rd post-v1.0 Q-lock and the 23rd+ entry in the FDA interview lock/amendment canon (Q57 was the most recent at v1.2 cycle entry). Q58 does not renumber or supersede Q29.7 — see § Q29.7 reconciliation above.

### Audit trail

Q58 authored 2026-05-22 by orchestrator session-start synthesizing the BC-11029 handoff prompt + brite-roster PR #8 reference impl read + `commands/retrofit-project.md` Phase 1 structural analysis. Triggered by BC-11029 scoping (filed 2026-05-21). Sibling BCs to file post-ship: (a) `/flow:start-project` templates-scaffold parity; (b) brite-roster swap to plugin-provided scripts (low priority — current code works); (c) brite-base swap to plugin-provided scripts (defer until ≥2 more dogfood iterations). Companion artifacts: `plugins/flow-architecture/templates/README.md` (consumer-facing install + Option C migration plan) + `tests/run-verify-docs-ecosystem-vslice.sh` (harness asserting template fidelity) + BC-6956 description amendment (layer-boundary note: BC-6956 = plugin-internal helpers under `plugins/flow-architecture/scripts/`; BC-11029 = project-side toolchain templates under `plugins/flow-architecture/templates/`).

### Q58 amendment 1 — `/flow:start-project` parity + recipe-block expansion (2026-05-26, [BC-11089](https://linear.app/brite-nites/issue/BC-11089))

**What changed.** Two orchestrator-level changes close the Q58 § Out-of-scope gap (a) and fold in the BC-11029 final-review P3 #3:

1. **`/flow:start-project` gains the templates-scaffold step.** The same 5-step recipe (resolve org slug → build arrays → idempotency check → copy+substitute+chmod → emit confirmation) now appears in `commands/start-project.md` Phase 1, byte-identical to `commands/retrofit-project.md` Phase 1. Greenfield projects bootstrapping via `/flow:start-project` no longer skip the verify-docs ecosystem. The `--overwrite-scripts` flag, failure semantics, and trust-boundary discipline are identical across both orchestrators.

2. **Recipe-block expansion in both orchestrators.** The `cp` + `mkdir -p` + `chmod +x` loops and the `SRC_PATHS` / `TARGET_PATHS` array construction are now explicit inline bash in both `start-project.md` and `retrofit-project.md` (previously elided as prose in retrofit-project.md). This keeps the orchestrator-LLM from needing to synthesize the mechanical recipe from narrative paragraphs at runtime.

**What did NOT change.** Q58's core decisions (Option A for v1.2, Option C as planned end-state, Q29.7 consumer-ownership semantics, idempotency design, placeholder substitution set, sub-decision 1 schema discipline, sub-decision 2 reversibility, sub-decision 3 migration trigger) are all unchanged. The amendment extends coverage to a second orchestrator surface; it does not alter the recipe itself.

**Regression prevention.** [BC-11091](https://linear.app/brite-nites/issue/BC-11091)'s `tests/run-verify-docs-ecosystem-integration-vslice.sh` gains §9 — a contract-sync check against `start-project.md` mirroring §8's check against `retrofit-project.md`. The same 24 assertions (9 template refs + 4 placeholders + 7 primitives + 4 esc() metachar handlers) are verified in both files. Regression-validated: mutate start-project recipe → test FAILS; revert → test PASSES.

**Audit trail.** Q58 amendment 1 authored 2026-05-26 by executor session implementing [BC-11089](https://linear.app/brite-nites/issue/BC-11089). Closes the gap called out in Q58 § Out-of-scope item (a). Plugin version 1.2.3 → 1.2.4 (patch — additive parity, no breaking change).

### Q58 amendment 2 — seed the canonical doc templates into consumers (copy manifest 9 → 11) + journey/story-doc-author drift correction (2026-05-30, [BC-11983](https://linear.app/brite-nites/issue/BC-11983) WS-E precursor)

**Trigger.** The brite-sites WS-E doc pass (PR #32) surfaced that the FDA-generated journey + story docs had **drifted structurally from the canonical handbook templates** (`about-handbook/style-guide/templates/{domain-journey,job-story}.md`) — losing `## Decision points` / `## Open questions` (journey) and `## Preconditions` / `## QA history` (story), and adding domain-level duplicate `Pain points`/`Opportunities`/`Sub-flows`/consolidated `Job stories` sections. Full decision record + grill (D1–D6) in [`docs/designs/fda-journey-story-template-alignment.md`](../../../../docs/designs/fda-journey-story-template-alignment.md).

**Root cause (two layers).** (1) The author reads `template_path = docs/templates/<journey|job-story>.md` from the **consumer repo**, but the plugin shipped **only** the verify-docs.sh ecosystem (`templates/scripts/` + `.flow/`), never the doc templates — so a consumer without the hand-promoted handbook templates (brite-sites) had no file to read; (2) the author's fallback prose (`journey-doc-author` / `story-doc-author`) had itself drifted from its own **Q15 / Q16 canonical-section locks**.

**What changed (plugin-side only — handbook templates were already canonical).**
1. **Seed the doc templates (Q58 manifest 9 → 11).** The plugin now ships `templates/docs/templates/{domain-journey,job-story}.md` (canonical structure + the FDA-additive sections — `## L2 review summary` per Q26 mod 2, conditional `## Cross-domain dependencies` per Q27 amendment 1 mod 4, `## Status notes`, and an evidence-anchor `## Status` section [grill D4]). Both `/flow:start-project` + `/flow:retrofit-project` Phase 1 templates-scaffold copy them into the consumer's `docs/templates/`. Only the journey template's `linear_project_id: <LINEAR_PROJECT_ID>` is sed-substituted; all authoring placeholders (`<DOMAIN>`, `<DOMAIN-NN>`, `<role>`) pass through intact.
2. **Drift correction to the Q15 / Q16 agent locks.** `journey-doc-author` + `story-doc-author` prose re-aligned to the canonical section order their Q15/Q16 locks already specified. The per-phase-only rule (no domain-level duplicate sections), the canonical-order enumeration, and a `(sometimes)`-is-a-template-annotation rule (+ matching `fidelity-reviewer` conditional-section handling, so a correctly-omitted optional section never false-FAILs the structural gate) are made explicit. This includes **dropping `## Title + domain code`** from the journey author + seeded template: Q26 mod 3 + Q16 sub-decision 1 already removed it (redundant with the H1 `# <DOMAIN>: <Display name>`); the first implementation cut wrongly re-added it by copying the **stale handbook template file**, which still carries the section its own Q26 mod 3 dropped (flagged in adversarial review; a separate handbook-template cleanup should drop it there too). Frame rules (D11 / EARS constraint-spec) unchanged. **One genuinely new body section** — the evidence-anchor `## Status` on the story doc (grill D4) — is a Q27 schema addition recorded as **Q27 amendment 2** (not folded silently here).

**Frontmatter (grill D3, amended).** Story frontmatter = full canonical incl. per-discipline `eng_status`/`design_status`/`docs_status`/`qa_status` — these are the **published delivery-state mirror** `regenerate-flow-index.mts` renders into the `INDEX.md` grid (Linear stays orchestration SoT). Omitting them silently blanks that dashboard, so the original "hybrid: omit volatile state" framing was reversed during implementation.

**Regression prevention.** New `tests/run-template-alignment-vslice.sh` (50 assertions; validate.sh §2b''''''''''') — grep-triad (catchphrase + structural + negative) over both templates, both agents, and both orchestrators' copy arrays; mutation-verified. `tests/run-verify-docs-ecosystem-vslice.sh` §3b scoped to exclude `templates/docs/` (doc templates are a separate category from the verify-docs ecosystem).

**Audit trail.** Q58 amendment 2 authored 2026-05-30 by grill-with-docs session (BC-11983 WS-E precursor). Plugin version 1.2.8 → 1.2.9 (patch — additive template seeding + agent drift correction, no breaking change). Sequencing: template-first → re-pass brite-sites → 6 remaining WS-E repos (grill D6).

## Q59 — `/flow:deprecate-legacy` orchestrator: Phase 5 legacy-milestone retirement codified as a two-pass command (LOCKED 2026-05-26, per [BC-10219](https://linear.app/brite-nites/issue/BC-10219))

Phase 5 of the FDA lifecycle — retiring legacy milestones after a project's retrofit is complete — was previously a manual process (precedent: [BC-6580](https://linear.app/brite-nites/issue/BC-6580) BriteBase). Q59 codifies the 4 per-milestone sub-steps into a repeatable orchestrator command at `commands/deprecate-legacy.md`.

### The 5 design decisions

**Sub-decision 1 — Two-pass execution model.**

Mirrors Q14.6's filesystem-artifact gate pattern. Pass 1 generates a review doc (`docs/plans/<project-slug>-deprecate-legacy.md`) with a per-milestone disposition table; operator reviews + edits + bumps `last_reviewed: TBD` to ISO-8601. Pass 2 (on re-invocation) detects `last_reviewed != TBD`, enforces the pre-comms gate, then executes the serial per-milestone disposition. The two-pass split ensures:

- Operator review of every disposition (re-home / close-as-obsolete / scoping-needed) before any mutation.
- A filesystem artifact (not a chat-ack) as the review-completion signal — the same unambiguous check that Q14.6 established.
- Resumability across sessions (review doc tracks per-milestone progress markers).

**Sub-decision 2 — Pre-comms 24h gate.**

Before Pass 2 executes, the review doc must contain a `## Pre-comms posted at <ISO-8601>` header that is ≥24 hours old. Rationale: legacy milestones are shared team context; teammates working in or referencing those milestones need advance notice before their issues move or close. The 24h window mirrors the BC-6580 manual precedent where a Slack announcement preceded the deprecation by ~1 business day.

The gate is enforced mechanically (ISO-8601 timestamp delta ≥ 24h) rather than via chat acknowledgment. This prevents accidental same-day execution and creates an audit trail of when the team was notified.

**Sub-decision 3 — `flow-legacy-cross-reference` stays user-invocable (approach a).**

The existing skill at `skills/flow-legacy-cross-reference/SKILL.md` had `user-invocable: false` + `disable-model-invocation: true`. Q59 lifts both flags, making the skill user-invocable. Two consumers:

- `/flow:retrofit-project` (existing) — dispatches the skill at Phase 3 for annotation per Q9 additive-only contract.
- `/flow:deprecate-legacy` (new) — invokes the 3-tier mapping cascade (Sections 1-6) at Pass 1 for disposition mapping.

The annotation logic (Sections 1-6) is the shared reuse surface. The re-home/close/archive steps in `/flow:deprecate-legacy` are new to that command and NOT part of the skill. The simpler approach (a) was chosen over approach (b) — extracting into `_shared/` — because only the mapping cascade is reused, not a separable "shared module" with its own lifecycle.

**Sub-decision 4 — Cadence linear-housekeeping NOT extended.**

The cadence plugin's batch-mutation framework (`linear-housekeeping/SKILL.md`) is intentionally NOT extended with `milestone-archive` / `milestone-rehome` mutation types. Three reasons:

1. Cross-plugin coupling: flow-architecture → cadence dependency direction is novel and unjustified for a single use case.
2. Self-contained batch logic: `/flow:deprecate-legacy` already has AskUserQuestion gates at each milestone boundary and its own preview/approve/execute cycle.
3. Low reuse frequency: milestone deprecation is a once-per-retrofit lifecycle event, not a weekly cadence operation.

If a future use case requires milestone mutations from cadence (e.g., bulk milestone renames during sprint planning), a Q-lock amendment can add the types at that time. The decision is conservative — adding coupling is easy; removing it is not.

**Sub-decision 5 — Q9 scope widening for Phase 5 controlled mutations.**

Q9 (memory:64) established: "Retrofit is additive-only with cross-reference annotations." The annotation step (sub-step c in `/flow:deprecate-legacy`) honors Q9 — it extends the existing `## FDA migration` appendix within the Q14 markers. But sub-steps a (re-home issues) and b (close-as-obsolete) are MUTATIONS that go beyond Q9's additive-only scope.

Q59 explicitly widens the Phase 5 contract: controlled mutations on legacy milestones are permitted WHEN:

- The project's FDA retrofit is complete (breadcrumb at `status: completed`).
- An operator has reviewed and approved each milestone's disposition (Pass 1 review doc gate).
- The team has been notified (pre-comms 24h gate).
- Each milestone is individually confirmed (per-milestone AskUserQuestion gate).

The widening is scoped to `/flow:deprecate-legacy` only. Other FDA commands continue to honor Q9's additive-only contract for legacy milestones.

### Per-milestone sub-step ordering (LOCKED)

For each legacy milestone, execute in this exact order:

1. **Re-home open issues** — `save_issue` + `save_comment` per issue to move to FDA domain milestone.
2. **Close-as-obsolete** — `save_issue` (state → Canceled) + `save_comment` per remaining issue.
3. **Annotate milestone** — extend `## FDA migration` appendix within Q14 markers (marker-based idempotent rewrite).
4. **Archive hand-off** — `AskUserQuestion` gate (Linear MCP doesn't expose milestone archive API).

Ordering rationale: issues must be re-homed/closed BEFORE annotation (so the annotation accurately reflects the final state); annotation BEFORE archive (so the appendix is written while the milestone is still accessible).

### Review doc schema (LOCKED)

Front-matter fields: `generated_by`, `generated_at`, `last_reviewed`.

Disposition table required columns: `Legacy Milestone`, `Mapped FDA Domain(s)`, `Open Issues`, `Closed Issues`, `Proposed Disposition`, `Source Signal`.

Valid disposition values: `re-home`, `close-as-obsolete`, `scoping-needed`.

Progress markers (inline in disposition table during Pass 2): `[DONE]`, `[SKIPPED]`, `[ERROR: <reason>]`, `[PENDING]`.

### Version + milestone

- **Plugin version:** 1.2.4 → 1.2.5 (patch — new command, additive).
- **Milestone:** [BC-10219](https://linear.app/brite-nites/issue/BC-10219) in v1.2 milestone. Closes the v1.2 scope entirely.

### Audit trail

Q59 authored 2026-05-26 by executor session implementing [BC-10219](https://linear.app/brite-nites/issue/BC-10219). Triggered by v1.2 milestone scope (Q57 deferred `/flow:deprecate-legacy` from v1.1 to v1.2). Precedent: [BC-6580](https://linear.app/brite-nites/issue/BC-6580) (BriteBase manual Phase 5 deprecation, Done). Companion: [BC-10234](https://linear.app/brite-nites/issue/BC-10234) (brite-base FDA-shape sweep — depends on this BC for tooling-assisted mode).
