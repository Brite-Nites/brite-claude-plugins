# Triage Event #3 — Post-v1.1 parking-lot re-triage

> **Per Q40 sub-decision 5 step 9 + sub-decision 6, applied to the v1.1 release cycle** ([`fda-plugin-interview.md`](fda-plugin-interview.md)). Re-walks all parking-lot entries (#1–#55 at file lines ~2035–2135) after the **full Brand Hub iter-3 dogfood** (BC-10321: 10 domains / 51 sub-flows / 255 discipline children, AC met EXACTLY). Distinct from **Triage Event #2** (post-v1.0, 2026-05-18), which ran under the 1.9% scope-cap (1 domain × 1 sub-flow) and reached 0 promotions / HOLD-by-default because the cap could not exercise cross-domain signals. Triage Event #3 fires INSIDE the v1.1 release sequence (BC-10652 step 4), authored alongside the Q57 scope lock and the v1.1 production-readiness checklist.
>
> **Why this re-triage is substantive, not a rubber-stamp.** Triage Event #2's own closing note predicted: "the next Triage Event would naturally fire after Brand Hub fan-out completes (BC-9559 children, 9 remaining domains) — at that point, cross-domain signals become measurable and several HOLD entries should re-evaluate (#26, #41, #43, #44, #50)." That fan-out is exactly what iter-3 delivered. This event walks those entries against real cross-domain evidence — and reaches **non-HOLD verdicts**, including one HOLD that is a deliberate *reversal* of the naive at-scale read.
>
> Inputs: parking lot (55 entries); iter-3 dogfood evidence ([`brand-hub-dogfood-findings.md`](brand-hub-dogfood-findings.md) § Iter-3 + § Post-iter-3 crm-sync close); the v1.1 dogfood-bug cohort (BC-9026 / BC-9027 / BC-9028 / BC-9971, shipped 1.0.4→1.0.8) + the iter-3-surfaced BC-10352 (P2, open) + BC-9564 (crm-sync scaffold, impl deferred) + BC-6039 (consumer prod concern); the Q57 scope lock (locked 2026-05-20).

## Verdict summary

- **2 hard PROMOTE** to v1.1.x backlog: **#6** (issue-level cross-reference annotations) and **#54** (bash unit tests for the 4 helper scripts).
- **1 soft PROMOTE** to a low-priority evaluation task: **#26** (journey-doc-author sonnet→opus) — its gating condition (a cross-domain authoring run) is now met, though no quality deficit was logged.
- **1 deliberate HOLD-with-reversal**: **#7** (`--auto-accept-priors` for inventory-codebase-scan) — the at-scale signal arrived and argues *against* the feature, not for it (the confirmation interview caught 6 real inventory-drift corrections that auto-accept would have silently shipped wrong).
- **0 RETIREMENTS** (no entry revealed as not-actually-needed).
- **1 DONE** carried forward unchanged: **#45** (drift-detection runtime tooling, promoted to advisory CI guard via BC-7060 on 2026-05-12).
- **Cross-domain retro entries (#41, #43, #44, #50) remain HOLD** — iter-3 *scaffolded* domains but shipped/completed none, so the "completed domains" + "/flow:review-at-depth" signals these gate on are still absent. Explicit rationale below (this is not a default HOLD — it is a verified "the gating signal still hasn't fired").
- **All remaining entries hold at their Triage Event #2 disposition** unless listed below.
- **1 NEW candidate** surfaced by iter-3, not currently a parking-lot entry: an **inventory-"BUILT" criterion tightening** (BUILT = operator can consume through the intended surface, not merely API-callable) — recommend filing fresh, see "New candidates" below.
- **1 NEW Q-lock authored this release window**: **Q57** (v1.1 release-gate scope deferral — defer /flow:deprecate-legacy to v1.2). Recorded in [`fda-plugin-interview.md` § Q57](fda-plugin-interview.md). Q57 is a scope lock, not a parking-lot promotion.

## Entries whose disposition CHANGED vs Triage Event #2

Categorized by the four Triage dispositions: **PROMOTE** (cross-domain signal now justifies near-term work), **RETIRE**, **HOLD** (still a v1.x candidate; signal absent or feature contraindicated), **DONE**.

| # | Title (truncated) | Triage #2 | Triage #3 | iter-3 evidence + rationale |
|---|---|---|---|---|
| 6 | Issue-level cross-reference annotations | HOLD | **PROMOTE** | iter-3's 10-domain fan-out surfaced a dense cross-domain dependency graph invisible at iter-2's 1-domain cap: explicit build-order blocks (`asset-unification-02` → `creative-operations-01/-02`; `analytics-dashboard-03` → `asset-content-libraries-05`; `crm-sync` transitively gated on `creative-operations-02` + `analytics-dashboard-04`) and gating-concentration hotspots (`access-governance-02/-06/-07` each gate multiple batch-1 sub-flows). These dependencies currently live only as prose in story docs. Issue-level cross-reference annotations (Linear `blockedBy`/`relatedTo` + doc cross-refs) would make the graph machine-visible for plan-ordering. **File as v1.1.x enhancement, Medium.** |
| 7 | `--auto-accept-priors` flag for inventory-codebase-scan | HOLD | **HOLD (reversal)** | The at-scale signal #7 gated on has now arrived — and it argues *against* the feature. iter-3 logged **6 inventory-drift corrections** (batch 1: 3; batch 2: 3; batch 3: 0) where the codebase-scan marked a sub-flow ✓ BUILT but the operator-facing surface did not consume the primitive. The Phase 5 confirmation interview *caught* all 6; `--auto-accept-priors` would have silently shipped them wrong. Keep HOLD — the confirmation step is earning its keep. Re-evaluate only if a future inventory-criterion tightening (see New candidates) drops the drift rate to ~0. |
| 26 | journey-doc-author sonnet → opus | HOLD | **PROMOTE (soft / evaluate)** | The trigger #26 named — "a cross-domain authoring run" — is now met: iter-3 authored 10 journey docs on sonnet (Q21 lock), including a distinct narrative shape (`crm-sync` "integration-readiness arc gated on an external dependency"). No quality deficiency was logged, so this is a *soft* promote: file a **Low**-priority opus A/B evaluation task, not a blocker. Decide on measured quality delta, not assumption. |
| 41 | `/flow:retro --cross-domain` time-window flag | HOLD | **HOLD (signal still absent)** | iter-3 *scaffolded* 10 domains but *completed/shipped* none — `/flow:retro` fires on domain ship, and `--cross-domain` needs ≥2 completed domains. The fan-out exercised scaffolding, not the ship/retro path. Re-evaluate after the first ≥2 domains ship in a consuming project. |
| 43 | "Plan Completion" cross-skill-state mining for retros | HOLD | **HOLD (signal still absent)** | Same as #41 — needs Q53 ship maturity + completed-domain plan-completion data. iter-3 produced no ship-time plan-completion records. |
| 44 | Team retro facilitation features | HOLD | **HOLD (signal still absent)** | iter-3 was a solo dogfood; no multi-participant retro need surfaced. |
| 50 | Plan-context augment retire for Q52 | HOLD | **HOLD (signal still absent)** | iter-3 did not run `/flow:review` at depth on the scaffolded output, so the "do reviewers benefit from plan context?" question is still unmeasured. |
| 54 | Bash unit tests for 4 helper scripts | HOLD | **PROMOTE** | The Q40 R3 promotion criterion ("any v1.x release introduces schema regression") is **formally met** by BC-10352: the Phase 2 classifier `flow-classify-domain-state.sh` hard-rejected Brand Hub's iter-2 shipped inventory on 3 schema axes (UPPERCASE-vs-lowercase, bare-vs-backtick-wrapped H3, triple-hyphen-vs-em-dash). That is exactly the parser bug a bash unit test on the helper would catch. The bug was load-bearing — manual orchestration fallback was needed across **all 10** iter-3 domains because the orchestrator-driven path was blocked. **File as v1.1.x, High** (it gates retiring the manual fallback). |
| 45 | Drift-detection for cloned workflows commands | DONE | **DONE (unchanged)** | Carried forward — promoted to advisory CI guard via BC-7060 (2026-05-12): `scripts/check-clone-drift.sh` + advisory `clone-drift-check` job. Entry stays open as the tracker for the hard-block promotion (`continue-on-error: false` flip). iter-3 surfaced no clone drift. |

## Entries re-checked and confirmed HOLD (no change)

The remaining 46 entries hold at their Triage Event #2 disposition. The full-fan-out evidence base was checked against each class:

- **Architecture / config / v2+ entries (#1, #2, #3, #8, #9, #10, #14, #25, #30, #46, #47):** no v1.1 signal; iter-3 ran cleanly on the v1 architecture (3-pattern state split #30 produced no consolidation pressure across 10 domains; `.flow/config.json` future fields #14 surfaced no need across the 10-domain fan-out).
- **Doc / template polish (#11, #12, #13, #16, #17, #22, #23, #24, #29):** iter-3 authored 10 journey docs + 51 story docs without surfacing pain in these (flow-ID padding #23 untouched — no domain crossed 99 flows; max was 8 sub-flows in `ops-hardening`).
- **Q46 writeback + Linear-gate batching (#27, #35, #36, #37, #38, #49):** iter-3's manual-orchestration fallback wrote Linear via direct `save_milestone`/`save_issue` calls rather than the Q46 writeback path at scale, so the Q46-specific signals these gate on were not exercised; the #27 `linear-children-match` batched-gate extraction stays gated on its third-caller threshold (Q38 already adopted the batched pattern inline, so no v1.1 extraction pressure). HOLD, not promoted on absent evidence.
- **Test-surface siblings #52, #53, #55:** unlike #54, these had no v1.1 regression — the `plugin.json` manifest (#52) and SKILL.md frontmatter (#53) were correct throughout iter-3, and trigger-resolution (#55) was bypassed entirely by manual orchestration (so not exercised). HOLD. **Note:** if #54 is filed, #52/#53/#55 are the cheapest co-located CI insurance and could ride along as a bundle — but they are not independently signal-justified by iter-3.
- **Methodology / discipline notes (#4, #5, #15, #18, #19, #20, #21, #28, #31, #32, #33, #34, #39, #40, #42, #48, #51):** discipline guidance or features gated on signals the scaffold-only dogfood did not exercise. #19 (selective re-author / `/flow:journey-refresh`) is the closest near-miss — iter-3 re-scaffolded inventory-only domains (Branch B per Q20 amendment 1) — but that path shipped its fix (Q20 amend 1) and its follow-up is tracked as BC-10352, not as #19. HOLD.

## New candidates surfaced by iter-3 (not currently parking-lot entries)

1. **Inventory-"BUILT" criterion tightening.** iter-3 logged 6 drift corrections where `master-flow-inventory.md` marked a sub-flow ✓ BUILT but the operator could not consume it through the intended surface (the API was callable but no `.tsx` consumed it; or the inventory anchor pointed at a different surface entirely). The findings doc recommends (twice) tightening the criterion in writing: **"BUILT = an operator can consume the sub-flow through its intended surface, not merely that the API is callable."** Reference clean-inventory domains: `data-quality-migration` + `ops-hardening` (0 corrections). Recommend filing as a `flow-inventory-codebase-scan` doc/criterion issue, Medium. Interacts with #7 (a lower drift rate would re-open the auto-accept-priors question).

2. **Manual-orchestration-fallback retirement gate.** Across all 10 iter-3 domains the orchestrator-driven `/flow:add-domain` path was never exercised — manual orchestration (direct Linear MCP + `Write`) was load-bearing throughout because BC-10352 blocked the classifier. The findings recommend: re-validate the orchestrator-driven path against one fresh domain when BC-10352 ships (v1.1.x), then retire the fallback if clean. This is tracked under BC-10352's resolution, not as a new parking-lot entry; noted here so the dependency (#54 unit tests + BC-10352 fix → fallback retirement) is explicit.

3. **Vocabulary-collision doc discipline (Q28).** iter-3 surfaced 5 cross-domain vocabulary collisions (image-level vs request-level "approval"; image-flagging vs feature "flags"; CI "test" vs request-QC; ops "hardening" vs share-link work; Brand Hub↔SF "sync" vs Brite Base↔SF mirror; SF "card" vs kanban "card"). These are consumer-side authoring concerns the Q28 story-doc discipline already covers in principle; iter-3 confirms the discipline is load-bearing at fan-out scale. No plugin change needed — noted as a methodology observation for the operating-standards FDA page.

## Filing recommendation (for the maintainer)

The three promotions are recorded here as Triage Event #3 verdicts; filing them as Linear backlog issues is the downstream clerical step (mirrors Triage Event #2's promote-to-backlog pattern — Triage #2 simply had nothing to file). Recommended:

| Source | Title | Milestone | Priority |
|---|---|---|---|
| #54 | Bash unit tests for the 4 helper scripts (would have caught BC-10352) | v1.1.x | High |
| #6 | Issue-level cross-reference annotations for cross-domain dependency graph | v1.1.x / v1.2 | Medium |
| New #1 | Tighten inventory "BUILT" criterion (operator-consumable, not API-callable) | v1.1.x | Medium |
| #26 | journey-doc-author sonnet→opus A/B evaluation | v1.2 | Low |

## Methodology lesson preserved

Triage Event #2 was a short, honest HOLD-by-default outcome *because the dogfood was scope-capped*. Triage Event #3 is the counter-example the v1.1 cycle was designed to produce: a real cross-domain evidence base (full fan-out) yields real promotions (#6, #54), a soft promote (#26), an evidence-driven *reversal* (#7 stays HOLD because the at-scale signal contraindicated the feature), and a clear "still absent" verdict for the entries gated on the ship/retro path that scaffolding alone cannot exercise (#41, #43, #44, #50). The discipline lesson: re-triage cadence should track *which signal* an entry gates on, not calendar time — iter-3 unlocked the cross-domain-dependency and helper-script-regression signals but left the completed-domain/ship-time signals still pending the first real domain ships.

**Re-triage cadence:** the next Triage Event fires after the first ≥2 Brand Hub domains *ship* (not just scaffold) — at that point #41/#43/#44/#50 (retro + ship-maturity entries) become measurable.

## Cross-reference

- [`fda-plugin-interview.md` § Parking lot follow-ups](fda-plugin-interview.md) — source-of-truth for entries #1–#55.
- [`fda-plugin-interview.md` § Q57](fda-plugin-interview.md) — the v1.1 scope lock authored this release window.
- [`brand-hub-dogfood-findings.md`](brand-hub-dogfood-findings.md) § Iter-3 + § Post-iter-3 crm-sync close — iter-3 evidence base for this Triage.
- [`triage-event-2-2026-05-18.md`](triage-event-2-2026-05-18.md) — the prior (post-v1.0, scope-capped) re-triage this one supersedes for the v1.1 cycle.
- [`production-readiness.md`](../production-readiness.md) § v1.1 — the lightweight 4-category v1.1 checklist; Category D Triage-Event-#3 item is satisfied by this artifact.
- BC-10651 (v1.1 production-readiness checklist) — Open question resolved → Q57 + this checklist.
- BC-10652 (v1.1 release sequence) — this Triage is step 4, authored before the `flow-architecture@v1.1.0` git tag.
