# Independent Review Receipt Pattern

A lightweight technique for getting a cold second opinion on a PR without
opening a full review pipeline. The authoring session writes a self-contained
**handoff prompt**; a fresh session reads it with no prior context, reviews the
diff, and returns a structured **receipt** the author pastes back.

First used: BC-12347/BC-12348 (PR #494). Caught a P1 glob-quoting bug in bash
pattern matching that would have silently bypassed the guard the PR was
introducing.

## When to use

- You authored the code yourself and want an independent eye before merging
- The change touches bash, awk, or other logic where subtle correctness bugs
  hide (quoting, edge cases, off-by-ones)
- You want a structured record of what was checked, not just a verbal "LGTM"
- The change is self-contained enough that a cold reader can evaluate it
  without deep repo context

Not needed for: documentation-only changes, version bumps, or changes already
covered by a required review agent in `## Review Agents`.

## How to write the handoff prompt

Paste this template into a new message, fill in the bracketed sections, and
send it to a fresh Claude Code session (open a new window/tab).

---

```
# Independent Review — PR #<number> (<issue IDs>)

You are doing a **cold independent review** of PR #<number> in the
`<org>/<repo>` repo. No prior session context. Do not ask clarifying
questions — read the files, form your own opinion, report the receipt
at the end.

## What the PR does

<2–4 sentences: the problem being solved and the mechanism used>

## Files changed

| File | What changed |
|---|---|
| `<path>` | <one line> |
...

## Review dimensions — check all of these

### 1. <Dimension name>

<What to read (file + line range or search term)>

<The specific question or correctness claim to evaluate>

### 2. <Dimension name>
...

## Reference material

To read the diff:

    git diff <base>...<branch> -- <files>

Or read files directly at:
- `<path>` (lines ~N–M or search for "<landmark>")

Branch: <branch-name>

## Receipt format

When you are done, print EXACTLY this block (fill in the bracketed fields).
Do not add prose after the block. The block is the deliverable.

    ---REVIEW-RECEIPT-PR<number>---
    verdict: [LGTM | LGTM-with-notes | NEEDS-CHANGES | BLOCK]
    reviewer: [your session ID or "independent session"]
    date: [today's date]

    findings:
      [P1 - must fix before merge / P2 - should fix / P3 - note only]
      - [severity] [file:line-range] [brief description]
      ... (or "none" if verdict is LGTM)

    dimension-scores:
      <dimension-1-slug>: [PASS | WARN | FAIL] — [one line]
      ...

    notes: |
      [2–5 sentences of free-form context the author should read]
    ---END-RECEIPT---
```

---

## Tips for writing good dimensions

**Be specific about what to verify, not just what to read.** "Check the awk
logic" is weaker than "verify this awk comparison correctly implements
`>= 2.135.7` for edge cases: 2.135.6 (should fail), 2.135.7 (pass),
2.136.0 (pass), 2.200.0 (pass)."

**Seed the hard questions.** If you already suspect an edge case, say so
explicitly — the point is an independent check, not a surprise. From PR #494:
> *`.forceignore` files use glob patterns. When `$pat` contains literal `*`,
> the double-quoting `"$pat"` in the `case` pattern means `*` is treated as
> a literal character, NOT a glob.*

The reviewer confirmed this was a real P1 and provided the exact fix.

**Name your dimensions as slugs** (`doctor-semver-logic`, not `1.`) so the
receipt scores map unambiguously back to what was checked.

## Applying the receipt

Paste the receipt back into the authoring session. For each P1/P2 finding:

1. Fix in the same branch, new commit (not amend — keep the review audit trail)
2. Re-run `./scripts/validate.sh` locally
3. Push and re-check CI before merging

P3 findings are optional — note them in the PR comment but don't block on them.
