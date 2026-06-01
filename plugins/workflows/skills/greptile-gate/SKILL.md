---
name: greptile-gate
description: After a PR is opened (or on demand), read Greptile's 0–5 confidence score and converge the PR toward it — grill on intent, fix review findings, re-trigger Greptile — reporting each round. Use during /workflows:ship right after the PR is created, or when the user asks to check the Greptile score, run the Greptile gate, or read/address the Greptile review on a PR. Skips gracefully when Greptile isn't on the repo.
user-invocable: true
---

# Greptile Gate

Read the Greptile AI reviewer's verdict on an open PR, report its 0–5 confidence score, and — when the score is below 5/5 — run one convergence round to close the gap. Invoked by `/workflows:ship` right after the PR is created, and re-runnable standalone against any open PR.

> **Scope (through Slice 2 — BC-12248 / BC-12249): read, report, and one convergence round.** The full multi-round loop (max 3 rounds + escalation), the final independent PR review, and the stop-before-merge handoff land in BC-12250 — along with reordering ship's terminal steps to run after convergence.

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

3. **If score == 5** → done for now; report and stop. *(The final independent review + merge handoff is Slice 3.)*

4. **If score < 5 → run ONE convergence round** (human-in-the-loop):
   1. **Grill on intent.** Run the `grill-with-docs` skill to align on requirements and sharpen terminology; capture decisions in CONTEXT.md / ADRs. Where Greptile flagged a *deliberate* choice, reply to its comment explaining the intent so it learns.
   2. **Fix the code.** Run `/workflows:review`; fix each finding with sequential-thinking and ultrathink; re-run `/workflows:review` until it returns nothing.
   3. **Confirm before pushing.** Show the developer the changes and get approval — this round is human-in-the-loop.
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
      The final line is the terminal state: `FRESH_PASS`, `FRESH_FAIL`, or `TIMED_OUT` (Greptile didn't respond within the bound — report that and stop).
   7. **Re-report** the new score from the returned verdict, then stop. *(Looping up to 3 rounds + escalation is Slice 3.)*

## Notes

- **Skip-gracefully is mandatory.** Greptile absent → report + exit 0; never hard-fail a ship.
- **The @-handle is the #1 silent-stall risk.** `@greptile-apps` is the default; verify it against a live Greptile PR (BC-12249 AC) — a wrong handle posts the comment but triggers nothing, and the wait will (correctly) `TIMED_OUT` rather than hang.
- The verdict reader keys off the Greptile author and the latest comment by timestamp; the freshness classifier treats a pre-trigger comment as stale, so an old summary never reads as a fresh re-review.
- Requires authenticated `gh`, plus `jq` and `python3` (the helpers check and error clearly).
- `grill-with-docs` is a user-global skill — invoke its behavior; don't vendor a copy.
