---
description: Sandbox deploy orchestration for brite-salesforce — pre-flight, dry-run, deploy, Apex tests, manual browser verification. Use when you've completed SF metadata changes and want to validate in `brite-staging` before opening a PR. Fills the gap between `/workflows:review` and `/workflows:ship` that SF-specific ship discipline requires.
allowed-tools: Bash, AskUserQuestion
---

# /revops:deploy-sandbox

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered gate so the user explicitly acknowledges the state before any mutating step. If the user answers anything other than the proceed option, halt and surface the blocker — do not re-run past phases silently.

**One question at a time.** Never batch gate questions.

Canonical invocation pattern comes from `brite-salesforce/CLAUDE.md` §Commands + §Development Flow §2. Sandbox alias is `brite-staging`. Always pass `--target-org` explicitly — never rely on a default org. Always use `sf`, never legacy `sfdx`.

Out of scope for this command: prod deploy (use `/revops:deploy-prod`), post-deploy manual runbook (use `/revops:post-deploy-runbook`), automating browser verification.

---

## Phase 1 — Pre-flight

Narrate: `Phase 1/6: Pre-flight checks...`

### 1.1 Confirm cwd is an SFDX project

Run:

```bash
test -f sfdx-project.json && echo "SFDX_PROJECT_OK" || echo "NOT_SFDX"
```

- `SFDX_PROJECT_OK` → continue.
- `NOT_SFDX` → **halt** with this message:

  > Not in an SFDX project — no `sfdx-project.json` in the current directory. `/revops:deploy-sandbox` must be run from the root of a Salesforce DX repo (e.g., `brite-salesforce`). `cd` into the repo and re-run.

  Do not continue. Do not prompt further.

### 1.2 Confirm sandbox alias with the user

Ask via `AskUserQuestion`:

- Question: `Deploy to brite-staging?`
- Options:
  - `Yes, brite-staging` — proceed to Phase 2.
  - `No, pick a different alias` — halt. Tell the user: *"This command pins `brite-staging` by design (from `brite-salesforce/CLAUDE.md` §Development Flow). If you need a different sandbox, run the `sf` commands manually or open an issue to parameterize this command."*

Narrate: `Phase 1/6: Pre-flight checks... done`

---

## Phase 2 — Dry-run deploy

Narrate: `Phase 2/6: Dry-run deploy...`

Run:

```bash
sf project deploy start --source-dir force-app --dry-run --target-org brite-staging --json
```

Parse the JSON response. Treat top-level `status === 0` as success (the stable cross-version exit-code field):

- `status: 0` → dry-run passed. Extract `result.numberComponentsTotal`, `result.numberComponentsDeployed`, `result.numberTestsTotal` (if present). Report counts to the user.
- Any other `status` → dry-run failed. Print `result.details.componentFailures[*].problem` for each failure (or the raw JSON if the shape is unexpected). **Halt** with:

  > Dry-run failed in `brite-staging`. Fix the errors above locally, then re-run `/revops:deploy-sandbox`. No actual deploy was attempted.

  Do **not** continue to Phase 3 under any circumstances.

If dry-run passed, ask via `AskUserQuestion`:

- Question: `Dry-run passed ({N} components). Proceed to actual sandbox deploy?`
  - Substitute `{N}` with `numberComponentsTotal` from the dry-run response.
- Options:
  - `Yes, deploy to brite-staging` — proceed to Phase 3.
  - `No, stop here` — **halt** cleanly. Print: *"Stopped after dry-run. No deploy was attempted. Re-run `/revops:deploy-sandbox` when ready."* Exit.

Narrate: `Phase 2/6: Dry-run deploy... done`

---

## Phase 3 — Actual sandbox deploy

Narrate: `Phase 3/6: Actual sandbox deploy...`

Run (same command as Phase 2, without `--dry-run`):

```bash
sf project deploy start --source-dir force-app --target-org brite-staging --json
```

Parse the JSON (same `status === 0` check as Phase 2):

- `status: 0` → deploy succeeded. Print `result.numberComponentsDeployed` and `result.id` (the AsyncResult Id, useful for Setup > Deployment Status lookups).
- Any other `status` → deploy failed after dry-run passed. This is unusual (dry-run normally catches failures) but can happen with rollbacks or race conditions. Print `result.details.componentFailures[*]` verbatim. **Halt** with:

  > Deploy failed in `brite-staging` despite dry-run passing. Inspect the errors above and check `Setup > Deployment Status` in the sandbox. Apex tests were not attempted.

  Do **not** continue to Phase 4.

Narrate: `Phase 3/6: Actual sandbox deploy... done`

---

## Phase 4 — Apex tests

Narrate: `Phase 4/6: Running Apex tests...`

Run:

```bash
sf apex run test --target-org brite-staging --wait 10 --json
```

Parse the JSON. Report to the user:

- `result.summary.outcome` (e.g., `Passed`, `Failed`)
- `result.summary.testsRan`, `result.summary.passing`, `result.summary.failing`
- `result.summary.testTotalTime` (human-readable duration)
- `result.summary.testRunCoverage` if present

If `outcome` is not `Passed`, list `result.tests[*]` entries where `Outcome` != `Pass` — include `FullName`, `Message`, and `StackTrace` for each failure. Do **not** halt — failing Apex tests are a reportable state but Phase 5 (manual verification) can still proceed; the user may have deliberately deployed a broken test they want to debug in the sandbox UI. If tests failed, append a warning:

> ⚠️ Apex tests failed. The sandbox deploy landed, but tests did not pass. Continue to Phase 5 only if you're deliberately investigating failures.

Narrate: `Phase 4/6: Running Apex tests... done`

---

## Phase 5 — Manual browser verification

Narrate: `Phase 5/6: Manual browser verification...`

The sandbox deploy has landed and tests have run. Some classes of defect are only observable in the Lightning UI — cached flexipage definitions, Kanban Group By cache (BC-4734), IndexedDB staleness, Dynamic Forms FLS paths. Ask the user to verify manually.

Tell the user:

> Open the sandbox in your browser and verify any UI that the deploy touched. Work through each section that applies to what you just deployed.
>
> ---
>
> ### 1. Flexipage changes
>
> **Symptom:** Page still shows the old layout after deploy — hard-refresh (`Cmd+Shift+R`) didn't help.
>
> **Why it happens:** Lightning caches flexipage definitions in IndexedDB (`actions` database). A hard-refresh clears the HTTP cache but not IndexedDB. The stale definition persists until the DB is cleared or you log out/in.
>
> **Fix (fastest) — clear IndexedDB via DevTools:**
> 1. Open the sandbox page that looks wrong.
> 2. Open Chrome DevTools (`Cmd+Option+I`) → **Application** tab → **Storage** → **IndexedDB** → `actions`.
> 3. Right-click `actions` → **Delete database**, or run in the Console tab: `indexedDB.deleteDatabase("actions")`
> 4. Hard-refresh (`Cmd+Shift+R`). The page re-fetches the definition from the server.
>
> **Fix (alternative) — log out/in:**
> 1. Click your avatar (top-right) → **Log Out**.
> 2. Log back in. Session re-init clears the IndexedDB state.
>
> ---
>
> ### 2. Kanban Group By dropdown
>
> **Symptom:** A new picklist field you deployed doesn't appear as an option in the Kanban **Group By** dropdown.
>
> **Why it happens:** Salesforce caches the list of fields eligible for Kanban grouping server-side. A new picklist field isn't added to that cache until it appears on at least one page layout for the object — the layout assignment is the cache invalidation trigger.
>
> **Fix:**
> 1. In the sandbox: **Setup → Object Manager → [Object] → Page Layouts → [any layout] → Edit**.
> 2. Drag the new picklist field onto the layout anywhere (it doesn't need to stay there permanently).
> 3. **Save** the layout.
> 4. Re-deploy: `sf project deploy start --source-dir force-app --target-org brite-staging --json`
> 5. Return to the Kanban view — the field should now appear in Group By.
>
> ---
>
> ### 3. Dynamic Forms — custom fields not rendering
>
> **Symptom:** A custom field you deployed is missing from a record page that uses Dynamic Forms, even when logged in as a System Administrator.
>
> **Why it happens:** Dynamic Forms respects FLS (Field-Level Security) even for System Administrators when `runInMode` is `SystemModeWithoutSharing` or the page is component-driven. A field with no FLS grant on any permission set won't render in Dynamic Forms.
>
> **Fix:**
> 1. Identify which permission sets need access. Per `brite-salesforce/CLAUDE.md` §Permissions, find sets via:
>    ```bash
>    grep -l "{Object}\." force-app/main/default/permissionsets/*.permissionset-meta.xml
>    ```
>    Exclude migration-scoped / one-time sets (e.g. `HubSpot_Migration`).
> 2. Add `<fieldPermissions>` to each relevant permset XML:
>    ```xml
>    <fieldPermissions>
>        <editable>true</editable>
>        <field>ObjectName__c.FieldName__c</field>
>        <readable>true</readable>
>    </fieldPermissions>
>    ```
> 3. Re-deploy, then hard-refresh the record page.
>
> ---
>
> ### 4. Screen Flows — not running after deploy
>
> **Symptom:** A screen flow you deployed doesn't launch, or the Launch button is missing.
>
> **Why it happens:** Salesforce deploys flows as **Draft** status by default, even if the source XML has `<status>Active</status>`. The deploy always resets to Draft on first land.
>
> **Fix:**
> 1. In the sandbox: **Setup → Flows → [Flow Name]**.
> 2. Click **Activate** (top-right of the flow detail page).
> 3. Confirm — the flow status changes to **Active**.
>
> If the flow was previously active in the sandbox and this deploy is an update (not a first deploy), it will have been deactivated. Re-activate the same way.
>
> **Note:** Record-triggered flows (`RecordAfterSave`, `RecordBeforeSave`) are also deployed as Draft. Same fix applies.

Ask via `AskUserQuestion`:

- Question: `Did the sandbox verify cleanly?`
- Options:
  - `Verified` — all sandbox UI behaves as expected. Narrate `Phase 5/6: Manual browser verification... done` and proceed to Phase 6.
  - `Not yet` — user hasn't had a chance to look. Print: *"Sandbox deploy + tests complete. Verification pending. Re-run any sanity checks manually; `/revops:deploy-prod` should wait until verification is done."* Skip Phase 6 finish summary and exit with this advisory.
  - `Failed verification` — something is broken in the sandbox UI. Print: *"Deploy landed in sandbox, but verification failed. Inspect the failing UI, file a rollback issue if needed, and do NOT run `/revops:deploy-prod` on this change."* Exit with this advisory.

---

## Phase 6 — Completion

Narrate: `Phase 6/6: Completion...`

Print the summary:

- `✓ Pre-flight passed`
- `✓ Dry-run passed ({N} components)`
- `✓ Sandbox deploy succeeded (deploy id: {id})`
- `✓ Apex tests: {outcome} ({passing}/{testsRan}, {duration})`
- `✓ Manual verification: Verified`

Then the next-step hint:

> Sandbox is green. Next step options:
>
> - `/workflows:review` — run review agents against the diff before opening a PR
> - `/workflows:ship` — push branch and open the PR
> - `/revops:deploy-prod` — after PR merge, deploy the same change to production

Narrate: `Phase 6/6: Completion... done`

---

## Rules

- **Never skip a gate.** Every mutating phase (2, 3) is preceded by an explicit `AskUserQuestion` confirm. A user response other than the "proceed" option halts the command.
- **Always pass `--target-org brite-staging`.** Never rely on the default org for this command — behavior must be reproducible across machines.
- **Parse `--json` output, not stdout strings.** Parsing the human-readable text is fragile; Salesforce CLI's JSON envelope is stable across 2.x versions.
- **`sf`, not `sfdx`.** Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **Do not retry on failure.** If any `sf` invocation fails, surface the raw output and halt. Silent retries mask real issues.
- **Do not automate browser verification.** Phase 5 is intentionally manual — the user is the sensor.
