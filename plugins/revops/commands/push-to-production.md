---
disable-model-invocation: true
description: Push a merged change to the production Salesforce org by dispatching and watching the brite-salesforce CI deploy workflow. Runs the local pre-flight ceremonies (clean tree, branch check, blocking concurrency probe, .forceignore pre-flight, intent summary), then hands the deploy itself to CI — this command never deploys from your laptop. Use after the PR is merged to `main`. Formerly `/revops:deploy-prod`.
argument-hint: [--override-concurrency] [--activation <plan|canary|apply>]
allowed-tools: Bash, AskUserQuestion
---

<!-- eval-waiver: CI-dispatch orchestrator: it runs local git and .forceignore pre-flights, gates on two separate AskUserQuestion calls, then shells `gh workflow run` and `gh run watch` against the live brite-salesforce Actions API and reports what CI did. Every phase depends on live host, git, org, and GitHub state; there is no decide()-to-artifact core here, because the two decisions that are pure — the concurrency verdict and the org classification — are already delegated to scripts/promotion_topology.py and covered by scripts/test_promotion_topology.sh. -->

# /revops:push-to-production

**This command does not deploy. CI does.**

brite-salesforce ADR-016 section 6, ratified further by Amendment E, retired the raw local production deploy. CI is the only normal path to `brite-prod`. What this command owns is everything around the deploy: the pre-flight checks that are cheapest to run on your laptop, the confirmation gates, the dispatch, and the watch.

Execute the phases below sequentially. Use `AskUserQuestion` at every gate so the user explicitly acknowledges state before any mutating step. If the user answers anything other than the proceed option, halt and surface the blocker — never re-run past phases silently.

**One question at a time.** Never batch gate questions.

## What moved where

| Concern | Before | Now |
|---|---|---|
| The deploy itself | `sf project deploy start --target-org brite-prod`, from a laptop | CI — `deploy-prod.yml` in brite-salesforce ([BC-19513](https://linear.app/brite-nites/issue/BC-19513)) |
| Apex coverage gate | Phase 5 here, parsing the local deploy envelope | CI, in the same job |
| Tooling API post-deploy verification | Phase 6 here | CI — flow activation + six-type verify ([BC-19514](https://linear.app/brite-nites/issue/BC-19514)) |
| Clean-tree / branch / intent checks | here | **still here** — cheapest correct layer |
| `.forceignore` pre-flight (F1) | here | **still here**, and mirrored as a CI step ([ADR-026](../../../docs/decisions/026-revops-promotion-topology.md) section 4) |
| Concurrency probe | advisory, failed open | **still here**, now blocking and failing closed |

Out of scope: inner-loop deploys (use `/revops:preview-changes`), promoting to integration (use `/revops:submit-changes-to-integration`), the break-glass path when CI itself is down (use `/revops:emergency-deploy-to-production`), manual post-deploy steps (use `/revops:run-manual-post-deploy-steps`), rollback automation.

Legacy name `/revops:deploy-prod` still resolves — it is a deprecation stub that points here.

> **Dependency.** This command dispatches `deploy-prod.yml`, which is built in brite-salesforce [BC-19513](https://linear.app/brite-nites/issue/BC-19513). Until that workflow exists, Phase 4 will halt at the workflow-presence check and tell you so. That is the intended behaviour: the plugin refuses to pretend a lane exists.

---

## Phase 0 — Invocation resolution

Inspect the invocation arguments:

- `--override-concurrency` — proceed past a *recent* prod deploy found by the Phase 0.5 probe. It does **not** clear an in-flight deploy.
- `--activation <plan|canary|apply>` — choose the post-deploy Flow-activation scope. Default: `plan` (read-only). `canary` activates only `Lead_Disqualify`; `apply` activates every eligible Flow and is a separate behavioral go-live decision.

Reject any other activation value before the concurrency probe. There is deliberately no `--ref`: the production workflow refuses every ref except `main`, and Phase 1.4 already proves local `main` equals `origin/main`.

There is no `--reconcile` here any more. Deploy scope is CI's decision now: the workflow computes it from the merge commit, so a scope flag on the laptop side would be a lie about who is in charge. If you need a full-tree prod reconcile, run the workflow directly with its own inputs and say why in the run notes.

Set `ACTIVATION=plan` unless the invocation explicitly selected `canary` or `apply`. Tell the user what will happen before Phase 1 starts:

> This command will run local pre-flight checks, then dispatch the `deploy-prod.yml` workflow from `main` in `Brite-Nites/brite-salesforce` with Flow activation mode `{ACTIVATION}` and watch the exact run it creates. No `sf` deploy runs on this machine.

---

## Phase 0.5 — Blocking concurrency probe

Narrate: `Phase 0.5: Checking for concurrent prod deploys...`

Run the shared procedure in [`_shared/concurrency-probe.md`](_shared/concurrency-probe.md) with `{target-org}` = `brite-prod` and `OVERRIDE` = `true` only if `--override-concurrency` was passed. Act on its verdict exactly as that file's table says.

The probe **blocks and fails closed**. Two prod deploys landing minutes apart without coordination is the failure this exists for ([BC-11037](https://linear.app/brite-nites/issue/BC-11037)); the old advisory version could not see a deploy that was in flight and read a Tooling API error as "all clear."

Dispatching CI while a prod deploy is already running is the same hazard as running two local deploys. CI's own concurrency group is the platform-side guard; this probe is the laptop-side one, and it gives the operator the answer before the dispatch rather than after.

Narrate: `Phase 0.5: Concurrency probe... clear`

---

## Phase 1 — Pre-flight

Narrate: `Phase 1/5: Pre-flight checks...`

### 1.1 Confirm cwd is an SFDX project

Run:

```bash
test -f sfdx-project.json && echo "SFDX_PROJECT_OK" || echo "NOT_SFDX"
```

- `SFDX_PROJECT_OK` → continue.
- `NOT_SFDX` → **halt** with this message:

  > Not in an SFDX project — no `sfdx-project.json` in the current directory. `/revops:push-to-production` must be run from the root of the `brite-salesforce` repo. `cd` into the repo and re-run.

  Do not continue. Do not prompt further.

### 1.2 Confirm current git branch is `main`

Run:

```bash
git rev-parse --abbrev-ref HEAD
```

- Output equals `main` → continue.
- Any other output → **halt** with:

  > Current branch is `{branch}`, not `main`. Production ships from `main` — check out `main` and pull first. CI deploys what is on `main`, so dispatching from a feature branch would ship something you have not reviewed.

  Do not continue.

### 1.3 Confirm working tree is clean

Run:

```bash
git status --porcelain
```

- Empty output → continue.
- Any output → **halt** with:

  > Working tree is not clean. Uncommitted changes on `main` mean your local view and the commit CI will deploy are not the same thing. Commit, revert, or stash before re-running `/revops:push-to-production`.

  Print the `git status --porcelain` output verbatim so the user can see what is dirty.

### 1.4 Confirm local `main` matches the remote

CI deploys the remote's `main`, not yours. If they differ, the intent summary you are about to approve describes the wrong commit.

Run:

```bash
git fetch origin main --quiet 2>&1
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
if [ "$LOCAL" = "$REMOTE" ]; then
  echo "IN_SYNC $LOCAL"
else
  echo "DIVERGED local=$LOCAL remote=$REMOTE"
  git log --oneline "$LOCAL".."$REMOTE" 2>/dev/null | sed 's/^/  remote-ahead: /'
  git log --oneline "$REMOTE".."$LOCAL" 2>/dev/null | sed 's/^/  local-ahead:  /'
fi
```

- `IN_SYNC` → continue.
- `DIVERGED` → **halt**. Print the divergence listing verbatim and:

  > Local `main` and `origin/main` differ. CI will deploy `origin/main`. Pull (or push) so the two agree, confirm which commit you actually mean to ship, then re-run.

### 1.5 Confirm `gh` is authenticated and new enough to return the created run URL

Run:

```bash
gh auth status 2>&1 && echo "GH_AUTH_OK" || echo "GH_NOT_AUTHED"
GH_VERSION="$(gh --version 2>/dev/null | awk 'NR == 1 { print $3 }')"
python3 - "$GH_VERSION" <<'PY'
import re
import sys

match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)(?:[-+].*)?", sys.argv[1])
if not match or tuple(map(int, match.groups())) < (2, 87, 0):
    raise SystemExit(1)
PY
if [ "$?" -eq 0 ]; then
  echo "GH_VERSION_OK $GH_VERSION"
else
  echo "GH_TOO_OLD ${GH_VERSION:-unknown}"
fi
```

- `GH_AUTH_OK` and `GH_VERSION_OK` → continue.
- `GH_NOT_AUTHED` → **halt** with:

  > `gh` is not authenticated, so this command cannot dispatch or watch the deploy workflow. Run `gh auth login`, then re-run `/revops:push-to-production`.

- `GH_TOO_OLD` → **halt** with:

  > `/revops:push-to-production` requires `gh` 2.87.0 or newer because that version returns the exact workflow-run URL created by `gh workflow run`. Upgrade `gh`, then re-run. Do not fall back to `gh run list`: selecting “the newest run” can attach to another operator's production deploy.

### 1.6 `.forceignore` pre-flight (F1, BC-12347)

Narrate: `Phase 1.6/5: .forceignore pre-flight...`

Run the shared procedure in [`_shared/forceignore-preflight.md`](_shared/forceignore-preflight.md) with `RANGE="main~1..main"` — the squash commit that just landed, per BC-6000 squash-merge discipline. Act on the result exactly as that file says.

CI runs the same check as a mirrored step. Running it here too is deliberate: it costs a second and it tells you *before* you dispatch, not five minutes into a run.

Narrate: `Phase 1.6/5: .forceignore pre-flight... done`

### 1.7 Confirm intent

Collect:

```bash
git rev-parse --short HEAD
git log -1 --pretty=format:'%s'
git log -1 --pretty=format:'%an'
```

Show the user a pre-flight summary:

> You are about to ship to **PRODUCTION** (`brite-prod`) — via CI.
>
> - Repo: `Brite-Nites/brite-salesforce`
> - Branch: `main` (in sync with `origin/main`)
> - Commit: `{short-sha}` — `{commit-subject}` (by `{author}`)
> - Flow activation: `{ACTIVATION}` (`plan` is read-only; `canary`/`apply` mutate Flow activation)
> - Working tree: clean
> - Concurrency probe: clear
> - `.forceignore` pre-flight: no unexpected exclusions
>
> Next: dispatch `deploy-prod.yml`. The deploy, the Apex coverage gate, and post-deploy verification all run in CI. Nothing deploys from this machine.

Ask via `AskUserQuestion`:

- Question: `Proceed to the production confirmation gate?`
- Options:
  - `Yes, continue` — proceed to Phase 2.
  - `No, stop here` — **halt** cleanly. Print: *"Stopped before the confirmation gate. Nothing was dispatched."* Exit.

Narrate: `Phase 1/5: Pre-flight checks... done`

---

## Phase 2 — DOUBLE confirmation gate

Narrate: `Phase 2/5: Double-confirmation gate...`

This phase issues **two separate** `AskUserQuestion` calls — never a single multi-option picker. The second confirmation must occur after the user has committed to the first.

### 2.1 Gate A — intent

Ask via `AskUserQuestion`:

- Question: `Dispatch the production deploy for {short-sha} — "{commit-subject}" — with Flow activation mode {ACTIVATION}?`
- Options:
  - `Yes, dispatch the prod deploy` — proceed to Gate B.
  - `No, stop here` — **halt** cleanly. Print: *"Stopped at Gate A. Nothing was dispatched."* Exit.

### 2.2 Gate B — final confirmation

Only reached if Gate A returned `Yes`. Ask via `AskUserQuestion`:

- Question: `This will modify the production Salesforce org. Confirm one more time.`
- Options:
  - `Confirm — dispatch now` — proceed to Phase 3.
  - `Cancel — do not dispatch` — **halt** cleanly. Print: *"Canceled at final confirmation. Nothing was dispatched."* Exit.

Narrate: `Phase 2/5: Double-confirmation gate... done` only after both gates return proceed.

---

## Phase 3 — Dispatch the CI workflow *(mutating)*

Narrate: `Phase 3/5: Dispatching deploy-prod.yml...`

### 3.1 Confirm the workflow exists

Never dispatch a name you have not confirmed. `gh workflow run` on a missing workflow fails in a way that is easy to misread as a permissions problem.

```bash
gh workflow list --repo Brite-Nites/brite-salesforce --all --json name,path,state 2>&1
```

Look for a workflow whose `path` ends in `deploy-prod.yml`.

- Present and `state` is `active` → continue.
- Absent → **halt** with:

  > `deploy-prod.yml` does not exist in `Brite-Nites/brite-salesforce`. It is built in [BC-19513](https://linear.app/brite-nites/issue/BC-19513). Until it lands there is no CI production lane to dispatch, and this command will not fall back to a local deploy — brite-salesforce ADR-016 section 6 retired that path. If production genuinely must move before then, use `/revops:emergency-deploy-to-production` and record why.

- Present but `disabled_manually` → **halt** and say so; someone disabled the lane on purpose, and finding out why comes first.

### 3.2 Dispatch and capture the exact created run

```bash
RUN_URL="$(gh workflow run deploy-prod.yml \
  --repo Brite-Nites/brite-salesforce \
  --ref main \
  --raw-field mode=deploy \
  --raw-field confirm=DEPLOY-PROD \
  --raw-field activation="$ACTIVATION" 2>&1)"
DISPATCH_STATUS=$?
printf '%s\n' "$RUN_URL"
```

- Non-zero `DISPATCH_STATUS` → **halt.** Print the raw output. Common causes: no `workflow_dispatch` trigger on the workflow, or the token lacks `actions:write` on the repo. Do not retry.
- Exit 0 and `RUN_URL` exactly matches `https://github.com/Brite-Nites/brite-salesforce/actions/runs/{numeric-id}` → set `RUN_ID` to that final numeric path segment and continue.
- Exit 0 but the output is not exactly that URL → **halt** with the raw output. The dispatch may have succeeded, so **do not re-dispatch**. Open the Actions tab and reconcile manually.

Do not call `gh run list` to resolve the run. The returned URL is the dispatch receipt; a “newest matching run” query is ambiguous when two authorized operators dispatch the same `main` SHA close together.

Narrate: `Phase 3/5: Dispatching deploy-prod.yml... done (run {id})`

---

## Phase 4 — Watch the run

Narrate: `Phase 4/5: Watching run {id}...`

```bash
gh run watch {run-id} --repo Brite-Nites/brite-salesforce --exit-status 2>&1
```

`--exit-status` makes the exit code carry the run's conclusion, so success is not something you have to infer from scraped text.

- Exit 0 → the run succeeded. Continue to Phase 5.
- Non-zero → the run failed, was cancelled, or timed out. Fetch the detail:

  ```bash
  gh run view {run-id} --repo Brite-Nites/brite-salesforce --log-failed 2>&1 | tail -100
  ```

  **Halt** with:

  > The production deploy run failed. Production may be in a partial state depending on how far the deploy progressed — check `Setup > Deployment Status` in `brite-prod` now. Do not re-run `/revops:push-to-production` until you understand what landed. The failing job's log tail is above; the full run is at {url}.

If the watch itself drops (network, timeout) rather than the run failing, say which happened. Re-attach with `gh run watch` — that is a read and is always safe. Never re-dispatch to "check".

Narrate: `Phase 4/5: Watching run {id}... done`

---

## Phase 5 — Report + handoff

Narrate: `Phase 5/5: Completion...`

Read the run's job summary so the report describes what CI actually did, not what you assume it does:

```bash
gh run view {run-id} --repo Brite-Nites/brite-salesforce --json conclusion,jobs,displayTitle,url 2>&1
```

Print the summary:

- `✓ Pre-flight passed (branch=main, in sync, clean tree, intent confirmed)`
- `✓ Concurrency probe: clear` (or `⚠ overridden — {N} recent deploy(s)`)
- `✓ .forceignore pre-flight: no unexpected exclusions`
- `✓ Dispatched deploy-prod.yml @ {short-sha} (run {id})`
- `✓ Flow activation mode: {ACTIVATION}`
- `✓ CI run conclusion: {conclusion}`
- One line per CI job with its conclusion — including the coverage gate and the post-deploy verification job, which is where those checks now live ([BC-19514](https://linear.app/brite-nites/issue/BC-19514)).

If the run's output reports Flows deployed as Draft, surface that list here verbatim. It is the one post-deploy result that still needs a human.

Then run the guidance layer:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/promotion_topology.py" --pipeline-guidance . --lane production
```

If `decision` is `guidance`, use the config's lane names in the hint below. If it is `no_config` or `unreadable`, print the default hint unchanged — the guidance layer no-ops where the config is absent, by design (ADR-026 section 5). Never present it as a gate.

> Production deploy landed via CI. **Next: run `/revops:run-manual-post-deploy-steps`** for the steps `sf` cannot automate:
>
> - Screen Flow activation (flagged above if any)
> - Scheduled Apex re-schedule (if Apex jobs were redeployed)
> - Named Credential URL refresh (per prod org)
> - Kanban / page layout cache flush (if new picklist values landed on standard objects)

Narrate: `Phase 5/5: Completion... done`

---

## Rules

- **This command never deploys.** There is no `sf project deploy start` in it and none may be added. If CI is unavailable, that is not a reason to fall back locally — it is the reason `/revops:emergency-deploy-to-production` exists, with its own gates and its own record.
- **Never skip a gate.** Every `AskUserQuestion` halt path must halt — no silent continuation.
- **Phase 2 gates are two separate `AskUserQuestion` calls.** A single multi-option picker is unacceptable.
- **The Phase 0.5 probe blocks.** A `blocked_*` verdict halts the command. `--override-concurrency` clears a recent deploy and nothing clears an in-flight one.
- **Confirm the workflow exists before dispatching.** A missing `deploy-prod.yml` halts; it never degrades into a local deploy.
- **Dispatch `main` only, with every required input.** Always pass `mode=deploy`, `confirm=DEPLOY-PROD`, and the explicit `activation` mode. Never accept an arbitrary SHA or feature-branch ref.
- **Use the exact run URL returned by `gh workflow run`.** Require `gh >= 2.87.0`; never guess the run with `gh run list`.
- **Never re-dispatch to check on a run.** Re-attaching with `gh run watch` is a read and is safe. A second dispatch is a second deploy.
- **Read the run's conclusion, do not infer it.** `--exit-status` and the `conclusion` field are the contract; scraped log text is not.
- **`sf`, not `sfdx`,** for the read-only probes this command still makes. Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **Do not retry on failure.** Any `gh` or `sf` invocation that fails surfaces the raw output and halts. Silent retries mask real issues.
- **brite-salesforce wins on convention conflicts.** Its `CLAUDE.md` and ADR-016 define deploy discipline; this command mirrors them. When the two disagree, this file is what is stale.
