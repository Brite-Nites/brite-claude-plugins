# BC-5796 Plan — Customize sf-apex with Brite Apex discipline

**Issue:** [BC-5796](https://linear.app/brite-nites/issue/BC-5796) · **Milestone:** RevOps Plugin · **Priority:** High · **Blocked by:** BC-5789 (scaffold — done)

## Scope

Layer Brite's Apex discipline onto the upstream `plugins/revops/skills/sf-apex/SKILL.md`. Single-file markdown customization. No upstream logic, references/, or assets/ are touched.

## Departures from issue body (locked by BC-5793 → BC-5794 → BC-5795 precedents)

Three departures apply verbatim from BC-5793 — NOT re-litigated at this gate per BC-5794:

| # | Issue body says | Override | Source |
|---|-----------------|----------|--------|
| 1 | Rename `sf-apex` → `brite-apex` | Keep upstream directory name `sf-apex/` | ADR-007 §3.6 + BC-5793 precedent |
| 2 | Execute step 1: `git mv skills/sf-apex skills/brite-apex` | No-op, skill already at final location | Follows from override 1 |
| 3 | Verify T1: `ls plugins/revops/skills/brite-apex` | `ls plugins/revops/skills/sf-apex` (exists) | Follows from override 1 |
| 4 | Verify T3-T7: grep `brite-apex/SKILL.md` | grep `sf-apex/SKILL.md` | Follows from override 1 |

Per BC-5794 precedent, no AskUserQuestion is needed for these overrides — the template is locked and re-deriving would waste turns.

## Template shape (BC-5795 v2 canonical, matches sibling-one sf-permissions + sibling-two sf-connected-apps)

Placement: **Brite sections BEFORE `## When This Skill Owns the Task`.** This is the majority pattern (2/3 siblings) and is more discoverable when the skill auto-invokes against Brite repo Apex work.

Sections to add, in order:

1. Frontmatter updates (extended `author:`, new `upstream:` key, version bump)
2. Attribution HTML comment below frontmatter, above H1
3. `## Brite Context` — Brite's Apex stance in 3-5 bullets + See-also links
4. `## Brite Apex Conventions` — 12 non-negotiable rules grounded in brite-salesforce/CLAUDE.md §Apex & Automation (lines 175-196) + §Engineering Standards (lines 41-42) + §Permissions & Security (line 171)
5. Preserve all original upstream sections unchanged below

## Frontmatter changes

```yaml
metadata:
  version: "1.1.0-brite.1"          # was "1.1.0"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
  scoring: "150 points across 8 categories"
```

Also extend `description:` with the Brite-repo trigger signal (Brite Apex patterns / LeadTriggerHandler / Queueable BATCH_SIZE=90) so the skill auto-invokes inside brite-salesforce and does NOT fire elsewhere (T8 + T9 verify).

## Attribution comment

```
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Apex & Automation (lines 175-196) + §Engineering Standards (lines 41-42). -->
```

Matches T2 grep (`"Adapted from Jaganpro"`) and the canonical form in `plugins/revops/UPSTREAM.md`.

## Brite Apex Conventions (12 rules, grounded in brite-salesforce/CLAUDE.md)

Each rule cites the source line with §/verbatim wording where possible. Factual claims verified via `gh api` fetch of brite-salesforce main on 2026-04-20 (ground-truth anchor per BC-5795 learning).

| # | Rule | brite-salesforce source | Canonical class/file named |
|---|------|------------------------|---------------------------|
| 1 | Apex-first automation; Flows only for screen flows + simple notifications | §Engineering Standards line 41 | — |
| 2 | Trigger handler pattern: one trigger per object delegates to a handler class; per-LeadSource service registries via `LeadAfterInsertService` interface | §Apex line 177 | `LeadTriggerHandler`, `LeadAfterInsertService`, `webFormAfterInsertServices`, `newsletterAfterInsertServices` |
| 3 | Queueable callout limit = 100; BATCH_SIZE=90 self-chain; MAX_RETRIES=3 | §Apex line 178 | `SlackWebformAlertJob` |
| 4 | Queueable silent-retry diagnostic: N consecutive "Completed" jobs = 1 original + (N-1) silent retries; check Named Credential first | §Apex line 179 | — |
| 5 | Schedulable DML row limit = 10,000; 4 × LIMIT 2500 pattern | §Apex line 184 | `DisqualifiedRecycleScheduler` |
| 6 | Scheduled Apex jobs don't survive sandbox refresh; re-schedule manually | §Apex line 182 | `DisqualifiedRecycleScheduler` |
| 7 | `@TestVisible` + `Test.isRunningTest()` together on security-critical escape hatches (compile-gate + runtime-gate); narrow the scope | §Apex line 192 | `AccountTriggerHandler.skipFreeEmailNameBlockInTestsOnly` |
| 8 | `@TestSetup` static state doesn't persist into `@IsTest` methods — reset flags inline | §Apex line 191 | — |
| 9 | Queueables fired inside `Test.stopTest()` re-enter handlers with current static state — reset flags immediately after fixture DML | §Apex line 193 | — |
| 10 | Before-update trigger self-query caveat: SOQL sees pre-update state; exclude trigger records via `NOT IN` | §Apex line 183 | — |
| 11 | `with sharing` exception for `User` — sharing rules don't apply; document the nuance | §Apex line 196 | — |
| 12 | Bypass_Validation_Rules pattern: all validation rules must include `NOT($Permission.Bypass_Validation_Rules)` as first AND arg; session-based activation doesn't reach Bulk API / `sf` CLI | §Permissions line 171, §Permissions line 172 | `HubSpot_Migration`, `SessionPermissionSetActivation` |

Test coverage rule (§Engineering Standards line 42 — "100% coverage per class; 90%+ org-wide; 75% SF minimum") is already surfaced in the upstream PNB testing section + Score Guide but I'll promote the specific targets to a short "Coverage targets" subsection in § Brite Apex Conventions so T7 grep (`100%.*coverage|90%`) matches.

Two issue-body-requested rules (HubSpot emails migrate as Task, Screen Flows deploy as Draft) are **Flow-domain concerns, not Apex**. Keep them out of sf-apex (they belong in sf-flow's future customization) — noted here so review agents don't flag missing content.

## See-also links

Below § Brite Context:

- `brite-salesforce/CLAUDE.md` §Apex & Automation (the 22 gotchas this section summarizes)
- `brite-salesforce/CLAUDE.md` §Engineering Standards (Apex-first principle, coverage targets)
- `brite-salesforce/docs/artifacts/testing-strategy.md` (referenced by §Engineering Standards line 42)

## Execute steps

1. **No `git mv`** — directory name stays `sf-apex/` per override table above.
2. Edit `plugins/revops/skills/sf-apex/SKILL.md`:
   - Update frontmatter (version, author, upstream, description)
   - Add attribution comment above H1
   - Insert `## Brite Context` + `## Brite Apex Conventions` between H1 and `## When This Skill Owns the Task`
   - Leave all existing sections unchanged
3. No changes to `references/`, `CREDITS.md`, `assets/`, `hooks/`, or `README.md`.
4. Commit: `customize sf-apex with Brite Apex discipline (BC-5796)` — body cites BC-5793 precedent for the departure block per BC-5758 3-location audit trail pattern.

## Verify — 10 objective tests (issue body + 4 path flips)

| T | Command | Pass criteria |
|---|---------|---------------|
| T1 | `ls plugins/revops/skills/sf-apex` (flipped from brite-apex) | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-apex/SKILL.md` | Match |
| T3 | `grep -E "LeadTriggerHandler\|trigger handler pattern" plugins/revops/skills/sf-apex/SKILL.md` | Match |
| T4 | `grep -E "BATCH_SIZE.*90\|Queueable callout limit" plugins/revops/skills/sf-apex/SKILL.md` | Match |
| T5 | `grep -E "TestVisible\|Test\.isRunningTest" plugins/revops/skills/sf-apex/SKILL.md` | Match |
| T6 | `grep "Bypass_Validation_Rules" plugins/revops/skills/sf-apex/SKILL.md` | Match |
| T7 | `grep -E "100%.*coverage\|90%" plugins/revops/skills/sf-apex/SKILL.md` | Match |
| T8 | In brite-salesforce: ask "write me a trigger handler for Case" | Deferred — cross-repo manual check post-merge, per BC-5793 deferral pattern |
| T9 | In non-SF repo: same question | Deferred — cross-repo manual check post-merge |
| T10 | `./scripts/validate.sh` | Exit 0 |

T8/T9 deferred in keeping with BC-5793 precedent — cross-repo manual verification only feasible post-merge. T1-T7 + T10 all runnable locally before PR.

## Check-in cadence

One check-in gate remaining: **this plan → approval before Execute.** Explore gate already closed (findings summarized above). Verify gate runs automatically (10 objective tests → paste results).

## Artifacts produced

- `docs/plans/BC-5796-plan.md` (this file)
- `plugins/revops/skills/sf-apex/SKILL.md` (edited in Execute)
- Verification output in PR body
- Precedent trace `docs/precedents/BC-5796.md` (Ship phase)
