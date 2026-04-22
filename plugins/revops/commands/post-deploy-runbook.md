---
description: Post-deploy manual runbook for brite-salesforce — diff-driven walk through Screen Flow activation, Scheduled Apex re-schedule, Named Credential URL updates, and Kanban Group By cache flush. Use after `/revops:deploy-sandbox` or `/revops:deploy-prod` lands, to walk the manual steps `sf project deploy start` can't automate. Zero-mutation command — every action is user-performed; this orchestration detects, narrates, and gates.
allowed-tools: Bash, AskUserQuestion
---

# /revops:post-deploy-runbook

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered gate so the user explicitly acknowledges the manual step is complete (or deliberately skipped) before the command advances. If the user answers anything other than the proceed / skip options, halt and surface the blocker — never re-run past phases silently.

**One question at a time.** Never batch gate questions.

Source material: `brite-salesforce/CLAUDE.md` §Apex & Automation (Screen Flow activation, Scheduled Apex re-schedule), §Deploy & Retrieve (Named Credential PLACEHOLDER convention), §Metadata Authoring (Kanban Group By cache gotcha). The four detected post-deploy steps are the top documented causes of silent post-deploy failures in the Brite org.

Out of scope for this command: the deploy itself (use `/revops:deploy-sandbox` or `/revops:deploy-prod`), automating any manual step (each requires human judgment about org-specific config), rollback of partial runbook completion, component types beyond the four detected.

See the **Rules** section at the bottom for the enforcement contract (zero mutations, org-agnostic, no auto-retries, no Linear mutations).

---

## Phase 1 — Diff-based detection

Narrate: `Phase 1/6: Diff-based detection...`

### 1.1 Confirm cwd is an SFDX project

Run:

```bash
test -f sfdx-project.json && echo "SFDX_PROJECT_OK" || echo "NOT_SFDX"
```

- `SFDX_PROJECT_OK` → continue.
- `NOT_SFDX` → **halt** with this message:

  > Not in an SFDX project — no `sfdx-project.json` in the current directory. `/revops:post-deploy-runbook` must be run from the root of a Salesforce DX repo (e.g., `brite-salesforce`). `cd` into the repo and re-run.

  Do not continue. Do not prompt further.

### 1.2 Choose commit range

Ask via `AskUserQuestion`:

- Question: `Which commit range holds the deploy you want to walk?`
- Options:
  - `Just-deployed commit (HEAD~1..HEAD)` — Phase 1.3 uses `git diff HEAD~1 HEAD --name-only`.
  - `Last 5 commits on main (origin/main~5..origin/main)` — Phase 1.3 uses `git diff origin/main~5 origin/main --name-only`.
  - `Custom range — enter your own git range expression` — user enters the range via the Other free-text field (e.g., `<sha-before-deploy>..<sha-at-deploy>`); interpolate verbatim into `git diff <range> --name-only`.

The default recommendation is `Just-deployed commit (HEAD~1..HEAD)`.

### 1.3 Run diff + classify

Run (substitute `<range>` with the user's Phase 1.2 selection):

```bash
git diff <range> --name-only
```

If the command exits non-zero, print the raw stderr and **halt** with:

> `git diff <range>` failed. Verify the range is valid in this repo (e.g., `git log <range>`). Do not re-run this command with a guessed fallback range.

On success, classify each touched path against four detection regexes (set a boolean flag for each):

- `^force-app/.*/flows/.*\.flow-meta\.xml$` → `needs_flow_activation = true`
- `^force-app/.*/classes/.*(Scheduler|Scheduled).*\.cls(-meta\.xml)?$` **and** the filename does NOT end in `Test.cls` or `Test.cls-meta.xml` → `needs_scheduled_apex_reschedule = true`. Test classes (e.g., `UserSchedulerTest.cls`) match the base regex but are never schedulable jobs — exclude them explicitly. This is a surface-heuristic match: true correctness requires checking `implements Schedulable` in the source, which is out of scope.
- `^force-app/.*/namedCredentials/.*\.namedCredential-meta\.xml$` → `needs_named_credential_update = true`
- `^force-app/.*/objects/(?<object>[^/]+)/fields/.*\.field-meta\.xml$` where `<object>` does NOT end in `__c` **and** the file contains `<type>Picklist</type>` or `<type>MultiselectPicklist</type>` → `needs_kanban_flush = true` *(the Kanban Group By cache bug only affects standard objects; custom objects ending in `__c` don't have the bug per `brite-salesforce/CLAUDE.md` §Metadata Authoring. MultiselectPicklist has the same cache behavior as Picklist)*.

For the Kanban regex, run one batched grep across all candidate paths at once to confirm the field type — avoid spawning a subprocess per file:

```bash
grep -lE "<type>(Picklist|MultiselectPicklist)</type>" <path1> <path2> ...
```

The output is the subset of paths that actually contain a Picklist or MultiselectPicklist field. Text / Number / Date fields on standard objects are not affected and will not appear in the output.

### 1.4 All-false fast-exit

If all four flags are false, narrate:

> No manual post-deploy steps detected for this diff — the deploy landed no Flows, Scheduled Apex, Named Credentials, or standard-object picklists. Nothing to walk.

Then **skip directly to Phase 6** and surface all four steps as `N/A — not detected`. Do not walk Phases 2-5. Do not prompt further.

### 1.5 Detection summary

If any flag is true, narrate a one-line summary:

> Detected: {list of true-flag steps}. Skipped: {list of false-flag steps}. Walking each detected step now.

Then proceed to Phase 2.

Narrate: `Phase 1/6: Diff-based detection... done`

---

## Phase 2 — Flow activation *(conditional on `needs_flow_activation`)*

Narrate: `Phase 2/6: Flow activation...`

### 2.1 List affected Flows

From the Phase 1.3 diff output, filter paths matching `flows/.*\.flow-meta\.xml`. For each, extract the developer name from the filename (strip `.flow-meta.xml`). Print the list:

> The following Flows were deployed. Per Salesforce platform behavior, Screen Flows deploy as Draft regardless of `<status>Active</status>` in source metadata — activate each manually before users rely on it.
>
> - `{DeveloperName1}`
> - `{DeveloperName2}`
> - ...

### 2.2 Print Setup UI path

For each Flow, the activation path is:

> `Setup → Process Automation → Flows → find "{DeveloperName}" → Open → Activate`
>
> Active vs Draft is displayed in the top-right of the Flow Builder. "Run" executes the flow once without activating it — do not use "Run" for activation.

Brite uses Screen Flows + simple notifications only per `brite-salesforce/CLAUDE.md` §Apex & Automation (Apex-first automation principle; Flows are used sparingly).

### 2.3 Gate

Ask via `AskUserQuestion`:

- Question: `Flow activation — completed all {N} Flows?` (substitute `{N}` with the count from 2.1)
- Options:
  - `All activated` — mark phase status `completed`. Proceed.
  - `Skip — will do later` — mark phase status `skipped`. Proceed (Phase 6 surfaces as follow-up).
  - `Need help` — see below.

If the user selects `Need help`, print this guidance verbatim then re-ask the question (do not advance):

> If you don't see the Flow in the list, confirm the deploy landed via `Setup → Deployment Status` in the target org. If the Flow shows Draft and you're certain you activated it, refresh the page — the list is cached. The Active/Draft toggle is on the Flow detail page, not in the list view.

Narrate: `Phase 2/6: Flow activation... done`

---

## Phase 3 — Scheduled Apex re-schedule *(conditional on `needs_scheduled_apex_reschedule`)*

Narrate: `Phase 3/6: Scheduled Apex re-schedule...`

### 3.1 List affected Schedulers

From the Phase 1.3 diff output, filter paths matching `classes/.*(Scheduler|Scheduled).*\.cls(-meta\.xml)?$` **and** NOT ending in `Test.cls` or `Test.cls-meta.xml` (apply the same Test-exclusion as Phase 1.3 — test classes match the name pattern but aren't schedulable). Extract the class name from the filename (strip `.cls-meta.xml` or `.cls` suffix). Since each class ships a paired source + metadata file, de-duplicate by base name — and this listing must remain non-empty when `needs_scheduled_apex_reschedule` is true, including the edge case where only the `.cls-meta.xml` is in the diff (metadata-only API-version bump). Print:

> The following Scheduled Apex classes were deployed. Per `brite-salesforce/CLAUDE.md` §Apex & Automation, CronTrigger rows do not survive a deploy that replaces the class, and do not survive sandbox refresh. Re-schedule each one manually.
>
> - `{SchedulerClass1}`
> - `{SchedulerClass2}`
> - ...

### 3.2 Print re-schedule template

For each class, the anonymous Apex to run is:

```apex
System.schedule('<Job Name>', '<cron expression>', new <SchedulerClass>());
```

Replacement guidance:

- `<Job Name>` — conventionally matches the class name (e.g., `'LeadScoringScheduler'`). The job name is what appears in `Setup → Apex Jobs → Scheduled Jobs`.
- `<cron expression>` — preserve the prior schedule. Standard Brite patterns: hourly = `'0 0 * * * ?'`, daily at 3am UTC = `'0 0 3 * * ?'`, weekly Sunday at midnight = `'0 0 0 ? * SUN'`. If you don't know the prior cron, check the target org: `SELECT Id, CronJobDetailId, CronExpression, State FROM CronTrigger` via SOQL, **before** you deploy next time.

Execute via:

```bash
sf apex run --target-org <alias> --file scratch.apex
```

where `scratch.apex` contains the `System.schedule(...)` line(s). Alternatively paste into Developer Console → Execute Anonymous.

Verify jobs exist post-schedule via `Setup → Apex Jobs → Scheduled Jobs`.

### 3.3 Gate

Ask via `AskUserQuestion`:

- Question: `Scheduled Apex re-schedule — completed all {N} classes?` (substitute `{N}` with the count from 3.1)
- Options:
  - `All scheduled` — mark phase status `completed`. Proceed.
  - `Skip — will do later` — mark phase status `skipped`. Proceed (Phase 6 surfaces as follow-up).
  - `Need help` — see below.

If the user selects `Need help`, print this guidance verbatim then re-ask the question (do not advance):

> If you get `System.AsyncException: An instance of the scheduled class has already been scheduled with this name`, the prior job still exists — abort it first via `Setup → Apex Jobs → Scheduled Jobs → <row> → Del`, then re-run `System.schedule`. If you need the prior cron and don't have it, the target org's `CronTrigger` table has it (pre-redeploy — query `SELECT Id, CronJobDetail.Name, CronExpression, State FROM CronTrigger WHERE State = 'WAITING'`).

Narrate: `Phase 3/6: Scheduled Apex re-schedule... done`

---

## Phase 4 — Named Credential URL update *(conditional on `needs_named_credential_update`)*

Narrate: `Phase 4/6: Named Credential URL update...`

### 4.1 List affected Named Credentials

From the Phase 1.3 diff output, filter paths matching `namedCredentials/.*\.namedCredential-meta\.xml`. Extract the Named Credential name from the filename. Surface the PLACEHOLDER value in each file via one batched grep across all NC paths (not one invocation per NC):

```bash
grep -HE "<endpoint>" <path1> <path2> ...
```

The `-H` flag forces filename-prefixing so per-NC attribution is preserved when multiple NCs are in the diff. Classic NamedCredential XML uses `<endpoint>`; if a file returns no match, it's a modern NamedCredential that references an `ExternalCredential` — in that case the endpoint lives in the paired `.externalCredential-meta.xml` instead, and the NamedCredential XML itself carries no URL to update. Surface the PLACEHOLDER value to the user so they know what to replace (Brite convention per `brite-salesforce/CLAUDE.md` §Deploy & Retrieve — Named Credential XMLs ship with `PLACEHOLDER` or similar sentinel URLs so real URLs stay out of source control).

Print the list:

> The following Named Credentials were deployed. The source XML carries a PLACEHOLDER URL by Brite convention — update each one in every target org (sandbox + prod) to the real endpoint before any callout code relies on them.
>
> - `{Name1}` — source URL: `{placeholder1}`
> - `{Name2}` — source URL: `{placeholder2}`
> - ...

### 4.2 Per-org UI path

For each target org, the update path is:

> **`brite-sandbox`:** `Setup → Security → Named Credentials → {Name} → Edit → set URL to the real sandbox endpoint → Save`
>
> **`brite-prod`:** `Setup → Security → Named Credentials → {Name} → Edit → set URL to the real production endpoint → Save`

The prod and sandbox endpoints usually differ (different vendor environments, different allowed IP ranges). The user must know which is which — this command does not look them up.

### 4.3 Gate

Ask via `AskUserQuestion`:

- Question: `Named Credential URL update — completed all {N} credentials across all target orgs?` (substitute `{N}` with the count from 4.1)
- Options:
  - `All URLs updated` — mark phase status `completed`. Proceed.
  - `Skip — will do later` — mark phase status `skipped`. Proceed (Phase 6 surfaces as follow-up).
  - `Need help` — see below.

If the user selects `Need help`, print this guidance verbatim then re-ask the question (do not advance):

> If callouts fail with `Invalid URL` or auth errors right after deploy, this is almost always the cause. Check the current URL via the Setup UI or via `SELECT Id, DeveloperName, Endpoint FROM NamedCredential` in Tooling API. If the URL still reads PLACEHOLDER, the update didn't save — retry the Edit flow.

Narrate: `Phase 4/6: Named Credential URL update... done`

---

## Phase 5 — Kanban Group By cache flush *(conditional on `needs_kanban_flush`)*

Narrate: `Phase 5/6: Kanban Group By cache flush...`

### 5.1 List affected fields

From the Phase 1.3 detection, list each standard-object picklist field that matched:

> The following standard-object picklist fields were deployed. Per `brite-salesforce/CLAUDE.md` §Metadata Authoring, new picklist values on standard objects don't appear in the Kanban Group By dropdown until the UI metadata cache is flushed — this is a platform cache bug that only affects standard objects (custom objects don't have it).
>
> - `{Object1}.{Field1}`
> - `{Object2}.{Field2}`
> - ...

### 5.2 Flush technique

For each affected field, the flush is indirect:

> Add the field to any page layout on that object (even a seldom-used or hidden layout works) and redeploy that layout. The layout touch invalidates the UI metadata cache for the object, and the Kanban Group By dropdown picks up the field on next render.
>
> Alternatively: open `Setup → Lightning App Builder → <any page referencing the object> → Save` — the save propagates the cache flush.

The fix is platform-side; there's no API to invalidate the cache directly.

### 5.3 Gate

Ask via `AskUserQuestion`:

- Question: `Kanban Group By cache flush — completed for all {N} fields?` (substitute `{N}` with the count from 5.1)
- Options:
  - `Flushed` — mark phase status `completed`. Proceed.
  - `Skip — will do later` — mark phase status `skipped`. Proceed (Phase 6 surfaces as follow-up).
  - `Need help` — see below.

If the user selects `Need help`, print this guidance verbatim then re-ask the question (do not advance):

> Verify the flush worked by opening a Kanban view on the affected object and checking that the new field appears in the Group By dropdown. If it doesn't, the layout redeploy didn't trigger the cache invalidation — try editing a different layout, or save-and-close any page in Lightning App Builder.

Narrate: `Phase 5/6: Kanban Group By cache flush... done`

---

## Phase 6 — Completion summary

Narrate: `Phase 6/6: Completion summary...`

Print the per-phase status matrix, using the phase-status values set in Phases 2-5 (`completed`, `skipped`, or `N/A — not detected` for any phase that Phase 1 didn't flag):

- `✓ Flow activation: {completed / skipped / N/A — not detected}`
- `✓ Scheduled Apex re-schedule: {completed / skipped / N/A — not detected}`
- `✓ Named Credential URL update: {completed / skipped / N/A — not detected}`
- `✓ Kanban Group By flush: {completed / skipped / N/A — not detected}`

If **any** phase has status `skipped`, append the follow-up list:

> ⚠️ Follow-up required — the following manual steps were deliberately skipped and are still pending:
>
> - {each skipped phase, with the affected components relisted}
>
> Don't consider this deploy done until these complete. Re-run `/revops:post-deploy-runbook` on the same commit range after finishing them. If tracking the follow-up as a Linear sub-issue helps, create one manually — this command does not create Linear issues by design (allowed-tools is `Bash, AskUserQuestion` only).

If **no** phase has status `skipped` and at least one phase ran, append:

> Post-deploy manual runbook complete. The deploy is now functionally live — Flows active, Scheduled Apex jobs restored, Named Credential URLs real, Kanban caches flushed as applicable.

If **all** phases were `N/A — not detected` (Phase 1 fast-exit path), the summary suffices — no additional narration needed.

Narrate: `Phase 6/6: Completion summary... done`

---

## Rules

- **This command issues ZERO `sf` CLI mutations.** It is a read-only walkthrough of user-performed manual steps. Every mutating action is executed by the user in their browser / IDE / Developer Console; the command narrates, detects, and gates.
- **Never skip a gate silently.** Every `AskUserQuestion` halt path must halt — no silent continuation. `Skip` answers explicitly advance the phase but get surfaced as follow-ups in Phase 6.
- **`sf`, not `sfdx`.** Any CLI invocations (e.g., the `sf apex run` example in Phase 3.2 guidance) use `sf`. Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **No auto-retries.** If Phase 1's `git diff` invocation fails (non-zero exit), print the raw error and halt — never silently retry with a different range. If a `grep` call in Phase 1.3 (Kanban secondary check) or Phase 4.1 (PLACEHOLDER surface) **errors (exit ≥ 2** — real fault like unreadable file, bad regex, permission denied), surface the raw error and halt. Exit 1 (no match found) is a legitimate outcome at both grep sites — it means the candidate paths had no Picklist/MultiselectPicklist (Phase 1.3) or the NC is a modern ExternalCredential-backed one with no `<endpoint>` (Phase 4.1) — and is handled by body-phase logic, not treated as failure.
- **Org-agnostic.** Unlike `/revops:deploy-sandbox` and `/revops:deploy-prod`, this command does not pin a target org. The user invokes it after deploying to whichever org the manual steps apply to; the command shows paths for both sandbox and prod where relevant (e.g., Phase 4), but issues no org-specific calls itself.
- **No Linear mutations.** Skip follow-ups surface as narrated reminders only; the user creates Linear sub-issues manually if tracking is needed. This preserves the Phase 2 template contract (allowed-tools = `Bash, AskUserQuestion`) inherited from `/revops:deploy-sandbox` (BC-5790) and `/revops:deploy-prod` (BC-5791).
- **Conditional phases compile cleanly.** When Phase 1 detection flags a phase as not-applicable, the entire phase block (narration + listing + gate) is skipped — no "N/A" inline noise. The only place `N/A — not detected` appears is the Phase 6 summary matrix.
- **Need help is a repeat, not an advance.** If a user answers `Need help` at any gate, print the extended guidance and re-ask the original Completed/Skip question. Do not treat `Need help` as a terminal answer.
