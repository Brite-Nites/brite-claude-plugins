---
description: Post-deploy manual runbook for brite-salesforce — diff-driven walk through Screen Flow activation, Flow Draft cleanup, Scheduled Apex re-schedule, Named Credential URL updates, and Kanban Group By cache flush. Use after `/revops:deploy-sandbox` or `/revops:deploy-prod` lands, to walk the manual steps `sf project deploy start` can't automate.
allowed-tools: Bash, AskUserQuestion
---

# /revops:post-deploy-runbook

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered gate so the user explicitly acknowledges the manual step is complete (or deliberately skipped) before the command advances. If the user answers anything other than the proceed / skip options, halt and surface the blocker — never re-run past phases silently.

**One question at a time.** Never batch gate questions.

Source material: `brite-salesforce/CLAUDE.md` §Apex & Automation (Screen Flow activation, Scheduled Apex re-schedule), §Deploy & Retrieve (Named Credential PLACEHOLDER convention), §Metadata Authoring (Kanban Group By cache gotcha). The five post-deploy steps are the top documented causes of silent post-deploy failures in the Brite org.

Out of scope for this command: the deploy itself (use `/revops:deploy-sandbox` or `/revops:deploy-prod`), automating manual steps beyond Flow Draft cleanup (each remaining step requires human judgment about org-specific config), rollback of partial runbook completion, component types beyond the five detected.

See the **Rules** section at the bottom for the enforcement contract (zero mutations except Phase 3, org-agnostic for manual phases, no auto-retries, no Linear mutations).

---

## Phase 1 — Diff-based detection

Narrate: `Phase 1/7: Diff-based detection...`

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

The `-l` flag emits filenames-only (one path per line for each file containing a match) — which is all Phase 6 needs, because the `{Object}.{Field}` listing is re-derived from the path itself, not from the grep output content. This is why Phase 5.1 uses `-HE` instead: there, grep is surfacing the actual PLACEHOLDER URL text, so filename-prefixed matches (`-H`) are needed for per-NC attribution. Text / Number / Date fields on standard objects are not affected and will not appear in the output.

### 1.4 All-false fast-exit

If all four flags are false, narrate:

> No manual post-deploy steps detected for this diff — the deploy landed no Flows, Scheduled Apex, Named Credentials, or standard-object picklists. No Flow Draft cleanup needed. Nothing to walk.

Then **skip directly to Phase 7** and surface all five steps as `N/A — not detected`. Do not walk Phases 2-6. Do not prompt further.

### 1.5 Detection summary

If any flag is true, narrate a one-line summary:

> Detected: {list of true-flag steps}. Skipped: {list of false-flag steps}. Walking each detected step now.

Then proceed to Phase 2.

Narrate: `Phase 1/7: Diff-based detection... done`

---

## Phase 2 — Flow activation *(conditional on `needs_flow_activation`)*

Narrate: `Phase 2/7: Flow activation...`

### 2.1 List affected Flows

From the Phase 1.3 diff output, filter paths matching `^force-app/.*/flows/.*\.flow-meta\.xml$` — the same regex as Phase 1.3 (one source of truth). For each, extract the developer name from the filename (strip `.flow-meta.xml`). Print the list:

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
  - `Skip — will do later` — mark phase status `skipped`. Proceed (Phase 7 surfaces as follow-up).
  - `Need help` — see below.

If the user selects `Need help`, print this guidance verbatim then re-ask the question (do not advance):

> If you don't see the Flow in the list, confirm the deploy landed via `Setup → Deployment Status` in the target org. If the Flow shows Draft and you're certain you activated it, refresh the page — the list is cached. The Active/Draft toggle is on the Flow detail page, not in the list view.

Narrate: `Phase 2/7: Flow activation... done`

---

## Phase 3 — Flow Draft cleanup

Narrate: `Phase 3/7: Flow Draft cleanup...`

This phase queries the Tooling API for stale Flow Draft versions created during the deploy window and offers to delete them. Deploying Flows creates new Draft versions on every deploy (see [BC-11038](https://linear.app/brite-nites/issue/BC-11038)) — left uncleaned, they pile up and clutter the Flow version history. This is the one phase that issues `sf` CLI mutations (gated by operator consent via Phase 3.3).

### 3.1 Derive deploy-window start

From the Phase 1.2 commit range, extract the earliest commit's author date as a proxy for the deploy-window start:

```bash
git log <range> --format='%aI' --reverse | head -1
```

If the command produces output, convert the ISO 8601 timestamp to a SOQL-compatible datetime literal:

```bash
python3 -c "
from datetime import datetime, timezone
dt = datetime.fromisoformat('<git-date-output>')
print(dt.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
"
```

Store the result as `<deploy-window-start>` for Phase 3.2.

If either command fails (non-zero exit or empty output), fall back to the SOQL date literal `LAST_N_HOURS:2` as a safe default. Narrate: *"Could not extract deploy timestamp from commit range — using LAST_N_HOURS:2 fallback."*

### 3.2 Query Flow Drafts

Run:

```bash
sf data query --use-tooling-api --json \
  --query "SELECT Id, Status, Definition.DeveloperName, VersionNumber, CreatedDate
           FROM Flow
           WHERE Status = 'Draft'
             AND CreatedDate >= <deploy-window-start>
           ORDER BY CreatedDate DESC"
```

Substitute `<deploy-window-start>` with the SOQL datetime from Phase 3.1 (e.g., `2026-05-27T10:00:00Z`) or the `LAST_N_HOURS:2` fallback.

Parse the JSON response. Read `result.records` (an array of Flow rows).

- **Non-empty result set** — format the records as an operator-readable table:

  ```
  Flow Drafts from deploy window:
    - {Definition.DeveloperName} v{VersionNumber} | {CreatedDate} | {Id}
    - ...
  ```

  Then proceed to Phase 3.3 (gate).

- **Empty result set** (`result.records` is empty or `result.totalSize === 0`) — narrate: *"No Flow Drafts found in deploy window — skipping."* Mark phase status `N/A — no Drafts detected`. Narrate: `Phase 3/7: Flow Draft cleanup... done`. Proceed to Phase 4.

- **Query failure** (`status !== 0` or unexpected shape) — do **not** halt the runbook over an advisory check. Print the raw JSON and narrate: *"Flow Draft query failed (Tooling API error). Proceeding — check manually in Setup → Process Automation → Flows if needed."* Mark phase status `N/A — query failed`. Narrate: `Phase 3/7: Flow Draft cleanup... done`. Proceed to Phase 4.

### 3.3 Gate

Ask via `AskUserQuestion`:

- Question: `{N} stale Flow Drafts detected from this deploy window. Delete them?` (substitute `{N}` with the record count)
- Options:
  - `Delete all` — proceed to Phase 3.4 (bulk delete).
  - `Skip — keep Drafts` — mark phase status `skipped`. Narrate: `Phase 3/7: Flow Draft cleanup... done`. Proceed to Phase 4.
  - `Pick individually` — proceed to Phase 3.5 (per-Draft gate).

### 3.4 Bulk delete

For each Draft in the result set, run:

```bash
sf data delete record --use-tooling-api --sobject Flow --record-id <Id> --json
```

After all deletions, report the count:

> Deleted {success_count}/{total_count} Flow Drafts.

If any individual deletion fails, surface the per-record error (record Id + error message) but continue to the next record — do not halt the runbook over a single-record failure. After all iterations, if any failures occurred, append:

> {fail_count} deletion(s) failed — see errors above. These Drafts remain in the org; delete manually via Setup → Process Automation → Flows if needed.

Mark phase status `completed`. Proceed to Phase 4.

### 3.5 Per-Draft gate

For each Draft in the result set (one at a time):

Ask via `AskUserQuestion`:

- Question: `Delete Flow Draft: {Definition.DeveloperName} v{VersionNumber} ({CreatedDate})?`
- Options:
  - `Delete` — run `sf data delete record --use-tooling-api --sobject Flow --record-id <Id> --json`. Surface success or failure per record.
  - `Keep` — skip this Draft.

After all individual gates, report the final count:

> Deleted {deleted_count}/{total_count} Flow Drafts ({kept_count} kept).

Mark phase status `completed`. Proceed to Phase 4.

Narrate: `Phase 3/7: Flow Draft cleanup... done`

---

## Phase 4 — Scheduled Apex re-schedule *(conditional on `needs_scheduled_apex_reschedule`)*

Narrate: `Phase 4/7: Scheduled Apex re-schedule...`

### 4.1 List affected Schedulers

From the Phase 1.3 diff output, filter paths matching `^force-app/.*/classes/.*(Scheduler|Scheduled).*\.cls(-meta\.xml)?$` **and** NOT ending in `Test.cls` or `Test.cls-meta.xml` — the same regex and Test-exclusion as Phase 1.3 (one source of truth). Extract the class name from each matched path by stripping the `.cls-meta.xml` or `.cls` suffix, then de-duplicate by base name. This handles all three diff shapes: paired `.cls` + `.cls-meta.xml` produce one class name after dedup; a `.cls`-only change produces one class name; a `.cls-meta.xml`-only change (metadata-only API-version bump) produces one class name. The listing must be non-empty whenever `needs_scheduled_apex_reschedule` is true. Print:

> The following Scheduled Apex classes were deployed. Per `brite-salesforce/CLAUDE.md` §Apex & Automation, CronTrigger rows do not survive a deploy that replaces the class, and do not survive sandbox refresh. Re-schedule each one manually.
>
> - `{SchedulerClass1}`
> - `{SchedulerClass2}`
> - ...

### 4.2 Print re-schedule template

For each class, the anonymous Apex to run is:

```apex
System.schedule('<Job Name>', '<cron expression>', new <SchedulerClass>());
```

Replacement guidance:

- `<Job Name>` — conventionally matches the class name (e.g., `'LeadScoringScheduler'`). The job name is what appears in `Setup → Environment → Jobs → Scheduled Jobs`.
- `<cron expression>` — preserve the prior schedule. Standard Brite patterns: hourly = `'0 0 * * * ?'`, daily at 3am UTC = `'0 0 3 * * ?'`, weekly Sunday at midnight = `'0 0 0 ? * SUN'`. If you don't know the prior cron, check the target org: `SELECT Id, CronJobDetailId, CronExpression, State FROM CronTrigger` via SOQL, **before** you deploy next time.

Execute via:

```bash
sf apex run --target-org <alias> --file scratch.apex
```

where `scratch.apex` contains the `System.schedule(...)` line(s). Alternatively paste into Developer Console → Execute Anonymous.

Verify jobs exist post-schedule via `Setup → Environment → Jobs → Scheduled Jobs` (not "Apex Jobs" — that's the async execution-history page; "Scheduled Jobs" is the sibling page carrying the active `CronTrigger` rows and the `Del` column).

### 4.3 Gate

Ask via `AskUserQuestion`:

- Question: `Scheduled Apex re-schedule — completed all {N} classes?` (substitute `{N}` with the count from 4.1)
- Options:
  - `All scheduled` — mark phase status `completed`. Proceed.
  - `Skip — will do later` — mark phase status `skipped`. Proceed (Phase 7 surfaces as follow-up).
  - `Need help` — see below.

If the user selects `Need help`, print this guidance verbatim then re-ask the question (do not advance):

> If you get `System.AsyncException: An instance of the scheduled class has already been scheduled with this name`, the prior job still exists — abort it first via `Setup → Environment → Jobs → Scheduled Jobs → <row> → Del`, then re-run `System.schedule`. If you need the prior cron and don't have it, the target org's `CronTrigger` table has it (pre-redeploy — query `SELECT Id, CronJobDetail.Name, CronExpression, State FROM CronTrigger WHERE State = 'WAITING'`).

Narrate: `Phase 4/7: Scheduled Apex re-schedule... done`

---

## Phase 5 — Named Credential URL update *(conditional on `needs_named_credential_update`)*

Narrate: `Phase 5/7: Named Credential URL update...`

### 5.1 List affected Named Credentials

From the Phase 1.3 diff output, filter paths matching `^force-app/.*/namedCredentials/.*\.namedCredential-meta\.xml$` — the same regex as Phase 1.3 (one source of truth). Extract the Named Credential name from the filename. Surface the PLACEHOLDER value in each file via one batched grep across all NC paths (not one invocation per NC):

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

### 5.2 Per-org UI path

For each target org, the update path is:

> **`brite-sandbox`:** `Setup → Security → Named Credentials → {Name} → Edit → set URL to the real sandbox endpoint → Save`
>
> **`brite-prod`:** `Setup → Security → Named Credentials → {Name} → Edit → set URL to the real production endpoint → Save`

The prod and sandbox endpoints usually differ (different vendor environments, different allowed IP ranges). The user must know which is which — this command does not look them up.

### 5.3 Gate

Ask via `AskUserQuestion`:

- Question: `Named Credential URL update — completed all {N} credentials across all target orgs?` (substitute `{N}` with the count from 5.1)
- Options:
  - `All URLs updated` — mark phase status `completed`. Proceed.
  - `Skip — will do later` — mark phase status `skipped`. Proceed (Phase 7 surfaces as follow-up).
  - `Need help` — see below.

If the user selects `Need help`, print this guidance verbatim then re-ask the question (do not advance):

> If callouts fail with `Invalid URL` or auth errors right after deploy, this is almost always the cause. Check the current URL via the Setup UI or via `SELECT Id, DeveloperName, Endpoint FROM NamedCredential` in Tooling API. If the URL still reads PLACEHOLDER, the update didn't save — retry the Edit flow.

Narrate: `Phase 5/7: Named Credential URL update... done`

---

## Phase 6 — Kanban Group By cache flush *(conditional on `needs_kanban_flush`)*

Narrate: `Phase 6/7: Kanban Group By cache flush...`

### 6.1 List affected fields

From the Phase 1.3 detection, list each standard-object picklist field that matched:

> The following standard-object picklist fields were deployed. Per `brite-salesforce/CLAUDE.md` §Metadata Authoring, new picklist values on standard objects don't appear in the Kanban Group By dropdown until the UI metadata cache is flushed — this is a platform cache bug that only affects standard objects (custom objects don't have it).
>
> - `{Object1}.{Field1}`
> - `{Object2}.{Field2}`
> - ...

### 6.2 Flush technique

For each affected field, the flush is indirect:

> Add the field to any page layout on that object (even a seldom-used or hidden layout works) and redeploy that layout. The layout touch invalidates the UI metadata cache for the object, and the Kanban Group By dropdown picks up the field on next render.
>
> Alternatively: open `Setup → Lightning App Builder → <any page referencing the object> → Save` — the save propagates the cache flush.

The fix is platform-side; there's no API to invalidate the cache directly.

### 6.3 Gate

Ask via `AskUserQuestion`:

- Question: `Kanban Group By cache flush — completed for all {N} fields?` (substitute `{N}` with the count from 6.1)
- Options:
  - `Flushed` — mark phase status `completed`. Proceed.
  - `Skip — will do later` — mark phase status `skipped`. Proceed (Phase 7 surfaces as follow-up).
  - `Need help` — see below.

If the user selects `Need help`, print this guidance verbatim then re-ask the question (do not advance):

> Verify the flush worked by opening a Kanban view on the affected object and checking that the new field appears in the Group By dropdown. If it doesn't, the layout redeploy didn't trigger the cache invalidation — try editing a different layout, or save-and-close any page in Lightning App Builder.

Narrate: `Phase 6/7: Kanban Group By cache flush... done`

---

## Phase 7 — Completion summary

Narrate: `Phase 7/7: Completion summary...`

Print the per-phase status matrix, using the phase-status values set in Phases 2-6 (`completed`, `skipped`, `N/A — not detected` for any phase that Phase 1 didn't flag, or Phase 3's additional `N/A — no Drafts detected` / `N/A — query failed`):

- `✓ Flow activation: {completed / skipped / N/A — not detected}`
- `✓ Flow Draft cleanup: {completed / skipped / N/A — no Drafts detected / N/A — query failed / N/A — not detected}`
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

> Post-deploy manual runbook complete. The deploy is now functionally live — Flows active, Flow Drafts cleaned, Scheduled Apex jobs restored, Named Credential URLs real, Kanban caches flushed as applicable.

If **all** phases were `N/A — not detected` (Phase 1 fast-exit path), the summary suffices — no additional narration needed.

Narrate: `Phase 7/7: Completion summary... done`

---

## Rules

- **This command issues ZERO `sf` CLI mutations except in Phase 3.** Phases 2 and 4–6 are read-only walkthroughs of user-performed manual steps. Phase 3 (Flow Draft cleanup) is the sole exception — it runs `sf data delete record` against Flow Drafts, gated by operator consent via Phase 3.3. Every other mutating action is executed by the user in their browser / IDE / Developer Console; the command narrates, detects, and gates.
- **Never advance past a gate silently.** Every `AskUserQuestion` has a defined advance / halt / repeat disposition for each option: the phase-completed option advances with status `completed`; the `Skip — will do later` option advances with status `skipped` (Phase 7 surfaces it as follow-up); `Need help` repeats the same question (see final rule); any other answer — including halt paths defined per-phase — halts cleanly without continuing to the next phase.
- **`sf`, not `sfdx`.** Any CLI invocations (e.g., the `sf apex run` example in Phase 4.2 guidance, or the `sf data delete record` in Phase 3.4) use `sf`. Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **No auto-retries.** If Phase 1's `git diff` invocation fails (non-zero exit), print the raw error and halt — never silently retry with a different range. If a `grep` call in Phase 1.3 (Kanban secondary check) or Phase 5.1 (PLACEHOLDER surface) **errors** (exit ≥ 2 — real fault like unreadable file, bad regex, permission denied), surface the raw error and halt. Exit 1 (no match found) is a legitimate outcome at both grep sites — it means the candidate paths had no Picklist/MultiselectPicklist (Phase 1.3) or the NC is a modern ExternalCredential-backed one with no `<endpoint>` (Phase 5.1) — and is handled by body-phase logic, not treated as failure. Phase 3.2 Tooling API query failure is advisory and does not halt (see Phase 3.2 failure handling).
- **Org-agnostic (except Phase 3).** Unlike `/revops:deploy-sandbox` and `/revops:deploy-prod`, this command does not pin a target org for manual-step phases. The user invokes it after deploying to whichever org the manual steps apply to; the command shows paths for both sandbox and prod where relevant (e.g., Phase 5), but issues no org-specific calls itself outside of Phase 3. Phase 3 (Flow Draft cleanup) runs `sf data query` and `sf data delete record` against the default target-org — ensure the default org is set to the deployed org before running the runbook.
- **No Linear mutations.** Skip follow-ups surface as narrated reminders only; the user creates Linear sub-issues manually if tracking is needed. This preserves the Phase 2 template contract (allowed-tools = `Bash, AskUserQuestion`) inherited from `/revops:deploy-sandbox` (BC-5790) and `/revops:deploy-prod` (BC-5791).
- **Conditional phases compile cleanly.** When Phase 1 detection flags a phase as not-applicable, the entire phase block (narration + listing + gate) is skipped — no "N/A" inline noise. The only place `N/A — not detected` appears is the Phase 7 summary matrix. Phase 3 is not conditional on a diff flag — it always runs in the non-fast-exit path and self-determines via the Tooling API query result.
- **Need help is a repeat, not an advance.** If a user answers `Need help` at any gate, print the extended guidance and re-ask the original Completed/Skip question. Do not treat `Need help` as a terminal answer.
