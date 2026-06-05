# BC-11071 plan — document EB within-chunk silent-dedup behavior on POST /api/leads/multiple

**Issue:** [BC-11071](https://linear.app/brite-nites/issue/BC-11071) (Backlog → in progress)
**Branch:** `corinne/bc-11071-bc-7667-follow-up-a-document-eb-within-chunk-silent-dedup`
**Shape:** TRIVIAL doc-only — single gotcha bullet add to `email-bison.md § Known gotchas`. Pattern-matches the BC-5906 → BC-6785 chain (10+ prior TRIVIAL spec-fix shipments).

## Plain-language gist

Right now EB's `email-bison.md` doesn't say what happens when you accidentally include the same email twice in a single `POST /api/leads/multiple` call. Live test showed: EB silently keeps the first row and drops the rest, returning HTTP 201 success — the agent sees "all good" but actually got fewer leads than it sent. This adds one bullet to the gotchas section warning about that and contrasting it with the adjacent Sx-8 bullet (which fires on a different scenario: re-POSTing a lead that already exists in the workspace).

## Source evidence (verbatim from round-6 transcript)

From `docs/dogfood/bc-7667-round-6/round-6-transcript.md` (commit `fe3cd6a`, 2026-05-22, workspace 13):

| Test | Input | Response |
|------|-------|----------|
| (a) Within-chunk duplicate | 2 rows with same email `bc7667r6-dup-test@dogfoodtest.com` in 1 POST | HTTP 201 success, **1 lead created** (id 15152), 2nd occurrence silently dropped |
| (b) Re-POST existing       | 1 row with `dogfood-test-01@gmail.com` (= existing id 15143)        | `{"error":"HTTP 422 Error"}` — atomic 422 |

(b) is BC-11072's territory (Sx-8 framing correction). (a) is BC-11071's scope (this issue) — new gotcha bullet.

## Scope-expansion decision (operator-confirmed, 2026-05-22)

- `email-bison.md:212` carries the same wrong "re-POST upserts in place" claim that BC-11072 targets at `launch-campaign.md:454`. **Leave it for BC-11072** — do not touch line 212 in this PR. Surface in PR description.

## Tasks

### T1 — Add the gotcha bullet to email-bison.md

**File:** `plugins/marketing/tools/integrations/email-bison.md`
**Location:** insert immediately after the existing Sx-8 bullet (currently at line 276; verify line is still the Sx-8 "Bulk POST is all-or-nothing on validation failure" bullet before inserting — the file may have shifted since plan-time).

**Content shape** (matches the format of adjacent bullets at lines 270 / 276 / 279 / 281):

```markdown
- **Within-chunk duplicate emails are silently deduplicated, not rejected (verified BC-7667 round-6, 2026-05-22).** `POST /api/leads/multiple` with the same email appearing twice or more in a single chunk returns HTTP 201 success and creates exactly ONE lead — the first occurrence wins, subsequent rows are silently dropped. **Distinct from the Sx-8 bullet above:** Sx-8's atomic-422 behavior fires when the bulk POST includes a row whose email matches an ALREADY-EXISTING lead in the workspace (re-POST of existing); within-chunk duplicates of a NEW email do not trigger 422. Workspace 13 verification: 2 rows with `bc7667r6-dup-test@dogfoodtest.com` in one POST → HTTP 201, 1 lead (id 15152) created, 2nd occurrence dropped silently. Agent implication — if an upstream dedup is expected, do it client-side; don't rely on EB to reject within-chunk dupes. Surfaced by BC-7667 round-6 R-6 Side-finding A.
```

**Verification before write:**
- `grep -n 'Bulk POST is all-or-nothing' plugins/marketing/tools/integrations/email-bison.md` → confirm Sx-8 line number, insert immediately below that bullet (after its full block, before the next blank line + bullet).
- The new bullet is plain markdown; no schema change, no code, no behavior change.

### T2 — Validate

Run `./scripts/validate.sh` from repo root. Expect exit 0.

Also `git diff --stat` to confirm only `plugins/marketing/tools/integrations/email-bison.md` was touched.

### T3 — Acceptance criteria check

From issue body:
- [ ] Add gotcha bullet to `email-bison.md § Known gotchas` describing within-chunk silent-dedup behavior — T1
- [ ] Cross-ref Sx-8 (existing-lead re-POST → 422) to distinguish the two scenarios — T1 (in bullet body)
- [ ] `./scripts/validate.sh` exits 0 — T2
- [ ] No behavior change — by construction (markdown-only)

## Non-tasks (explicitly out of scope)

- **`email-bison.md:212` "re-POST upserts in place" claim** → BC-11072 (sibling); surface in PR body.
- **`launch-campaign.md:454` same claim** → BC-11072 (named target).
- **Rewording of the existing Sx-8 bullet** (its "duplicate email" wording is now ambiguous in light of the new bullet) → BC-11072 will likely revisit; leave alone here.
- **Other round-6 R-6 side-findings** (none — only A and B; A is this issue, B is BC-11072).
- **Cleanup of lead 15152** in workspace 13 → tracked separately at round-6 loop close per the transcript.

## Risks

- **Line drift:** between plan-write and execute, the file may have grown. Mitigation: re-grep for the Sx-8 anchor before inserting.
- **Bullet shape drift:** adjacent gotcha bullets follow a "bold lead → behavior → distinction → evidence → implication → surfaced-by footer" pattern. Mitigation: T1 content above matches that pattern exactly.

## Estimated effort

5–10 minutes. Single file, single bullet, validate, commit.
