# BC-6308 Round-3 Launch Dogfood — Transcript

**Date:** 2026-04-30
**Workspace:** `emailbison-personal` (id 13, BriteNites Team)
**Leads:** 9 (round-2's 6 verbatim + 3 augmented role-based addresses for BC-6307 R-9 verification)
**Entity:** brite-labs
**Preset:** list-building / municipalities
**Offer tier:** T2
**Activate:** OFF (draft-only — no real customer emails sent)
**User gate 2 choice:** "Include all" (max R-9 signal — 3 main campaigns: Google + Microsoft + Other)
**Round-1 reference:** `docs/dogfood/bc-5826/dogfood-transcript.md`
**Round-2 reference:** `docs/dogfood/bc-5906/round-2-transcript.md`
**Plan:** `docs/plans/BC-6308-plan.md`

## Outcome

*(filled at T15 convergence call — placeholder)*

**Hypothesis tally:** *(15 R-rows pending — fix-validation R-1 through R-9, BC-6299 carryover R-2a + R-2b, new fixes R-10/R-11/R-12, regressions R-13/R-14/R-15)*

**Convergence verdict:** *(zero blockers → terminate chain; ≥1 blockers → file round-4)*

---

## Inputs used

**CSV** — `.claude/worktrees/bc-6308/dogfood/test-leads.csv`. Round-2 verbatim copy from `docs/dogfood/bc-5906/test-leads.csv` (6 leads — gmail x2, outlook x2, brite.co x2) + 3 role-based addresses appended for R-9 augmentation:
- `info@dogfoodtest.com` (Operations Manager / Test Dogfood Aquarium)
- `sales@dogfoodtest.com` (Sales Director / Test Dogfood Stadium)
- `contact@dogfoodtest.com` (General Manager / Test Dogfood Zoo)

`dogfoodtest.com` is non-resolving — safe even if `--activate` were fat-fingered.

**Copy artifact** — `.claude/worktrees/bc-6308/dogfood/test-copy.json` (verbatim copy of round-2's `docs/dogfood/bc-5906/test-copy.json`). T2 free-asset, list-building preset, municipalities vertical. 8 custom variables (recency_anchor through sender_first_name).

**Brainstorm decisions (2026-04-30):** see `docs/plans/BC-6308-plan.md` § Brainstorm decisions. Key calls:
1. Augmented CSV (round-2 + 3 role-based)
2. Gate 2 = "Include all"
3. R-2a/R-2b via UI Preview Body in 2 dedicated single-lead test campaigns
4. F22 re-deferred
5. R-5 collision-trigger detect-and-decide in Phase 1
6. New permanent variable `empty_test_var` for R-2b
7. Schedule attach on test campaigns for symmetry
8. Refuted hypotheses → round-4 follow-ups (batched at T15)

## Command invocation

```
/marketing:launch-campaign \
  --csv .claude/worktrees/bc-6308/dogfood/test-leads.csv \
  --copy-artifact .claude/worktrees/bc-6308/dogfood/test-copy.json \
  --workspace emailbison-personal \
  --campaign-name "BC-6308 Round 3" \
  --entity brite-labs
```

No `--activate`. No `--test-send`. No `--no-segment`. No `--no-host-lookup`. No `--reference`. No `--no-deliverability-defaults`.

---

## Phase 1 PRE-FLIGHT — live-walk

*(populated at T2 — placeholder)*

**R-5 trigger detection:** *(leftover BC-6308 / BC-5906 campaign matches — count + IDs; trigger-source decision)*

---

## Phase 2 HOST LOOKUP — live-walk

*(populated at T3 — placeholder)*

**R-9 (BC-6307 — email-type segmentation):** *(verbatim `email_type_segments` populated from per-lead detection; ESP bucketing post-filter)*

---

## Phase 3 VARIABLES — live-walk

*(populated at T4 — placeholder)*

**R-2 (BC-6299 — variable reuse classification):** *(verbatim user gate 3 render; classification of 8 leftover round-2 vars)*

**R-13 (F14 pagination regression):** *(Laravel `?page=N` meta still present)*

---

## Phase 4 UPLOAD — live-walk

*(populated at T5 — placeholder)*

**R-3 (BC-6300 — lead-body field names):** *(post-create lead `title` / `company` values verbatim from GET response)*

**R-1 partial (Sx-1/5/8 — API quirks):** *(spec-coverage cross-references)*

---

## Phase 5 CAMPAIGN CREATE — live-walk

*(populated at T6 — placeholder)*

**R-5 (BC-6302 — pre-list duplicate guard):** *(verbatim user gate 5 render with matched campaigns surfaced; gate-5 4th option "Reuse existing IDs")*

**R-8 ★ (BC-6306 — deliverability PATCH):** *(post-create campaign GET showing `plain_text: true`, `reputation_building: true`, `can_unsubscribe: true` for all 3 main campaigns)*

---

## Phase 6 ATTACH LEADS — live-walk

*(populated at T7 — placeholder)*

**R-6 partial (BC-6303 — `lead_ids_by_bucket`):** *(metadata excerpt showing per-bucket lead-ID arrays)*

**R-14 (F16 workspace-scoped variable persistence regression):** *(8 vars from round-2 still present after one round; verified at T4 reuse classification)*

**R-12 (F22 `allow_parallel_sending`):** *(re-deferred per brainstorm decision 4)*

---

## Phase 7 ATTACH SENDERS — live-walk

*(populated at T8 — placeholder)*

**R-1 partial (Sx-10 — `?per_page` ignored):** *(verbatim test of `?per_page=100` vs no-param)*

**R-1 partial (Sx-11 — status filter case-sensitivity):** *(verbatim test of `?status=Connected` vs `?status=connected`)*

**R-15 (F26 — sub-second eventual consistency regression):** *(post-attach Δ measurement)*

---

## Phase 8 SCHEDULE — live-walk

*(populated at T9 — placeholder)*

**R-6 partial (BC-6303 — `schedule_template_id` + `campaign_schedule_ids` rename):** *(metadata excerpt)*

---

## Phase 9 SEQUENCE — live-walk

*(populated at T10 — placeholder)*

**R-4 (BC-6301 — variant boolean + no double Re:):** *(request payload showing `"variant": false`; post-create response showing single "Re: " prefix on step 2)*

---

## R-2a / R-2b dedicated render-test (T11)

*(populated at T11 — placeholder)*

**Setup state:**
- Custom variable `empty_test_var` created (id <pending>)
- Lead A id <pending> — `recency_anchor: "ROUND-3 CASE TEST"`, `empty_test_var: ""`
- Lead B id <pending> — `recency_anchor: ""`, `empty_test_var: ""`
- Campaign `BC-6308 RENDER TEST A` id <pending>
- Campaign `BC-6308 RENDER TEST B` id <pending>
- Sequence step body submitted to each (test tokens: `{RECENCY_ANCHOR}`, `{recency_anchor}`, `EMPTY_TEST:[{empty_test_var}]:END`)

**R-2a (case-sensitivity):** *(operator-reported Preview Body output for Lead A — what `{RECENCY_ANCHOR}` resolved to + control `{recency_anchor}`)*

**R-2b (empty-value rendering):** *(operator-reported Preview Body output for Lead B — what `EMPTY_TEST:[{empty_test_var}]:END` resolved to)*

**Tie-breaker decision:** *(skip / fire one real /test-email send to corinne@britenites.com)*

---

## R-7 / R-10 / R-11 — spec-read + flag/metadata sweep (T12)

*(populated at T12 — placeholder)*

**R-7 (BC-6304 — Tool tier map clarifies wrapper-vs-API gate):** *(verbatim quote from spec § Tool tier map)*

**R-10 (new flags introduced by round-2 fixes):** *(any new flags, e.g., `--no-deliverability-defaults`; default round-3 invocation paths verified)*

**R-11 (new metadata schema fields populated):** *(verbatim metadata excerpt showing `email_type_segments`, `email_type_filter_applied`, `existing_campaign_matches`, `reused_existing_ids`, `plain_text_applied`, `lead_ids_by_bucket`, `schedule_template_id`, `campaign_schedule_ids`, `activated_per_campaign`)*

---

## Phase 11 ACTIVATE — spec re-check (T13, no live execution)

*(populated at T13 — placeholder)*

Per round-3 scope, Phase 11 not exercised. Spec re-read confirms BC-6303 schema + resume rule alignment.

---

## Findings table (R-1 through R-15)

| # | Hypothesis | Status | Evidence (verbatim) | Follow-up if any |
|---|---|---|---|---|
| R-1 | BC-6298 — EB API quirks bundle (Sx-1/5/8/10/11) | *pending* | | |
| R-2 | BC-6299 — Phase 3 variable reuse classification | *pending* | | |
| R-2a ★ | BC-6299 carryover — case-sensitivity | *pending* | | |
| R-2b ★ | BC-6299 carryover — empty-value rendering | *pending* | | |
| R-3 | BC-6300 — Phase 4 lead-body field names | *pending* | | |
| R-4 | BC-6301 — variant boolean + no double Re: | *pending* | | |
| R-5 | BC-6302 — Phase 5 pre-list duplicate guard | *pending* | | |
| R-6 | BC-6303 — metadata schema (4 new fields) | *pending* | | |
| R-7 | BC-6304 — Tool tier map clarifies wrapper-vs-API gate | *pending* | | |
| R-8 ★ | BC-6306 — Phase 5 deliverability PATCH | *pending* | | |
| R-9 | BC-6307 — Phase 2 email-type segmentation | *pending* | | |
| R-10 | New flags introduced by round-2 fixes | *pending* | | |
| R-11 | New metadata schema fields populate | *pending* | | |
| R-12 | F22 `allow_parallel_sending` (deferred again) | *deferred* | Brainstorm decision 4 — same rationale as round-2 brainstorm decision 3 | |
| R-13 | F14 pagination regression | *pending* | | |
| R-14 | F16 workspace-scoped variable persistence regression | *pending* | | |
| R-15 | F26 sub-second eventual consistency regression | *pending* | | |

---

## Workspace cleanup (T14)

*(populated at T14 — placeholder)*

**Pre-cleanup state:**
- Custom variables: 14 pre-existing + 1 new (`empty_test_var`) = 15 total in workspace 13
- Leads: 9 main + 2 R-2a/R-2b test (Lead A + Lead B) + any R-5 trigger lead (none expected)
- Campaigns: 3 main + 2 RENDER TEST + 0–1 R-5 placeholder = 5–6 total

**Post-cleanup verification:**
- `list_campaigns(search="BC-6308")` returns 0
- `list_leads(search="bc6308")` returns 0
- 8 round-2 leftover variables + 1 new `empty_test_var` = **9 permanent variables** in workspace 13 (Sx-4 — no DELETE endpoint)

**Async-drain timing:** *(measured Δ; round-2 baseline ~seconds)*

---

## Convergence call (T15)

*(populated at T15 — placeholder)*

**Blocking findings count:** *(zero → terminate chain; ≥1 → file round-4)*

**Verdict:** *(Convergence achieved | Recurse to round-4)*

**If recursing — round-4 issues filed:** *(list of new follow-up issue IDs + round-4 dogfood issue ID)*

**Workspace state delta after round-3:** +1 net new permanent variable (`empty_test_var`); 9 permanent variables total; everything else reverted via T14 cleanup.
