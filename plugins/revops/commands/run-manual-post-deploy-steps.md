---
disable-model-invocation: true
description: Walk the manual post-deploy steps `sf` cannot automate — diff-driven pass through Screen Flow activation, Flow Draft cleanup, Scheduled Apex re-schedule, Named Credential URL updates, and Kanban Group By cache flush. Use after `/revops:preview-changes` or `/revops:push-to-production` lands. Formerly `/revops:post-deploy-runbook`.
argument-hint: (--target-org brite-dev-<name> --deploy-id <0Af...> | --production | --production-breakglass)
allowed-tools: Bash, AskUserQuestion
---

<!-- eval-waiver: Seven-phase diff-driven manual runbook: it classifies a git diff against four detection regexes and walks AskUserQuestion-gated manual UI steps. Dev Flow receipt, activation, and Draft-query evidence is separated into the hermetic flow_postdeploy_guard.py; the remaining UI acknowledgements have no deterministic artifact boundary. A deterministic git-diff to four-flag classifier seam remains deferred (BC-13163). -->

# /revops:run-manual-post-deploy-steps

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered gate so the user explicitly acknowledges the manual step is complete (or deliberately skipped) before the command advances. If the user answers anything other than the proceed / skip options, halt and surface the blocker — never re-run past phases silently.

**One question at a time.** Never batch gate questions.

Source material: `brite-salesforce/CLAUDE.md` §Apex & Automation (Screen Flow activation, Scheduled Apex re-schedule), §Deploy & Retrieve (Named Credential PLACEHOLDER convention), §Metadata Authoring (Kanban Group By cache gotcha). The five post-deploy steps are the top documented causes of silent post-deploy failures in the Brite org.

Out of scope for this command: the deploy itself (use `/revops:preview-changes` or `/revops:push-to-production`), changing the production Flow-activation decision made by CI, automating manual steps beyond dev-org Flow Draft cleanup (each remaining step requires human judgment about org-specific config), rollback of partial runbook completion, component types beyond the five detected.

See the **Rules** section at the bottom for the enforcement contract (zero mutations except Phase 3, org-agnostic for manual phases, no auto-retries, no Linear mutations).

---

## Invocation context — required before Phase 1

Require **exactly one** context:

- `--target-org brite-dev-<name> --deploy-id <0Af...>` — a per-developer org after `/revops:preview-changes`, plus the exact Metadata API deployment ID printed by that command. Reject the alias unless it matches `^brite-dev-[a-z0-9][a-z0-9-]*$`; reject the deployment ID unless it matches `^0Af[A-Za-z0-9]{12}([A-Za-z0-9]{3})?$`. Store the validated values as `{dev-org}` and `{deploy-id}`. This is the only context in which Phase 2 may guide Flow activation and Phase 3 may query or delete Flow Draft versions.
- `--production` — the deploy came from `/revops:push-to-production`. There is no target-org flag and this command issues no Salesforce CLI query or mutation. Production Flow activation and version verification belong to the selected `plan|canary|apply` stage in `deploy-prod.yml`.
- `--production-breakglass` — the deploy came from `/revops:emergency-deploy-to-production` while CI was down. This command still issues no Salesforce CLI query or mutation. Because no reviewed CI activation stage ran, Flow activation remains blocked pending a separate Kells/release-manager scope decision; this runbook handles only the other detected manual steps.

If neither or both are present, **halt before reading the diff**:

  > Choose exactly one post-deploy context: `--target-org brite-dev-<name> --deploy-id <0Af...>` after an inner-loop deploy, `--production` after the CI production lane, or `--production-breakglass` after the emergency lane. The command will not infer an org, deployment, or time window from local defaults.

For a dev context, a missing or malformed `--deploy-id` is the same as a missing target org: halt before reading the diff. Never guess the newest deployment or derive cleanup authority from a commit timestamp.

Reject every shared or protected alias (`briteint`, `brite-integration`, `brite-uat`, `brite-prod`, `brite-sandbox`) passed through `--target-org`. Do not resolve or inspect local org defaults.

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

  > Not in an SFDX project — no `sfdx-project.json` in the current directory. `/revops:run-manual-post-deploy-steps` must be run from the root of a Salesforce DX repo (e.g., `brite-salesforce`). `cd` into the repo and re-run.

  Do not continue. Do not prompt further.

### 1.2 Choose commit range

Ask via `AskUserQuestion`:

- Question: `Which commit range holds the deploy you want to walk?`
- Options:
  - `Just-deployed commit (HEAD~1..HEAD)` — Phase 1.3 uses `git diff HEAD~1 HEAD --name-only`.
  - `Last 5 commits on the deployed lane` — use `origin/integration~5..origin/integration` for `--target-org brite-dev-<name>`, or `origin/main~5..origin/main` for `--production`. Never compare a Salesforce feature/dev deployment to `main`.

The default recommendation is `Just-deployed commit (HEAD~1..HEAD)`. Those are the only accepted choices. Do not accept or interpolate a custom git range: free-form revision syntax is also shell syntax, and this command later reuses the selected value. If neither bounded choice represents the deploy, halt and ask the operator to reconstruct an exact reviewed receipt first.

### 1.3 Run diff + classify

Set `RANGE` to the fixed value selected in Phase 1.2, then run it as one quoted
argument:

```bash
git diff "$RANGE" --name-only
```

If the command exits non-zero, print the raw stderr and **halt** with:

> `git diff "$RANGE"` failed. Verify the selected bounded range is present in this repo. Do not re-run this command with a guessed fallback range.

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

### Production Flow ownership

If the invocation uses `--production`, do not enter the manual activation steps below. Print:

> Production Flow activation is owned by the explicit `plan|canary|apply` activation stage in `deploy-prod.yml`, followed by the six-type verifier. `plan` is intentionally read-only. Do not activate a Flow manually here: that would bypass the reviewed scope and could turn a reported Draft into an unapproved behavioral go-live.

Mark Phase 2 `CI-owned — see deploy run` and proceed to Phase 3. The remainder of Phase 2 applies only to the validated `{dev-org}` context.

If the invocation uses `--production-breakglass`, also skip the manual activation steps. Print:

> The break-glass deploy bypassed CI's activation stage. Flow activation is **not approved by that fact** and remains blocked pending a separate Kells/release-manager scope decision. Do not activate a Flow manually from this runbook.

Mark Phase 2 `blocked — separate activation decision required` and proceed to Phase 3.

### 2.1 List affected Flows

From the Phase 1.3 diff output, filter paths matching `^force-app/.*/flows/.*\.flow-meta\.xml$` — the same regex as Phase 1.3 (one source of truth). For each, extract the developer name from the filename (strip `.flow-meta.xml`), then de-duplicate and sort. Every name must match `^[A-Za-z][A-Za-z0-9_]*$`; otherwise mark Phases 2 and 3 `blocked — affected Flow set invalid` and issue no org command. Print the validated list:

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
  - `All activated` — run the readback below; the click alone is not proof.
  - `Skip — will do later` — mark phase status `skipped`. Proceed (Phase 7 surfaces as follow-up).
  - `Need help` — see below.

If the user selects `Need help`, print this guidance verbatim then re-ask the question (do not advance):

> If you don't see the Flow in the list, confirm the deploy landed via `Setup → Deployment Status` in the target org. If the Flow shows Draft and you're certain you activated it, refresh the page — the list is cached. The Active/Draft toggle is on the Flow detail page, not in the list view.

After `All activated`, query the exact affected set from the validated dev org and pass the untouched JSON to the deterministic guard:

```bash
sf data query --use-tooling-api --json --target-org {dev-org} \
  --query "SELECT DeveloperName, ActiveVersion.VersionNumber, LatestVersion.VersionNumber
           FROM FlowDefinition WHERE DeveloperName IN (<affected-flow-names>)"
python3 "$CLAUDE_PLUGIN_ROOT/scripts/flow_postdeploy_guard.py" \
  activation-query <query-json-file> --flow <one-argument-per-affected-name>
```

Write the raw query response to a mode-600 `mktemp` file, pass each already-regex-validated name as a separate `--flow` argument, then delete the file. Only a guard exit 0 with `decision: ready` proves that the complete result contains every affected Flow exactly once and that each `ActiveVersion.VersionNumber` equals its positive `LatestVersion.VersionNumber`. Then mark Phase 2 `completed`. On query or guard failure, print the raw JSON and guard reason, mark Phase 2 `blocked — activation verification untrusted`, and proceed without claiming activation succeeded.

Narrate: `Phase 2/7: Flow activation... done`

---

## Phase 3 — Flow Draft cleanup

Narrate: `Phase 3/7: Flow Draft cleanup...`

If the invocation uses `--production`, **do not query or delete Flow versions**. Mark Phase 3 `CI-owned — see deploy run`, narrate `Phase 3/7: Flow Draft cleanup... skipped (production CI-owned)`, and proceed to Phase 4. A production `plan` result that lists Drafts is evidence for a later deliberate decision, not permission for this runbook to clean up or activate them.

If the invocation uses `--production-breakglass`, likewise do not query or delete Flow versions. Mark Phase 3 `blocked — separate activation decision required` and proceed to Phase 4. The emergency deploy did not grant cleanup or activation authority.

The rest of this phase is dev-org only. If `needs_flow_activation` is false, mark Phase 3 `N/A — no affected Flows` and proceed to Phase 4 without querying the org. A deploy may clean up Draft versions only for the Flow developer names in the reviewed diff; a time window alone is never an ownership boundary.

For an affected-Flow diff, query the Tooling API for Draft versions of **those exact Flows** created during the deploy window and offer to delete them. Deploying Flows creates new Draft versions on every deploy (see [BC-11038](https://linear.app/brite-nites/issue/BC-11038)) — left uncleaned, they pile up and clutter the Flow version history. This is the one phase that issues `sf` CLI mutations (gated by operator consent via Phase 3.3), and every call pins the validated `{dev-org}` explicitly.

Reuse the de-duplicated, sorted, regex-validated affected names from Phase 2.1. The strict name grammar is what makes the `IN (...)` predicate and discrete `--flow` arguments below non-injectable.

### 3.1 Validate the deploy receipt and derive a bounded window

Read the exact deployment named by the validated invocation; never select the newest deployment. Write the raw response to a mode-600 `mktemp` file and run:

```bash
sf project deploy report --job-id {deploy-id} --target-org {dev-org} --json
python3 "$CLAUDE_PLUGIN_ROOT/scripts/flow_postdeploy_guard.py" \
  receipt <report-json-file> --deploy-id {deploy-id} \
  --flow <one-argument-per-affected-name>
```

The helper is the only receipt authority. It requires CLI `status === 0`; exact `result.id`; `done === true`, `success === true`, `status === "Succeeded"`, `checkOnly === false`; a server-recorded start/completion interval that is ordered, not future, and no longer than six hours; and well-formed `componentSuccesses` containing every affected Flow exactly once as `componentType === "Flow"`. Use its `window_start` and `window_end` outputs as `<deploy-window-start>` and `<deploy-window-end>`. The receipt—not a commit's mutable author date or laptop clock—owns the window.

If the report or guard exits nonzero, print the raw JSON and guard reason, delete the temp file, mark Phase 3 `blocked — deploy receipt untrusted`, and proceed to Phase 4 with **no query and no mutation**. Never retry with another deployment ID or a guessed `LAST_N_HOURS` window.

### 3.2 Query Flow Drafts

Run:

```bash
sf data query --use-tooling-api --json --target-org {dev-org} \
  --query "SELECT Id, Status, Definition.DeveloperName, VersionNumber, CreatedDate
           FROM Flow
           WHERE Status = 'Draft'
             AND Definition.DeveloperName IN (<affected-flow-names>)
             AND CreatedDate >= <deploy-window-start>
             AND CreatedDate <= <deploy-window-end>
           ORDER BY CreatedDate DESC"
python3 "$CLAUDE_PLUGIN_ROOT/scripts/flow_postdeploy_guard.py" \
  draft-query <query-json-file> --window-start <deploy-window-start> \
  --window-end <deploy-window-end> --flow <one-argument-per-affected-name>
```

Substitute the already-validated names and the guard-emitted UTC window. Write the untouched query response to a fresh mode-600 `mktemp` file. The helper is the only delete-list authority: it requires a complete status-0 query whose `totalSize` exactly reconciles, then validates every unique `301...` Id, Draft status, affected developer name, positive version, and CreatedDate inside the closed deployment interval. Delete the temp files after parsing.

- **Non-empty result set** — format the records as an operator-readable table:

  ```
  Guarded affected Flow Drafts from deploy window:
    - {Definition.DeveloperName} v{VersionNumber} | {CreatedDate} | {Id}
    - ...
  ```

  Render this table only from the guard's `drafts` output, and carry only its `delete_ids` to Phase 3.3.

- **Guarded empty result** (`draft_count === 0` and `delete_ids` is empty) — narrate: *"No affected Flow Drafts found in deploy window — skipping."* Mark phase status `N/A — no Drafts detected`. Narrate: `Phase 3/7: Flow Draft cleanup... done`. Proceed to Phase 4.

- **Query or guard failure** — print the raw JSON and guard reason, mark phase status `blocked — cleanup query untrusted`, and proceed to Phase 4 with **no deletion prompt and no mutation**. Manual inspection may continue in Setup, but this command must not turn an unanswered population question into delete authority.

### 3.3 Gate

Ask via `AskUserQuestion`:

- Question: `{N} Drafts for the affected Flows were detected in this deploy window. Delete them?` (substitute `{N}` with the guard's `draft_count`)
- Options:
  - `Delete all` — proceed to Phase 3.4 (bulk delete).
  - `Skip — keep Drafts` — mark phase status `skipped`. Narrate: `Phase 3/7: Flow Draft cleanup... done`. Proceed to Phase 4.
  - `Pick individually` — proceed to Phase 3.5 (per-Draft gate).

### 3.4 Bulk delete

For each exact Id in the guard's `delete_ids` array, run:

```bash
sf data delete record --use-tooling-api --sobject Flow --record-id <Id> --target-org {dev-org} --json
```

After all deletions, report the count:

> Deleted {success_count}/{total_count} Flow Drafts.

If any individual deletion fails, surface the per-record error (record Id + error message) but continue to the next record — do not halt the runbook over a single-record failure. After all iterations, if any failures occurred, append:

> {fail_count} deletion(s) failed — see errors above. These Drafts remain in the org; delete manually via Setup → Process Automation → Flows if needed.

Mark phase status `completed`. Proceed to Phase 4.

### 3.5 Per-Draft gate

For each row in the guard's `drafts` array (one at a time):

Ask via `AskUserQuestion`:

- Question: `Delete Flow Draft: {Definition.DeveloperName} v{VersionNumber} ({CreatedDate})?`
- Options:
  - `Delete` — run `sf data delete record --use-tooling-api --sobject Flow --record-id <Id> --target-org {dev-org} --json`. Surface success or failure per record.
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

<!-- guard:target-org:exempt operator copy-paste runbook snippet — the operator fills <alias> and runs it in their own terminal (or Developer Console); the command never interpolates-and-executes it, so there is no command-driven --target-org sink to guard (BC-12638) -->

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

> **your `brite-dev-<name>` org (or `brite-integration`):** `Setup → Security → Named Credentials → {Name} → Edit → set URL to the real non-prod endpoint → Save`
>
> **`brite-prod`:** `Setup → Security → Named Credentials → {Name} → Edit → set URL to the real production endpoint → Save`

The prod and sandbox endpoints usually differ (different vendor environments, different allowed IP ranges). The user must know which is which — this command does not look them up.

### 5.3 Gate

Ask via `AskUserQuestion`:

- Question: `Named Credential URL update — completed all {N} credentials in this run's explicit environment?` (substitute `{N}` with the count from 5.1)
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

Print the per-phase status matrix, using the phase-status values set in Phases 2-6 (`completed`, `skipped`, `N/A — not detected` for any phase that Phase 1 didn't flag, `CI-owned — see deploy run` for normal production Flows, `blocked — separate activation decision required` for break glass, `blocked — activation verification untrusted` for failed dev readback, or Phase 3's additional `N/A — no affected Flows` / `N/A — no Drafts detected` / `blocked — affected Flow set invalid` / `blocked — deploy receipt untrusted` / `blocked — cleanup query untrusted` in a dev org):

- `✓ Flow activation: {completed / skipped / CI-owned — see deploy run / blocked — separate activation decision required / blocked — activation verification untrusted / N/A — not detected}`
- `✓ Flow Draft cleanup: {completed / skipped / CI-owned — see deploy run / blocked — separate activation decision required / N/A — no affected Flows / N/A — no Drafts detected / blocked — affected Flow set invalid / blocked — deploy receipt untrusted / blocked — cleanup query untrusted / N/A — not detected}`
- `✓ Scheduled Apex re-schedule: {completed / skipped / N/A — not detected}`
- `✓ Named Credential URL update: {completed / skipped / N/A — not detected}`
- `✓ Kanban Group By flush: {completed / skipped / N/A — not detected}`

If **any** phase has status `skipped`, append the follow-up list:

> ⚠️ Follow-up required — the following manual steps were deliberately skipped and are still pending:
>
> - {each skipped phase, with the affected components relisted}
>
> Don't consider this deploy done until these complete. Re-run `/revops:run-manual-post-deploy-steps` on the same commit range after finishing them. If tracking the follow-up as a Linear sub-issue helps, create one manually — this command does not create Linear issues by design (allowed-tools is `Bash, AskUserQuestion` only).

If **no** phase has status `skipped` and at least one phase ran, append:

> Post-deploy manual runbook complete. The CI Flow-activation decision is preserved, and Scheduled Apex jobs, Named Credential URLs, and Kanban caches are handled as applicable.

If **all** phases were `N/A — not detected` (Phase 1 fast-exit path), the summary suffices — no additional narration needed.

Narrate: `Phase 7/7: Completion summary... done`

---

## Rules

- **This command issues ZERO `sf` CLI mutations except in dev-org Phase 3.** Dev Phase 2 adds a read-only, guarded activation query; Phases 4–6 remain walkthroughs of user-performed manual steps. Phase 3 alone runs `sf data delete record` against the explicitly validated `{dev-org}`, gated by operator consent via Phase 3.3. Production contexts issue no Salesforce command. Every other mutating action is executed by the user in their browser / IDE / Developer Console; the command narrates, detects, and gates.
- **Never advance past a gate silently.** Every `AskUserQuestion` has a defined advance / halt / repeat disposition for each option: the phase-completed option advances with status `completed`; the `Skip — will do later` option advances with status `skipped` (Phase 7 surfaces it as follow-up); `Need help` repeats the same question (see final rule); any other answer — including halt paths defined per-phase — halts cleanly without continuing to the next phase.
- **`sf`, not `sfdx`.** Any CLI invocations (e.g., the `sf apex run` example in Phase 4.2 guidance, or the `sf data delete record` in Phase 3.4) use `sf`. Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **No auto-retries.** If Phase 1's quoted, fixed `git diff` invocation fails (non-zero exit), print the raw error and halt — never silently retry with a different range. Custom ranges are not accepted. If a `grep` call in Phase 1.3 (Kanban secondary check) or Phase 5.1 (PLACEHOLDER surface) **errors** (exit ≥ 2 — real fault like unreadable file, bad regex, permission denied), surface the raw error and halt. Exit 1 (no match found) is a legitimate outcome at both grep sites — it means the candidate paths had no Picklist/MultiselectPicklist (Phase 1.3) or the NC is a modern ExternalCredential-backed one with no `<endpoint>` (Phase 5.1) — and is handled by body-phase logic, not treated as failure. Phase 3.1 receipt failures and Phase 3.2 query failures or incomplete results fail the cleanup gate closed: the rest of the runbook may continue, but no Draft deletion is offered.
- **Context is explicit; local defaults are never authority.** `--target-org` accepts only a validated `brite-dev-<name>`; its paired `--deploy-id` names the exact completed, non-check-only deployment. Every dev activation query and Phase 3 report/query/delete pins `{dev-org}`. `--production` performs no Salesforce CLI query or mutation and never repeats the CI Flow decision. `--production-breakglass` also performs no Salesforce CLI query/mutation and leaves Flow activation blocked for a separate human decision. Shared and protected aliases are refused as `--target-org` values.
- **No Linear mutations.** Skip follow-ups surface as narrated reminders only; the user creates Linear sub-issues manually if tracking is needed. This preserves the Phase 2 template contract (allowed-tools = `Bash, AskUserQuestion`) inherited from `/revops:preview-changes` (BC-5790) and `/revops:push-to-production` (BC-5791).
- **Conditional phases compile cleanly.** When Phase 1 detection flags a phase as not-applicable, the entire phase block (narration + listing + gate) is skipped — no "N/A" inline noise. The only place `N/A — not detected` appears is the Phase 7 summary matrix. Phase 3 runs in the non-fast-exit path but performs no org query unless the reviewed diff contains a valid, non-empty affected-Flow set.
- **Need help is a repeat, not an advance.** If a user answers `Need help` at any gate, print the extended guidance and re-ask the original Completed/Skip question. Do not treat `Need help` as a terminal answer.
