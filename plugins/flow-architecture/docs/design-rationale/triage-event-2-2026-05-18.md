# Triage Event #2 — Post-v1.0 parking-lot re-triage

> **Per Q40 sub-decision 5 step 9 + sub-decision 6** ([`fda-plugin-interview.md`](fda-plugin-interview.md)). Walks all parking-lot entries (#1–#55 at file lines 1998–2099) after Brand Hub dogfood (BC-6998) under Q56 representative-demonstration interpretation. Distinct from **Triage Event #1** (pre-implementation, Phase 1 close, fired 2026-05-08, OUTSIDE Q40 release sequence). Triage Event #2 fires INSIDE the Q40 release sequence as the final step before the `flow-architecture@v1.0.0` git tag.
>
> Inputs: parking lot (55 entries), BC-6998 iter-2 dogfood findings ([`brand-hub-dogfood-findings.md`](brand-hub-dogfood-findings.md)), feedback memories captured during iter-2 + post-iter-2 sessions ([[feedback_retroactive_fda_scaffold_per_domain_validation]], [[feedback_no_unauthorized_scope_reduction]], [[feedback_manual_orchestration_fallback]], [[feedback_review_agent_factual_verification]], [[feedback_re_verify_linear_state]], [[feedback_manual_orchestration_story_doc_id_backfill]]), and the 3 plugin-bug issues filed during dogfood (BC-9026 P1, BC-9027 P2, BC-9028 P3) + the post-dogfood orchestrator-gap issue BC-9971 P2.

## Verdict summary

- **0 promotions** of existing parking-lot entries to v1.0 blockers.
- **0 retirements** of parking-lot entries (none revealed as not-actually-needed).
- **1 NEW Q-lock authored** during this release window: **Q56** (Brand Hub dogfood representative-demonstration scope amendment) — locked 2026-05-18 per Q40 sub-decision 6 escalation pattern; recorded inline in [`fda-plugin-interview.md` § Q56](fda-plugin-interview.md).
- **4 NEW plugin-bug issues** filed during dogfood, tracked as v1.1 backlog (NOT parking lot — separate from the design-time deferral list): BC-9026 (P1 list_issues project filter), BC-9027 (P2 security hook blocks heredoc), BC-9028 (P3 AskUserQuestion shape mismatch), BC-9971 (P2 `/flow:add-domain` inventory-only re-scaffold gap). All have proven manual-orchestration workarounds per [[feedback_manual_orchestration_fallback]]; none are v1.0 blockers under the Q56 representative-demonstration acceptance threshold.
- **1 already-promoted parking-lot entry** acknowledged as DONE inline: #45 (drift-detection runtime tooling) — promoted to advisory CI guard via BC-7060 on 2026-05-12 (`scripts/check-clone-drift.sh` + GitHub Actions advisory `clone-drift-check` job).

## Per-entry walk

Categorized by the four possible Triage #2 dispositions: **PROMOTE** (v1.1 candidate that dogfood revealed needs work soon), **RETIRE** (not-actually-needed; remove from backlog), **HOLD** (unchanged; still v1.x candidate at original priority), or **DONE** (already executed; close the entry).

Default is **HOLD** unless dogfood surfaced specific signal. The dogfood was deliberately scope-capped at 1 domain × 1 sub-flow under Q56; many parking-lot entries gate on signals the cap didn't exercise. Holding the default avoids over-promoting based on absent evidence.

| # | Title (truncated) | Verdict | Rationale |
|---|---|---|---|
| 1 | Re-evaluate workflows plugin split | HOLD | Architectural re-evaluation; v2+ territory; dogfood did not surface |
| 2 | Wire FDA → /workflows:project-start handoff | HOLD | v2 enhancement; no dogfood signal |
| 3 | Retrofit cadence plugin to artifact-existence gates | HOLD | Cross-plugin retrofit; out of FDA v1.0 scope |
| 4 | Audit existing orchestrator skills for `disable-model-invocation: true` | HOLD | Discipline check; not blocking |
| 5 | BC-6774 backfill-vs-greenfield doc | HOLD | Separate concern; BC-6774 tracked independently |
| 6 | Issue-level cross-reference annotations | HOLD | v1.1+; no dogfood signal |
| 7 | `--auto-accept-priors` flag for inventory-codebase-scan | HOLD | v1.1; needs at-scale signal not present in 1-domain cap |
| 8 | Standalone `/flow:review-{project,domain,sub-flow}` skills | HOLD | v1.5+ territory |
| 9 | Canonical Brite design-system repo (Q49) | HOLD | Q49 already locks v2+ deferral with 3 pre-conditions + 2 promotion criteria; parking-lot entry preserved as origin reference per Q49 lock |
| 10 | Graduation criteria for FDA-cloned vs workflows skills | HOLD | Post-dogfood concern; iter-2 produced no demand for graduation |
| 11 | Per-phase `last_reviewed` in journey doc (Q26 mod 6) | HOLD | v1.1; no dogfood pain |
| 12 | `last_synced_to_linear` in story-doc front-matter | HOLD | v1.1; no dogfood pain |
| 13 | Customer-doc URL as 12th INDEX column | HOLD | v1.1; needs real-usage click-friction signal |
| 14 | `.flow/config.json` future fields | HOLD | v1.1+ |
| 15 | flow-legacy-cross-reference Tier 3 LLM perf | HOLD | iter-2 Phase 3 ran cleanly; no perf complaint surfaced |
| 16 | Q22-Q28 template edits in BriteBase | HOLD | Only load-bearing if BriteBase adopts FDA (post-Phase-4) |
| 17 | Q27 mod 1 in `docs/templates/job-story.md` | HOLD | Sub-finding of #16 |
| 18 | `_shared/code-evidence-collector.md` DRY utility | HOLD | v1.1 refactor candidate |
| 19 | Selective re-author mode + `/flow:journey-refresh` | HOLD | v1.1 extension per Q47 sub-decision 5.5; no dogfood signal |
| 20 | sandbox-scaffold per-flow vs per-domain | HOLD | iter-2 didn't exercise sandbox at depth |
| 21 | `flow-regen-index --force-upgrade-headers` | HOLD | iter-2 generated fresh INDEX from scratch; no upgrade-friction signal |
| 22 | Q25 mod 1 emoji-prefixed link schema | HOLD | Brand Hub got amended schema fresh; no BriteBase pressure |
| 23 | Flow ID 3-digit padding beyond 99 flows | HOLD | No domain at 99 yet |
| 24 | Notes column default for flow-inventory-add | HOLD | v1.1 docs polish |
| 25 | `[DEPRECATED]` marker support | HOLD | v1.1+ design candidate |
| 26 | journey-doc-author sonnet → opus | HOLD | iter-2 produced 1 journey doc with sonnet; quality acceptable in subjective read; no measurable trigger |
| 27 | `linear-children-match` gate batched (Q38 hybrid resolved) | HOLD | Q38 already adopted batched pattern inline; parking lot reframed (NOT closed) per Q38 sub-decision 3 hybrid; v1.1 extraction gated on third-caller threshold |
| 28 | HTTP HEAD on figma URLs (Q29.2) | HOLD | v1.1; no broken-figma-link signal |
| 29 | python3 dep in CLAUDE.md (Q55) | HOLD | Already documented in plugin CLAUDE.md § MCP + dependencies; entry preserved as discipline note |
| 30 | 3-pattern FDA-state storage split | HOLD | iter-2 ran cleanly with split; no consolidation pressure |
| 31 | L1/L2/L3 review state in phase_status | HOLD | iter-2 didn't crash mid-review; no pain signal |
| 32 | bash 3.2 constraint as authoring guideline | HOLD | Discipline note; no v1.0 surface change |
| 33 | Per-org FDA bootstrap (`/flow:setup-org`) | HOLD | One-time operation; maintainer hand-crafts initial PRs |
| 34 | flow-preflight refactor to dedicated bootstrap skill | HOLD | iter-2 ran preflight without issue |
| 35 | Q46 fail-and-prompt clobber detection | HOLD | iter-2 didn't surface edit-loss incidents |
| 36 | `--linear-surface` flag for /flow:audit | HOLD | v1.1; no team-visibility demand surfaced |
| 37 | Q42 L1 concerns Linear routing | HOLD | v1.1; iter-2 used filesystem path successfully |
| 38 | Cross-skill notification rate-limiter for Q46 | HOLD | iter-2 didn't reveal comment spam |
| 39 | Cribbed-content lock-prerequisite (methodology) | HOLD | Methodology note; permanent discipline guidance, not an action item |
| 40 | Auto-trigger /flow:retro from /flow:ship | HOLD | v1.1; opt-in feature, no discipline-gap signal |
| 41 | `/flow:retro --cross-domain` time-window flag | HOLD | v1.1; no longitudinal-retro request surfaced |
| 42 | Q22 amendment 1 retro-summary body marker | HOLD | v1.1; no body-surface preference signal |
| 43 | "Plan Completion" cross-skill-state mining for retros | HOLD | v1.1; waits on Q53 ship maturity |
| 44 | Team retro facilitation features for Q44 | HOLD | v1.1; iter-2 was solo dogfood |
| 45 | Drift-detection for cloned workflows commands | **DONE** | Promoted 2026-05-12 via BC-7060: `scripts/check-clone-drift.sh` + `clone-drift-check` advisory CI job. Entry preserved as tracker for hard-block promotion (continue-on-error: false flip) — still v1.1 candidate for the promotion decision |
| 46 | flow-brainstorming clone | HOLD | iter-2 didn't surface FDA-context miscalibration |
| 47 | flow-writing-plans clone | HOLD | iter-2 didn't trigger writing-plans path |
| 48 | `--audit-preflight` flag for /flow:review | HOLD | iter-2 didn't run /flow:review; no signal |
| 49 | `review-summary` type promotion (Q46 amend 3 + Q52 amend 1) | HOLD | v1.1; no Linear-surface demand for review findings |
| 50 | Plan-context augment retire for Q52 | HOLD | iter-2 didn't run /flow:review; no signal |
| 51 | Q29 amendment 1 plan-X-section completion gate | HOLD | v1.1; consolidates under /flow:audit eventually |
| 52 | plugin.json schema validation CI | HOLD | v1.1 per Q40 R3 — no schema regressions in v1.0 |
| 53 | SKILL.md frontmatter validation CI | HOLD | v1.1 per Q40 R3 — same trigger as #52 |
| 54 | Bash unit tests for 4 helper scripts | HOLD | v1.1 per Q40 R3 — iter-2 integration test sufficient |
| 55 | Smoke tests for command trigger resolution | HOLD | v1.1 per Q40 R3 — lowest priority of #52–#55 |

## New issues filed during dogfood (NOT parking lot)

These are runtime bugs surfaced during iter-2; they live in Linear as separate `flow-architecture` issues, not parking-lot entries. All have proven workarounds documented in `brand-hub-dogfood-findings.md` § Bugs surfaced. None gate v1.0 under Q56.

| BC-issue | Severity | One-line summary | Workaround |
|---|---|---|---|
| BC-9026 | P1 | `/flow:retrofit-project` pre-preflight hits `list_issues` project filter gotcha | `team` + `query` text-search + client-side `projectId` filter |
| BC-9027 | P2 | Security hook blocks orchestrator python-heredoc breadcrumb-write pattern | `mktemp` file intermediate then `bash $HELPER write $PATH < $TMP_JSON` |
| BC-9028 | P3 | Q42 free-text interview mismatches AskUserQuestion multi-choice shape | Drafted multi-choice options with "Other" fallback per question |
| BC-9971 | P2 | `/flow:add-domain` rejects inventory-only-domain re-scaffold (Q20.4) | Manual orchestration per [[feedback_manual_orchestration_fallback]] (read `commands/<name>.md` as prose spec, execute phases by hand) |

## Q56 escalation invocation (Q40 sub-decision 6 boundary policy applied)

Per Q40 sub-decision 6, dogfood findings that conflict with locked acceptance criteria escalate via NEW Q-lock (Q56+) rather than silently bypass. **Q56** is the first such escalation:

- **Trigger:** iter-2 scaffolded 1 of 10 inventoried Brand Hub domains × 1 of 7 sub-flows = 5 of 260 expected discipline children = 1.9% of the strict Q40 sub-decision 4 bullet 3 sub-bullet 6 reading ("Linear milestones + parents + 5N children chain per Q22-Q24 + Q13 scaffold").
- **Resolution:** Q56 (locked 2026-05-18) amends "successful" to **representative demonstration** (≥1 domain × ≥1 sub-flow end-to-end + remaining inventory tracked downstream via BC-9559 in the consumer's Linear project, NOT the plugin's).
- **Discipline preserved:** the iter-2 mid-run scope reduction was an orchestrator-side auto-descope rationalized in audit-trail rather than a user-authorized gate; that violated [[feedback_no_unauthorized_scope_reduction]] (locked 2026-05-15). Q56 retroactively legitimizes the scope choice with audit trail; the discipline going forward is unchanged — mid-orchestrator scope reductions require user gates, not after-the-fact Q-locks.

No further v1.0 blockers surfaced. Q56 is the only Q56+ escalation needed for v1.0.

## Methodology lesson preserved

Triage Event #2 produced a short outcome: 0 promotions, 0 retirements. (Q56 is counted in the verdict summary at the top of this doc as "1 NEW Q-lock authored during this release window" — locked the same day as this Triage, technically inside the release window. The "already in flight at Triage time" framing some earlier drafts used was slippery; honest count is 1 new Q-lock, namely Q56 itself.) This is a feature, not a bug. The dogfood was scope-capped to 1 domain × 1 sub-flow; many parking-lot entries gate on signals that cap could not exercise (e.g., #26 journey-doc-author opus upgrade needs cross-domain authoring run; #41 cross-domain retro needs ≥2 completed domains). A short Triage Event #2 with deliberate HOLD-by-default disposition is the correct outcome when dogfood scope-cap limits the evidence base.

**Re-triage cadence:** the next Triage Event would naturally fire after Brand Hub fan-out completes (BC-9559 children, 9 remaining domains) — at that point, cross-domain signals become measurable and several HOLD entries should re-evaluate (#26, #41, #43, #44, #50). Not formalized as Triage Event #3; just "re-triage when BC-9559 closes."

## Cross-reference

- [`fda-plugin-interview.md` § Parking lot follow-ups](fda-plugin-interview.md) — source-of-truth for entries #1–#55.
- [`fda-plugin-interview.md` § Q56](fda-plugin-interview.md) — first post-v1.0 Q-lock (representative-demonstration scope amendment).
- [`brand-hub-dogfood-findings.md`](brand-hub-dogfood-findings.md) — iter-2 evidence base for this Triage.
- [`production-readiness.md`](../production-readiness.md) — Q40 sub-decision 3 checklist; Category D item 12 is satisfied by this artifact.
- BC-6997 (production-readiness doc) — Done 2026-05-18.
- BC-6998 (Brand Hub dogfood) — Done 2026-05-18 under Q56.
- BC-6999 (v1.0 release sequence) — in flight; Triage #2 is the final step before git tag `flow-architecture@v1.0.0`.
