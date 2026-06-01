---
name: greptile-gate
description: After a PR is opened (or on demand), read Greptile's 0–5 confidence score and converge the PR toward 5/5 — grill on intent, fix review findings, re-trigger Greptile, loop up to 3 rounds, then run a final independent review. Use during /workflows:ship right after the PR is created, or when the user asks to check the Greptile score, run the Greptile gate, or read/address the Greptile review on a PR. Skips gracefully when Greptile isn't on the repo.
user-invocable: true
---

# Greptile Gate

Read the Greptile AI reviewer's verdict on an open PR, report its 0–5 confidence score, and converge the PR toward **5/5** — grilling on intent and fixing findings across up to **3 rounds**, then a final independent review. Invoked by `/workflows:ship` right after the PR is created, and re-runnable standalone against any open PR.

> **The gate never merges — the developer merges manually.** It converges and hands back.

## Quick start

```bash
PR="$(gh pr view --json number -q .number)"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/greptile-verdict.sh" --pr "$PR"
```

The verdict helper emits one JSON line: `{"present":true,"score":3,…}`, `{"present":true,"score":null,…}`, or `{"present":false}`. **Always read the score from the helper — never parse the Greptile comment yourself.**

## Workflow

1. **Resolve the PR.** Use the PR number/url the user gave, else `gh pr view --json number,url` for the current branch. No PR → report and stop.

2. **Read the verdict** via `greptile-verdict.sh --pr <PR>`.
   - `present:false` → "No Greptile verdict — Greptile isn't installed or hasn't reviewed yet. **Skipping the gate.**" Exit 0. *(Never block a ship.)*
   - `present:true` → report "Greptile scored this PR **N/5**" (or, `score:null`, "reviewed but posted no parseable score").

3. **Convergence loop — repeat up to a maximum of 3 rounds, until the score is 5/5.** If the current score is already 5/5, skip straight to the Final review. Otherwise run a round (human-in-the-loop):
   1. **Grill on intent — every round.** Run the `grill-with-docs` skill to align on requirements and sharpen terminology; capture decisions in CONTEXT.md / ADRs. Where Greptile flagged a *deliberate* choice, reply to its comment explaining the intent so it learns.
   2. **Fix the code.** Run `/workflows:review`; fix each finding with sequential-thinking and ultrathink; re-run `/workflows:review` until it returns nothing.
   3. **Confirm before pushing.** Show the developer the changes and get approval — every round is human-in-the-loop.
   4. **Push** the fixes to the PR branch.
   5. **Re-trigger Greptile.** Record the trigger time, then post the re-review request:
      ```bash
      TRIGGER_ISO="$(python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00","Z"))')"
      gh pr comment "$PR" --body "@greptile-apps please re-review"
      ```
   6. **Wait for the fresh re-review** (bounded — never hangs):
      ```bash
      bash "${CLAUDE_PLUGIN_ROOT}/scripts/greptile-await.sh" --pr "$PR" --trigger "$TRIGGER_ISO"
      ```
      Final line is the terminal state:
      - `FRESH_PASS` → now 5/5 → go to Final review.
      - `FRESH_FAIL` → re-report the new N/5; if rounds remain, loop; else escalate (below).
      - `TIMED_OUT` → Greptile didn't respond within the bound → stop and hand back with context.

   **After 3 rounds without 5/5 → escalate:** stop and hand the developer the remaining Greptile findings plus the full context of what each round tried. Do not merge.

4. **Final review (only on 5/5).** Dispatch **one independent review agent** to read the **open PR diff** (`gh pr diff "$PR"`) with fresh eyes and report its verdict. Then **stop — the gate never merges; the developer merges manually.** `/workflows:ship` then resumes its terminal steps (Linear stays **In Review**, compound-learnings, audit, handbook-drift) on the converged code.

## Notes

- **Skip-gracefully is mandatory.** Greptile absent → report + exit 0; never hard-fail a ship.
- **@-handle.** `@greptile-apps` is the confirmed trigger handle for this org. If it ever changes, the await fails *safe* (`TIMED_OUT` rather than hang) — but update it here, since a wrong handle posts the comment and triggers nothing.
- The verdict reader keys off the Greptile author and the latest comment by timestamp; the freshness classifier treats a pre-trigger comment as stale, so an old summary never reads as a fresh re-review.
- Requires authenticated `gh`, plus `jq` and `python3` (the helpers check and error clearly).
- `grill-with-docs` is a user-global skill — invoke its behavior; don't vendor a copy.
