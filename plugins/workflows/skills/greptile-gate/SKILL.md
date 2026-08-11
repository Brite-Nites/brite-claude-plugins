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
VERDICT="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/greptile-verdict.sh" --pr "$PR")"
STATE="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/greptile-gate-state.sh" --verdict "$VERDICT")"
```

`greptile-verdict.sh` emits one JSON line: `{"present":true,"score":3,…}`, `{"present":true,"score":null,…}`, or `{"present":false}`. **Always read the score from the helper — never parse the Greptile comment yourself.** Read the verdict exactly once per check (below and in the convergence loop's re-review wait) — a second read moments later can only add noise, never a different answer.

`{"present":false}` and a converged `5/5` are NOT the same outcome — the gate must never report one as if it were the other. `greptile-gate-state.sh` (pure, unit-tested in `tests/test-greptile-gate-state.sh`) classifies `VERDICT` into `STATE`, one of `NO_REVIEWER` | `CONVERGED` | `NEEDS_ROUND` — the gate's three PR-open-time terminal states.

## Workflow

1. **Resolve the PR.** Use the PR number/url the user gave, else `gh pr view --json number,url` for the current branch. No PR → report and stop.

2. **Read the verdict and classify it** (Quick start).
   - `NO_REVIEWER` → terminal state **NO REVIEWER ON THIS REPO** — its own outcome, distinct from a pass and from a converged 5/5. Greptile isn't installed on this repo, or hasn't posted a review yet. Post it where a steward will see it — **once**, idempotently, so a re-run of this skill against the same PR doesn't pile up duplicate comments:
     ```bash
     MARKER="Greptile gate: NO REVIEWER ON THIS REPO"
     if ! gh pr view "$PR" --json comments -q '.comments[].body' | grep -qF "$MARKER"; then
       gh pr comment "$PR" --body "**${MARKER}.** Greptile isn't installed on this repo, or hasn't posted a review yet — no machine reviewed this PR. Non-blocking; a human reviewer should read the diff directly."
     fi
     ```
     Then skip the gate (never blocks a ship). Report to the developer: "**NO REVIEWER ON THIS REPO** — Greptile isn't installed or hasn't reviewed yet. Skipping the gate." Exit 0. Carry the **NO REVIEWER ON THIS REPO** state into whatever you report upward (session summary, PR description, handoff) — see `/workflows:ship` Step 2b/Step 8.
   - `CONVERGED` → already 5/5 → skip straight to the Final review (step 4).
   - `NEEDS_ROUND` → report "Greptile scored this PR **N/5**" (or, `score:null`, "reviewed but posted no parseable score") and enter the convergence loop (step 3).

3. **Convergence loop — repeat up to a maximum of 3 rounds, until the score is 5/5.** Otherwise run a round (human-in-the-loop):
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
      - `FRESH_PASS` → now 5/5, **and the score is confirmed bound to your head** → go to Final review.
      - `FRESH_FAIL` → re-report the new N/5; if rounds remain, loop; else escalate (below).
      - `TIMED_OUT` → Greptile didn't respond within the bound → stop and hand back with context.
      - `UNBOUND` → a score exists but the helper could not read which commit it describes → **stop; do not treat as a pass.** Verify by hand (below) and report that the helper could not verify. Most likely cause: Greptile changed its summary footer, which is worth a ticket.

      Add `2>/dev/null` only if you do not want the per-poll trace; it goes to
      stderr and names which signal fired and which commit the score was bound to.
      Keep it when something looks wrong — it is the record this gate lacked when
      BC-18961 happened.

   **After 3 rounds without 5/5 → escalate:** stop and hand the developer the remaining Greptile findings plus the full context of what each round tried. Do not merge.

4. **Final review (only on 5/5).** Dispatch **one independent review agent** to read the **open PR diff** (`gh pr diff "$PR"`) with fresh eyes and report its verdict. Then **stop — the gate never merges; the developer merges manually.** `/workflows:ship` then resumes its terminal steps (Linear stays **In Review**, compound-learnings, audit, handbook-drift) on the converged code.

## Notes

- **Skip-gracefully is mandatory, but silence is not.** Greptile absent → **NO REVIEWER ON THIS REPO** (its own terminal state, posted to the PR and reported upward) + exit 0; never hard-fail a ship. Before BC-18947, absence and a pass produced the same exit-0 output — a repo with no reviewer read identically to a converged 5/5.
- **@-handle.** `@greptile-apps` is the confirmed trigger handle for this org. If it ever changes, the await fails *safe* (`TIMED_OUT` rather than hang) — but update it here, since a wrong handle posts the comment and triggers nothing.
- The verdict reader keys off the Greptile author and the latest comment by timestamp; the freshness classifier treats a pre-trigger comment as stale, so an old summary never reads as a fresh re-review. Because Greptile re-scores by **editing its summary in place** (the comment keeps its original `createdAt`), freshness is the latest of three signals — comment `createdAt`, the head-SHA check-run's `completed_at`, and the comment's `updated_at` — so an in-place re-score is not misread as no-response.
- **A pass needs identity, not just recency (BC-18961).** Those three timestamps only answer "did something happen since I asked". They cannot answer "is this score about *my* head", and on mission-control#2 that gap produced a `FRESH_PASS` carrying a 5/5 bound to the previous commit. Greptile puts **two** check-runs named `Greptile Review` on one head — an ack that finishes in seconds with conclusion `neutral`, then the real review — and the ack completing after the trigger was enough to satisfy a recency-only test. So the helper now also requires the summary's **"Last reviewed commit" SHA to equal the PR head**, and counts only check-runs whose conclusion is a real verdict.
- **The evidence is still the SHA, and you should still check it.** The helper is a convenience; it tells you when to look, not what is true. Its terminal check is now the same one you would run by hand: `Last reviewed commit` in the summary body, the `Reviews (N)` counter, and a completed check-run on your head. Note that `gh api …/check-runs` defaults to `filter=latest`, which shows only the newest run per name — **pass `filter=all`** or the ack run is invisible and the history will look simpler than it was.
- Requires authenticated `gh`, plus `jq` and `python3` (the helpers check and error clearly).
- `grill-with-docs` is a user-global skill — invoke its behavior; don't vendor a copy.
