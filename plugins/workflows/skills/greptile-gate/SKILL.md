---
name: greptile-gate
description: After a PR is opened (or on demand), read Greptile's 0–5 confidence score on the PR and report it. Use during /workflows:ship right after the PR is created, or when the user asks to check the Greptile score, run the Greptile gate, or read the Greptile review on a PR. Skips gracefully when Greptile isn't on the repo.
user-invocable: true
---

# Greptile Gate

Read the Greptile AI reviewer's verdict on an open PR and report its 0–5 confidence score. Invoked by `/workflows:ship` right after the PR is created, and re-runnable standalone against any open PR.

> **Scope (Slice 1 — BC-12248): read & report only.** The convergence loop — grill-with-docs, the `/workflows:review` fix loop, re-trigger via `@greptile-apps`, max-3 rounds, and the final independent PR review — lands in BC-12249 / BC-12250. Until then this gate surfaces the score and hands control back to the developer.

## Quick start

```bash
# Verdict for the current branch's PR (or pass an explicit PR number/url):
bash "${CLAUDE_PLUGIN_ROOT}/scripts/greptile-verdict.sh" --pr "$(gh pr view --json number -q .number)"
```

The helper emits exactly one JSON line:

- `{"present":true,"score":3,"comment_id":"…","commented_at":"…"}` — Greptile scored the PR
- `{"present":true,"score":null,…}` — Greptile reviewed but posted no parseable score
- `{"present":false}` — no Greptile comment found on the PR

**Always read the score from this helper — never parse the Greptile comment yourself.** The helper is the deterministic source of truth (it keys off the Greptile author and the latest comment by timestamp).

## Workflow

1. **Resolve the PR.** Use the PR number/url the user gave, if any; otherwise `gh pr view --json number,url` for the current branch. If there is no PR, report that and stop.

2. **Read the verdict.** Run the helper above against the PR and capture the single JSON line.

3. **Report, then exit.**
   - `present:false` → "No Greptile verdict available — Greptile isn't installed on this repo, or hasn't reviewed the PR yet. **Skipping the Greptile gate.**" Exit cleanly. *(Skip-gracefully is mandatory — see Notes.)*
   - `present:true` with a numeric score → "Greptile scored this PR **N/5**." Surface the score; the developer decides next steps (the automated loop arrives in a later slice).
   - `present:true` with `score:null` → "Greptile reviewed this PR but posted no parseable confidence score."

## Notes

- **Skip-gracefully is mandatory.** When Greptile isn't present the gate reports and exits 0 so `/workflows:ship` proceeds — it must never hard-fail a ship over a missing reviewer.
- Requires an authenticated `gh` and `jq` (the helper checks for `jq` itself and errors clearly if missing).
- The exact Greptile bot @-handle and comment format are reconciled against a live PR in BC-12249; the helper's detection is intentionally tolerant (case-insensitive `greptile` author match, score parsed near a "confidence" cue).
