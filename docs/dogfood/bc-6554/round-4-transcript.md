# BC-6554 — Round-4 Launch-Campaign Dogfood Transcript

**Date:** 2026-05-05 (setup) / TBD (execution)
**Workspace:** `emailbison-personal` (workspace 13)
**Issue:** [BC-6554](https://linear.app/brite-nites/issue/BC-6554)
**Round:** 4th iteration of convergent-dogfood chain (BC-5826 → BC-5906 → BC-6308 → THIS)
**Branch:** `corinne/bc-6554-round-4-v2-launch-campaign-dogfood`
**Format:** mirrors round-2 (BC-5906) shape — hypotheses by phase, terse rows, 1 main invocation + 4 side-flow invocations

---

## Header — Walk parameters

- **Leads:** 9 (round-3 verbatim — see Inputs section)
- **Entity:** `brite-labs` (Labs T2 vertical: municipalities)
- **Preset:** list-building
- **Offer-tier:** 2
- **Activate flag:** OFF (no real emails sent except S-23 tie-breaker if it fires)
- **Gate-2 choice (main walk):** "Include all"
- **Walks executed:** 5 invocations (S-7 main multiplicative happy + S-20 empty-default sad + S-21 lowercase-token sad + S-22 --no-host-lookup + --no-segment combined + S-23 Liquid live-test setup)

---

## Outcome summary

> **(Filled at end of walk — paste the verdict table summary here. State convergence verdict: terminate or recurse to round-5.)**

---

## Inputs used

- **CSV:** `dogfood/test-leads.csv` (9 leads, copied verbatim from `docs/dogfood/bc-6308/test-leads.csv`)
- **Clean copy artifact:** `dogfood/test-copy.json` (round-3 verbatim — bare step_2.subject per BC-6301)
- **S-21 sad-path variant:** `dogfood/test-copy-lowercase.json` (single token `{FIRST_NAME}` lowercased to `{first_name}`)
- **S-20 sad-path variant:** `dogfood/test-copy-empty.json` (RECENCY_ANCHOR.default empty + bare token in body, no Liquid wrapper)
- **S-23 Liquid variant:** `dogfood/test-copy-liquid.json` (Pattern A `{{ recency_anchor | default: "recently" }}` + Pattern B `{% if proof_point_company %}...{% else %}NO_PROOF_POINT_company{% endif %}`)

---

## Workspace pre-state

15 PERMANENT custom variables from round-3 cleanup (Sx-4 — no DELETE endpoint):

| ID | Name | Source |
|---|---|---|
| 1-6 | company address, company linkedin url, company phone, company website, person job title, person linkedin url | round-1 era |
| 7-14 | recency_anchor through sender_first_name | round-2 |
| 15 | empty_test_var | round-3 T11 |

Net-new permanent variables expected: 0.

**⚠️ Cleanup debt from abandoned T5 attempt** (2026-05-05): 9 leads (IDs 14727-14735) left in workspace 13 from the abandoned scope walk. Round-4 Phase 1 pre-flight should detect and clean these up before main walk starts.

---

## S-1 — F14/R-13 pagination regression (Phase 3)

> **(Result — fill during execution)**
> **Output:** [verbatim]
> **Expected:** Laravel `?page=N` pagination, hardcoded `per_page: 15`
> **Verdict:** ✅ Expected / ⚠️ Unexpected / 🔴 Follow-up

## S-2 — F16/R-14 workspace-scoped persistence regression (Phase 3)

> **Output:** [verbatim]
> **Expected:** 15 permanent vars from round-3 cleanup all present
> **Verdict:** ✅ / ⚠️ / 🔴

## S-3 — BC-6299 existing→reuse classification fix-validation (Phase 3)

> **Output:** [verbatim]
> **Expected:** 8 artifact UPPERCASE variables → 8 lowercase EB-stored matches; zero new creates
> **Verdict:** ✅ / ⚠️ / 🔴

## S-4 — BC-6300 lead-body field names + BC-6515 UUID forward-compat (Phase 4)

> **Output:** [verbatim]
> **Expected:** POST /api/leads/multiple accepts title/company; response includes both id (int) and uuid (str)
> **Verdict:** ✅ / ⚠️ / 🔴

## S-5 — F18 mid-chunk failure recovery regression (Phase 4)

> **Output:** [verbatim]
> **Expected:** Forced duplicate-email → all-or-nothing 422 (Sx-8 atomic)
> **Verdict:** ✅ / ⚠️ / 🔴

## S-6 — BC-6304/Sx-9 wrapper-vs-API gate clarity spec-read (Phase 4)

> **Output:** [verbatim quote from spec]
> **Expected:** call_api has no vendor confirmation field; agent-side AskUserQuestion is sole safeguard
> **Verdict:** ✅ / ⚠️ / 🔴

## S-7 ★ — BC-6514+BC-6654 multiplicative fix-validation (Phase 5)

> **Output:** [verbatim]
> **Expected:** 9-cell grid; F12 prune; ~4 cells survive (Pro|Google, Personal|Google, Personal|Microsoft, Role|Other); naming `{base} | {Email-type} | {ESP}`; metadata `segments` map keyed by `{email_type}|{esp}`
> **Verdict:** ✅ / ⚠️ / 🔴

## S-8 — BC-6302/F20 silent-duplicate guard fix-validation (Phase 5)

> **Output:** [verbatim]
> **Expected:** Pre-create decoy → gate-5 surfaces match inline + 4-option render including "Reuse existing IDs"
> **Verdict:** ✅ / ⚠️ / 🔴

## S-9 — BC-6306/R-8 deliverability auto-PATCH regression (Phase 5)

> **Output:** [verbatim]
> **Expected:** plain_text/reputation_building/can_unsubscribe all set true on every campaign post-create
> **Verdict:** ✅ / ⚠️ / 🔴

## S-10 — BC-6544 PATCH-omit live test (Phase 5)

> **Output:** [verbatim]
> **Expected:** PATCH omitting plain_text reverts it to false (post-PATCH GET shows reverted state); restore via re-PATCH
> **Verdict:** ✅ / ⚠️ / 🔴

## S-11 — F21/BC-6303 lead bucket mapping fix-validation (Phase 6)

> **Output:** [verbatim]
> **Expected:** metadata `lead_ids_by_bucket` AND `lead_attach_counts` populate per cell key
> **Verdict:** ✅ / ⚠️ / 🔴

## S-12 — F22/BC-6545 allow_parallel_sending — DEFERRED 4th round

> **Status:** Deferred per round-2/3/4 brainstorm decision. BC-6545 spec-read confirms safety check spec edits landed (PR #246). Live-fire requires pre-poison setup not justified.
> **Verdict:** ⏭️ Deferred

## S-13 — F23/Sx-10/Sx-11 sender pagination + per_page + status filter (Phase 7)

> **Output:** [verbatim]
> **Expected:** Laravel ?page=N; ?per_page=N silently ignored (hardcoded 15); status case-sensitive (lowercase works, capitalized 422s)
> **Verdict:** ✅ / ⚠️ / 🔴

## S-14 — F24 partial-pool 15-sender decision regression (Phase 7)

> **Output:** [verbatim]
> **Expected:** 15 senders from page 1 attached to all N campaigns (sender invariant)
> **Verdict:** ✅ / ⚠️ / 🔴

## S-15 — F26/R-15 eventual-consistency regression (Phase 7)

> **Output:** [verbatim]
> **Expected:** Post-attach Δ < 30s (sub-second per round-3)
> **Verdict:** ✅ / ⚠️ / 🔴

## S-16 — F27 + BC-6303 schedule_template_id rename fix-validation (Phase 8)

> **Output:** [verbatim]
> **Expected:** Workspace 13 has 1 template (id 3); applied to all N campaigns; metadata `schedule_template_id: 3` + `campaign_schedule_ids` per-cell clones
> **Verdict:** ✅ / ⚠️ / 🔴

## S-17 — BC-6301/R-4 variant boolean + auto-Re: prefix (Phase 9)

> **Output:** [verbatim post-create stored subject]
> **Expected:** `"variant": false` boolean; step_2 stored subject has single "Re: " prefix
> **Verdict:** ✅ / ⚠️ / 🔴

## S-18 — F29/F30 + BC-6548 UPPERCASE happy path (Phase 9)

> **Output:** [verbatim]
> **Expected:** `max(1, wait_in_days)` clamp; `thread_reply` field name; UPPERCASE token validator passes clean artifact
> **Verdict:** ✅ / ⚠️ / 🔴

## S-19 — BC-6307 + BC-6654 grid construction fix-validation (Phase 2)

> **Output:**
> - Email-type tags: 4 personal (gmail.com 2 + outlook.com 2) + 2 professional (brite.co 2) + 3 role (info/sales/contact @ dogfoodtest.com)
> - 9-cell grid built from join of email-type × ESP
> - dig MX results: gmail.com → Google, outlook.com → Microsoft (`outlook-com.olc.protection.outlook.com`), brite.co → Google (`aspmx.l.google.com`), dogfoodtest.com → no MX (Unknown → rolled into Other)
> - Gate-2 filter: `include_all` (operator chose to keep all leads to exercise the multiplicative happy path)
> - F12 prune dropped **5** empty cells: `professional|Microsoft`, `professional|Other`, `role|Google`, `role|Microsoft`, `personal|Other`
> - **4 cells survive**: `professional|Google` (2), `personal|Google` (2), `personal|Microsoft` (2), `role|Other` (3) — total 9 leads
>
> **Expected:** Email-type tags 4 personal + 2 professional + 3 role; 9-cell grid joins email-type with ESP; F12 drops 5 empty cells
>
> **Verdict:** ✅ Expected — every sub-check matched.

---

## Side-flow / dedicated invocations

### S-20 — BC-6556 fail-closed gate sad-path

> **Invocation:** `/marketing:launch-campaign --csv ... --copy-artifact dogfood/test-copy-empty.json ...`
> **Output:** [verbatim error message]
> **Expected:** Phase 1 step 5 HARD FAIL with diagnostic naming RECENCY_ANCHOR; zero EB mutations
> **Verdict:** ✅ / ⚠️ / 🔴

### S-21 — BC-6548 lowercase-token sad-path

> **Invocation:** `/marketing:launch-campaign --csv ... --copy-artifact dogfood/test-copy-lowercase.json ...`
> **Output:** [verbatim error message]
> **Expected:** Phase 1 step 6 OR Phase 9 step 2 HARD FAIL naming `{first_name}`; sequence does NOT create
> **Verdict:** ✅ / ⚠️ / 🔴
> **Cleanup:** if reaches Phase 5+, partial-state cleanup of campaigns/leads created before halt.

### S-22 — Combined --no-host-lookup + --no-segment

> **(a) `--no-host-lookup`:**
> > **Output:** [verbatim]
> > **Expected:** Phase 2 skipped; 1 combined campaign with all 9 leads; metadata `segments: null` or absent
> > **Verdict:** ✅ / ⚠️ / 🔴

> **(b) `--no-segment` (REMOVED per BC-6514):**
> > **Output:** [verbatim arg-parse error]
> > **Expected:** Arg-parse rejection before any EB call
> > **Verdict:** ✅ / ⚠️ / 🔴

### S-23 — BC-6613 Liquid Pattern A + B render via UI Preview Body

> **Setup:** 2 dedicated single-lead test campaigns (`BC-6554 LIQUID TEST DEFAULT` + `BC-6554 LIQUID TEST IF`) with sender + schedule + sequence step using Liquid bodies. Operator clicks Preview Body in EB UI and reports verbatim rendered output.

> **(a) Pattern A — `{{ recency_anchor | default: "recently" }}`:**
> Lead with `recency_anchor` empty → expect rendered: `Saw the recently at ...` (default fired)
> > **Rendered output:** [paste from operator]
> > **Verdict:** ✅ / ⚠️ / 🔴

> **(b) Pattern B truthy — `{% if proof_point_company %}{{ proof_point_company }}{% else %}NO_PROOF_POINT_company{% endif %}`:**
> Lead with `proof_point_company: "TestCo"` → expect rendered: `... TestCo, who ...` (truthy branch)
> > **Rendered output:** [paste]
> > **Verdict:** ✅ / ⚠️ / 🔴

> **(c) Pattern B falsy:**
> Lead with `proof_point_company: ""` → expect rendered: `... NO_PROOF_POINT_company worked through it` (else branch)
> > **Rendered output:** [paste]
> > **Verdict:** ✅ / ⚠️ / 🔴

> **Tie-breaker:** if any verdict ambiguous from UI Preview Body, fall back to single real `--test-send` to corinne@britenites.com.

---

## S-1 through S-23 findings table

| S-ID | Hypothesis | Source | Verdict | Notes / round-5 follow-up |
|---|---|---|---|---|
| S-1 | F14/R-13 pagination | F-row regression | TBD | |
| S-2 | F16/R-14 workspace persistence (15 vars) | F-row regression | TBD | |
| S-3 | BC-6299 existing→reuse classification | round-2 fix-validation | TBD | |
| S-4 | BC-6300 field names + BC-6515 UUID | round-2/3 fix-validation | TBD | |
| S-5 | F18 mid-chunk failure recovery | F-row regression | TBD | |
| S-6 | BC-6304/Sx-9 wrapper-vs-API gate clarity | round-2 fix-validation | TBD | |
| S-7 ★ | BC-6514+BC-6654 multiplicative | KEYSTONE | TBD | |
| S-8 | BC-6302/F20 silent-duplicate guard | round-2 fix-validation | TBD | |
| S-9 | BC-6306/R-8 deliverability auto-PATCH | round-2/3 fix-validation | TBD | |
| S-10 | BC-6544 PATCH-omit live test | round-3 fix-validation | TBD | |
| S-11 | F21/BC-6303 lead bucket mapping | round-2 fix-validation | TBD | |
| S-12 | F22/BC-6545 allow_parallel_sending | DEFERRED 4th round | ⏭️ | |
| S-13 | F23/Sx-10/Sx-11 sender pagination | F-row regression | TBD | |
| S-14 | F24 partial-pool 15-sender | F-row regression | TBD | |
| S-15 | F26/R-15 eventual-consistency | F-row regression | TBD | |
| S-16 | F27 + BC-6303 schedule_template_id rename | round-2 fix-validation | TBD | |
| S-17 | BC-6301/R-4 variant boolean + auto-Re: | round-2 fix-validation | TBD | |
| S-18 | F29/F30 + BC-6548 UPPERCASE happy path | F-row regression | TBD | |
| S-19 | BC-6307 + BC-6654 grid construction | round-2/3 fix-validation | ✅ | 4+2+3 email-type tags, 4 cells survive (Pro\|Google, Personal\|Google, Personal\|Microsoft, Role\|Other), F12 dropped 5 empty cells |
| S-20 | BC-6556 empty-default fail-closed sad-path | round-3 fix-validation | TBD | |
| S-21 | BC-6548 lowercase-token sad-path | round-3 fix-validation | TBD | |
| S-22 | --no-host-lookup + --no-segment | BC-6654 new-surface | TBD | |
| S-23 | BC-6613 Liquid Pattern A + B | round-3 fix-validation | TBD | |

---

## Workspace cleanup (end of walk)

- Bulk-delete campaigns: TBD list
- Bulk-delete leads: TBD list (including the 9 leads 14727-14735 left from abandoned T5)
- Async drain time: TBD
- Custom variables: should remain at 15 permanent (no net new)

---

## Round-4 follow-up candidates (parked during walk)

Captured as the walk progresses; promoted to round-5 issues at end-of-walk if they still seem worth filing.

| Source | Concern | Status |
|---|---|---|
| Phase 2 gate-2 (S-19 walk) | Revisit default filter — should it default to "include all" instead of skipping role + personal? Touches BC-6307 design + relates to BC-6655/BC-6718 free-mail filter audit. Operator surfaced concern after gate-2 filter explanation. | parked |
| Phase 2 (post-S-19) | 5 of 9 grid cells unreached by current 9-lead test set (2 of those structurally unreachable due to role+free-mail tiebreak; 3 reachable but not in scope). Question: does the keystone need broader cell coverage in a future round? | parked |

---

## Convergence call (end of walk)

> Walk findings table; count blocking findings (refuted S-rows or render-engine-broken verdicts); render terminate-or-recurse decision; post comment to BC-6554; if recurse, file round-5 follow-up issues + round-5 dogfood issue.

**Blocking findings count:** TBD
**Verdict:** TERMINATE / RECURSE
**Round-5 issues filed (if any):** TBD

---

## Pacing note

Per memory: per-S-row recap protocol. After each S-row's test produces a result, agent presents:
- **S-N output:** [verbatim or summary]
- **Expected:** [what spec says]
- **Verdict:** ✅ Expected / ⚠️ Unexpected / 🔴 Needs round-5 follow-up
- **(If unexpected/follow-up):** Proposed framing
- "Record as [verdict] and commit?"

Operator confirms before transcript update + commit.
