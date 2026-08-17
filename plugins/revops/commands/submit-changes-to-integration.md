---
disable-model-invocation: true
description: Submit your verified Salesforce change to the shared integration org by opening a PR into the `integration` branch — the only way changes reach `brite-integration`. Runs the local pre-flight (clean tree, dev-org verification done, .forceignore check), pushes the branch, opens the PR, then points at the CI run. Use after `/revops:preview-changes` is green. New in ADR-026.
argument-hint: [--draft] [--title "<pr title>"]
allowed-tools: Bash, AskUserQuestion
---

<!-- eval-waiver: Git and GitHub orchestrator: it reads live git state, runs the .forceignore pre-flight against a real working tree, gates on AskUserQuestion, then shells git push and gh pr create against the live brite-salesforce remote and reports the CI run that results. Every phase depends on live host, git, and GitHub state, and the artifact is a real PR, so there is no hermetically fixturable decide()-to-artifact core. -->

# /revops:submit-changes-to-integration

Get a change from "green in my own dev org" to "opened as a PR into `integration`," which is how it reaches the shared `brite-integration` org.

**You do not deploy to integration. CI does, on merge.** That is the whole point of the lane: one org, one source of truth, one deployer. A laptop deploy to `brite-integration` is refused by policy — see [`../config/org-aliases.json`](../config/org-aliases.json) and the brite-salesforce deploy-policy hook ([BC-19519](https://linear.app/brite-nites/issue/BC-19519)).

Execute the phases below sequentially. Use `AskUserQuestion` at each gate. **One question at a time** — never batch gate questions.

Out of scope: the inner-loop deploy (use `/revops:preview-changes` first), the production ship (use `/revops:push-to-production` after the change has been through integration and merged to `main`), and reviewing your own diff (use `/workflows:review`).

This command is new in [ADR-026](../../../docs/decisions/026-revops-promotion-topology.md). It replaces the informal "run `/workflows:ship` and hope the base branch is right" step.

---

## Phase 1 — Pre-flight

Narrate: `Phase 1/4: Pre-flight checks...`

### 1.1 Confirm cwd is an SFDX project

```bash
test -f sfdx-project.json && echo "SFDX_PROJECT_OK" || echo "NOT_SFDX"
```

- `SFDX_PROJECT_OK` → continue.
- `NOT_SFDX` → **halt**: *"Not in an SFDX project. Run this from the root of `brite-salesforce`."*

### 1.2 Confirm you are on a feature branch

```bash
git rev-parse --abbrev-ref HEAD
```

- A branch that is not `main`, `integration`, or `uat` → continue.
- `main`, `integration`, or `uat` → **halt** with:

  > You are on `{branch}`. Changes reach `integration` through a PR from a feature branch, never by committing to a long-lived branch directly. Create a branch for your change and re-run.

### 1.3 Confirm the working tree is clean

```bash
git status --porcelain
```

- Empty → continue.
- Any output → **halt.** Print it verbatim and say: *"Commit or stash before submitting — the PR ships what is committed, not what is in your editor."*

### 1.4 Confirm `gh` is authenticated

```bash
gh auth status 2>&1 && echo "GH_OK" || echo "GH_NOT_AUTHED"
```

- `GH_OK` → continue.
- `GH_NOT_AUTHED` → **halt**: *"Run `gh auth login`, then re-run."*

### 1.5 Confirm the `integration` branch exists

The base branch is the whole point of this command. Confirm it before offering to target it.

```bash
git fetch origin --quiet 2>&1
git ls-remote --heads origin integration 2>&1
```

- A ref is printed → continue.
- Empty output → **halt** with:

  > `origin/integration` does not exist. The integration lane is part of the brite-salesforce ADR-016 topology rollout; until the branch is created there is nowhere to submit to. Use `/revops:preview-changes` for inner-loop work and raise the gap in Linear.

### 1.6 `.forceignore` pre-flight (F1, BC-12347)

Narrate: `Phase 1.6/4: .forceignore pre-flight...`

Run the shared procedure in [`_shared/forceignore-preflight.md`](_shared/forceignore-preflight.md) with `RANGE` = the merge-base of `origin/integration` with `HEAD`:

```bash
MERGE_BASE=$(git merge-base origin/integration HEAD 2>&1) && RANGE="${MERGE_BASE}..HEAD"
```

If the merge-base cannot be computed, print the error and skip the pre-flight with a `WARN` — it is not worth blocking a PR over, and CI runs the mirrored check anyway.

Narrate: `Phase 1.6/4: .forceignore pre-flight... done`

### 1.7 Confirm the change was verified in a dev org

This is a question, not a probe. There is no reliable way to prove from the outside that a given commit was deployed to a given dev org, so ask rather than guess.

Ask via `AskUserQuestion`:

- Question: `Has this change been deployed and checked in your own dev org?`
- Options:
  - `Yes — /revops:preview-changes was green` — proceed to Phase 2.
  - `No — run it first` — **halt** cleanly. Print: *"Stopped before submitting. Run `/revops:preview-changes`, verify, then re-run this command."* Exit.
  - `No — this change cannot be deployed to a dev org` — proceed to Phase 2, and record the reason in the PR body. Some changes (org-wide settings, licence-gated features) genuinely cannot be. Say which, so the reviewer knows what was not checked.

Narrate: `Phase 1/4: Pre-flight checks... done`

---

## Phase 2 — Intent summary + gate

Narrate: `Phase 2/4: Intent summary...`

Collect:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git log origin/integration..HEAD --oneline
git diff origin/integration...HEAD --name-only --diff-filter=ACMRT | grep '^force-app/' || true
git diff origin/integration...HEAD --name-only --diff-filter=D | grep '^force-app/' || true
```

Show the user:

> Submitting to **integration**.
>
> - Branch: `{branch}` → base `integration`
> - Commits: {N}
> - Metadata paths changed: {N}
> - Metadata paths deleted: {N} — these need `destructiveChanges.xml` in the PR, or they will not be removed from the org.
> - Dev-org verification: {answer from 1.7}
>
> On merge, CI deploys this to `brite-integration`. Nothing deploys from this machine.

If any deletions were listed, ask whether `destructiveChanges.xml` is in the PR. A deletion that is not expressed there is a silent no-op — the file leaves git and the component stays in the org.

Ask via `AskUserQuestion`:

- Question: `Push the branch and open a PR into integration?`
- Options:
  - `Yes, open the PR` — proceed to Phase 3.
  - `No, stop here` — **halt** cleanly. Print: *"Stopped before pushing. Nothing was submitted."* Exit.

Narrate: `Phase 2/4: Intent summary... done`

---

## Phase 3 — Push and open the PR *(mutating)*

Narrate: `Phase 3/4: Pushing and opening the PR...`

### 3.1 Push the branch

```bash
git push --set-upstream origin "$(git rev-parse --abbrev-ref HEAD)" 2>&1
```

- Success → continue.
- Failure → **halt.** Print the raw output. Do not force-push, and do not retry.

### 3.2 Open the PR

```bash
gh pr create \
  --repo Brite-Nites/brite-salesforce \
  --base integration \
  --head "$(git rev-parse --abbrev-ref HEAD)" \
  --title "{title}" \
  --body "{body}" 2>&1
```

Use `--draft` if the user passed it. `{title}` comes from `--title` if given, otherwise the subject of the branch's first commit.

`{body}` states, plainly:

- What changed, in one or two sentences.
- Which dev org it was verified in, or why it could not be (from 1.7).
- Whether `destructiveChanges.xml` is included, if any paths were deleted.
- The Linear issue, if the branch name carries one.

If a PR already exists for this branch, `gh` says so. That is not an error — print the existing PR URL and continue to Phase 4.

Narrate: `Phase 3/4: Pushing and opening the PR... done`

---

## Phase 4 — Report + handoff

Narrate: `Phase 4/4: Completion...`

Print the summary:

- `✓ Pre-flight passed (feature branch, clean tree, integration base exists)`
- `✓ .forceignore pre-flight: no unexpected exclusions`
- `✓ Branch pushed`
- `✓ PR opened: {url}`

Then run the guidance layer:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/promotion_topology.py" --pipeline-guidance . --lane integration
```

If `decision` is `guidance`, name the configured next lane. If it is `no_config` or `unreadable`, print the default hint unchanged — the guidance layer no-ops where the config is absent (ADR-026 section 5). It guides; it never claims to enforce.

> PR is open against `integration`. Next:
>
> - Get it reviewed and merged. **CI deploys to `brite-integration` on merge** — you do not deploy it.
> - Watch the run: `gh run list --repo Brite-Nites/brite-salesforce --branch integration --limit 5`
> - Once integration is happy and the change reaches `main`, ship it with `/revops:push-to-production`.

Narrate: `Phase 4/4: Completion... done`

---

## Rules

- **This command never deploys.** No `sf project deploy start` appears in it and none may be added. Integration is CI-deployed; a laptop deploy to `brite-integration` is refused by policy.
- **Never skip a gate.** Every `AskUserQuestion` halt path must halt.
- **Never force-push.** A failed push is surfaced and halts. Rewriting a shared branch's history to make a push succeed is not a fix.
- **Deletions need `destructiveChanges.xml`.** Removing a file from git does not remove the component from the org. Phase 2 surfaces deletions so this cannot pass unnoticed.
- **Do not retry on failure.** Surface the raw output and halt.
- **brite-salesforce wins on convention conflicts.** Its `CLAUDE.md` defines branch and PR discipline; this command mirrors it.
