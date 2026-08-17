---
disable-model-invocation: true
description: Deploy your working branch to your own brite-dev-<name> Salesforce org and check it — pre-flight, dry-run, deploy, Apex tests, manual browser verification. Use when you've finished SF metadata changes and want to see them run before submitting to integration. Fills the gap between `/workflows:review` and `/workflows:ship` that SF-specific ship discipline requires. Formerly `/revops:deploy-sandbox`.
argument-hint: [--reconcile] [--target-org brite-dev-<name>] [--override-concurrency]
allowed-tools: Bash, AskUserQuestion
---

<!-- eval-waiver: Six-phase inner-loop deploy orchestrator that shells sf project deploy start and sf apex run test against the developer's live brite-dev-<name> org and gates each mutating phase on AskUserQuestion; the branch-diff resolver is deterministic but not a separable decide()-to-artifact core, and the value is the live deploy plus Apex-test plus manual-verification gating, which is host-state-dependent and not hermetically fixturable. The two decisions that ARE pure — dev-org resolution and the blocking concurrency verdict — are delegated to scripts/promotion_topology.py and covered by scripts/test_promotion_topology.sh. -->

# /revops:preview-changes

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered gate so the user explicitly acknowledges the state before any mutating step. If the user answers anything other than the proceed option, halt and surface the blocker — do not re-run past phases silently.

**One question at a time.** Never batch gate questions.

Canonical invocation pattern comes from `brite-salesforce/CLAUDE.md` §Commands + §Development Flow §2. Always pass `--target-org` explicitly — never rely on a default org. Always use `sf`, never legacy `sfdx`.

**Target org — read this first.** This command deploys to **the developer's own `brite-dev-<name>` org**, resolved at Phase 0.25. It no longer pins the shared `brite-sandbox`, which is retiring: inner-loop work moves to per-developer orgs and shared integration moves to `brite-integration` (alias `briteint`), reached by merging a PR, not by a laptop deploy. The full alias list lives in one file, [`../config/org-aliases.json`](../config/org-aliases.json), shared with the brite-salesforce deploy-policy hook. See [ADR-026](../../../docs/decisions/026-revops-promotion-topology.md).

**Deploy scope.** Defaults to feature-branch-diff-scoped `--source-dir` (computed from `git diff $(git merge-base origin/main HEAD)..HEAD`) to avoid Flow Draft pile-up and unrelated drift surprises — see [BC-11030](https://linear.app/brite-nites/issue/BC-11030). Pass `--reconcile` to opt into full-tree behavior for explicit drift sync (org-refresh hydration, first-run on a long-paused feature branch, mass drift audit). When run from `main` itself the diff range falls back to `main~1..main`.

Out of scope for this command: promoting to integration (use `/revops:submit-changes-to-integration`), prod deploy (use `/revops:push-to-production`), post-deploy manual runbook (use `/revops:run-manual-post-deploy-steps`), automating browser verification.

Legacy name `/revops:deploy-sandbox` still resolves — it is a deprecation stub that points here.

---

## Phase 0 — Deploy-mode resolution

Inspect the invocation arguments. The command supports three optional flags:

- `--reconcile` — opt into the full-tree deploy (`--source-dir force-app`). Documented use cases: org-refresh hydration, drift mass-fix, first-time deploy of a long-paused feature branch where you genuinely want every component re-evaluated.
- `--target-org brite-dev-<name>` — name your own dev org explicitly instead of letting Phase 0.25 resolve it. Only a `brite-dev-<name>` alias is accepted; anything else is rejected, not honoured.
- `--override-concurrency` — proceed past a *recent* deploy found by the Phase 0.5 probe. It does **not** clear an in-flight deploy.

If `--reconcile` is in the invocation, set deploy mode to `reconcile` for the rest of the run and skip the diff resolution in Phase 2.1. Otherwise the deploy mode is `branch-diff`, and the bash blocks in Phase 2 / Phase 3 compute the `--source-dir` set from the feature branch diff vs `origin/main`.

Tell the user which mode is active before Phase 1 starts:

> Mode: `branch-diff` — deploying only paths changed on this branch since `origin/main`. Pass `--reconcile` to deploy the full tree.

or, if `--reconcile` was passed:

> Mode: `reconcile` — deploying the full `force-app/` tree to your dev org. This will create Draft versions of every Flow in source and may incidentally redeploy any source-vs-org drift. Use only when you intend exactly that.

---

## Phase 0.25 — Resolve the target org

Narrate: `Phase 0.25: Resolving your dev org...`

This command deploys to the developer's own `brite-dev-<name>` org. It never picks one silently, and it never falls back to a shared org.

Run:

```bash
sf org list --json 2>/dev/null \
  | python3 "${CLAUDE_PLUGIN_ROOT}/scripts/promotion_topology.py" --resolve-dev-org - \
      ${REQUESTED:+--requested "$REQUESTED"}
```

Where `REQUESTED` is the value of `--target-org` if the user passed one, and unset otherwise.

Read the emitted JSON's `decision` field:

| `decision` | What you do |
|---|---|
| `resolved` | Use `alias` as `{dev-org}` for every remaining phase. Narrate which org was chosen. |
| `ambiguous` | Ask via `AskUserQuestion`, one option per entry in `candidates`, plus `Cancel`. **Never pick one yourself.** |
| `none` | **Halt.** No authenticated `brite-dev-<name>` org. Print the `reason` and point at `/revops:setup-dev-workspace`. |
| `rejected` | **Halt.** The requested alias is a protected/shared org. Print the `reason`; see the table below. |
| `unusable` | **Halt.** `sf org list` could not be read. Print the raw output and point at `/revops:check-environment-health`. |

For `ambiguous`, ask:

- Question: `You have {N} dev orgs authenticated. Which one should this deploy target?`
- Options: one per candidate alias, labelled `{alias} ({username})`, plus `Cancel — stop here`.
- `Cancel` → **halt** cleanly. Print: *"Stopped at org resolution. Nothing was deployed."*

For `rejected`, print this and stop:

> `{requested}` is not a per-developer org. `/revops:preview-changes` only targets `brite-dev-<name>`.
>
> - `brite-integration` / `briteint` — reached by merging a PR into the `integration` branch. Use `/revops:submit-changes-to-integration`.
> - `brite-uat` — promoted from integration; not yet wired (ADR-026 Phase 2).
> - `brite-prod` — CI only. Use `/revops:push-to-production`.
> - `brite-sandbox` — retiring. Move to your own `brite-dev-<name>` org; run `/revops:setup-dev-workspace`.

The resolved alias always matches `^brite-dev-[a-z0-9][a-z0-9-]*$`, so it is safe to interpolate into the `sf` invocations below. Substitute it for `{dev-org}` everywhere it appears.

Narrate: `Phase 0.25: Resolving your dev org... done ({dev-org})`

---

## Phase 0.5 — Blocking concurrency probe

Narrate: `Phase 0.5: Checking for concurrent deploys...`

Run the shared procedure in [`_shared/concurrency-probe.md`](_shared/concurrency-probe.md) with `{target-org}` = `{dev-org}` and `OVERRIDE` = `true` only if `--override-concurrency` was passed. Act on its verdict exactly as that file's table says.

This probe **blocks and fails closed**. It replaces the old advisory lookback, which explicitly told you to keep going when the query failed — so a Tooling API error read as "nobody else is deploying" ([BC-11037](https://linear.app/brite-nites/issue/BC-11037), ADR-026).

A dev org is your own, so a concurrent deploy is rarer here than in a shared org. It is not impossible: a CI job, a second terminal, or a teammate you lent access to all produce one, and the failure mode (two interleaved deploys, neither landing cleanly) is the same. The probe is the same in every lane on purpose.

Narrate: `Phase 0.5: Concurrency probe... clear`

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

  > Not in an SFDX project — no `sfdx-project.json` in the current directory. `/revops:preview-changes` must be run from the root of a Salesforce DX repo (e.g., `brite-salesforce`). `cd` into the repo and re-run.

  Do not continue. Do not prompt further.

### 1.2 Confirm the target org with the user

Phase 0.25 already resolved `{dev-org}` and proved it is a per-developer org. This gate confirms the choice out loud before anything mutates.

Ask via `AskUserQuestion`:

- Question: `Deploy to {dev-org}?`
- Options:
  - `Yes, {dev-org}` — proceed to Phase 1.3.
  - `No, pick a different org` — return to Phase 0.25 and re-run the resolution with an explicit `--requested`. If the user names a shared org, the resolver rejects it; surface that rejection rather than working around it.
  - `Stop here` — halt cleanly. Print: *"Stopped before pre-flight. Nothing was deployed."*

### 1.3 `.forceignore` pre-flight (F1, BC-12347)

Narrate: `Phase 1.3/6: .forceignore pre-flight...`

Run the shared procedure in [`_shared/forceignore-preflight.md`](_shared/forceignore-preflight.md). Act on its result exactly as that file says.

Set `RANGE` from the Phase 0 deploy mode:

- Mode `branch-diff` — the merge-base of `origin/main` with `HEAD`, or `main~1..main` when run from `main` itself.
- Mode `reconcile` — skip the whole pre-flight. Print `NOTE: reconcile mode — skipping .forceignore pre-flight.` and proceed to Phase 2.

Narrate: `Phase 1.3/6: .forceignore pre-flight... done`

Narrate: `Phase 1/6: Pre-flight checks... done`

---

## Phase 2 — Dry-run deploy

Narrate: `Phase 2/6: Dry-run deploy...`

### 2.1 Resolve deploy scope

The deploy invocation is assembled from the Phase 0 mode. Run **one** of the two blocks below.

**Mode `reconcile`** (full-tree, opt-in):

```bash
sf project deploy start --source-dir force-app --dry-run --target-org {dev-org} --json
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
  echo "If you intended to reconcile drift, re-run: /revops:preview-changes --reconcile"
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

# Array form (not word-split) so the argv expands under zsh too — the Bash tool runs zsh (BC-16872).
ARGS=()
while IFS= read -r p; do [ -n "$p" ] && ARGS+=(--source-dir "$p"); done <<< "$COALESCED"
sf project deploy start "${ARGS[@]}" --dry-run --target-org {dev-org} --json
```

If any deletions were surfaced above, decide before continuing: do they belong in this deploy via `destructiveChanges.xml`? If yes, fold the destructive manifest in and re-run. If no (e.g., the file was moved/renamed and the new path is in the deploy set), continue.

### 2.2 Parse response

Parse the JSON response. Treat top-level `status === 0` as success (the stable cross-version exit-code field):

- `status: 0` → dry-run passed. Extract `result.numberComponentsTotal`, `result.numberComponentsDeployed`, `result.numberTestsTotal` (if present). Report counts to the user.
- Any other `status` → dry-run failed. Print `result.details.componentFailures[*].problem` for each failure (or the raw JSON if the shape is unexpected). **Halt** with:

  > Dry-run failed in `{dev-org}`. Fix the errors above locally, then re-run `/revops:preview-changes`. No actual deploy was attempted.

  Do **not** continue to Phase 3 under any circumstances.

If dry-run passed, ask via `AskUserQuestion`:

- Question: `Dry-run passed ({N} components). Proceed to the actual deploy into {dev-org}?`
  - Substitute `{N}` with `numberComponentsTotal` from the dry-run response.
- Options:
  - `Yes, deploy to {dev-org}` — proceed to Phase 3.
  - `No, stop here` — **halt** cleanly. Print: *"Stopped after dry-run. No deploy was attempted. Re-run `/revops:preview-changes` when ready."* Exit.

Narrate: `Phase 2/6: Dry-run deploy... done`

---

## Phase 3 — Actual deploy to your dev org

Narrate: `Phase 3/6: Deploying to {dev-org}...`

Use the same deploy-mode branch chosen at Phase 0. Re-compute the `--source-dir` set in this phase (do not cache state across the Phase 2 confirmation gate — re-resolving from `git diff` keeps the deploy honest if the working tree changed unexpectedly).

**Mode `reconcile`** (same as Phase 2.1, without `--dry-run`):

```bash
sf project deploy start --source-dir force-app --target-org {dev-org} --json
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

# Array form so the argv expands under zsh too (BC-16872; see Phase 2 note).
ARGS=()
while IFS= read -r p; do [ -n "$p" ] && ARGS+=(--source-dir "$p"); done <<< "$COALESCED"
sf project deploy start "${ARGS[@]}" --target-org {dev-org} --json
```

Parse the JSON (same `status === 0` check as Phase 2):

- `status: 0` → deploy succeeded. Print `result.numberComponentsDeployed` and `result.id` (the AsyncResult Id, useful for Setup > Deployment Status lookups).
- Any other `status` → deploy failed after dry-run passed. This is unusual (dry-run normally catches failures) but can happen with rollbacks or race conditions. Print `result.details.componentFailures[*]` verbatim. **Halt** with:

  > Deploy failed in `{dev-org}` despite dry-run passing. Inspect the errors above and check `Setup > Deployment Status` in that org. Apex tests were not attempted.

  Do **not** continue to Phase 4.

Narrate: `Phase 3/6: Deploying to {dev-org}... done`

---

## Phase 4 — Apex tests

Narrate: `Phase 4/6: Running Apex tests...`

Run:

```bash
sf apex run test --target-org {dev-org} --wait 10 --json
```

Parse the JSON. Report to the user:

- `result.summary.outcome` (e.g., `Passed`, `Failed`)
- `result.summary.testsRan`, `result.summary.passing`, `result.summary.failing`
- `result.summary.testTotalTime` (human-readable duration)
- `result.summary.testRunCoverage` if present

If `outcome` is not `Passed`, list `result.tests[*]` entries where `Outcome` != `Pass` — include `FullName`, `Message`, and `StackTrace` for each failure. Do **not** halt — failing Apex tests are a reportable state but Phase 5 (manual verification) can still proceed; the user may have deliberately deployed a broken test they want to debug in the org UI. If tests failed, append a warning:

> ⚠️ Apex tests failed. The deploy landed, but tests did not pass. Continue to Phase 5 only if you're deliberately investigating failures.

Narrate: `Phase 4/6: Running Apex tests... done`

---

## Phase 5 — Manual browser verification

Narrate: `Phase 5/6: Manual browser verification...`

The deploy has landed in `{dev-org}` and tests have run. Some classes of defect are only observable in the Lightning UI — cached flexipage definitions, Kanban Group By cache (BC-4734), IndexedDB staleness, Dynamic Forms FLS paths. Ask the user to verify manually.

Tell the user to work through the sections in [`_shared/manual-ui-verification.md`](_shared/manual-ui-verification.md) that apply to what this deploy touched — flexipage cache, Kanban Group By, Dynamic Forms FLS, and Screen Flow activation. Present only the relevant ones; do not paste the whole catalogue for a two-field change.

Ask via `AskUserQuestion`:

- Question: `Did {dev-org} verify cleanly?`
- Options:
  - `Verified` — all UI behaves as expected. Narrate `Phase 5/6: Manual browser verification... done` and proceed to Phase 6.
  - `Not yet` — user hasn't had a chance to look. Print: *"Deploy + tests complete. Verification pending. Re-run any sanity checks manually; `/revops:push-to-production` should wait until verification is done."* Skip Phase 6 finish summary and exit with this advisory.
  - `Failed verification` — something is broken in the org UI. Print: *"Deploy landed in `{dev-org}`, but verification failed. Inspect the failing UI, file a rollback issue if needed, and do NOT run `/revops:push-to-production` on this change."* Exit with this advisory.

---

## Phase 6 — Completion

Narrate: `Phase 6/6: Completion...`

Print the summary:

- `✓ Pre-flight passed`
- `✓ Dry-run passed ({N} components)`
- `✓ Deploy to {dev-org} succeeded (deploy id: {id})`
- `✓ Apex tests: {outcome} ({passing}/{testsRan}, {duration})`
- `✓ Manual verification: Verified`

Then run the guidance layer and print the next-step hint.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/promotion_topology.py" --pipeline-guidance . --lane dev
```

If `decision` is `guidance`, name the configured next lane and the command that enters it. If `decision` is `no_config` or `unreadable`, print nothing extra — the guidance layer no-ops by design (ADR-026 section 5) and the default hint below still applies. Never present any of this as a gate; revops guides, the platform enforces.

> `{dev-org}` is green. Next step options:
>
> - `/workflows:review` — run review agents against the diff before opening a PR
> - `/revops:submit-changes-to-integration` — open the PR into `integration` so CI deploys it to `brite-integration`
> - `/revops:push-to-production` — later, once the change has been through integration and merged to `main`

Narrate: `Phase 6/6: Completion... done`

---

## Rules

- **Never skip a gate.** Every mutating phase (2, 3) is preceded by an explicit `AskUserQuestion` confirm. A user response other than the "proceed" option halts the command.
- **Only ever target a `brite-dev-<name>` org.** Phase 0.25 owns that decision and rejects every shared alias. Do not work around a rejection by editing the `sf` invocation by hand.
- **Never pick a dev org for the user.** An `ambiguous` verdict means ask. A silent default is the bug this command was rewritten to remove.
- **The Phase 0.5 probe blocks.** A `blocked_*` verdict halts the command. There is no gate question that converts it into a proceed; `--override-concurrency` is the only path past a *recent* deploy, and nothing clears an *in-flight* one.
- **Always pass `--target-org {dev-org}`.** Never rely on the default org for this command — behavior must be reproducible across machines.
- **Parse `--json` output, not stdout strings.** Parsing the human-readable text is fragile; Salesforce CLI's JSON envelope is stable across 2.x versions.
- **`sf`, not `sfdx`.** Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **Do not retry on failure.** If any `sf` invocation fails, surface the raw output and halt. Silent retries mask real issues.
- **Do not automate browser verification.** Phase 5 is intentionally manual — the user is the sensor.
