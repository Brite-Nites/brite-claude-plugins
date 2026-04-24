# BC-5927 Plan — Customize Phase 3 skills: sf-testing + sf-debug

**Issue:** [BC-5927](https://linear.app/brite-nites/issue/BC-5927)
**Phase:** 3 (per-skill customization) — Group A
**Absorbs:** BC-5799 (sf-testing) + BC-5800 (sf-debug) — both Canceled
**Worktree:** `.claude/worktrees/bc-5927/`
**Branch:** `holden/bc-5927-customize-phase-3-skills-sf-testing-sf-debug-apex-diagnostic`

---

## Design decisions (from brainstorm)

1. **Overlap policy** — restate with `See also: sf-apex` cross-reference. Each skill stands alone on retrieval; sf-testing restates its own coverage targets + escape-hatch pattern (overlap with sf-apex is intentional, matches the existing cross-link direction).
2. **Scope** — `plugins/revops/skills/sf-testing/SKILL.md` and `plugins/revops/skills/sf-debug/SKILL.md` only. Reference files untouched (consistent with sf-apex, sf-permissions, sf-metadata, sf-soql, sf-connected-apps). `sf-testing/hooks/scripts/parse-test-results.py` is an upstream Jaganpro artifact — out of scope.
3. **Frontmatter pattern** — sf-apex template: `version: 1.1.0-brite.1`, `upstream: Jaganpro/sf-skills@ff1ab74`, `author: "Jag Valaiyapathy (upstream); Brite Company (customization)"`, description expanded with Brite triggers, title suffix `(Brite edition)`.
4. **Attribution** — HTML comment at top of body: `<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Apex & Automation. -->`
5. **Section structure** — matches sf-apex: `## Brite Context` (narrative framing + See also) → `## Brite <Domain> Conventions` (numbered rules from issue-specified bullets) → existing upstream body retained.
6. **Batch order** — sf-testing first (per issue), commit + checkpoint, then sf-debug.
7. **Plugin version bump — MUST happen in this PR** (discovered mid-plan). `plugins/revops/.claude-plugin/plugin.json` and the revops entry in `.claude-plugin/marketplace.json` have both sat at `0.1.0` since BC-5789 scaffolded the plugin — six prior Phase 3 ports (BC-5793–BC-5798) skipped the bump, so their customizations may still be serving stale-cached content to clients. BC-6000 precedent is explicit: any edit under `plugins/revops/skills/**` requires bumping both files in the same commit. This PR bumps `0.1.0 → 0.2.0` (minor, reflecting 8-way cumulative catch-up). Bundled into Commit 1 alongside the sf-testing edit.

---

## Task 1 — Customize `plugins/revops/skills/sf-testing/SKILL.md`

**Absorbs:** BC-5799

### Frontmatter edits

- `description` — extend with Brite triggers: mention 100% class coverage, brite-salesforce trigger tests, `@TestSetup` static-state trap, Queueable-in-`Test.stopTest()` pattern, LWC Jest pre-commit. Mirror sf-apex expansion style.
- `metadata.version`: `"1.1.0"` → `"1.1.0-brite.1"`
- `metadata.author`: `"Jag Valaiyapathy"` → `"Jag Valaiyapathy (upstream); Brite Company (customization)"`
- `metadata.upstream`: new field `"Jaganpro/sf-skills@ff1ab74"`

### Title edit

`# sf-testing: Salesforce Test Execution & Coverage Analysis` → `# sf-testing: Salesforce Test Execution & Coverage Analysis (Brite edition)`

### Attribution comment (insert before `# sf-testing:` title)

```html
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Apex & Automation (lines 175-196) + §Engineering Standards (line 42). -->
```

### New `## Brite Context` section (insert after the attribution comment, before the existing "Use this skill when..." paragraph)

Narrative framing — 4 bullets:
- **Coverage target is 100% per class, not the SF 75% floor.** 90%+ org-wide is the target. Apply to all triggers and service classes. Source: §Engineering Standards line 42.
- **Apex-first Brite code requires Apex tests.** Flows are limited to screen flows + simple notifications (sf-flow covers the policy); everything else is Apex, which means trigger tests, service tests, and bulk-path coverage are non-negotiable.
- **LWC Jest runs at pre-commit.** The pre-commit hook runs Jest tests for staged LWCs; any new LWC ships with Jest coverage.
- **Escape-hatch discipline.** `@TestVisible` + `Test.isRunningTest()` gate narrow exceptions (e.g., `Bypass_Validation_Rules` honoring); pattern is narrow-scoped per check, never a blanket sibling bypass.

**See also:** `sf-apex` for production Apex patterns (trigger handler dispatch, Queueable `BATCH_SIZE=90` self-chaining, `Bypass_Validation_Rules` design); `sf-debug` for diagnostic signatures when tests leak static state across fixtures.

### New `## Brite Test Discipline` section (numbered rules, insert after `## Brite Context`)

1. **Coverage targets — 100% class / 90%+ org-wide / 75% SF floor.** The 75% number is Salesforce's deploy floor, not Brite's target. Individual classes hit 100%; org-wide averages 90%+. Source: §Engineering Standards line 42.
2. **LWC Jest required for all LWCs.** Pre-commit hook runs Jest on staged files; any new LWC ships with Jest coverage. Jest commands: `npm test`, `npm run test:unit:coverage`.
3. **Apex tests required for all triggers + service classes.** No exceptions.
4. **`@TestSetup` static state does not persist across `@IsTest` methods.** Each `@IsTest` runs a fresh transaction. Set bypass flags inside the `@IsTest` method body, not in `@TestSetup`. Source: §Apex & Automation.
5. **Queueables enqueued inside `Test.stopTest()` re-enter trigger handlers with current static state.** Reset bypass flags before `Test.startTest()` and again before `Test.stopTest()` when the fixture has set them. Counterpart signature in sf-debug: a fixture that left a flag on manifests as unexpected async handler behavior.
6. **`@TestVisible` + `Test.isRunningTest()` pattern gates narrow escape hatches.** Used together; `@TestVisible` exposes a private field to tests, `Test.isRunningTest()` gates the behavior to test context only. Pattern is narrow-scoped (per-check), not a blanket sibling bypass on security-critical paths.
7. **`Bypass_Validation_Rules` pattern is test-only.** Honored via `@TestVisible`; production code path never sets it. See sf-apex §Brite Apex Conventions for design.
8. **Pre-deploy validation + CI.** Scratch-org-per-PR validates deploys before merge. Live tests via `sf apex run test --wait 10 --target-org <alias>`.
9. **Run As for permission scenarios.** `User.create()` + `System.runAs(...)` establishes permission context; pairs with factory-built test users.

### Verify — sf-testing (T1-T9)

| Test | Command / Action | Pass |
|---|---|---|
| T1 | `ls plugins/revops/skills/sf-testing` | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-testing/SKILL.md` | Match |
| T3 | `grep -E "100%.*class\|90%.*org-wide" plugins/revops/skills/sf-testing/SKILL.md` | Coverage targets present |
| T4 | `grep "@TestSetup" plugins/revops/skills/sf-testing/SKILL.md` | Static-state gotcha present |
| T5 | `grep "Test.stopTest" plugins/revops/skills/sf-testing/SKILL.md` | Queueable pattern present |
| T6 | `grep -E "npm test\|npm run test" plugins/revops/skills/sf-testing/SKILL.md` | LWC Jest commands present |
| T7 | Ask in brite-salesforce: "how do I write a trigger test?" | sf-testing activates; Brite discipline surfaces |
| T8 | Ask same in non-SF repo | Does NOT activate |
| T9 | `./scripts/validate.sh` | Exit 0 |

### Commit message

`BC-5927: customize sf-testing + bump revops 0.1.0 → 0.2.0` (bundled commit — sf-testing SKILL.md edit + plan doc + plugin.json bump + marketplace.json bump)

### Checkpoint gate

User confirms T1-T6 + T9 pass before we start sf-debug. T7/T8 are user-driven activation probes — deferred to PR-review time if user prefers.

---

## Task 2 — Customize `plugins/revops/skills/sf-debug/SKILL.md`

**Absorbs:** BC-5800

### Frontmatter edits

- `description` — extend with Brite triggers: Queueable silent-retry signature, Web-to-Lead BeforeUpdate cascade, TraceFlag-driven debugging, CronTrigger silent-retry, Apex Error email PII discipline.
- `metadata.version`: `"1.1.0"` → `"1.1.0-brite.1"`
- `metadata.author`: `"Jag Valaiyapathy"` → `"Jag Valaiyapathy (upstream); Brite Company (customization)"`
- `metadata.upstream`: new field `"Jaganpro/sf-skills@ff1ab74"`

### Title edit

`# sf-debug: Salesforce Debug Log Analysis & Troubleshooting` → `# sf-debug: Salesforce Debug Log Analysis & Troubleshooting (Brite edition)`

### Attribution comment

```html
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Apex & Automation + §Integrations (Named Credential + Web-to-Lead specifics). -->
```

### New `## Brite Context` section

- **Apex-first Brite code means the debug targets are Apex.** Flows are rare (sf-flow covers the policy); debugging focuses on Apex trigger/service execution.
- **Queueable silent-retry is a common Brite signature.** N consecutive "Completed" AsyncApexJob rows for the same class = 1 original + (N-1) silent retries. Signals callout failure — usually a Named Credential misconfiguration. Check NC endpoint first.
- **Web-to-Lead has a BeforeUpdate cascade.** Brite's Lead Settings (default Lead Owner + "Override the existing record type") drive an implicit UPDATE after the initial before-insert completes. This is expected behavior, not a bug.
- **Apex Error emails for Lead triggers go to the Web-to-Lead admin.** PII or employee emails in exception messages get redistributed broadly — use role-based descriptions instead.

**See also:** `sf-testing` for prevention (resetting bypass flags before `Test.stopTest()`); `sf-apex` for the fix loop (trigger handler pattern, Queueable design); `/revops:post-deploy-runbook` for post-deploy verification that catches Named Credential misconfigs before they appear as silent retries.

### New `## Brite Diagnostic Patterns` section

1. **Queueable silent-retry diagnostic.** N consecutive "Completed" AsyncApexJob rows for the same class across a short window = 1 original + (N-1) silent retries. Root cause is almost always a callout failure. Check Named Credential endpoint first; the Queueable is masking the failure by re-enqueuing.
2. **Web-to-Lead BeforeUpdate cascade.** Expected ApexLog signature: `BeforeInsert → Validation → DuplicateDetector(INSERT) → AfterInsert → Workflow:Lead → BeforeUpdate → DuplicateDetector(UPDATE)`. The second pass is driven by default Lead Owner + "Override the existing record type" settings. If a trigger handler fires twice, this is why.
3. **TraceFlag-driven debugging for hard-to-reproduce issues.** Enable TraceFlag on the affected User; capture ApexLog; decode message-by-message. Precedent: BC-5609 used TraceFlag to surface a webform Lead Owner bug.
4. **CronTrigger silent-retry pattern.** Scheduled jobs failing silently need manual inspection via Developer Console (or `SELECT Id, State, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = '<name>'`). Scheduled Apex does not survive sandbox refresh — missing CronTrigger rows post-refresh are a known cause.
5. **Apex Error email PII discipline.** ConfigException in Lead triggers surfaces in (a) the Web-to-Lead admin error email + (b) the Apex Debug Log. Do NOT include PII or employee emails in error messages — use role-based descriptions ("Lead owner not configured for source X"), never direct names.
6. **`Test.stopTest()` async drain** — counterpart to sf-testing rule 5. When debugging a test fixture, if Queueables fired inside `Test.stopTest()` exhibit unexpected behavior, suspect a bypass flag that the fixture left set. sf-testing covers prevention; this is the diagnostic angle.

### Verify — sf-debug (T1-T7)

| Test | Command / Action | Pass |
|---|---|---|
| T1 | `ls plugins/revops/skills/sf-debug` | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-debug/SKILL.md` | Match |
| T3 | `grep -E "silent.retry\|BATCH_SIZE.*90" plugins/revops/skills/sf-debug/SKILL.md` | Queueable diagnostic present |
| T4 | `grep -E "Web-to-Lead\|BeforeUpdate" plugins/revops/skills/sf-debug/SKILL.md` | Cascade pattern present |
| T5 | `grep "TraceFlag" plugins/revops/skills/sf-debug/SKILL.md` | TraceFlag approach present |
| T6 | Ask in brite-salesforce: "why is my trigger firing twice?" | sf-debug activates; surfaces cascade diagnostic |
| T7 | `./scripts/validate.sh` | Exit 0 |

### Commit message

`customize sf-debug with Brite diagnostic patterns (BC-5927)`

---

## Task 3 — Final verify

1. Run full 16-test matrix; capture output for PR body.
2. `./scripts/validate.sh` passes (0 errors, 16 warnings baseline preserved).
3. Worktree `git log --oneline` shows exactly 3 commits on the branch:
   - `customize sf-testing with Brite test discipline (BC-5927)`
   - `customize sf-debug with Brite diagnostic patterns (BC-5927)`
   - `BC-5927: plan doc` (added as part of Step 6 commit — optional but consistent with session-history pattern)
4. No changes outside `plugins/revops/skills/sf-testing/SKILL.md`, `plugins/revops/skills/sf-debug/SKILL.md`, and this plan doc.

---

## Out of scope

- Reference files (`sf-testing/references/*`, `sf-debug/references/*`) — keep upstream-MIT; Brite context lives in SKILL.md only.
- `sf-testing/hooks/scripts/parse-test-results.py` — upstream Jaganpro hook; not a Brite hook.
- ~~Plugin version bump~~ — **IN SCOPE after all.** See Design decision #7 above. Prior Phase 3 ports skipped the bump before BC-6000 precedent landed; this PR fixes the drift (0.1.0 → 0.2.0 in plugin.json + marketplace.json).
- sf-flow, sf-lwc, sf-data, sf-docs, sf-integration — Groups B + C, separate issues (BC-5928, BC-5931).

---

## Rollback

`git worktree remove -f .claude/worktrees/bc-5927 && git branch -D holden/bc-5927-customize-phase-3-skills-sf-testing-sf-debug-apex-diagnostic` — no external state mutated; all changes are local repo edits.
