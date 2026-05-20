# Flow-Architecture Plugin — Production Readiness Checklist

> **Source spec:** Q40 sub-decision 3 ([`docs/design-rationale/project_fda_plugin_interview.md`](design-rationale/project_fda_plugin_interview.md) — Q40 lock, drafter D session 2026-05-08). Twelve criteria across four categories that together close the v1.0 release gate. Q40 fills Q8's "successful Brand Hub retrofit" gap (Q8 7 sub-criteria embedded inside sub-decision 4). Sibling artifact: [`design-rationale/brand-hub-dogfood-findings.md`](design-rationale/brand-hub-dogfood-findings.md) (BC-6998 iteration log + AC verdict). Companion to [CDR-023][cdr-023] (handbook decision record) + [operating-standards FDA page][ops-fda] (practitioner-facing process page).
>
> **Audience:** plugin maintainer at v1.0 release time and at every future v1.x re-validation. **Not** dual-audience like the plugin CLAUDE.md (Q55) — this is a maintainer-only release-gate checklist.
>
> **FIX-3 cascade footnote (BC-6997 inline editorial fix applied at issue creation per memory:1862, drafter D R5 catch):** Q40 sub-decision 3 was locked 2026-05-08 enumerating **6 locked amendments** (Q31 amend 1, Q31 amend 2, Q24 amend 1, Q21 amend 1, Q50 amend 1, Q50 amend 2). The amendment cascade between Q40 lock close (2026-05-08) and v1.0 release (2026-05-18) brought the total to **16 amendments** (Q2 amend 1 + Q22 amend 1 + Q28 amend 1 + Q41 amend 1 + Q33 amend 2 + Q34 amend 2 + Q49 amend 1 via PR #513 + #514 cascade 2026-05-10; plus Q1 amend 1 + Q51/Q52/Q53 amend 1 + Q56). Q40-fidelity preservation: the 6-count below is verbatim from sub-decision 3 (preserved per the schema-discipline amendment pattern); the current count "**16 amendments**" is recorded here as a forward-looking footnote per Q40 R3 sub-decision authoring guidance. Reconciliation command: `grep -c "^\*\*Q[0-9]\+ amend\|^## Q[0-9]\+ amend" plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md`.

## Category A — Design phase complete (closes interview)

- [ ] All 54 active Q-numbers (**Q1-Q55 minus deleted Q39**) have lock entries in `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md`, including **6 locked amendments** at Q40 lock close — **Q31 amend 1** (office-hours-state schema), **Q31 amend 2** (linear-writeback-state schema), **Q24 amend 1** (Plan-section Q46 markers in discipline-child templates), **Q21 amend 1** (`adjustments[]` reframed), **Q50 amend 1** (workflows-cloned classification), **Q50 amend 2** (TRANSITIVE REUSE classification gap caught at Q53 drafting). See FIX-3 cascade footnote above — current authoring-time count is **16 amendments**.
- [ ] Memory file archived from working location to `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md` AND verified bit-for-bit via `diff -q` (snapshot regeneration discipline; Q9.4 brite-base session windup action; coexists with [`design-rationale/brand-hub-dogfood-findings.md`](design-rationale/brand-hub-dogfood-findings.md) in same subdirectory per Standalone #17 / #18 path coordination).

## Category B — Implementation complete (plugin code shipped per locked specs)

- [ ] Plugin manifest at `plugins/flow-architecture/.claude-plugin/plugin.json` + directory structure per **Q30** (commands/, skills/, agents/, scripts/, LICENSE, README, CLAUDE.md) verified; marketplace.json entry at `.claude-plugin/marketplace.json` mirrors plugin.json version per BC-6000 same-commit bump rule.
- [ ] `plugins/flow-architecture/CLAUDE.md` authored per **Q55** spec — 13 H2 sections; 5 cross-cutting requirements have headings; file size 15000–25000 bytes (verify via `wc -c plugins/flow-architecture/CLAUDE.md`).
- [ ] `plugins/flow-architecture/README.md` authored per **Q30.7** (installer-facing surface; lighter than CLAUDE.md; install path + first-run preflight pointer + slash-command index + cross-link to operating-standards page).

## Category C — Org prerequisites landed (handbook + about-handbook PRs)

- [ ] **handbook PR merged**: `decisions/CDR-023-flow-driven-architecture.md` (Q33) + `decisions/CDR-014-milestone-standards.md` amendment scoping Phase Pattern to non-product surfaces (Q35) + `how-we-work/operating-standards/flow-driven-architecture.md` operating-standards page (Q34). Verify via `gh api repos/Brite-Nites/handbook/contents/<path>`.
- [ ] **about-handbook PR merged**: `about-handbook/style-guide/templates/` promoted templates (Q22-Q28 issue + journey + story-doc + INDEX schema) + Q41 PROJECT-INTENT template. (Per Q2 amend 1, `about-handbook/` is a subdirectory of the handbook repo, NOT a separate Brite-Nites repo.)

## Category D — Dogfood + version flip (closes v1.0)

- [ ] **Brand Hub retrofit dogfood succeeds per Q8** sub-decision 4 concrete acceptance criteria (BC-6998). Per **Q56** representative-demonstration amendment locked 2026-05-18 ([`design-rationale/project_fda_plugin_interview.md` § Q56](design-rationale/project_fda_plugin_interview.md)): success = orchestrator demonstrably runs all 9 retrofit phases end-to-end on the real consumer with ≥1 representative domain × ≥1 sub-flow scaffolded fully; remaining inventory tracked downstream via BC-9559 children. AC1-AC7 verdict mapping recorded in [`design-rationale/brand-hub-dogfood-findings.md`](design-rationale/brand-hub-dogfood-findings.md).
- [ ] **Drift-detection baseline recorded** — workflows v3.29.4 SHAs in HTML-comment headers of the 3 cloned commands (Q51 `/flow:session-start`, Q52 `/flow:review`, Q53 `/flow:ship`). Q40 sub-decision 7 verification command:

  ```
  grep -l "Cloned from workflows v3.29.4" plugins/flow-architecture/commands/*.md
  ```

  must return 3 file paths (`session-start.md`, `review.md`, `ship.md`); FDA-native commands carry no header.
- [ ] **Plugin version bump** — `plugins/flow-architecture/.claude-plugin/plugin.json` version field flips `0.1.0` → `1.0.0` (Q40 sub-decision 5 step 7) in the SAME commit as the marketplace.json entry bump per BC-6000 cache-propagation discipline. Verify via `jq -r .version plugins/flow-architecture/.claude-plugin/plugin.json`.
- [ ] **CDR-023 status flip** — handbook PR amending `decisions/CDR-023-flow-driven-architecture.md` from `Status: Proposed` to `Status: Accepted` per **Q35** amendment-with-audit-trail pattern: preserve original `Status: Proposed` text in HTML-comment audit-trail block BEFORE flipping (schema-discipline; do not silently overwrite — 16-amendment precedent). Verify via `gh api repos/Brite-Nites/handbook/contents/decisions/CDR-023-flow-driven-architecture.md | jq -r .content | base64 -d | grep -q "Status: Accepted"` AND a parallel grep that the audit-trail comment preserves the original `Status: Proposed` line.
- [ ] **Triage Event #2** post-v1.0 re-triage of parking lot per Q40 sub-decision 5 step 9 (**distinct from Triage Event #1**, which fired pre-implementation at Phase 1 close on 2026-05-08, OUTSIDE the Q40 release sequence). Walk all parking-lot entries: promote v1.1 candidates to Linear backlog, retire obsolete entries, escalate any newly-discovered v1.0 blockers via NEW Q-lock (Q56+) per Q40 sub-decision 6 boundary policy. Produces artifact: `plugins/flow-architecture/docs/design-rationale/triage-event-2-<YYYY-MM-DD>.md`.

## Dual-event triage distinction

**Triage Event #1** (pre-implementation, Phase 1 close, fired 2026-05-08, OUTSIDE Q40 release sequence): verified no v1 blockers escaped to parking lot; audited numbering consistency; cosmetic disorder cleanup; mapped to outer-loop Phase 1 close TaskList items.

**Triage Event #2** (post-v1.0, post-dogfood, INSIDE Q40 release sequence): re-triages parking lot based on Brand Hub dogfood findings — promotes items revealed as v1.1-pulling-forward, drops items revealed as not-actually-needed, verifies no v1 blockers were misclassified.

The two events are deliberately separate. Skipping Triage Event #2 ships v1.0 without harvesting the dogfood learnings; merging it with Triage Event #1 conflates pre-implementation gap-check with post-implementation refinement.

## Release sequence summary

Q40 sub-decision 5 strict ordering (re-verify at release time):

1. Design phase complete (Category A item 1) — Phase 1 close 2026-05-08.
2. Handbook PR merged (Category C item 6) — PR #513 + #514 merged 2026-05-10.
3. About-handbook PR merged (Category C item 7) — merged inside same handbook PR cascade.
4. Plugin code implementation (Category B items 3–5) — versions `0.1.0` → `0.2.24` over the implementation cycle (Cluster A through D + iter-1 + iter-2 dogfood); ready to flip `0.1.0...1.0.0` (Category D item 10).
5. Brand Hub retrofit dogfood (Category D item 8) — iter-2 PASS under Q56 representative-demonstration interpretation; BC-6998 Done.
6. Drift-detection baseline (Category D item 9) — captured at clone time 2026-05-07; verified via `grep -l "Cloned from workflows v3.29.4" plugins/flow-architecture/commands/*.md` returning 3 paths.
7. Plugin version bump (Category D item 10) — flip to v1.0.0 this release.
8. CDR-023 status flip (Category D item 11) — handbook PR `Proposed` → `Accepted` post-version-bump.
9. Triage Event #2 + memory archive (Category D item 12 + Category A item 2) — ships LAST; closes interview artifacts.

## v1.0 / v1.1 boundary policy

Per Q40 sub-decision 6: **no parking lot items are v1.0 blockers**. If Triage Event #2 reveals a parking-lot item is actually v1.0-blocking, escalate via NEW Q-lock (Q56+) rather than silently bypass — preserves design-rationale audit trail per schema-discipline pattern. **Q56 (locked 2026-05-18)** is the first post-Q40 Q-lock and exercises this escalation path for the Brand Hub dogfood representative-demonstration scope amendment.

## Test surface stance (v1)

Per Q40 sub-decision 3 Category B explicit non-criterion: Brand Hub dogfood IS the integration test for v1. Bash + schema-validation tests are parking-lot v1.1 candidates (#52–#55 per Q40 R3 user lock). Promotion criteria: any v1.x release introduces schema regression OR adds 3+ new skills/agents/utilities (which increases edit frequency on schemas).

---

# Flow-Architecture Plugin — v1.1 Readiness Checklist (lightweight)

> **Source spec:** [BC-10651][bc-10651] (v1.1 readiness gate). v1.1 is a **maintenance minor** — a 5-fix dogfood-bug patch cohort (plugin 1.0.4 → 1.0.8) validated end-to-end by a full Brand Hub acceptance dogfood. It introduces **no new methodology surface**, so this section is a deliberately lightweight **4-category checklist**, NOT a replica of the v1.0 Q40-style 12-criterion gate above. The scope of this lightweight-vs-full decision is formalized at **[Q57][interview]** (locked 2026-05-20, per the BC-10651 Open-question resolution + Q56 "formalize, don't bypass" precedent). The v1.1-cycle schema amendments (Q42 amendment 1, Q20 amendment 1) live in [`design-rationale/project_fda_plugin_interview.md`][interview]; the post-v1.1 parking-lot re-triage lives in [`design-rationale/triage-event-3-2026-05-20.md`](design-rationale/triage-event-3-2026-05-20.md).
>
> **Audience:** plugin maintainer at v1.1 release time. Same maintainer-only audience as the v1.0 gate above.

## Category A — Patch cohort complete (5 dogfood-bug fixes shipped)

The five dogfood-surfaced bugs from the Brand Hub retrofit cycle, each shipped as its own squash PR with a same-commit version bump (BC-6000 discipline), cumulatively carrying the plugin 1.0.4 → 1.0.8:

- [x] [BC-9026][bc-9026] — P1 `/flow:retrofit-project` pre-preflight hit the `list_issues` project-filter gotcha. Fixed via `team` + `query` text-search + client-side `projectId` filter. **PR #323 → plugin 1.0.4.**
- [x] [BC-9027][bc-9027] — P2 security hook blocked the orchestrator's canonical python-heredoc breadcrumb-write pattern. Fixed via `flow-resume-breadcrumb` stdin → file-arg refactor. **PR #324 → plugin 1.0.5.**
- [x] [BC-10302][bc-10302] — P3 `retrofit-project.md` "Capture from preamble" 10-field set mismatch (same count, different set). Fixed by clarifying the Capture header field set. **PR #325 → plugin 1.0.6.**
- [x] [BC-9028][bc-9028] — P3 `/flow:office-hours` Q42 free-text interview mismatched the `AskUserQuestion` multi-choice shape. Fixed via **Q42 amendment 1** (free-text-via-Other shape; recorded in [`project_fda_plugin_interview.md` § Q42 amendment 1][interview]). **PR #326 → plugin 1.0.7.**
- [x] [BC-9971][bc-9971] — `/flow:add-domain` could not re-scaffold an inventory-only domain (Q20.4 hard-reject gap). Fixed via **Q20 amendment 1** (inventory-only-domain re-scaffold branch; recorded in [`project_fda_plugin_interview.md` § Q20 amendment 1][interview]). **PR #327 → plugin 1.0.8.**

## Category B — Acceptance dogfood complete

- [x] **Brand Hub FDA retrofit dogfood iter-3** ([BC-10321][bc-10321]) closed 2026-05-19 with the dogfood-bug cohort acceptance gate **AC met EXACTLY**. Full fan-out: **10 FDA domain milestones / 51 sub-flow parents / 255 discipline children** (the canonical headline; the 10th domain is `crm-sync`, scaffolded per [BC-9564][bc-9564] with implementation deferred — see Category C). The without-`crm-sync` working subset cited mid-cycle in BC-10651's body is **9 / 46 / 230**; the delta is exactly `crm-sync` (1 domain × 5 sub-flows × 5 disciplines = 25 children). Filesystem cross-check: one journey doc per domain + one story doc per sub-flow. iter-3's full cross-domain fan-out is the real evidence base that makes Triage Event #3 (Category D) a substantive re-triage rather than the HOLD-by-default of Triage Event #2 (which ran under the 1.9% scope-cap).

## Category C — Known-issue disposition (tracked, NOT v1.1 blockers)

- [x] [BC-10352][bc-10352] — Q20.4 classifier schema mismatch with iter-2 shipped inventory (classifier rejects lowercase + backtick-wrapped + em-dash H3s). Manual-orchestration fallback was in use across iter-3. **Disposition: v1.1.x patch (post-release).**
- [x] [BC-9564][bc-9564] — `crm-sync` domain (10th / final FDA domain, Salesforce-only close) is **scaffolded** but implementation is deferred pending the HubSpot-vs-Salesforce CRM-target decision. **Disposition: deferred (impl blocked on SF stable-API + CRM-target decision); scaffold counted in the 10/51/255 fan-out.**
- [x] [BC-6039][bc-6039] — active prod `TypeError: Cannot read properties of null (reading 'fileId')` in tagging-claims, flagged as a v1-close concern on a Brand Hub consumer surface (data-quality-migration). **Disposition: consumer concern, not a plugin gate.**

## Category D — Version + release mechanics

- [x] **Version bump 1.0.8 → 1.1.0** in `plugins/flow-architecture/.claude-plugin/plugin.json` AND the matching `.claude-plugin/marketplace.json` entry, same commit (BC-6000). Verify: `jq -r .version plugins/flow-architecture/.claude-plugin/plugin.json` returns `1.1.0`.
- [x] **Q57 lock transcribed** verbatim into [`design-rationale/project_fda_plugin_interview.md` § Q57][interview] (scope deferral: /flow:deprecate-legacy → v1.2; ship v1.1 on bug-cohort + dogfood; no feature requirement). Schema-discipline amendment pattern applied.
- [x] **Triage Event #3** — post-v1.1 parking-lot re-triage at [`design-rationale/triage-event-3-2026-05-20.md`](design-rationale/triage-event-3-2026-05-20.md) (real re-triage under iter-3's cross-domain evidence base, not a rubber-stamp HOLD).
- [ ] **Handbook v1.1 note merged** — a v1.1 release line appended to the ops-standards FDA page / CDR-023 changelog noting the patch cohort + full Brand Hub dogfood. **NO CDR-023 status flip** (already `Accepted` from v1.0). Lands BEFORE the tag (Q40 sub-decision 5 ordering). Verify via `gh api`.
- [ ] **git tag `flow-architecture@v1.1.0`** on plugins `main` — the LAST action, AFTER the handbook note merges (Q40 sub-decision 5 ordering: handbook note before tag). Verify: `git tag -l "flow-architecture@v1.1.0"`.
- [x] **`scripts/validate.sh` green** with flow-architecture@1.1.0.

## v1.1 release sequence summary

Mirrors the v1.0 Q40 sub-decision 5 ordering, scoped to the maintenance-minor mechanics:

1. Patch cohort complete (Category A) — plugin 1.0.4 → 1.0.8, all merged before this release cut.
2. Acceptance dogfood complete (Category B) — BC-10321 iter-3 closed 2026-05-19.
3. Version bump + Q57 lock + Triage Event #3 + v1.1 readiness section (Category D) — this release PR.
4. Handbook v1.1 note merged (Category D) — separate handbook PR; NO status flip.
5. git tag `flow-architecture@v1.1.0` (Category D) — LAST, after the handbook note merges.

## What v1.1 deliberately does NOT gate on

Per [Q57][interview]: **BC-10219 (`/flow:deprecate-legacy`) is NOT a v1.1 blocker.** The v1.1 milestone's original gate named "at least one new feature (BC-10219)"; Q57 drops the feature requirement and re-homes BC-10219 to the v1.2 milestone. v1.1 ships on the validated bug-cohort + full dogfood alone. Reversibility trigger (Q57): if a consumer (e.g. BC-10234 brite-base FDA-shape sweep) needs `/flow:deprecate-legacy` before v1.2 lands, re-prioritize BC-10219 as a v1.1.x patch.

[cdr-023]: https://github.com/Brite-Nites/handbook/blob/main/decisions/CDR-023-flow-driven-architecture.md
[ops-fda]: https://github.com/Brite-Nites/handbook/blob/main/how-we-work/operating-standards/flow-driven-architecture.md
[interview]: design-rationale/project_fda_plugin_interview.md
[bc-10651]: https://linear.app/brite-nites/issue/BC-10651
[bc-9026]: https://linear.app/brite-nites/issue/BC-9026
[bc-9027]: https://linear.app/brite-nites/issue/BC-9027
[bc-9028]: https://linear.app/brite-nites/issue/BC-9028
[bc-9971]: https://linear.app/brite-nites/issue/BC-9971
[bc-10302]: https://linear.app/brite-nites/issue/BC-10302
[bc-10321]: https://linear.app/brite-nites/issue/BC-10321
[bc-10352]: https://linear.app/brite-nites/issue/BC-10352
[bc-9564]: https://linear.app/brite-nites/issue/BC-9564
[bc-6039]: https://linear.app/brite-nites/issue/BC-6039
