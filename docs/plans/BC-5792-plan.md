# BC-5792 Plan — Build `/revops:post-deploy-runbook` orchestration command

**Issue:** [BC-5792](https://linear.app/brite-nites/issue/BC-5792/build-revopspost-deploy-runbook-orchestration-command)
**Priority:** High
**Milestone:** RevOps Plugin (Phase 2 — Orchestration Commands, **3rd and final** of 3)
**Branch:** `holden/bc-5792-build-revopspost-deploy-runbook-orchestration-command`
**Worktree:** `.claude/worktrees/bc-5792`
**Baseline:** `origin/main` at `db2b7ed` — `validate.sh`: 0 errors, 16 warnings.

## Goal

Ship `plugins/revops/commands/post-deploy-runbook.md` — a 6-phase orchestration command that walks the user through the mandatory manual steps `sf project deploy start` doesn't handle: Screen Flow activation (Flows deploy as Draft regardless of source `<status>Active</status>`), Scheduled Apex re-scheduling (CronTrigger doesn't survive sandbox refresh), Named Credential URL updates (metadata deploys carry PLACEHOLDER values per-org), and Kanban Group By layout refresh (picklist-on-standard-object cache gotcha).

Closes Phase 2 of the RevOps plugin (3/3 commands: deploy-sandbox ✅ → deploy-prod ✅ → post-deploy-runbook). `/revops:deploy-prod` Phase 7 already hardcodes this command as its next-step handoff — so shipping this closes the loop the prod deploy already promises.

## Inherited template contract (BC-5790 + BC-5791 precedent)

Per `docs/precedents/BC-5790.md` + `docs/precedents/BC-5791.md` and the two shipped sibling command files, every Phase 2 RevOps command must:

1. **Frontmatter**: `description` + `allowed-tools: Bash, AskUserQuestion` only. No MCP tools, no file-mutation tools, no Linear tools — side-effects are confined to user-visible narration + `sf` CLI + git read-only + AskUserQuestion prompts.
2. **Top-of-file Rules section** that explicitly states which phases (if any) are mutating.
3. **Every mutating phase** preceded by an `AskUserQuestion` gate; halt cleanly on non-proceed.
4. **Narrate every phase boundary** with the `Phase N/M: <title>...` / `...done` convention.
5. **Use `sf`, never legacy `sfdx`**.
6. **No silent retries** — surface raw output and halt.
7. **One question at a time** at gates (no multi-option batched pickers where a binary confirm is needed).

## BC-5792 departures from BC-5790 + BC-5791

| Aspect | BC-5790 sandbox | BC-5791 prod | **BC-5792 runbook** |
|---|---|---|---|
| `sf` CLI mutating calls | Phases 2, 3 (dry-run + deploy) | Phase 4 (deploy) | **None** — command issues no `sf` mutations |
| Mutating phases total | 2 | 1 | **0** — all phases are read-only walks of user-performed manual steps |
| Target org alias pin | `brite-sandbox` | `brite-prod` | **Neither** — command is org-agnostic (user deploys separately before invoking this) |
| Phase enablement | Static — every phase runs | Static — every phase runs | **Dynamic** — Phases 2–5 each run only if Phase 1 detection flags their component type as present in the deploy diff |
| Pre-flight scope | cwd=SFDX + alias confirm | cwd=SFDX + branch=main + clean tree + intent | **cwd=SFDX** only (halts if not, per T7). No branch/clean-tree check — runbook runs *after* deploy, user may be on any branch/state. |
| Diff detection | N/A | N/A | **New mechanic**: Phase 1 runs `git diff HEAD~1 --name-only` (or user-supplied range) and classifies touched files into 4 detection flags |
| Skip semantics | No skip option (halts or proceeds) | No skip option (halts or proceeds) | **3-way gate** at each phase: Completed / Skip / Need help — Skip surfaces in Phase 6 as a follow-up list |
| Completion summary | Phase 6 — terminal | Phase 7 — terminal + runbook hint | **Phase 6 — terminal** with per-phase status (ran / skipped / N/A-not-detected) and explicit follow-up recap for any Skip |
| Detection semantics | N/A | N/A | **Deny-`__c` inversion for Kanban** — any non-custom object, not a fixed 8-object allowlist. **Test-class exclusion for Scheduler** — filenames ending in `Test.cls` / `Test.cls-meta.xml` drop from the flag despite matching the base `(Scheduler|Scheduled)` pattern. |
| Shell-call economy | Single `sf` call per phase | Single `sf` call per phase | **Batched `grep`** — Phase 1.3 Kanban secondary check and Phase 4.1 NC endpoint surface each spawn one subprocess across all candidate paths, not N subprocesses. |

## Phase structure (from issue body §Plan, Brite-adapted)

- **Phase 1 — Diff-based detection**
  - 1.1 Confirm cwd is SFDX project → halt if not (matches T7 + BC-5790/5791 pre-flight).
  - 1.2 Prompt for commit range via `AskUserQuestion`: default `HEAD~1..HEAD` (just-deployed commit), or user-supplied range like `origin/main~5..origin/main`. The command is org-agnostic — it uses git diff, not `sf` diff, so any post-merge range works.
  - 1.3 Run `git diff <range> --name-only` and classify each touched path against four detection regexes. The shipped command file is the source of truth; summary here reflects the shipped shape (including simplify-pass refinements for false-positive/false-negative correctness):
    - `^force-app/.*/flows/.*\.flow-meta\.xml$` → `needs_flow_activation = true`
    - `^force-app/.*/classes/.*(Scheduler|Scheduled).*\.cls(-meta\.xml)?$` AND filename does NOT end in `Test.cls` / `Test.cls-meta.xml` → `needs_scheduled_apex_reschedule = true` *(Test-exclusion drops non-schedulable test classes that match the name pattern.)*
    - `^force-app/.*/namedCredentials/.*\.namedCredential-meta\.xml$` → `needs_named_credential_update = true`
    - `^force-app/.*/objects/(?<object>[^/]+)/fields/.*\.field-meta\.xml$` where `<object>` does NOT end in `__c` AND file contains `<type>Picklist</type>` or `<type>MultiselectPicklist</type>` → `needs_kanban_flush = true` *(deny-`__c` approach catches all standard objects — not only the 8 most-common ones — since the Kanban Group By cache bug is a platform behavior on any non-custom object. MultiselectPicklist has the same cache semantics as Picklist.)*
  - 1.4 If all four flags are false → Phase 6 fast-exit with "No manual post-deploy steps required for this diff" (T5).
  - 1.5 Otherwise, narrate the detection summary: "Detected: Flow activation, Scheduled Apex re-schedule. Skipped: Named Credential update, Kanban flush." Then proceed to Phase 2.

- **Phase 2 — Flow activation** *(conditional on `needs_flow_activation`)*
  - List each `.flow-meta.xml` path touched, extracting the developer name from the filename.
  - For each: print explicit Setup UI path: `Setup → Process Automation → Flows → find "{DeveloperName}" → Open → Activate` (Brite uses Screen Flows + simple notifications only per `brite-salesforce/CLAUDE.md` §Apex & Automation).
  - **`AskUserQuestion`** — 3-way: `All activated` / `Skip — will do later` / `Need help`. `Need help` prints extended guidance (where Draft-vs-Active is displayed, what happens if user clicks Run instead of Activate). `Skip` flags in Phase 6 follow-up list.

- **Phase 3 — Scheduled Apex re-schedule** *(conditional on `needs_scheduled_apex_reschedule`)*
  - List each `Scheduler`/`Scheduled` class touched.
  - For each, print the exact anonymous Apex template:
    ```apex
    System.schedule('<Job Name>', '<cron expression>', new <SchedulerClass>());
    ```
    with placeholder replacement guidance (Job Name can match class name; cron per class's existing schedule if known — surface the user's last-known cron from prior runs only if obviously available in the diff, otherwise leave placeholder).
  - Remind: "Running `sf apex run --target-org brite-prod --file <scratch.apex>` executes this. Jobs live in Setup → Apex Jobs → Scheduled Jobs." Per `brite-salesforce/CLAUDE.md` §Apex & Automation: CronTrigger does not survive sandbox refresh and must be re-scheduled manually after deploy.
  - **`AskUserQuestion`** — 3-way: `All scheduled` / `Skip` / `Need help`.

- **Phase 4 — Named Credential URL update** *(conditional on `needs_named_credential_update`)*
  - List each `.namedCredential-meta.xml` touched. Surface each file's PLACEHOLDER endpoint via one batched `grep -HE "<endpoint>" <path1> <path2> ...` call (N → 1 subprocess spawns; `-H` forces filename prefix for per-NC attribution). Classic NCs return one line per file; modern ExternalCredential-backed NCs return zero lines (handled as "endpoint lives in paired `.externalCredential-meta.xml`" in the narration).
  - For each, show **per-org** instructions (sandbox + prod separately), because the Named Credential XML in source carries PLACEHOLDER URLs by Brite convention:
    - `brite-sandbox`: `Setup → Named Credentials → {Name} → Edit → set URL to <sandbox-URL>`
    - `brite-prod`: `Setup → Named Credentials → {Name} → Edit → set URL to <prod-URL>`
  - **`AskUserQuestion`** — 3-way: `All URLs updated` / `Skip` / `Need help`.

- **Phase 5 — Kanban Group By cache flush** *(conditional on `needs_kanban_flush`)*
  - List each standard-object picklist field touched.
  - For each, print the flush technique: "Add the field to any page layout on that object (even a test layout) and deploy again — that flushes the UI cache. Alternatively, open Setup → Lightning App Builder and force a save on any page referencing the object."
  - Reference `brite-salesforce/CLAUDE.md` §Metadata Authoring — the canonical Kanban Group By stale-metadata gotcha.
  - **`AskUserQuestion`** — 3-way: `Flushed` / `Skip` / `Need help`.

- **Phase 6 — Completion summary** *(always runs; Phase 1 fast-exit path also terminates here)*
  - Per-phase status matrix:
    - `✓ Flow activation: {completed / skipped / N/A — not detected}`
    - `✓ Scheduled Apex re-schedule: {completed / skipped / N/A — not detected}`
    - `✓ Named Credential URL update: {completed / skipped / N/A — not detected}`
    - `✓ Kanban Group By flush: {completed / skipped / N/A — not detected}`
  - **Skip follow-up list** — if any phase returned Skip:
    > ⚠️ Follow-up required: {list of skipped phases}. These manual steps are still pending — don't consider this deploy done until they're complete. Re-run `/revops:post-deploy-runbook` after completing them, or track as a Linear sub-issue.
  - No automatic Linear mutation (honors allowed-tools contract — user does any Linear follow-up manually).

## Rules block (bottom of command file)

Per BC-5790/5791 precedent, the Rules block lives at the **bottom** of the command file with a forward-reference from the intro. Shipped block content (final — as landed after simplify + review passes):

- **ZERO `sf` CLI mutations** — read-only walkthrough of user-performed manual steps.
- **Never advance past a gate silently** — explicit per-option disposition: completed advances, Skip advances with skipped status (Phase 6 follow-up), Need help repeats, anything else halts.
- **`sf`, not `sfdx`** — legacy subcommands deprecated per `brite-salesforce/CLAUDE.md`.
- **No auto-retries** — `git diff` failure halts with raw error. `grep` errors (exit ≥ 2) halt; exit 1 (no-match) is legitimate at both grep sites.
- **Org-agnostic** — no `--target-org` pin; user invokes after deploying.
- **No Linear mutations** — Skip follow-ups are narrated reminders only.
- **Conditional phases compile cleanly** — a phase skipped by Phase 1's detection flag emits zero narration; `N/A — not detected` appears only in the Phase 6 summary matrix.
- **Need help is a repeat, not an advance** — print guidance, re-ask the original question.

## Tasks

1. **Write `plugins/revops/commands/post-deploy-runbook.md` skeleton + frontmatter + Rules block** (~5 min)
   - Frontmatter: `description` (post-deploy runbook — diff-driven walk), `allowed-tools: Bash, AskUserQuestion`.
   - Copy skeleton shape from `plugins/revops/commands/deploy-sandbox.md` (Phase N/M narration style, `---` separators).
   - Rules block per spec above (8 bullets, at bottom of file; shipped count reflects simplify + review pass expansions).

2. **Draft Phase 1 — diff-based detection** (~10 min)
   - 1.1 SFDX cwd halt (copy from BC-5790/5791 verbatim).
   - 1.2 `AskUserQuestion` for commit range — options: `HEAD~1..HEAD (just-deployed)` / `origin/main~5..origin/main (last 5 commits on main)` / `<custom range>` via Other. Default proceed = `HEAD~1..HEAD`.
   - 1.3 `git diff <range> --name-only` → 4 detection regexes (see Phase 1 spec). For Kanban: additionally grep the file for `<type>Picklist</type>` to distinguish picklist from text fields.
   - 1.4 All-false → skip to Phase 6 with "no action needed" message (T5 path).
   - 1.5 Detection summary narration.

3. **Draft Phase 2 — Flow activation** (~5 min)
   - Conditional guard on `needs_flow_activation`.
   - List + Setup UI path + 3-way `AskUserQuestion`.
   - `Need help` → extended guidance snippet (Draft-vs-Active in Setup, what "Run" button does).

4. **Draft Phase 3 — Scheduled Apex re-schedule** (~5 min)
   - Conditional guard.
   - List + `System.schedule` Apex template + where jobs live.
   - 3-way `AskUserQuestion`.

5. **Draft Phase 4 — Named Credential URL update** (~5 min)
   - Conditional guard.
   - Per-org instructions (sandbox + prod).
   - 3-way `AskUserQuestion`.

6. **Draft Phase 5 — Kanban Group By cache flush** (~5 min)
   - Conditional guard.
   - Flush technique + handbook/CLAUDE reference.
   - 3-way `AskUserQuestion`.

7. **Draft Phase 6 — Completion summary** (~5 min)
   - Per-phase status matrix.
   - Skip follow-up list (if any Skips).
   - Terminal — no next-step hint (runbook is already the end of the deploy loop).

8. **Simplify pass** (~5 min)
   - Dedupe any Rules directive that's also inline in a phase (BC-5790 precedent).
   - Verify no dead default-org checks carried from template copy-paste.
   - Verify detection regexes against `brite-salesforce/force-app/` structure (tracked via Read tool; if unreachable via MCP today, rely on SFDX-standard paths).
   - Ensure Phase 2-5 conditional guards compile cleanly — phase should vanish entirely when flag is false (no "N/A" inline noise; N/A only appears in Phase 6 summary).

9. **Static verify walk T1-T8** (~10 min)
   - T1 — new Screen Flow detected → Phase 2 appears, Setup UI path shown.
   - T2 — no Flows → Phase 2 skipped.
   - T3 — NC changed → Phase 4 appears with per-org URL.
   - T4 — Scheduled Apex changed → Phase 3 shows `System.schedule` template.
   - T5 — no-op deploy (CSS-only) → Phase 6 fast-exit, no empty-checklist walk.
   - T6 — user answers Skip → Phase 6 surfaces follow-up.
   - T7 — non-SFDX cwd → halts at Phase 1.1.
   - **T8 — `grep -c "AskUserQuestion" plugins/revops/commands/post-deploy-runbook.md` ≥ 4** — `grep -c` counts matching lines. Expected matches: one per Phase 2-5 gate + Phase 1.2 commit-range gate + the frontmatter `allowed-tools: Bash, AskUserQuestion` declaration. With simplify-pass hoisted `If Need help...` blocks adding further explicit `AskUserQuestion` mentions, the line count runs well above 4.
   - Paste all 8 test results into PR body (per issue body requirement).

10. **`validate.sh` + `check-guardrails.sh`** (~2 min)
    - `./scripts/validate.sh` → 0 errors, ≤17 warnings (16 baseline + possibly 0 delta).
    - `./scripts/check-guardrails.sh --claude-md CLAUDE.md` → 0 violations.

11. **Commit** (~1 min)
    - Message: `BC-5792: add /revops:post-deploy-runbook orchestration command`
    - Include plan file + command file in single commit.

## Out of scope

- **Automating any manual step.** Flow activation, Scheduled Apex re-setup, Named Credential URL updates, and Kanban flush are manual by design — each requires human judgment about org-specific config (URLs, cron expressions, job names, layout choices).
- **Rollback of partial runbook completion.** If user runs Phase 2-3 then aborts, no undo — the user simply re-runs.
- **Component types beyond the 4 detected.** ApexClass, PermissionSet, Layout, Profile, etc. are either handled by deploy success (no manual step needed) or rare enough that adding a branch here is YAGNI. Add new detection branches only when a repeat post-deploy surprise justifies it.
- **Agentforce / Data Cloud / Industries specific post-deploy steps.** Brite doesn't license Agentforce; Data Cloud and Industries aren't in the stack. Per RevOps plugin skill filter (ADR-007).
- **Automatic Linear sub-issue creation for skipped phases.** Would require `mcp__plugin_workflows_linear-server__save_issue` in `allowed-tools`, which breaks the Phase 2 template contract (Bash + AskUserQuestion only). User creates follow-up issues manually if tracking is needed.
- **T1 live end-to-end verification** (real deploy + live runbook walk) — deferred to first real-world invocation. The 8-row matrix is static/dry-path verification only.

## Precedent overrides to apply verbatim

- **BC-5790 (pattern-choice, 8/10):** state mutating phases in Rules (here: "Zero mutations" stated explicitly); ratify narration convention; no dead default-org checks; simplify-pass pre-commit.
- **BC-5791 (pattern-choice, 8/10):** declare any departure from sibling template upfront in plan §Departures (done above); Rules block states mutating-phase count even when count is zero; review thorough-mode per-finding Opus/Sonnet validation applies when we reach `/workflows:review`.
- **BC-5795 (pattern-choice, 9/10):** verify every CLI / tool field referenced in the command — for BC-5792 this means the git diff output shape. `git diff <range> --name-only` is stable across git versions; no version-drift concern. If `git diff` fails (e.g., non-git cwd despite SFDX passing — rare), halt with raw error per Rules "No auto-retries".
- **BC-5866 (pattern-choice, 8/10):** if this command introduces a new recurring gate pattern used elsewhere (3-way Completed/Skip/Need-help), consider whether a `_shared/` contract file is warranted. For BC-5792, the 3-way pattern is unique to this command (sibling commands use 2-way Yes/No); no `_shared/` extraction needed.

## Links

- **Issue body:** `gitBranchName: holden/bc-5792-build-revopspost-deploy-runbook-orchestration-command`
- **Related issues:** BC-5790 (deploy-sandbox template source, shipped), BC-5791 (deploy-prod template source, shipped), BC-5793 (brite-deploy skill, shipped — this command is referenced from it), BC-5806 (SessionStart hook, will list this command in banner)
- **Master plan:** `docs/plans/revops-plugin-master-plan.md` §8 Issue 2.3 (via §4 Phase 2 chain — the 3rd of 3 orchestration commands)
- **Template siblings:** `plugins/revops/commands/deploy-sandbox.md`, `plugins/revops/commands/deploy-prod.md`
- **Source material for gotchas:** `brite-salesforce/CLAUDE.md` §Apex & Automation (Flow Draft, Scheduled Apex), §Deploy & Retrieve (Named Credential PLACEHOLDER), §Metadata Authoring (Kanban Group By cache)
- **Precedent traces:** `docs/precedents/BC-5790.md`, `docs/precedents/BC-5791.md`, `docs/precedents/BC-5795.md`, `docs/precedents/BC-5866.md`
