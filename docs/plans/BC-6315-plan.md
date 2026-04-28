# BC-6315 — RevOps Plugin Validation Phase 1 (Lean fixture suite, 5 fixtures)

**Linear:** [BC-6315](https://linear.app/brite-nites/issue/BC-6315/revops-plugin-validation-phase-1-lean-fixture-suite-5-fixtures)
**Branch:** `holden/bc-6315-revops-plugin-validation-phase-1-lean-fixture-suite-5`
**Plan author:** Holden Halford
**Plan date:** 2026-04-28
**Phase 2 stub:** [BC-6317](https://linear.app/brite-nites/issue/BC-6317/revops-plugin-validation-phase-2-scope-tbd-post-phase-1)
**Phase 1.5 companion:** [BC-6316](https://linear.app/brite-nites/issue/BC-6316/revops-skill-activation-eval-harness-phase-15-28-cases-14-skills-2)
**Brainstorm:** Complete (F4 design, cross-repo strategy locked via 2 user gates)

**Fixtures filed (2026-04-28):** F1 [BC-6337](https://linear.app/brite-nites/issue/BC-6337) · F2 [BC-6338](https://linear.app/brite-nites/issue/BC-6338) · F3 [BC-6339](https://linear.app/brite-nites/issue/BC-6339) · F4 [BC-6340](https://linear.app/brite-nites/issue/BC-6340) · F5 [BC-6341](https://linear.app/brite-nites/issue/BC-6341). All in Salesforce Implementation project, label `test-fixture` (created 2026-04-28), status Backlog, assignee Holden Halford. Disclaimer line at top of every body. Invocable by ID only.

**Execute pause point (post step 2):** Per user gate at Step 8, I file the 5 fixtures + commit the plan, then stop. User drives F1–F5 in fresh Claude sessions to avoid context contamination from this session's pre-loaded skill descriptions. Resume on this branch for steps 8 (friction issues), 9 (gap analysis to BC-6317), and 10 (close BC-6315).

---

## 1. Issue-vs-ground-truth amendments (BC-5832 / BC-5786 / BC-2717 precedent)

The issue body was filed 2026-04-28 against earlier UPSTREAM.md state and earlier command-code expectations. The plan applies these amendments before execution:

| # | Issue claim | Ground truth | Resolution |
|---|---|---|---|
| A1 | Plan §3 prescribes "new 'Added by Brite (no upstream)' subsection" in `plugins/revops/UPSTREAM.md` | Subsection already exists at UPSTREAM.md §3 (added 2026-04-27 by [BC-5820](https://linear.app/brite-nites/issue/BC-5820), one day before BC-6315 was filed) — `version: 0.1.0`, no `upstream:`, no attribution comment, `author: "Brite Company"`, dropped `## Brite Context`. All 4 prescribed properties already documented. | **Skip the lineage-precedent edit.** Gap analysis records: "T1 verified by BC-5820 commit, not BC-6315." Test fixtures are Linear issues (not plugin skills) and are out of UPSTREAM.md scope by definition — UPSTREAM.md tracks plugin SKILL lineage. No edit lands. |
| A2 | F4 description: "Apex bug fix → review → deploy-sandbox **(forced fail mid-coverage)** → post-deploy-runbook" | `/revops:deploy-sandbox` has **no coverage hard-gate**. Phase 4 (Apex tests) prints `⚠️ Apex tests failed` *warning* and advances. The only `coverage_pct < 90` hard-gate lives in `/revops:deploy-prod` Phase 5, which pins `--target-org brite-prod` and requires `branch=main + clean tree`. Exercising it requires real prod mutation or canceling at one of the four gates upstream. | **F4 redesigned as B+D combined** (user-confirmed via brainstorm gate). Sub-run B exercises sandbox dry-run halt + runbook diff; sub-run D exercises deploy-prod gates A through Gate-A cancel. Coverage hard-gate stays code-inspection-only with explicit gap-analysis disclaimer. |
| A3 | Verification table T6: "F4 all-commands run — deploy-sandbox + deploy-prod (or sandbox-only) + post-deploy-runbook all invoked; abort path triggered + handled" | Same root cause as A2. "Abort path triggered" is satisfiable for deploy-sandbox (Phase 2 dry-run halt) and deploy-prod (Phase 3 Gate-A cancel) but not for the deploy-prod *coverage* halt without real prod mutation. | **T6 split into T6a (sandbox dry-run halt) + T6b (deploy-prod Gate-A cancel).** T6c (coverage halt) is recorded as code-inspection-only in gap analysis. |
| A4 | Verification table T7: "F4 real deploy — Confirmed real `brite-sandbox` deploy occurred (not simulated)" | F4-B uses dry-run halt (no actual deploy lands). F4-D cancels before Phase 4 (no actual deploy lands). | **T7 reframed:** "Confirmed real `sf` CLI invocation occurred against `brite-sandbox` (Phase 2 dry-run) and against `brite-prod` (Phase 2 dry-run); both halted before mutation." Pass criterion = `sf` JSON envelope captured for both, not "deploy occurred." |

---

## 2. Brainstorm decisions

| # | Decision | Locked at | Notes |
|---|---|---|---|
| B1 | F4 = B+D combined | User gate 2026-04-28 | B = sandbox dry-run halt + runbook diff; D = deploy-prod cancel at Gate A |
| B2 | Cross-repo: two repos, two branches | User gate 2026-04-28 | Worktree here for plan/tracking artifacts; feature branch in `~/Projects/work/brite-nites/brite-salesforce/` for F4-B broken Apex (delete on cleanup) |
| B3 | Fixture order = F1 → F2 → F3 → F4 → F5 (sequential) | Default | Per issue Execute steps 3-7; no benefit to re-sequencing once F4 settled |
| B4 | Friction-issue spawn = batched at end (Execute step 8) | Default | Per issue prescription; one issue per distinct friction, label `revops-validation`, filed in `Brite Plugin Marketplace` project |
| B5 | UPSTREAM.md §3 = no edit | A1 | Lineage precedent already captured by BC-5820 |

---

## 3. Five fixture body drafts

All five are filed in Linear project **Salesforce Implementation** (id `ff23634f-8186-4ac3-8e9d-243a856866d9`), team Brite Company, status Backlog, label `test-fixture` (created at first issue if not already present). All five carry the identical disclaimer line at the top of the body.

**Disclaimer line** (verbatim, top of every fixture body):

> ⚠️ **Test fixture — do NOT execute.** This issue exists only to exercise the RevOps plugin's skill activation. Invocable by ID only; never auto-pulled by `/workflows:session-start`. If you find this in your queue, leave it. Tracking the activation result lives in the corresponding `BC-XXXX` tracking issue in `Brite Plugin Marketplace`.

### F1 — Add `Lead.Outbound_Sequence_Stage__c` picklist + sync FLS across 7 permsets

- **Title:** `TEST FIXTURE: Add Lead.Outbound_Sequence_Stage__c picklist + 7-permset FLS sync`
- **Body sections:** Context (Outbound team needs a stage tracker on Lead) + Goal (add custom picklist field, declare FLS in all 7 permsets that touch Lead per `brite-salesforce/CLAUDE.md` §170) + Acceptance Criteria (`force-app/main/default/objects/Lead/fields/Outbound_Sequence_Stage__c.field-meta.xml` deployed; FLS entries added to `Base_CRM_Access`, `Finance_Read`, `Deal_Financial_Read`, `Sales_Operations`, `Marketing`, `Account_Location_Edit`, `Acquisition_Full_Access` permsets; sandbox dry-run passes).
- **Expected activation:** `sf-permissions` (7-permset list keyword, `permissionsets/`), `sf-metadata` (CustomField + `.field-meta.xml`), `sf-deploy` (deploy step).
- **Should NOT activate:** `sf-flow`, `sf-lwc`, `sf-apex`, `sf-soql`.
- **Pass/Fail criteria:** T1 = three positive skills fire; T2 = no false positives; T3 = 7-permset list cited verbatim from `brite-salesforce/CLAUDE.md` §170.

### F2 — Refactor `SlackWebformAlertJob` to BATCH_SIZE=90 self-chain

- **Title:** `TEST FIXTURE: Refactor SlackWebformAlertJob to Queueable BATCH_SIZE=90 self-chain`
- **Body sections:** Context (current synchronous handler hits 100-callout limit) + Goal (convert to Queueable that processes 90 records per invocation and self-chains for residual) + Acceptance Criteria (`SlackWebformAlertJob implements Queueable, Database.AllowsCallouts`; `BATCH_SIZE = 90`; `MAX_RETRIES = 3`; test class covers 100% of new behavior including `Test.stopTest()` async drain; sandbox tests pass).
- **Expected activation:** `sf-apex` (Queueable + BATCH_SIZE=90 keyword + class-rewrite intent), `sf-testing` (test class authoring + `Test.stopTest` async-drain + 100% coverage target).
- **Should NOT activate:** `sf-lwc`, `sf-flow`, `sf-data`, `sf-permissions`.
- **Pass/Fail criteria:** T1 = both positive skills fire; T2 = no false positives; T3 = `BATCH_SIZE = 90` correct, `MAX_RETRIES = 3` correct, `Test.stopTest()` async-drain caveat cited.

### F3 — Convert Apex method to LWC-invocable `@AuraEnabled(cacheable=true)` (collision)

- **Title:** `TEST FIXTURE: Surface LeadScoringService.calculateScore() to LWC via @AuraEnabled`
- **Body sections:** Context (existing `LeadScoringService.calculateScore(Id leadId)` is callable from Flow only; sales wants live score on Lead record page LWC) + Goal (add `@AuraEnabled(cacheable=true)` + `with sharing` annotations on the existing method; build accompanying LWC `leadScoreCard` that calls the method via `@wire`; test class covers cache invalidation behavior) + Acceptance Criteria (Apex method has correct annotations; LWC consumes via wire service; Jest tests pass; FLS respected — `with sharing` enforces).
- **Expected activation (collision case):** `sf-apex` (`@AuraEnabled` is in apex skill description) AND `sf-lwc` (`@AuraEnabled security primitives` is in lwc skill description). **This is a deliberate collision** — record exact behavior.
- **Should NOT activate:** `sf-flow`, `sf-soql`, `sf-data`.
- **Pass/Fail criteria:** T1 = collision recorded explicitly (both fired? one suppressed? user disambiguation prompted? skill-merge attempted?); T2 = no false positives among non-targets; T3 = `@AuraEnabled` security guidance cited from whichever skill responded.

### F4 — Apex bug fix end-to-end with abort paths (B+D combined)

- **Title:** `TEST FIXTURE: Apex bug fix → deploy-sandbox dry-run halt + deploy-prod Gate-A cancel`
- **Body sections:** Context (validate the 3 RevOps commands' abort-handling shape against intentional failure scenarios; per the BC-6315 plan, exercises sandbox dry-run failure path + deploy-prod cancel path; coverage hard-gate stays code-inspection-only by design) + **Sub-run B** (Goal: author throwaway `BC6315F4Broken.cls` with intentional compile error → invoke `/revops:deploy-sandbox` → observe Phase 2 dry-run failure halt → invoke `/revops:post-deploy-runbook HEAD~1..HEAD` → observe Phase 1.4 all-false fast-exit on diff with no flow/scheduled/NC/picklist matches) + **Sub-run D** (Goal: from clean `main`, invoke `/revops:deploy-prod` → navigate Phase 1 pre-flight (branch=main, clean tree, intent confirm) → reach Phase 3.1 Gate A → select Cancel → observe clean halt with no `sf` mutation).
- **Expected activation:**
  - Sub-run B: `sf-apex` (broken Apex authoring), `sf-deploy` skill (dry-run + post-deploy verify intent), `sf-debug` (compile error parsing); commands `/revops:deploy-sandbox` + `/revops:post-deploy-runbook` invoked.
  - Sub-run D: command `/revops:deploy-prod` invoked through Phase 3.1; no skill-level activation expected during command execution (commands have their own scaffolding).
- **Should NOT activate:** `sf-flow` (no flow files), `sf-permissions` (no permset changes in sub-run B; no diff in sub-run D), `sf-lwc`, `sf-data`.
- **Pass/Fail criteria:** T1 = `sf-apex` + `sf-deploy` + `sf-debug` fire on sub-run B authoring + halt; T2 = no false positives; T3 = halt messages match command spec verbatim (deploy-sandbox Phase 2 halt copy, deploy-prod Phase 3.1 cancel copy, runbook Phase 1.4 fast-exit copy).
- **Cross-repo coordination required.** See plan §6 for the dual-branch sequencing.

### F5 — Tableau dashboard for SF data (negative case)

- **Title:** `TEST FIXTURE: Tableau dashboard — Lead-to-Opportunity conversion by Territory__c`
- **Body sections:** Context (sales leadership wants a Tableau dashboard showing Lead-to-Opportunity conversion rate broken down by `Territory__c` per the existing 12-15 territory taxonomy) + Goal (build Tableau workbook connected to `Brite_Salesforce` data source; add 3 sheets: trend over time, by-territory bar, by-source heatmap) + Acceptance Criteria (workbook published to Tableau Server; refresh schedule daily; embedded link added to sales-leadership Slack canvas).
- **Expected activation:** **None.** All 14 sf-* skills' `DO NOT TRIGGER` clauses cover dashboards, BI tools, non-Salesforce systems.
- **Should NOT activate:** Every sf-* skill in the plugin.
- **Pass/Fail criteria:** T1 = N/A (no positive activation expected); T2 = zero sf-* skills fire (binary pass/fail); T3 = N/A.

---

## 4. Mapping table — fixture × Tier criteria

| Fixture | T1 (positive activation) | T2 (no false positives) | T3 (output correctness) |
|---|---|---|---|
| F1 | `sf-permissions` + `sf-metadata` + `sf-deploy` | `sf-flow`, `sf-lwc`, `sf-apex`, `sf-soql` silent | 7-permset list cited verbatim from `brite-salesforce/CLAUDE.md` §170 |
| F2 | `sf-apex` + `sf-testing` | `sf-lwc`, `sf-flow`, `sf-data`, `sf-permissions` silent | `BATCH_SIZE = 90` + `MAX_RETRIES = 3` + `Test.stopTest()` async-drain caveat cited |
| F3 | `sf-apex` + `sf-lwc` (collision behavior recorded) | `sf-flow`, `sf-soql`, `sf-data` silent | `@AuraEnabled` security guidance cited from responding skill |
| F4-B | `sf-apex` + `sf-deploy` + `sf-debug` + `/revops:deploy-sandbox` + `/revops:post-deploy-runbook` | `sf-flow`, `sf-permissions`, `sf-lwc`, `sf-data` silent | Halt copy matches command spec verbatim |
| F4-D | `/revops:deploy-prod` invoked through Phase 3.1 | No skill-level firing during command flow | Cancel copy matches deploy-prod Phase 3.1 spec |
| F5 | N/A — negative case | All 14 sf-* skills silent | N/A |

---

## 5. UPSTREAM.md text decision (per A1)

**Decision: skip the edit.** UPSTREAM.md §3 already captures the "Added by Brite (no upstream)" lineage class as of 2026-04-27 (BC-5820 ship). The four properties the issue's Plan §3 prescribes (`version: 0.1.0`, no `upstream:` field, no attribution comment, single Brite Company author) are all documented. Test fixtures are Linear issues filed in a companion repo's Linear project — they are not plugin skills and therefore are out of UPSTREAM.md scope by construction (UPSTREAM.md tracks `plugins/revops/skills/*/SKILL.md` lineage).

Gap-analysis flag: T1 (lineage-precedent grep for "Added by Brite (no upstream)") will pass, but credit goes to BC-5820, not BC-6315. The verification table treats T1 as PASS-via-precursor.

---

## 6. Cross-repo branch coordination (F4-B and F4-D)

Three branches are involved across two repos:

| Repo | Branch | Purpose | PR? | Cleanup |
|---|---|---|---|---|
| `britenites-claude-plugins` | `holden/bc-6315-revops-plugin-validation-phase-1-lean-fixture-suite-5` (worktree) | Plan, precedent, BC-6315 closing edits | Yes (ship phase) | Standard ship flow |
| `brite-salesforce` | `holden/bc-6315-f4-broken-apex` (feature branch) | Throwaway broken Apex for F4-B | **No** | `git branch -D` after F4-B run; never push |
| `brite-salesforce` | `main` (read-only checkout for F4-D) | F4-D pre-flight needs `branch=main` + clean tree | No | No cleanup; no edits |

### F4-B sequence (executes from `~/Projects/work/brite-nites/brite-salesforce/`)

1. Create `force-app/main/default/classes/BC6315F4Broken.cls` and `BC6315F4Broken.cls-meta.xml` with intentional compile error (e.g., missing semicolon, unknown identifier reference, or invalid annotation).
2. `git checkout -b holden/bc-6315-f4-broken-apex && git add force-app/main/default/classes/BC6315F4Broken* && git commit -m "BC-6315 F4-B fixture: intentional broken Apex"`
3. Invoke `/revops:deploy-sandbox` from this cwd. Expected: Phase 1 passes (SFDX cwd OK + sandbox alias confirmed); Phase 2 fails with `status != 0` and halts with the spec'd message.
4. Capture the `sf` JSON response and Phase 2 halt copy verbatim into the F4 tracking issue body.
5. Invoke `/revops:post-deploy-runbook`; choose Phase 1.2 option `Just-deployed commit (HEAD~1..HEAD)`. Expected: Phase 1.4 all-false fast-exit (no flow / no scheduled apex / no NC / no standard-object picklist in the diff).
6. Capture Phase 1.4 fast-exit copy into the tracking issue.
7. **Cleanup:** `git checkout main && git branch -D holden/bc-6315-f4-broken-apex`. Confirm branch deleted; never push.

### F4-D sequence (executes from `~/Projects/work/brite-nites/brite-salesforce/` on clean `main`)

1. `git checkout main && git pull origin main && git status --porcelain` — confirm clean tree.
2. Invoke `/revops:deploy-prod` from this cwd.
3. Phase 1.1 SFDX cwd check passes; Phase 1.2 branch=main check passes; Phase 1.3 clean tree check passes; Phase 1.4 intent gate — select `Yes, run prod dry-run`.
4. Phase 2 dry-run runs against `brite-prod`. Expected outcome: dry-run passes (since `main` is at last shipped state and prod is in sync) — capture `numberComponentsTotal` value from JSON response.
5. Phase 3.1 Gate A: select `No, stop here`. Expected: clean halt with the spec'd "Stopped after dry-run" message.
6. Capture the dry-run JSON envelope + Gate A halt copy verbatim into the F4 tracking issue.
7. **Verify no mutation:** `sf` deploy logs should show only the dry-run invocation; no deploy with status `Succeeded` lands.

---

## 7. Phase 2 stub gap-analysis template (writes into BC-6317 body)

Append the following block to BC-6317's existing body at Phase 1 close:

```markdown
## Phase 1 Gap Analysis (closed 2026-04-XX by BC-6315)

### Summary
- Fixtures filed: 5/5 (F1-F5) in Salesforce Implementation project, label `test-fixture`
- Tracking issues filed here: 5/5 (one per fixture, F4 single tracking issue covers both sub-runs)
- Friction issues filed: <N> in Brite Plugin Marketplace, label `revops-validation`
- Plugin version under test: revops 0.1.<X>
- Cross-repo cleanup: brite-salesforce feature branch deleted; no PRs opened in companion repo

### Tier-1 (positive activation)
| Fixture | Expected | Observed | Pass/Fail | Notes |
|---|---|---|---|---|
| F1 | sf-permissions + sf-metadata + sf-deploy | <observed> | <P/F> | <notes> |
| F2 | sf-apex + sf-testing | <observed> | <P/F> | <notes> |
| F3 | sf-apex + sf-lwc (collision) | <observed> | <P/F> | <collision behavior verbatim> |
| F4-B | sf-apex + sf-deploy + sf-debug + 2 commands | <observed> | <P/F> | <halt copy verbatim> |
| F4-D | /revops:deploy-prod through Phase 3.1 | <observed> | <P/F> | <Gate A copy verbatim> |
| F5 | None | <observed> | <P/F> | <any false positive listed> |

### Tier-2 (no false positives)
| Fixture | Skills that should NOT fire | Observed firing? | Pass/Fail |
| ... | ... | ... | ... |

### Tier-3 (output correctness)
| Fixture | Ground-truth claim | Cited correctly? | Pass/Fail |
| F1 | 7-permset list per CLAUDE.md §170 | <Y/N> | <P/F> |
| F2 | BATCH_SIZE=90, MAX_RETRIES=3, Test.stopTest async drain | <Y/N> | <P/F> |
| F3 | @AuraEnabled security primitives | <Y/N> | <P/F> |
| F4 | Halt copy matches command spec verbatim | <Y/N> | <P/F> |
| F5 | N/A (negative case) | N/A | N/A |

### Coverage hard-gate disclaimer
The deploy-prod Phase 5 coverage `< 90%` halt path is **code-inspection-only validated**. F4-D cancels at Phase 3.1 Gate A; the coverage check (Phase 5) is never reached. Validating the coverage path requires either real prod mutation or scratch-org rehearsal — both out of Phase 1 scope. Recommend Phase 2 covers via a scratch-org rehearsal.

### Phase 2 scope decision
One of:
- **(a) Standard expansion** — list <N> recommended Standard fixtures with target Tier coverage
- **(b) Won't-do** — Tier-1/2/3 all clean; Phase 2 closes with rationale "Lean suite passed; no incremental signal value"
- **(c) Skill-specific deep-dive** — surface friction warranting dedicated validation issues

### Open items
- <list any deferred tests + reasons>
- Coverage hard-gate validation (deferred — see disclaimer above)

### Links
- All 5 fixtures: <links>
- All 5 tracking issues: <links>
- All friction issues filed: <links>
- BC-6315 closing comment: <link>
```

---

## 8. Execute task list (TaskCreate input — 10 sub-tasks)

| # | Subject | Description |
|---|---|---|
| 1 | F4 broken-Apex authoring (sub-task of step 6) | In `brite-salesforce` repo, create feature branch + `BC6315F4Broken.cls` with intentional compile error, commit. Cleanup deferred to step 6.7. |
| 2 | File 5 fixture issues in Salesforce Implementation project | Title prefix `TEST FIXTURE:`, label `test-fixture` (create label if missing), status Backlog, disclaimer line in body, ticket-shaped body per plan §3. |
| 3 | Run F1 + file tracking issue | Drive a fresh Claude session against fixture body; record activation; file `BC-XXXX` tracking issue with relatesTo F1 link, T1/T2/T3 pass/fail, friction notes. |
| 4 | Run F2 + file tracking issue | Same pattern as F1. |
| 5 | Run F3 + file tracking issue (collision) | Special-attention to recording collision behavior verbatim — both fired? one suppressed? user disambiguation prompted? |
| 6 | Run F4-B + F4-D + file single tracking issue | Sub-run B uses step 1's broken-Apex branch; sub-run D uses clean main. Single tracking issue with two scenario blocks. Cleanup brite-salesforce feature branch at end. |
| 7 | Run F5 + file tracking issue (negative case) | Confirm zero sf-* activation. |
| 8 | Spawn friction issues | One per distinct friction across all 5 tracking issues. Filed in `Brite Plugin Marketplace` project, label `revops-validation`. |
| 9 | Write gap analysis into BC-6317 body | Per plan §7 template. Append to existing BC-6317 body, do not overwrite. |
| 10 | Update BC-6315 with summary + tracking-issue links | Closing comment lists all 5 fixtures + 5 tracking issues + friction issues + Phase 2 scope decision. Move BC-6315 to Done after edit. |

---

## 9. Verification — objective criteria (amended from issue T1-T12)

| # | Test | Command / Action | Pass criteria |
|---|---|---|---|
| T1 | Lineage precedent captured | `grep -E "Added by Brite \(no upstream\)" plugins/revops/UPSTREAM.md` | Subsection present, ≥5 lines. **PASS-via-precursor** (BC-5820, not BC-6315). Recorded in gap analysis per plan §5. |
| T2 | Fixtures filed | `mcp__plugin_workflows_linear-server__list_issues project:"Salesforce Implementation" label:test-fixture` | 5 issues, all titled `TEST FIXTURE: ...` |
| T3 | F1 activation | F1 tracking-issue body | sf-permissions + sf-metadata + sf-deploy all activated; T1/T2/T3 pass/fail recorded |
| T4 | F2 activation | F2 tracking-issue body | sf-apex + sf-testing activated; T1/T2/T3 pass/fail recorded |
| T5 | F3 collision check | F3 tracking-issue body | Collision outcome explicitly recorded (both fired? one suppressed? user disambiguation prompted?) |
| T6a | F4 sandbox abort path | F4 tracking-issue body | `/revops:deploy-sandbox` invoked; Phase 2 dry-run halt observed; halt copy verbatim captured |
| T6b | F4 prod-cancel abort path | F4 tracking-issue body | `/revops:deploy-prod` invoked; Phase 3.1 Gate A cancel observed; cancel copy verbatim captured |
| T6c | F4 runbook diff | F4 tracking-issue body | `/revops:post-deploy-runbook` invoked on `HEAD~1..HEAD`; Phase 1.4 fast-exit observed |
| T7 | F4 real `sf` invocations | F4 tracking-issue body | `sf` JSON envelope captured for both sandbox dry-run + prod dry-run; both halted before mutation; deploy-sandbox dry-run failed (intentional), deploy-prod dry-run passed but canceled at Gate A |
| T8 | F5 negative case | F5 tracking-issue body | Zero sf-* skills fired |
| T9 | Reference freshness | `grep -rEo "BC-[0-9]+" plugins/revops/skills/ \| sort -u` cross-checked vs Linear | All BC-#### resolve to existing issues |
| T10 | Friction issues filed | `mcp__plugin_workflows_linear-server__list_issues label:revops-validation` | One issue per distinct friction logged in any tracking issue |
| T11 | Gap analysis written | BC-6317 body | Body contains Phase 1 Gap Analysis block per plan §7 template; explicit pass/fail per Tier criterion; Phase 2 scope decision (a/b/c) named |
| T12 | TaskCreate state | TaskCreate tool state at issue close | All 10 Execute sub-tasks marked `completed`; none `in_progress` |
| T13 | Coverage gate disclaimer | BC-6317 body | Phase 1 Gap Analysis includes "Coverage hard-gate disclaimer" naming the deploy-prod Phase 5 path as code-inspection-only |
| T14 | Cross-repo cleanup | `cd ~/Projects/work/brite-nites/brite-salesforce && git branch --list holden/bc-6315-f4-broken-apex` | Empty output (branch deleted, never pushed) |

---

## 10. Out of scope

- Standard or Comprehensive fixture expansion (Phase 2 territory — gap analysis informs scope decision)
- BC-6081 sf-internal-docs authoring (gated on Phase 1 gap analysis signal)
- Skill description rewrites (only flag in spawn issues; rewrites land in dedicated follow-up issues)
- Eval harness work (covered by Phase 1.5 companion BC-6316 — parallel, harness-only)
- Coverage hard-gate validation against real prod (deferred — see plan §7 disclaimer; recommend Phase 2 cover via scratch-org rehearsal)
- BC-5787 standing monitor (passive watch only)

---

## 11. Related

- **Issue:** [BC-6315](https://linear.app/brite-nites/issue/BC-6315) (this plan)
- **Phase 2 stub:** [BC-6317](https://linear.app/brite-nites/issue/BC-6317) (`blockedBy` BC-6315)
- **Phase 1.5 companion:** [BC-6316](https://linear.app/brite-nites/issue/BC-6316) (parallel work, harness-only)
- **ADR-007:** [`docs/decisions/007-revops-plugin-design.md`](../decisions/007-revops-plugin-design.md) (plugin design + §3.8)
- **ADR-009:** [`docs/decisions/009-sf-capability-adoption.md`](../decisions/009-sf-capability-adoption.md) (6-check framework)
- **Source-of-truth:** [`plugins/revops/UPSTREAM.md`](../../plugins/revops/UPSTREAM.md) §3 (Brite-original lineage class)
- **Companion repo:** `brite-salesforce/CLAUDE.md` (7-permset list at §170, command source authority)
- **Precedents applied:** BC-5832 (amendments-table-at-plan-top, promoted to architecture-9 via BC-2717 task-2), BC-2717 (fix-pass-regression-check on review-fix passes ≥5 fixes or cross-file)
