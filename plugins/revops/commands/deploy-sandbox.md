---
description: Sandbox deploy orchestration for brite-salesforce — pre-flight, dry-run, deploy, Apex tests, manual browser verification. Use when you've completed SF metadata changes and want to validate in `brite-sandbox` before opening a PR. Fills the gap between `/workflows:review` and `/workflows:ship` that SF-specific ship discipline requires.
argument-hint: [--reconcile]
allowed-tools: Bash, AskUserQuestion
---

# /revops:deploy-sandbox

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered gate so the user explicitly acknowledges the state before any mutating step. If the user answers anything other than the proceed option, halt and surface the blocker — do not re-run past phases silently.

**One question at a time.** Never batch gate questions.

Canonical invocation pattern comes from `brite-salesforce/CLAUDE.md` §Commands + §Development Flow §2. Sandbox alias is `brite-sandbox`. Always pass `--target-org` explicitly — never rely on a default org. Always use `sf`, never legacy `sfdx`.

**Deploy scope.** Defaults to feature-branch-diff-scoped `--source-dir` (computed from `git diff $(git merge-base origin/main HEAD)..HEAD`) to avoid Flow Draft pile-up and unrelated drift surprises — see [BC-11030](https://linear.app/brite-nites/issue/BC-11030). Pass `--reconcile` to opt into full-tree behavior for explicit drift sync (sandbox-refresh hydration, first-run on a long-paused feature branch, mass drift audit). When run from `main` itself the diff range falls back to `main~1..main`.

Out of scope for this command: prod deploy (use `/revops:deploy-prod`), post-deploy manual runbook (use `/revops:post-deploy-runbook`), automating browser verification.

---

## Phase 0 — Deploy-mode resolution

Inspect the invocation arguments. The command supports one optional positional flag:

- `--reconcile` — opt into the legacy full-tree deploy (`--source-dir force-app`). Documented use cases: sandbox-refresh hydration, drift mass-fix, first-time deploy of a long-paused feature branch where you genuinely want every component re-evaluated.

If `--reconcile` is in the invocation, set deploy mode to `reconcile` for the rest of the run and skip the diff resolution in Phase 2.1. Otherwise the deploy mode is `branch-diff`, and the bash blocks in Phase 2 / Phase 3 compute the `--source-dir` set from the feature branch diff vs `origin/main`.

Tell the user which mode is active before Phase 1 starts:

> Mode: `branch-diff` — deploying only paths changed on this branch since `origin/main`. Pass `--reconcile` to deploy the full tree.

or, if `--reconcile` was passed:

> Mode: `reconcile` — deploying the full `force-app/` tree to `brite-sandbox`. This will create Draft versions of every Flow in source and may incidentally redeploy any source-vs-sandbox drift. Use only when you intend exactly that.

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

- Question: `Deploy to brite-sandbox?`
- Options:
  - `Yes, brite-sandbox` — proceed to Phase 2.
  - `No, pick a different alias` — halt. Tell the user: *"This command pins `brite-sandbox` by design (from `brite-salesforce/CLAUDE.md` §Development Flow). If you need a different sandbox, run the `sf` commands manually or open an issue to parameterize this command."*

Narrate: `Phase 1/6: Pre-flight checks... done`

---

## Phase 2 — Dry-run deploy

Narrate: `Phase 2/6: Dry-run deploy...`

### 2.1 Resolve deploy scope

The deploy invocation is assembled from the Phase 0 mode. Run **one** of the two blocks below.

**Mode `reconcile`** (full-tree, opt-in):

```bash
sf project deploy start --source-dir force-app --dry-run --target-org brite-sandbox --json
```

**Mode `branch-diff`** (default — compute `--source-dir` set from this branch's diff vs `origin/main`):

```bash
set -e

# Resolve diff range. On a feature branch (the normal case), use the
# merge-base with origin/main so we capture every commit the branch added.
# If we somehow run from main itself (e.g., post-merge sanity re-deploy),
# fall back to the single squash commit on main.
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "main" ]; then
  RANGE="main~1..main"
else
  # origin/main must be reachable. If the user hasn't fetched recently,
  # this could be stale — surface that.
  if ! git rev-parse --verify origin/main >/dev/null 2>&1; then
    echo "ERROR: origin/main not found in this clone — run \`git fetch origin main\` first."
    exit 2
  fi
  # Capture merge-base exit status separately. If there's no common
  # ancestor (orphaned branch, shallow clone where ancestor isn't fetched),
  # bare command substitution would leave RANGE="..HEAD" — a malformed
  # range that silently behaves like an empty diff downstream.
  if ! MERGE_BASE=$(git merge-base origin/main HEAD 2>&1); then
    echo "ERROR: \`git merge-base origin/main HEAD\` failed — output below."
    printf '%s\n' "$MERGE_BASE"
    echo "Is origin/main fetched and reachable from HEAD? (A shallow clone"
    echo "may need \`git fetch --unshallow origin main\`.)"
    exit 2
  fi
  RANGE="${MERGE_BASE}..HEAD"
fi

# Capture `git diff` exit status separately from the grep filter — without
# this split, a git failure would propagate as an empty diff and the script
# would mis-route the operator to --reconcile.
if ! RAW_CHANGED=$(git diff "$RANGE" --name-only --diff-filter=ACMRT 2>&1); then
  echo "ERROR: \`git diff $RANGE\` failed — output below."
  printf '%s\n' "$RAW_CHANGED"
  exit 2
fi
if ! RAW_DELETED=$(git diff "$RANGE" --name-only --diff-filter=D 2>&1); then
  echo "ERROR: \`git diff $RANGE --diff-filter=D\` failed — output below."
  printf '%s\n' "$RAW_DELETED"
  exit 2
fi

# --diff-filter=ACMRT excludes deletions (D) — sf can't deploy a path
# that no longer exists. True deletions must be handled via
# destructiveChanges.xml — surface them but don't try to deploy them.
CHANGED=$(printf '%s\n' "$RAW_CHANGED" | grep '^force-app/' || true)
DELETED=$(printf '%s\n' "$RAW_DELETED" | grep '^force-app/' || true)

if [ -z "$CHANGED" ]; then
  echo "ERROR: No force-app/** files changed in $RANGE — nothing to deploy."
  echo "If you intended to reconcile drift, re-run: /revops:deploy-sandbox --reconcile"
  exit 2
fi

# Coalesce multi-file LWC and Aura bundles to their bundle root —
# sf project deploy start --source-dir on a single LWC file fails because
# the metadata API treats the bundle as the deployable unit. Custom-object
# sub-files (objects/Foo__c/fields/Bar__c.field-meta.xml) are file-level
# deployable, so we leave them as-is.
COALESCED=$(printf '%s\n' "$CHANGED" | awk -F/ '
  NF>=5 && $1=="force-app" && $2=="main" && $3=="default" && ($4=="lwc" || $4=="aura") {
    print $1"/"$2"/"$3"/"$4"/"$5; next
  }
  { print $0 }
' | sort -u)

echo "Resolved deploy targets from $RANGE ($(printf '%s\n' "$COALESCED" | wc -l | tr -d ' ') paths):"
printf '%s\n' "$COALESCED" | sed 's/^/  /'

if [ -n "$DELETED" ]; then
  echo
  echo "WARNING: $(printf '%s\n' "$DELETED" | wc -l | tr -d ' ') deletion(s) detected — NOT included in --source-dir."
  echo "Metadata deletions must be expressed via destructiveChanges.xml in the PR."
  echo "Deleted paths:"
  printf '%s\n' "$DELETED" | sed 's/^/  /'
fi

ARGS=$(printf '%s\n' "$COALESCED" | sed 's/^/--source-dir /' | tr '\n' ' ')

# shellcheck disable=SC2086  # word-splitting is intentional here
sf project deploy start $ARGS --dry-run --target-org brite-sandbox --json
```

If any deletions were surfaced above, decide before continuing: do they belong in this deploy via `destructiveChanges.xml`? If yes, fold the destructive manifest in and re-run. If no (e.g., the file was moved/renamed and the new path is in the deploy set), continue.

### 2.2 Parse response

Parse the JSON response. Treat top-level `status === 0` as success (the stable cross-version exit-code field):

- `status: 0` → dry-run passed. Extract `result.numberComponentsTotal`, `result.numberComponentsDeployed`, `result.numberTestsTotal` (if present). Report counts to the user.
- Any other `status` → dry-run failed. Print `result.details.componentFailures[*].problem` for each failure (or the raw JSON if the shape is unexpected). **Halt** with:

  > Dry-run failed in `brite-sandbox`. Fix the errors above locally, then re-run `/revops:deploy-sandbox`. No actual deploy was attempted.

  Do **not** continue to Phase 3 under any circumstances.

If dry-run passed, ask via `AskUserQuestion`:

- Question: `Dry-run passed ({N} components). Proceed to actual sandbox deploy?`
  - Substitute `{N}` with `numberComponentsTotal` from the dry-run response.
- Options:
  - `Yes, deploy to brite-sandbox` — proceed to Phase 3.
  - `No, stop here` — **halt** cleanly. Print: *"Stopped after dry-run. No deploy was attempted. Re-run `/revops:deploy-sandbox` when ready."* Exit.

Narrate: `Phase 2/6: Dry-run deploy... done`

---

## Phase 3 — Actual sandbox deploy

Narrate: `Phase 3/6: Actual sandbox deploy...`

Use the same deploy-mode branch chosen at Phase 0. Re-compute the `--source-dir` set in this phase (do not cache state across the Phase 2 confirmation gate — re-resolving from `git diff` keeps the deploy honest if the working tree changed unexpectedly).

**Mode `reconcile`** (same as Phase 2.1, without `--dry-run`):

```bash
sf project deploy start --source-dir force-app --target-org brite-sandbox --json
```

**Mode `branch-diff`** (same logic as Phase 2.1, without `--dry-run`):

```bash
set -e

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "main" ]; then
  RANGE="main~1..main"
else
  if ! git rev-parse --verify origin/main >/dev/null 2>&1; then
    echo "ERROR: origin/main not found in this clone — run \`git fetch origin main\` first."
    exit 2
  fi
  if ! MERGE_BASE=$(git merge-base origin/main HEAD 2>&1); then
    echo "ERROR: \`git merge-base origin/main HEAD\` failed at Phase 3 — output below."
    printf '%s\n' "$MERGE_BASE"
    exit 2
  fi
  RANGE="${MERGE_BASE}..HEAD"
fi

if ! RAW_CHANGED=$(git diff "$RANGE" --name-only --diff-filter=ACMRT 2>&1); then
  echo "ERROR: \`git diff $RANGE\` failed at Phase 3 — output below."
  printf '%s\n' "$RAW_CHANGED"
  exit 2
fi
CHANGED=$(printf '%s\n' "$RAW_CHANGED" | grep '^force-app/' || true)

if [ -z "$CHANGED" ]; then
  echo "ERROR: Re-resolved diff is empty at Phase 3 — refusing to deploy."
  echo "This indicates the working tree changed between Phase 2 and Phase 3."
  exit 2
fi

COALESCED=$(printf '%s\n' "$CHANGED" | awk -F/ '
  NF>=5 && $1=="force-app" && $2=="main" && $3=="default" && ($4=="lwc" || $4=="aura") {
    print $1"/"$2"/"$3"/"$4"/"$5; next
  }
  { print $0 }
' | sort -u)

ARGS=$(printf '%s\n' "$COALESCED" | sed 's/^/--source-dir /' | tr '\n' ' ')

# shellcheck disable=SC2086  # word-splitting is intentional here
sf project deploy start $ARGS --target-org brite-sandbox --json
```

Parse the JSON (same `status === 0` check as Phase 2):

- `status: 0` → deploy succeeded. Print `result.numberComponentsDeployed` and `result.id` (the AsyncResult Id, useful for Setup > Deployment Status lookups).
- Any other `status` → deploy failed after dry-run passed. This is unusual (dry-run normally catches failures) but can happen with rollbacks or race conditions. Print `result.details.componentFailures[*]` verbatim. **Halt** with:

  > Deploy failed in `brite-sandbox` despite dry-run passing. Inspect the errors above and check `Setup > Deployment Status` in the sandbox. Apex tests were not attempted.

  Do **not** continue to Phase 4.

Narrate: `Phase 3/6: Actual sandbox deploy... done`

---

## Phase 4 — Apex tests

Narrate: `Phase 4/6: Running Apex tests...`

Run:

```bash
sf apex run test --target-org brite-sandbox --wait 10 --json
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
> 4. Re-deploy the affected layout to flush the cache (scope to just the changed layout — Brite default is PR-diff-scoped, see [BC-11030](https://linear.app/brite-nites/issue/BC-11030)): `sf project deploy start --source-dir force-app/main/default/layouts/<Object>-<Layout>.layout-meta.xml --target-org brite-sandbox --json`
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
- **Always pass `--target-org brite-sandbox`.** Never rely on the default org for this command — behavior must be reproducible across machines.
- **Parse `--json` output, not stdout strings.** Parsing the human-readable text is fragile; Salesforce CLI's JSON envelope is stable across 2.x versions.
- **`sf`, not `sfdx`.** Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **Do not retry on failure.** If any `sf` invocation fails, surface the raw output and halt. Silent retries mask real issues.
- **Do not automate browser verification.** Phase 5 is intentionally manual — the user is the sensor.
