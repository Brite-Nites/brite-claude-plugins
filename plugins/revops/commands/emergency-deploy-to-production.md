---
disable-model-invocation: true
description: Last-resort production deploy for when the CI lane itself is unavailable — re-trigger CI first, and only if that is impossible, run a guarded local validate then quick-deploy against brite-prod. Requires a stated reason plus recorded acknowledgement from the other production admin, keeps every pre-flight including the blocking concurrency probe and the .forceignore guard, enforces Apex coverage, runs F2 verification, and leaves a written record. Use only when `/revops:push-to-production` cannot run. Formerly `/revops:deploy-prod --break-glass`.
argument-hint: --reason "<why CI cannot be used>" --second-admin <holdeeno|kells-source> --ack-url <https://evidence> [--override-concurrency]
allowed-tools: Bash, AskUserQuestion
---

<!-- eval-waiver: Guarded last-resort live-org deploy: it runs local git and .forceignore pre-flights, requires two-admin evidence, gates on three separate AskUserQuestion calls, then shells sf project deploy validate and sf project deploy quick against the real brite-prod org and invokes the repo's F2 verifier. Every phase depends on live host, git, and org state and the substance is the gated mutation sequence itself; deterministic receipt/coverage decisions are delegated to scripts/breakglass_deploy_guard.py and covered by tests/test_breakglass_deploy_guard.py, while concurrency verdicts remain in scripts/promotion_topology.py. -->

# /revops:emergency-deploy-to-production

The name is the warning. Read it before you run it.

`/revops:push-to-production` is the production lane. This command exists for the case where that lane itself is down — GitHub Actions is unavailable, the runner pool is dead, the workflow is broken — and production genuinely cannot wait for it.

**Order of preference, in order:**

1. **Fix the CI run and re-trigger it.** A failed run is not a broken lane. Re-triggering is Phase 1 of this command, and it is the outcome you should want.
2. **Wait.** An outage that will clear in an hour is not an emergency for most changes. Say out loud what breaks if you wait, and check whether that is actually true.
3. **This command's local path.** A guarded `validate` then `quick-deploy` against `brite-prod`, with every gate intact.

Per [ADR-026](../../../docs/decisions/026-revops-promotion-topology.md) section 4, the emergency path is **never unguarded**. F1 (the `.forceignore` pre-flight) and the blocking concurrency probe both run here exactly as they run in the normal lane. Skipping a check because the situation is urgent is how an outage becomes two outages.

Execute the phases below sequentially. **One question at a time** — never batch gate questions.

Legacy invocation `/revops:deploy-prod --break-glass` still resolves through the `deploy-prod` deprecation stub, which points here.

---

## Phase 0 — Require a reason and the other admin's acknowledgement

Narrate: `Phase 0: Recording the reason...`

`--reason "<text>"`, `--second-admin <holdeeno|kells-source>`, and `--ack-url <https://evidence>` are **all required**. If any is missing, **halt** with:

> `/revops:emergency-deploy-to-production` requires a reason, the other production admin's GitHub login, and a durable acknowledgement URL. This is a two-admin break-glass lane, not a faster single-admin deploy.

Require the reason to be one nonblank line of at most 500 characters. Read the
authenticated GitHub operator without trusting git config or a user-supplied login:

```bash
if ! OPERATOR=$(gh api user --jq .login 2>&1); then
  printf '%s\n' "$OPERATOR"
  echo "ERROR: cannot prove the authenticated GitHub operator."
  exit 2
fi
```

The only valid operator/second-admin pairs are `holdeeno` + `kells-source` in either order. The identities must differ. Any other operator, self-acknowledgement, or unrecognized second admin **halts**. Never interpolate acknowledgement contents as shell. Keep the reason, both identities, and URL for the Phase 3 ceremony and Phase 5 record.

The acknowledgement URL is narrower than a generic evidence link: require a
comment permalink matching
`^https://github\.com/Brite-Nites/brite-salesforce/(issues|pull)/[0-9]+#issuecomment-[0-9]+$`.
The comment body must use this exact structure, filled with the current values:

```text
BREAKGLASS-ACK
operator: <authenticated operator>
sha: <full lowercase main SHA>
reason: <exact one-line reason>
```

Then ask via `AskUserQuestion`:

- Question: `Have you tried re-running the CI workflow?`
- Options:
  - `Yes — CI is genuinely unavailable` — proceed to Phase 1.
  - `No — let me try that first` — **halt** cleanly. Print: *"Stopped. Re-trigger the run with `gh run rerun <id> --repo Brite-Nites/brite-salesforce`, or dispatch a fresh one with `/revops:push-to-production`. Come back only if that is impossible."* Exit.

---

## Phase 1 — Try CI one more time

Narrate: `Phase 1/5: Re-checking the CI lane...`

ADR-026 section 6 is explicit: the emergency path's first move is to re-trigger CI, staying inside the enforced lane. Check whether the lane is actually down before concluding it is.

```bash
gh workflow list --repo Brite-Nites/brite-salesforce --all --json name,path,state 2>&1
gh run list --repo Brite-Nites/brite-salesforce --workflow deploy-prod.yml --limit 5 \
  --json databaseId,status,conclusion,createdAt,headSha 2>&1
```

Interpret:

- **The workflow exists and is `active`, and recent runs are completing** — the lane is up. **Halt** with:

  > The CI production lane looks healthy: `deploy-prod.yml` is active and recent runs are completing. Use `/revops:push-to-production`. If a specific run failed, fix that failure — a failing run is not a broken lane.

- **The workflow exists but recent runs are queued forever, or `gh` cannot reach the API** — the lane is plausibly down. Print the evidence and continue to Phase 2.
- **The workflow does not exist** ([BC-19513](https://linear.app/brite-nites/issue/BC-19513) has not landed) — continue to Phase 2. There is no lane to use yet.

Narrate: `Phase 1/5: Re-checking the CI lane... done`

---

## Phase 2 — Pre-flight *(identical to the normal lane)*

Narrate: `Phase 2/5: Pre-flight checks...`

Nothing here is relaxed. These are the same checks `/revops:push-to-production` runs.

### 2.1 Confirm cwd is an SFDX project

```bash
test -f sfdx-project.json && echo "SFDX_PROJECT_OK" || echo "NOT_SFDX"
```

`NOT_SFDX` → **halt**: *"Run this from the root of `brite-salesforce`."*

### 2.2 Confirm branch is `main` and the tree is clean

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

- Branch is `main` and `git status --porcelain` is empty → continue.
- Otherwise → **halt.** Print what is wrong verbatim. An emergency deploy from a dirty tree or a feature branch ships something nobody reviewed, which is worse than the outage you are responding to.

### 2.3 Confirm local `main` matches the remote

```bash
git fetch origin main --quiet 2>&1
LOCAL=$(git rev-parse HEAD); REMOTE=$(git rev-parse origin/main)
[ "$LOCAL" = "$REMOTE" ] && echo "IN_SYNC $LOCAL" || echo "DIVERGED local=$LOCAL remote=$REMOTE"
```

`IN_SYNC` → store the full SHA as `{approved-sha}`. `DIVERGED` → **halt**: *"Local `main` and `origin/main` differ. Reconcile them before deploying — otherwise nobody can tell afterwards what actually shipped."*

### 2.4 Blocking concurrency probe

Run the shared procedure in [`_shared/concurrency-probe.md`](_shared/concurrency-probe.md) with `{target-org}` = `brite-prod` and `OVERRIDE` = `true` only if `--override-concurrency` was passed. Act on its verdict exactly as that file's table says.

**This probe blocks here too.** If CI is mid-deploy and merely appears stuck, a concurrent local deploy is the worst possible move. An in-flight verdict is not overridable in the emergency path either.

### 2.5 `.forceignore` pre-flight (F1, BC-12347)

Run the shared procedure in [`_shared/forceignore-preflight.md`](_shared/forceignore-preflight.md) with `SCOPE_MODE=diff` and `RANGE="main~1..main"`. Act on its result exactly as that file says.

ADR-026 section 4: the emergency path is never unguarded. A component silently dropped by `.forceignore` during an emergency deploy is a defect you will find days later, under worse conditions.

### 2.6 Verify the second-admin acknowledgement

After Phase 2.3 has fixed `{approved-sha}`, fetch the exact GitHub comment ID
from the already shape-validated permalink and let the deterministic guard bind
its author and structured body to this ceremony:

```bash
ACK_ID="${ACK_URL##*#issuecomment-}"
if ! gh api "repos/Brite-Nites/brite-salesforce/issues/comments/$ACK_ID" \
  > /tmp/revops-breakglass-ack.json; then
  cat /tmp/revops-breakglass-ack.json 2>/dev/null || true
  echo "ERROR: cannot read the second-admin acknowledgement."
  exit 2
fi

if ! ACK_GUARD_JSON=$( \
  ACK_OPERATOR="$OPERATOR" \
  ACK_SECOND_ADMIN="$SECOND_ADMIN" \
  ACK_URL="$ACK_URL" \
  ACK_REASON="$REASON" \
  ACK_SHA="{approved-sha}" \
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/breakglass_deploy_guard.py" \
    ack /tmp/revops-breakglass-ack.json 2>&1
); then
  printf '%s\n' "$ACK_GUARD_JSON"
  echo "ERROR: second-admin acknowledgement is absent, spoofed, or stale."
  exit 2
fi
printf '%s\n' "$ACK_GUARD_JSON"
```

Only `decision: ready` continues. A URL supplied by the operator is never proof
by itself; the fetched comment must be authored by `{second-admin}` and name the
exact operator, full SHA, and reason. A generic, edited-to-different-scope, or
earlier acknowledgement is not reusable; a generic or earlier approval is not reusable.

Narrate: `Phase 2/5: Pre-flight checks... done`

---

## Phase 3 — TRIPLE confirmation gate

Narrate: `Phase 3/5: Confirmation gates...`

Three separate `AskUserQuestion` calls. Never a single multi-option picker. The normal lane uses two; this path adds one, because it bypasses the enforced lane.

### 3.1 Gate A — the reason still holds

Show the reason from Phase 0, the full `{approved-sha}`, Phase 1's finding, the operator/second-admin pair, the acknowledgement URL, and Phase 2.6's `decision: ready` receipt. If the receipt is absent, **halt**; do not re-interpret the link manually.

- Question: `Your stated reason: "{reason}". Phase 1 found: {finding}. Does the reason still hold?`
- Options:
  - `Yes — proceed` — go to Gate B.
  - `No — use the CI lane` — **halt** cleanly: *"Stopped. Use `/revops:push-to-production`."* Exit.

### 3.2 Gate B — intent

- Question: `Deploy {short-sha} — "{commit-subject}" — to PRODUCTION from this laptop, bypassing CI?`
- Options:
  - `Yes, run the guarded local deploy` — go to Gate C.
  - `No, stop here` — **halt** cleanly: *"Stopped at Gate B. Nothing was deployed."* Exit.

### 3.3 Gate C — final confirmation

- Question: `This modifies the production Salesforce org outside the enforced lane. Confirm one more time.`
- Options:
  - `Confirm — deploy now` — proceed to Phase 4.
  - `Cancel — do not deploy` — **halt** cleanly: *"Canceled at final confirmation. Nothing was deployed."* Exit.

Narrate: `Phase 3/5: Confirmation gates... done` only after all three return proceed.

---

## Phase 4 — Recheck, validate, quick-deploy, then F2 verify *(mutating)*

Narrate: `Phase 4/5: Recheck, validate, quick-deploy, then F2 verify...`

Four steps, in this order, always. Recheck the approved SHA; `validate` runs the deploy and RunLocalTests against production without committing anything; `quick-deploy` then commits that already-validated result; the six-type F2 verifier reads the deployed components back from the org. Skipping a step is how an emergency deploy becomes an unmeasured partial state.

### 4.0 Recheck the approved commit

Immediately before the first org command, fetch `origin/main` again and require both local `HEAD` and remote `main` to equal `{approved-sha}`. Any command failure or mismatch **halts** and restarts the whole command from Phase 0; the other admin acknowledged a commit, not a moving branch.

```bash
git fetch origin main --quiet 2>&1
[ "$(git rev-parse HEAD)" = "{approved-sha}" ] && \
  [ "$(git rev-parse origin/main)" = "{approved-sha}" ]
```

### 4.1 Validate

```bash
set -euo pipefail
RANGE="main~1..main"

if ! RAW_CHANGED=$(git diff "$RANGE" --name-only --diff-filter=ACMRT 2>&1); then
  echo "ERROR: \`git diff $RANGE\` failed — output below."
  printf '%s\n' "$RAW_CHANGED"
  exit 2
fi
CHANGED=$(printf '%s\n' "$RAW_CHANGED" | grep '^force-app/' || true)

if [ -z "$CHANGED" ]; then
  echo "ERROR: No force-app/** files changed in $RANGE — nothing to deploy."
  exit 2
fi

# Coalesce multi-file LWC and Aura bundles to their bundle root — the metadata
# API treats the bundle as the deployable unit, so --source-dir on a single file
# inside one fails.
COALESCED=$(printf '%s\n' "$CHANGED" | awk -F/ '
  NF>=5 && $1=="force-app" && $2=="main" && $3=="default" && ($4=="lwc" || $4=="aura") {
    print $1"/"$2"/"$3"/"$4"/"$5; next
  }
  { print $0 }
' | sort -u)

echo "Resolved deploy targets from $RANGE ($(printf '%s\n' "$COALESCED" | wc -l | tr -d ' ') paths):"
printf '%s\n' "$COALESCED" | sed 's/^/  /'

# Array form so the argv expands under zsh too — the Bash tool runs zsh (BC-16872).
ARGS=()
while IFS= read -r p; do [ -n "$p" ] && ARGS+=(--source-dir "$p"); done <<< "$COALESCED"

if ! sf project deploy validate "${ARGS[@]}" \
  --target-org brite-prod \
  --test-level RunLocalTests \
  --json > /tmp/revops-breakglass-validate.json; then
  cat /tmp/revops-breakglass-validate.json
  echo "ERROR: production validation failed. Nothing was deployed."
  exit 2
fi
cat /tmp/revops-breakglass-validate.json

if printf '%s\n' "$CHANGED" | grep -Eq '^force-app/.*/(classes/.*\.cls|triggers/.*\.trigger)$'; then
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/breakglass_deploy_guard.py" \
    validate /tmp/revops-breakglass-validate.json \
    --require-apex-coverage --minimum-coverage 90 \
    | tee /tmp/revops-breakglass-validate-guard.json
else
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/breakglass_deploy_guard.py" \
    validate /tmp/revops-breakglass-validate.json \
    | tee /tmp/revops-breakglass-validate-guard.json
fi
```

The deterministic guard requires an explicit completed, successful, check-only result; positive and exactly reconciled component counts; explicit zero component/test errors; an explicit empty component-failure surface; and complete RunLocalTests totals with zero failures. When an Apex class or trigger changed, it additionally requires weighted code coverage of **at least 90%**; missing or malformed coverage blocks. Read the validated deploy ID from `/tmp/revops-breakglass-validate-guard.json` only after the guard exits zero.

- `decision: ready` → keep `deploy_id`. That validated-deploy ID is the input to 4.2, and it is only valid for a limited window. Report component count, test failures, and the coverage verdict.
- Any other result or non-zero helper exit → **halt**:

  > Validation failed against `brite-prod`. Nothing was deployed. Fix the errors above — the emergency path does not have a force option, because a deploy that fails validation would fail the same way in CI.

### 4.2 Quick-deploy

Only reached if 4.1's deterministic guard returned `decision: ready`.

```bash
set -euo pipefail
if ! sf project deploy quick \
  --job-id {validated-deploy-id} \
  --target-org brite-prod \
  --json > /tmp/revops-breakglass-deploy.json; then
  cat /tmp/revops-breakglass-deploy.json
  echo "ERROR: quick-deploy failed. Production may already have changed; do not retry."
  exit 2
fi
cat /tmp/revops-breakglass-deploy.json
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/breakglass_deploy_guard.py" \
  quick /tmp/revops-breakglass-deploy.json \
  | tee /tmp/revops-breakglass-deploy-guard.json
```

The deterministic quick-receipt guard requires top-level `status === 0`; an explicit completed, successful, non-check-only result; a trustworthy deploy ID; an explicit empty component-failure surface; zero component errors; and positive, exactly reconciled total/deployed counts:

- `decision: ready` → the deploy landed. Print `components_deployed` and `deploy_id`.
- Any other result or non-zero helper exit → print the receipt and **halt**:

  > Quick-deploy failed after validation passed. Production may be in a partial state — inspect `Setup > Deployment Status` in `brite-prod` immediately. Do not re-run this command until you understand what landed.

### 4.3 F2 read-back verification

The deploy response proves Salesforce accepted the package; it does not prove the deployed components are usable. Require the current Salesforce checkout to contain the reviewed BC-19514 verifier, then run it against the exact quick-deploy receipt:

```bash
set -euo pipefail
test -f scripts/ci/verify-deploy-components.js
node scripts/ci/verify-deploy-components.js \
  --deploy-result /tmp/revops-breakglass-deploy.json \
  --target-org brite-prod \
  --json | tee /tmp/revops-breakglass-f2.json
```

The verifier checks the six supported types from the completed deploy receipt and fails closed on incomplete queries or malformed result rows. Any non-zero exit means the deploy may have landed but F2 is unproven: **halt, preserve all three `/tmp/revops-breakglass-*` receipts, record the partial verification state, and do not retry or declare completion.** Flow activation remains separately blocked; F2 is not activation authority.

Narrate: `Phase 4/5: Recheck, validate, quick-deploy, then F2 verify... done`

---

## Phase 5 — Record and hand off

Narrate: `Phase 5/5: Completion...`

An emergency deploy that nobody writes down is an emergency deploy that happens again.

Print the record:

- `⚠ EMERGENCY PRODUCTION DEPLOY — bypassed the CI lane`
- `Reason: {reason}`
- `Operator: @{operator}`
- `Second admin: @{second-admin}`
- `Second-admin acknowledgement: {ack-url}`
- `CI lane state at Phase 1: {finding}`
- `Commit: {approved-sha} — {commit-subject}`
- `Concurrency probe: clear` (or `⚠ overridden — {N} recent deploy(s)`)
- `.forceignore pre-flight: {result}`
- `Validated: {validate-id} ({N} components)`
- `RunLocalTests: 0 failures; Apex coverage: {N}%` (or `N/A — no Apex changed`)
- `Deployed: {deploy-id} ({N} components)`
- `F2 six-type verification: passed ({verification receipt})`

Then tell the user, plainly:

> Three things still need doing, and only you can do them.
>
> 1. Run `/revops:run-manual-post-deploy-steps --production-breakglass` for the remaining manual steps. F2 verification ran above, but this path still skipped CI's activation stage ([BC-19514](https://linear.app/brite-nites/issue/BC-19514)), so Flow activation stays blocked pending a separate Kells/release-manager scope decision; the runbook will not turn a break-glass deploy into an implicit behavioral go-live.
> 2. File a Linear issue for whatever made CI unavailable. The lane being down is its own defect, separate from the change you just shipped.
> 3. Paste the record above into that issue and into the team channel.

Do **not** offer to skip any of the three.

Narrate: `Phase 5/5: Completion... done`

---

## Rules

- **CI first, always.** Phase 1 re-checks the lane and halts if it is healthy. This command is not a faster alternative to `/revops:push-to-production`; it is what you use when that is impossible.
- **Reason plus the other admin's acknowledgement are required.** Only `holdeeno` and `kells-source` can form the operator/second-admin pair; self-acknowledgement and generic evidence block.
- **Every guard still runs.** The concurrency probe blocks and fails closed; the `.forceignore` pre-flight runs. ADR-026 section 4: the emergency path is never unguarded.
- **Three gates, three separate `AskUserQuestion` calls.** A single multi-option picker is unacceptable.
- **Recheck the exact acknowledged SHA, then validate before quick-deploy, always.** There is no direct-deploy option here and none may be added.
- **Apex changes require RunLocalTests with zero failures and weighted coverage ≥90%.** Missing or malformed coverage blocks; the deterministic parser is `scripts/breakglass_deploy_guard.py`.
- **F2 read-back is part of break glass, not a follow-up.** Run `scripts/ci/verify-deploy-components.js` against the exact quick-deploy receipt. A failed verifier means partial/unproven completion, never success.
- **No force flags.** A validation failure halts. There is no override, because a change that fails validation locally would fail identically in CI.
- **Parse `--json` via `status === 0`.** Never `result.success` — it has changed shape across `sf` CLI 2.x versions.
- **Do not retry on failure.** Surface the raw output and halt. Silent retries during an incident are how partial state becomes unknowable state.
- **The record is not optional.** Phase 5 prints it and names the follow-ups; do not offer to skip them.
