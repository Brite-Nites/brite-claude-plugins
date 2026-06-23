# 036. Story-frame predicate matches a marker keyword inside a bold span

**Status:** Accepted
**Date:** 2026-06-23
**Linear:** [BC-13751](https://linear.app/brite-nites/issue/BC-13751) (predicate loosening — fan-out foundation α) · [BC-12303](https://linear.app/brite-nites/issue/BC-12303) (wire FDA audit into consumer CI) · [BC-11983](https://linear.app/brite-nites/issue/BC-11983) (FDA quality-enforcement epic)
**Related ADRs:** none directly. Complements the per-repo `story_frame: strict` gate (BC-12198) and the redirect-stub gate (BC-12907, sibling fan-out unit β).

## Context

`_story_frame_present` (the `story-job-story-regex` gate) is the shared, golden-locked predicate that decides whether an FDA story doc carries a recognized job-story frame. It is single-sourced in `build_audit_report.py`, mirrored by a bash twin in `run-audit-smoke.sh`, and imported by the CI runner (`run_fda_ci_audit.py`). It recognizes two frames in the doc's title → first `## Acceptance` region:

- **human** (When / I want to / so I can) — passes in both modes;
- **constraint-spec** (Given / MUST / so that) — passes only under lenient (the frame retired by BC-12134; a lenient-only floor for not-yet-reframed infra / non-human flows).

Originally each marker was matched as an EXACT bold span (`**MUST**`, `**I want to**`, `**so I can**`). A 2026-06-23 census of the six WS-E consumer repos (all running story-frame **lenient** — none sets `story_frame` in `.flow/config.json`) found that most story-frame "failures" were not missing frames but **marker-form brittleness**: valid, fully-present, fully-bolded frames whose bold delimiters fall at different word boundaries than the exact pattern —

- `**the system MUST**` (the phrase bolded) ≠ `**MUST**` → 3 supply docs flagged;
- `**I want**` (the "to" left outside the bold) ≠ `**I want to**` → 5 supply/roster docs (+ base) flagged.

These are false negatives: the frame is present and bolded; only the span boundary differs. (Census + grill 2026-06-22 → option A "split": loosen the predicate for genuine bold-span brittleness; handle the separate UNBOLDED-prose case as a per-repo doc fix.)

## Decision

**A marker is present if its core keyword appears inside a real bold span — not only as the exact `**keyword**` span.** Implementation: extract each bold run left-to-right and non-overlapping (`\*\*([^*\n]+)\*\*`), then test the word-boundaried keyword against each extracted span's content.

Core keywords (each the minimal phrase that unambiguously identifies its clause):

- human: `When`, `I want` (the optional trailing "to" is dropped — `I want` identifies the want clause), `so I can` (kept whole — bare `so` is a conjunction, too weak to be a marker);
- constraint: `Given`, `MUST` (now recognized inside `**the system MUST**`), `so that`.

Invariants preserved:

- **Bold is still required** — unbolded `Given … MUST … so that` prose never matches. (This is why brite-labs' 11 unbolded infra docs are a separate doc fix, not cleared by this change.)
- **Mode guard intact** — the constraint frame still fails under `story_frame: strict`. Loosening the span match does NOT make constraint-spec docs strict-ready; it only stops mis-flagging them under the lenient floor they are meant to pass. Human near-misses DO become strict-ready (the human frame passes strict).
- **Region scope intact** — title → first `## Acceptance`.
- Keywords are word-boundaried (`\b`) so "must" in "mustard" / "I want" in "I wanted" do not leak.
- The bare `**so**` near-miss (only in brite-base) is NOT accepted here — deferred to the brite-base epic's investigate-then-decide.

**Extraction (not a single keyword-spanning regex) is load-bearing.** `\*\*[^*]*KEYWORD[^*]*\*\*` cannot tell an opening `**` from a closing one, so it pairs the *closing* `**` of one span with the *opening* `**` of the next and captures the unbolded prose between them — a real false positive observed on brite-labs `industry-verticals-03` (`**Doc type:**` … unbolded `Given … MUST … so that` … `**[persona link]**`). Left-to-right non-overlapping extraction never captures the inter-span gap. The Python canonical uses `re.findall(r"\*\*([^*\n]+)\*\*", region)`; the bash twin uses `grep -oE '\*\*[^*]+\*\*'` (line-scoped, matching the Python `[^*\n]`).

## Consequences

- **supply-commerce** → all 7 story-frame failures clear (genuinely-bolded markers); the runner now exits 0.
- **brite-roster** → ACL-06 clears; SFI-05 (an intentional redirect stub) remains and is handled by BC-12907 (unit β).
- 8 human near-misses + 3 constraint docs across the fan-out repos pass without doc edits.
- **brite-labs** is unaffected by α (its constraint markers are unbolded) → it stays a doc-bolding fix.
- The predicate is mildly looser: it tolerates marker-form variation (extra words inside the bold span, `I want` without `to`). The structural check is otherwise unchanged (bold + all three markers + region scope + mode guard).
- Regression-locked with negative controls in both test surfaces, including the GAP false-positive (two bold spans surrounding unbolded markers) and word-boundary controls (`mustard`, `I wanted`).
- **No plugin version bump:** the change is scripts + tests + this ADR only (no skills/commands/agents/hooks) — consistent with the BC-12303 mechanism PR (#485) and the ADR-034 ratchets.

## Rejected alternatives

- **Docs-first (normalize ~24 docs to exact markers, leave the predicate untouched):** keeps the predicate maximally strict but treats genuine false-negatives as doc defects; heaviest doc churn (incl. cross-team supply) and future `I want` docs keep getting flagged. Rejected for the bold-span-brittleness class — but it IS the chosen path for the UNBOLDED brite-labs docs, which are a real doc gap.
- **Loosen the bold REQUIREMENT (accept unbolded `Given/MUST/so that` prose):** would clear brite-labs with zero doc edits but false-positives on ordinary prose containing those words. Rejected — bold stays required.
- **Accept the bare `**so**` near-miss:** too aggressive (`so` is a bare conjunction); occurs only in brite-base. Deferred to that epic.
- **Single keyword-spanning regex (`\*\*[^*]*KEYWORD[^*]*\*\*`):** simpler, but pairs delimiters across the gap between two bold spans → the brite-labs false positive. Rejected in favor of left-to-right span extraction.
