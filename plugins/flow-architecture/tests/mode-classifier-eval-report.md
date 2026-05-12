# BC-7061 mode-classifier eval report

Generated: `2026-05-12T23:05:55Z`

Per-case classifier output vs expected_mode, plus per-mode TP/FP matrix.
Companion to `fixtures/mode-classifier-eval.json` (AC #6).

## Summary

- PASS: 20
- FAIL: 0
- DRIFT: 0 (expected_mode outside recognized registry)
- SKIP: 4 (non-headless phases)

## Per-mode matrix

| Mode | TP (pass) | FP (other mode misclassified as this) |
|---|---|---|
| `greenfield` | 6 | 0 |
| `retrofit` | 3 | 0 |
| `incremental-add` | 8 | 0 |
| `resume` | 3 | 0 |

## Per-case results

| ID | Expected | Actual | Status | Description |
|---|---|---|---|---|
| MC-01 | `greenfield` | `greenfield` | PASS | empty repo + no LINEAR_ISSUE_COUNT signal → greenfield (Q12.3 default) |
| MC-02 | `greenfield` | `greenfield` | PASS | empty repo + LINEAR_ISSUE_COUNT=5 → greenfield (below Q36.3 threshold) |
| MC-03 | `greenfield` | `greenfield` | PASS | empty repo + LINEAR_ISSUE_COUNT=9 → greenfield (boundary -1; Q36.3 strict >= 10) |
| MC-04 | `retrofit` | `retrofit` | PASS | empty repo + LINEAR_ISSUE_COUNT=10 → retrofit (boundary; Q36.3 step 4) |
| MC-05 | `retrofit` | `retrofit` | PASS | empty repo + LINEAR_ISSUE_COUNT=42 → retrofit (Q36.3 step 4 heuristic) |
| MC-06 | `retrofit` | `retrofit` | PASS | intent + inventory present, no flows dir → retrofit (Q12 edge: zero-domains-with-full-FDA) |
| MC-07 | `incremental-add` | `incremental-add` | PASS | intent + inventory + flows + no breadcrumb → incremental-add (full FDA shape, no active run) |
| MC-08 | `incremental-add` | `incremental-add` | PASS | full FDA + breadcrumb status=completed → incremental-add (Q31.3 stale-completed fallthrough) |
| MC-09 | `incremental-add` | `incremental-add` | PASS | full FDA + breadcrumb status=abandoned → incremental-add (Q31.3 stale-abandoned fallthrough) |
| MC-10 | `incremental-add` | `incremental-add` | PASS | full FDA + breadcrumb in_flight aged 14 days → incremental-add (Q31.3 stale-age fallthrough) |
| MC-11 | `incremental-add` | `incremental-add` | PASS | full FDA + breadcrumb malformed JSON → incremental-add (Q31.3 parse-error stale fallthrough) |
| MC-12 | `resume` | `resume` | PASS | full FDA + breadcrumb in_flight fresh (1h old) → resume (Q12.3 + Q31.3) |
| MC-13 | `resume` | `resume` | PASS | full FDA + breadcrumb in_flight fresh + LINEAR_ISSUE_COUNT=50 → resume (resume precedence over LIC heuristic) |
| MC-14 | `incremental-add` | `incremental-add` | PASS | full FDA + no breadcrumb + LINEAR_ISSUE_COUNT=50 → incremental-add (artifact-driven precedence over LIC) |
| MC-15 | `greenfield` | `greenfield` | PASS | empty repo + LINEAR_ISSUE_COUNT='not-a-number' → greenfield (malformed count ignored per flow-detect-mode.sh validation) |
| MC-16 | `incremental-add` | `incremental-add` | PASS | full FDA + breadcrumb in_flight aged 8 days → incremental-add (stale-age boundary +1 from 7d threshold) |
| MC-17 | `resume` | `resume` | PASS | full FDA + breadcrumb in_flight aged 6 days → resume (fresh boundary -1 from 7d threshold) |
| MC-18 | `incremental-add` | `incremental-add` | PASS | full FDA + breadcrumb valid JSON + last_updated='not-a-timestamp' → incremental-add (Q31.3 STALE_REASON=timestamp-unparseable fallthrough, distinct path from MC-11) |
| MC-19 | `greenfield` | `greenfield` | PASS | intent only (no inventory, no flows) → greenfield (partial-FDA: Q12.3 AND gate requires intent AND inventory; single artifact falls through to LIC heuristic) |
| MC-20 | `greenfield` | `greenfield` | PASS | flows only (no intent, no inventory) → greenfield (partial-FDA: Q12.3 AND gate requires intent AND inventory; flows-without-intent falls through) |
