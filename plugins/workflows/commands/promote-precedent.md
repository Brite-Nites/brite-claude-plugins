---
description: Review and promote flagged decision traces from project precedents to the org-level handbook
disable-model-invocation: true
---

# Promote Precedent

You are reviewing decision traces that have been flagged for promotion to the org-level handbook. Promotion is the final step of the compound knowledge flywheel — high-value project-level decisions become searchable across ALL projects via `handbook/precedents/`.

## Phase 0: Prerequisites

Narrate: `Phase 0/7: Checking prerequisites...`

1. **GitHub CLI authenticated**: Run `gh auth status` via Bash. If it fails, stop with: "GitHub CLI not authenticated — run `gh auth login` first."
2. **Handbook repo accessible**: Run `gh api repos/Brite-Nites/handbook --jq .name` via Bash. If it fails, stop with: "Handbook repo not accessible — check org access."
3. **Project precedents exist**: Check that `docs/precedents/INDEX.md` exists using Read. If it doesn't exist, stop with: "No project precedents found. Decision traces are created during `/workflows:ship`."

Print the activation banner:

```
---
**Promote Precedent** activated
Trigger: Manual invocation — reviewing promotion candidates
Produces: Handbook PR with promoted decision traces
---
```

Narrate: `Phase 0/7: Checking prerequisites... done`

## Phase 1: Gather Candidates

Narrate: `Phase 1/7: Gathering promotion candidates...`

Collect candidates from two sources, then merge.

### Source A: Linear issues with `precedent-promotion` label

Query Linear MCP: `list_issues` with `label: "precedent-promotion"` and `project` set to the project name from CLAUDE.md `## Linear Project`. Filter to issues where `status` is NOT "Done" and NOT "Cancelled".

For each Linear issue found:
- Extract the issue ID from the title or description (e.g., the trace's source issue ID)
- Record the decision summary from the issue description
- Record the Linear issue ID for later status updates

If Linear MCP is unavailable, skip Source A and log: "Linear MCP unavailable — gathering candidates from INDEX scan only."

### Source B: Direct INDEX scan (supplemental)

Source B catches eligible traces that may not have a Linear issue (e.g., Linear MCP was unavailable during ship, or the issue was accidentally closed). It does NOT re-evaluate the generalizability criterion — only compound-learnings does that.

Read `docs/precedents/INDEX.md` and parse the markdown table. For each row where Category is `architecture`, `library-selection`, or `trade-off`:

1. If this row's Issue ID + Decision text already matches a Source A candidate, skip it (already gathered)
2. Otherwise, add as a candidate — but mark it as **"not flagged by compound-learnings"** (the confidence check is deferred to Phase 3a where the trace file is loaded anyway)

### Merge and deduplicate

Merge candidates from Source A and Source B. Deduplicate by Issue ID + Decision text; keep the Source A entry when both sources have the same candidate (it carries Linear issue context).

Sort candidates for review presentation by:
1. Confidence descending (highest first)
2. Date descending (newest first)

Note: this sort order is for review presentation only. The handbook INDEX uses chronological insertion order per `docs/precedents/README.md`.

If no candidates found from either source:
- Narrate: "No promotion candidates found. Decision traces are flagged for promotion during `/workflows:ship` when they meet all criteria: confidence >= 8, category in {architecture, library-selection, trade-off}, and generalizable pattern."
- Exit.

Narrate: `Phase 1/7: Gathering promotion candidates... done ([N] candidates)`

## Phase 2: Fetch Handbook INDEX

Narrate: `Phase 2/7: Fetching handbook INDEX...`

Fetch the handbook precedent INDEX via GitHub API (no full clone needed yet — that is deferred to Phase 4):

```bash
gh api repos/Brite-Nites/handbook/contents/precedents/INDEX.md --jq '.content' | base64 -d
```

Parse the returned INDEX table for deduplication in Phase 3. If the API returns a 404 (file doesn't exist), note that the handbook precedents directory may need to be created and proceed with an empty dedup set.

If the API call fails for a reason other than 404 (auth error, rate limit), warn: "Could not fetch handbook INDEX — deduplication check will be skipped." Proceed without dedup.

Narrate: `Phase 2/7: Fetching handbook INDEX... done`

## Phase 3: Review Each Candidate

Narrate: `Phase 3/7: Reviewing candidates...`

For each candidate (in sorted order):

### 3a. Validate and load the full trace

**Validate ISSUE-ID format**: Confirm the Issue ID matches `^[A-Z]+-[0-9]+$` (e.g., `BC-1234`). If it does not match, skip with: "Invalid issue ID format: [value] — skipping." This prevents path traversal or shell metacharacter injection when the ID is used in file paths and git commands.

Read the project-level trace from `docs/precedents/<ISSUE-ID>.md`. Extract the specific trace section matching this candidate (match by the `## Trace —` heading that contains the decision summary).

If the trace file is missing or the section cannot be found:
- Log: "Trace file missing for [ISSUE-ID] — skipping this candidate."
- Continue to next candidate.

**For Source B candidates** (not flagged by compound-learnings): Check the trace's Confidence score. If Confidence < 8, skip with: "Confidence [N]/10 below promotion threshold — skipping." Also warn: "This candidate was not flagged by compound-learnings — assess generalizability carefully" in the Phase 3c presentation.

### 3b. Deduplication check

Compare against the handbook INDEX parsed in Phase 2 using the composite key: Issue ID + Decision text (case-insensitive match on Decision text).

If already present in the handbook:
- Log: "Already promoted: [ISSUE-ID] — [Decision summary]. Skipping."
- If a Linear issue exists for this candidate, add a comment: "Already present in handbook precedents. Closing as duplicate." and transition to Cancelled (consistent with skip handling — the review was not completed, the entry pre-existed).
- Continue to next candidate.

### 3c. Present for review

Display the trace to the user:

```
### Candidate [N] of [total]

**Issue:** [ISSUE-ID]
**Decision:** [Decision summary]
**Category:** [category]
**Confidence:** [N]/10
**Date:** [YYYY-MM-DD]

#### Inputs
[bullet list from trace]

#### Alternatives Considered
[numbered list from trace]

#### Precedent Referenced
[bullet list from trace]

#### Outcome
[files changed, tests, approved by]
```

Then assess generalizability:
- Flag any project-specific file paths (e.g., `src/middleware/auth.ts` — these should be generalized to `<project>/src/middleware/auth.ts`)
- Flag project-specific configuration or environment references
- Note whether the pattern is genuinely reusable across projects

### 3d. Human decision

Use AskUserQuestion with these options:
- **Promote** — Include this trace in the handbook PR as-is (with path generalization applied automatically)
- **Edit first** — Review and modify the trace content before promoting (for generalizing project-specific details)
- **Skip (too specific)** — Pattern doesn't generalize across projects
- **Skip (low confidence)** — Decision may not hold up
- **Skip (already covered)** — Similar precedent exists with different wording
- **Skip all remaining** — Stop reviewing further candidates

For **"Edit first"**: Display the trace content as it would appear in the handbook. Let the user describe what changes they want. Apply the changes, then confirm the edited version before staging.

Record each decision (promote/skip) with the trace details for the summary report.

Narrate: `Phase 3/7: Reviewing candidates... done ([N] promoted, [N] skipped)`

If no candidates were promoted, skip to Phase 6 (update Linear for skipped candidates) and Phase 7 (summary). No clone cleanup is needed — the handbook is not cloned until Phase 4.

## Phase 4: Clone Handbook and Write Traces

Narrate: `Phase 4/7: Cloning handbook and writing traces...`

Only runs if at least one trace was promoted in Phase 3.

### 4a. Clone handbook

Create a secure temporary directory and shallow-clone:

```bash
CLONE_PATH=$(mktemp -d /tmp/handbook-promote-XXXXXX)
gh repo clone Brite-Nites/handbook "$CLONE_PATH" -- --depth 1
```

Using `mktemp -d` prevents TOCTOU race conditions on the clone path. Do not use `trap EXIT` here — each Bash tool call runs in a separate subprocess, so the trap would delete the clone immediately on exit before subsequent calls can use it. Cleanup is handled explicitly in the "Clean up" section below. If the clone fails, present via AskUserQuestion:
- **Retry** — Try the clone again
- **Stop** — Halt for manual intervention

For each promoted trace:

### 4b. Write the trace file

Write to `$CLONE_PATH/precedents/<ISSUE-ID>.md`:

- If the file already exists in the handbook clone (same issue, different trace from a previous promotion), append the new trace section below existing content
- If the file does not exist, create it with the trace content
- **Generalize project-specific paths**: Replace absolute or project-relative paths with `<project>/path` notation (e.g., `src/middleware/auth.ts` → `<project>/src/middleware/auth.ts`)
- **Preserve all other trace content** exactly as it appears in the project-level file

### 4c. Update handbook INDEX

Apply the auto-update algorithm from `docs/precedents/README.md` (Read → Parse → Match → Replace/Append → Sort → Archive → Write) to `$CLONE_PATH/precedents/INDEX.md`. If the file doesn't exist, create it with the standard header template:

```
# Precedent Index

<!-- Auto-updated by promote-precedent. Do not edit manually. -->

| Issue | Decision | Category | Date | Tags |
|-------|----------|----------|------|------|
```

Use `$CLONE_PATH/precedents/INDEX-archive.md` for archive rotation instead of the project-level path.

Narrate: `Phase 4/7: Writing promoted traces... done ([N] trace files, INDEX updated)`

## Phase 5: Create Handbook PR

Narrate: `Phase 5/7: Creating handbook PR...`

Only runs if at least one trace was promoted in Phase 3.

### Branch and commit

Derive the project repo name from `basename $(git rev-parse --show-toplevel)` (run in the project directory, not the clone). Compute identifiers once: `PROMO_DATE=$(date +%Y-%m-%d)` and `BRANCH_NAME="precedent-promotion/$PROMO_DATE-$(date +%s)"` (epoch suffix prevents same-day collisions).

All git commands must use `git -C "$CLONE_PATH"` since shell working directory does not persist between Bash calls:

```bash
git -C "$CLONE_PATH" checkout -b "$BRANCH_NAME"
git -C "$CLONE_PATH" add precedents/INDEX.md
# Stage each promoted trace file by name (do not use git add -A)
git -C "$CLONE_PATH" add precedents/<ISSUE-ID>.md  # repeat for each promoted trace
git -C "$CLONE_PATH" commit -m "Promote [N] decision traces from [project-repo]

Traces promoted via /workflows:promote-precedent.
Source project: [project-repo]"
git -C "$CLONE_PATH" push -u origin "$BRANCH_NAME"
```

### Create PR

**IMPORTANT**: Pass the `--body` value via a HEREDOC to prevent shell metacharacter injection from trace content (decision summaries and issue IDs are user-derived data). Do not use string interpolation for these values in shell arguments.

```bash
gh pr create --repo Brite-Nites/handbook \
  --base main \
  --head "$BRANCH_NAME" \
  --title "Promote [N] decision traces to org precedents" \
  --body "$(cat <<'EOF'
## Precedent Promotion

Source: [project-repo]
Reviewed by: [developer name] via /workflows:promote-precedent

### Traces Promoted
- [ISSUE-ID]: [Decision summary] (Category, Confidence N/10)
- ...

### Source Linear Issues
- [links to precedent-promotion Linear issues, if any]

---
*Auto-generated by `/workflows:promote-precedent`*
EOF
)"
```

Record the PR URL for the summary report and Linear issue updates.

### Error recovery

If the push or PR creation fails, present via AskUserQuestion:
- **Retry** — Try push and PR creation again
- **Skip PR** — Keep the clone at `$CLONE_PATH` for manual push. Log the clone path.
- **Stop** — Halt for manual intervention

### Clean up

**Always** clean up the shallow clone, even if any prior step failed. Guard against empty variable:

```bash
[ -n "$CLONE_PATH" ] && [ -d "$CLONE_PATH" ] && rm -r "$CLONE_PATH"
```

Exception: if the user chose "Skip PR", do NOT clean up — they need the clone for manual push. Log: "Handbook clone preserved at: $CLONE_PATH"

Narrate: `Phase 5/7: Creating handbook PR... done ([PR URL])`

## Phase 6: Update Linear Issues

Narrate: `Phase 6/7: Updating Linear issues...`

If Linear MCP is unavailable, skip with: "Linear MCP unavailable — skipping issue updates."

### For each promoted trace with a Linear issue:

1. Add a comment on the Linear issue:
   ```
   Promoted to org-level handbook via /workflows:promote-precedent.
   Handbook PR: [PR URL]
   ```
2. Transition the issue to "Done" status using `save_issue`

### For each skipped trace with a Linear issue:

1. Add a comment on the Linear issue:
   ```
   Reviewed via /workflows:promote-precedent — not promoted.
   Reason: [user's reason from Phase 3d]
   ```
2. Transition the issue to "Cancelled" status using `save_issue`

Narrate: `Phase 6/7: Updating Linear issues... done`

## Phase 7: Summary Report

Narrate: `Phase 7/7: Summary`

```
## Precedent Promotion Complete

**Candidates reviewed**: [N]
**Promoted**: [N]
**Skipped**: [N]
**Already in handbook**: [N]
**Handbook PR**: [URL or "none — all candidates skipped"]

### Promoted Traces
| Issue | Decision | Category | Confidence |
|-------|----------|----------|------------|
| [ID]  | [summary]| [cat]    | [N]/10     |

### Skipped Traces
| Issue | Decision | Reason |
|-------|----------|--------|
| [ID]  | [summary]| [reason] |

Run `/workflows:promote-precedent` again after the next `/workflows:ship` to review new candidates.
```
