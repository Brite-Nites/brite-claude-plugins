# BC-16924 — greptile-await false TIMED_OUT (freshness keyed on comment createdAt)

**Issue:** [BC-16924](https://linear.app/brite-nites/issue/BC-16924) · **Project:** Brite Skill Packs
**Branch:** `kells/bc-16924-greptile-awaitsh-false-timed_out-freshness-keyed-on-comment` · **Base:** `9f46573`

## Problem
On a genuine, converged Greptile re-review, `greptile-await.sh` prints `TIMED_OUT` even at 5/5. Greptile
**edits its summary comment in place**, so the comment's `createdAt` (surfaced as `commented_at`) never
advances past `--trigger`; `greptile-freshness.sh` keyed freshness on that timestamp → always stale.
Reproduced live this session on PR #551. (Related: BC-12414, BC-12415.)

## Design (approved)
Key freshness on a signal that advances on a re-review: the **head-SHA `Greptile Review` check-run's
`completed_at`** (re-runs on the pushed commit; verified `> trigger` on #551). Score still comes from the
comment via `greptile-verdict.sh`. Rejected alternatives: comment `updatedAt` (not exposed by
`gh pr view --json comments`) and "Last reviewed commit" footer parse (fragile).

## Tasks (TDD)
1. **Red** — `tests/test-greptile-freshness.sh`: +7 `--review-ts` cases, incl. the exact bug
   (stale verdict-ts + fresh review-ts → `FRESH_PASS`), review-only, legacy verdict-only, both-stale,
   past-deadline precedence, garbage review-ts.
2. **Green** — `scripts/greptile-freshness.sh`: add `--review-ts`; `fresh = max(verdict_ts, review_ts) > trigger`
   (backward-compatible). score still gates PASS/FAIL.
3. **IO** — `scripts/greptile-await.sh`: resolve PR repo + HEAD sha once; read the head-SHA Greptile
   check-run `completed_at` each poll; pass `--review-ts`. Degrade to prior behavior if unresolved (no regression).
4. **Bump** — workflows `3.41.2 → 3.41.3` (scripts resolve from the version-keyed cache; BC-6000 lesson).
5. **Verify** — `validate.sh` green; live re-run of `greptile-await` vs PR #551 → `FRESH_PASS` (was `TIMED_OUT`).

## Review
Independent (bash/shell logic → fresh-session receipt per `docs/guides/independent-review-receipt.md`).
