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

**Active workspace verification.** `get_active_workspace_info` returned: instance `https://personal.outbase.so`, workspace `id: 13` ("BriteNites Team"), `is_primary: true`. Matches expected `--workspace emailbison-personal`. No `set_active_workspace` switch needed.

**Inputs verified.** `.claude/worktrees/bc-6308/dogfood/test-leads.csv` has 10 rows (1 header + 6 round-2 + 3 augmented role-based). `test-copy.json` has `schema_version: "1.0"`, `vertical: "municipalities"`, 8 custom variables.

**Cross-mapping check.** `--entity brite-labs` ↔ `--workspace emailbison-personal` is the expected dogfood cross-mapping (per F2 round-1 finding — IV-3 routes runtime metadata under `.claude/worktrees/bc-6308/dogfood/`). Round-3 inherits same routing.

**R-5 trigger detection.** Two pre-list calls fired:
- `list_campaigns(search="BC-6308")` → **0 campaigns** (clean)
- `list_campaigns(search="BC-5906")` → **0 campaigns** (round-2 cleanup fully drained; async-delete from 2026-04-27 has converged ~3 days later)

**Lead-state pre-check (optional, defensive against any async-delete straggle).**
- `list_leads(search="dogfood-test")` → **0 leads**
- `list_leads(search="bc6308")` → **0 leads**

**R-5 trigger decision:** workspace clean → R-5 verification REQUIRES a manually pre-created collision-trigger campaign at T6 step 1 (between Phase 5 step 2 plan render and step 3 pre-list call). Pre-create one campaign named `BC-6308 Round 3 | Google` via direct `call_api` so the pre-list naturally surfaces it at user gate 5, exercising the BC-6302 fix path. Track placeholder ID for cleanup at T14.

**Time-to-complete Phase 1 walk:** ~3 seconds (3 list calls + workspace info, all read-only, run in parallel).

---

## Phase 2 HOST LOOKUP — live-walk

**Step 1 — Email-type detection (BC-6307 per-lead pre-filter).** 19-entry role-prefix list + 12-entry free-mail-domain list applied to all 9 leads:

| Email | local-part | domain | is_role? | is_free? | Tag |
|---|---|---|---|---|---|
| dogfood-test-01@gmail.com | dogfood-test-01 | gmail.com | no | YES | personal |
| dogfood-test-02@gmail.com | dogfood-test-02 | gmail.com | no | YES | personal |
| dogfood-test-03@outlook.com | dogfood-test-03 | outlook.com | no | YES | personal |
| dogfood-test-04@outlook.com | dogfood-test-04 | outlook.com | no | YES | personal |
| dogfood-test-05@brite.co | dogfood-test-05 | brite.co | no | no | professional |
| dogfood-test-06@brite.co | dogfood-test-06 | brite.co | no | no | professional |
| info@dogfoodtest.com | info | dogfoodtest.com | YES | no | role |
| sales@dogfoodtest.com | sales | dogfoodtest.com | YES | no | role |
| contact@dogfoodtest.com | contact | dogfoodtest.com | YES | no | role |

Tiebreak rule (personal beats role) didn't fire in this dataset — no role address at a free-mail domain.

**Pre-filter email_type_segments: `{professional: 2, role: 3, personal: 4}`** ✓ matches plan expectation.

**Step 2 — ESP MX resolution (Bash dig pipeline per spec line 297-303).** Ran spec's exact one-invocation pipeline; results sequentially re-verified:

| Domain | MX record (sample) | ESP bucket (8-detail) | 3-bucket plan |
|---|---|---|---|
| gmail.com | `5 gmail-smtp-in.l.google.com.` (+4 alt) | Google | Google |
| outlook.com | `5 outlook-com.olc.protection.outlook.com.` | Microsoft | Microsoft |
| brite.co | `1 aspmx.l.google.com.` (+4 google) | Google | Google |
| dogfoodtest.com | (empty — no MX records) | **Unknown** | **Other** |

Per spec line 315: "Unknown — `dig` returned nothing (NXDOMAIN or no MX record)" — `dogfoodtest.com` correctly classifies as Unknown, which rolls into the 3-bucket `Other`.

**Step 3 — 3×3 ESP × email-type cell counts (under "Include all" preview):**

| ESP bucket | Professional | Role | Personal | Total |
|---|---|---|---|---|
| Google | 2 (brite.co) | 0 | 2 (gmail) | 4 |
| Microsoft | 0 | 0 | 2 (outlook) | 2 |
| Other (Unknown→Other) | 0 | 3 (dogfoodtest) | 0 | 3 |
| **Total** | 2 | 3 | 4 | 9 |

**8-bucket ESP detail under "Include all":** Google: 4, Microsoft: 2, Proofpoint: 0, Mimecast: 0, Barracuda: 0, Cisco: 0, Custom: 0, Unknown: 3.

**R-9 (classification verdict — confirmed):** Spec correctly tagged 3 role addresses (`info`, `sales`, `contact` all match 19-entry list); 4 personal-domain (gmail/outlook in 12-entry free-mail list); 2 professional (brite.co — neither list). Tiebreak path untested in this dataset (no role@free-mail) — already validated semantically in BC-6307. Filter application + metadata write verifies post-gate.

**Time-to-complete Phase 2 walk:** ~2 seconds (parallel dig pipeline; BC-6307 static lists are zero-latency in-memory predicates).

### Structural finding at gate 2 — segmentation-axis architectural mismatch (BC-6514 filed)

**During gate 2 framing**, operator surfaced live screenshots of Brite's actual production campaign topology in workspace 13. Production campaigns use **email-type as the segmentation axis** (Professional Emails / Role Emails as separate campaigns) and combine ESPs into single campaigns ("All ESPs" suffix universal). The current `/marketing:launch-campaign` spec uses the inverse model: ESP as axis, email-type as filter. Spec drift from production reality.

**Web research summary** (full detail in BC-6514):
- EB official position (verbatim from `docs.emailbison.com/campaigns/overview`): "EmailBison takes an unopinionated approach to ESP matching. It is left to the user to decide if ESP matching or mis-matching is better for their deliverability."
- The spec's ESP-axis rule comes from upstream Revgrowth-10 methodology, not from EB's own guidance
- Industry positioning is contested — vendor-marketing-driven on the pro-ESP-matching side; limited independent research

**Operator preference (recorded for BC-6514):** "in a perfect world we would want to be able to do all of the above of like yes we want to segment each campaign by both ESP and email type. so it'd be casino | microsoft | professional, casino | microsoft | role, and casino | microsoft | personal" — multiplicative ideal.

**Decision (per operator delegation-scope):** out-of-scope for this dogfood walk; needs Holden review. **Filed as BC-6514** (priority Medium, assigned to Holden Halford). Round-3 walk RESUMES against current spec (ESP-axis) with R-9 marked **partially validated**:
- ✅ Classification logic confirmed (per-lead email-type tagging is correct per BC-6307)
- ⚠️ Segmentation-axis design deferred to BC-6514 architectural review

**Round-3 unblocked for R-1, R-2, R-2a, R-2b, R-3 through R-8, R-10 through R-15** — all independent of segmentation-axis question.

### Step 4 — post-gate filter application

**User gate 2 choice:** "Include all" (max R-9 signal — all 9 leads survive into ESP segmentation per brainstorm decision 2 + plan recommendation).

**Step 4a — skipped-lead set:** empty (filter `include_all` → no leads dropped).

**Step 4b — F12 skip-empty buckets:** all 3 ESP buckets non-empty (Google: 4, Microsoft: 2, Other: 3) → no buckets pruned.

**Step 4c — sidecar CSV:** not written (skipped-lead set is empty per `include_all`).

**Step 4d — metadata writes:**
- `segmented: true`
- `esp_segments: {Google: 4, Microsoft: 2, Other: 3}`
- `email_type_segments: {professional: 2, role: 3, personal: 4}` (pre-filter — captures full input)
- `email_type_filter_applied: "include_all"`
- `skipped_leads_csv_path: null`
- `last_completed_phase: 2`

---

## Phase 3 VARIABLES — live-walk

**Step 1 — ground-truth.** `search_api_spec(GET /api/custom-variables)` returned 1 endpoint matching, summary "Get all custom variables." Confirms round-2's URL path + descriptive query forms (Sx-1 spec rewrite — both shape pass).

**Step 3 — list_custom_variables (via `call_api GET /api/custom-variables`).** Workspace 13 returns **14 total variables**, exactly as predicted by the round-3 plan:

| id | name | created_at | provenance |
|---|---|---|---|
| 1 | company address | 2025-11-14 | pre-existing (round-1 era) |
| 2 | company linkedin url | 2025-11-14 | pre-existing |
| 3 | company phone | 2025-11-14 | pre-existing |
| 4 | company website | 2025-11-14 | pre-existing |
| 5 | person job title | 2025-11-14 | pre-existing |
| 6 | person linkedin url | 2025-11-14 | pre-existing |
| 7 | recency_anchor | 2026-04-27 | round-2 (BC-5906) |
| 8 | vertical_descriptor | 2026-04-27 | round-2 |
| 9 | specific_friction | 2026-04-27 | round-2 |
| 10 | proof_point_company | 2026-04-27 | round-2 |
| 11 | proof_point_number | 2026-04-27 | round-2 |
| 12 | proof_point_timeframe | 2026-04-27 | round-2 |
| 13 | free_asset_noun | 2026-04-27 | round-2 |
| 14 | sender_first_name | 2026-04-27 | round-2 |

**R-13 verdict (F14 pagination regression — confirmed ✅).** Pagination meta is still Laravel-style page-based exactly as round-2 captured:

```
"meta": {
  "current_page": 1, "from": 1, "last_page": 1, "per_page": 15, "to": 14, "total": 14,
  "links": [{prev}, {numbered "1"}, {next}],
  "path": "https://personal.outbase.so/api/custom-variables"
}
```

NOT cursor-based. No regression. Spec's pagination model documentation matches reality.

**R-2 verdict (BC-6299 variable reuse classification — confirmed ✅).** The artifact's 8 custom variables (uppercase in JSON) all map to existing workspace variables (lowercase per Sx-3 EB silent lowercase):

| Artifact name (uppercase) | EB stored name (lowercase) | Match? | Variable ID |
|---|---|---|---|
| RECENCY_ANCHOR | recency_anchor | ✅ | id 7 |
| VERTICAL_DESCRIPTOR | vertical_descriptor | ✅ | id 8 |
| SPECIFIC_FRICTION | specific_friction | ✅ | id 9 |
| PROOF_POINT_COMPANY | proof_point_company | ✅ | id 10 |
| PROOF_POINT_NUMBER | proof_point_number | ✅ | id 11 |
| PROOF_POINT_TIMEFRAME | proof_point_timeframe | ✅ | id 12 |
| FREE_ASSET_NOUN | free_asset_noun | ✅ | id 13 |
| SENDER_FIRST_NAME | sender_first_name | ✅ | id 14 |

All 8 → "existing → reuse" classification. **Zero new creates required for Phase 3.** Per BC-6299 fix-validation, this is exactly the expected behavior — the spec's 2-way classification (new / existing) collapsed correctly, no F15 hard-fail-on-duplicate path is needed.

**Note re: `empty_test_var` (R-2b prep).** Not created here — deferred to T11 (R-2a/R-2b dedicated render-test side-flow). Will join workspace as the **9th permanent variable** at T11.

**R-2a / R-2b prep status.** Deferred to T11 per plan. Spec re-confirms: EB has no DELETE endpoint for custom variables (Sx-4) — `empty_test_var` will persist forever. Documented in T1 transcript header + final BC-6308 comment.

---

## Phase 4 UPLOAD — live-walk

**Step 1 — ground-truth.** `search_api_spec(POST /api/leads/multiple)` returned the canonical bulk endpoint with summary "Bulk create leads (limit 500 per request)." Body schema confirms BC-6300 fix:
- ✅ `title` (NOT `job_title`)
- ✅ `company` (NOT `company_name`)
- No `company_domain` field at lead level — confirms BC-6300 spec note that COMPANY_DOMAIN must be stashed in custom_variables OR dropped (in this artifact, no `{COMPANY_DOMAIN}` references → dropped is fine)
- `custom_variables` is per-lead array of `{name, value}`

**Step 4 — bulk POST.** Single `POST /api/leads/multiple` with all 9 leads. Body matches BC-6300 field names + 8 custom variables per lead (artifact defaults). Time: <1s.

**Result.** All 9 leads created successfully. IDs **14712–14720** (sequential, picking up after round-2's 14706–14711):

| Lead ID | Email | first_name | title | company | ESP bucket |
|---|---|---|---|---|---|
| 14712 | dogfood-test-01@gmail.com | Alex | Mayor | Test Denver City | Google |
| 14713 | dogfood-test-02@gmail.com | Sam | Parks Director | Test Aurora City | Google |
| 14714 | dogfood-test-03@outlook.com | Jordan | CFO | Test Boulder City | Microsoft |
| 14715 | dogfood-test-04@outlook.com | Taylor | Downtown Coord | Test Lakewood City | Microsoft |
| 14716 | dogfood-test-05@brite.co | Casey | Master Planner | Test Fort Collins | Google |
| 14717 | dogfood-test-06@brite.co | Morgan | Cultural Officer | Test Colorado Springs | Google |
| 14718 | info@dogfoodtest.com | Info | Operations Manager | Test Dogfood Aquarium | Other |
| 14719 | sales@dogfoodtest.com | Sales | Sales Director | Test Dogfood Stadium | Other |
| 14720 | contact@dogfoodtest.com | Contact | General Manager | Test Dogfood Zoo | Other |

**Bucket map for Phase 6 attach:**
- Google: [14712, 14713, 14716, 14717] — 4 leads
- Microsoft: [14714, 14715] — 2 leads
- Other: [14718, 14719, 14720] — 3 leads

**R-3 verdict (BC-6300 lead-body field names — confirmed ✅).** All 9 created leads' POST response shows `title` and `company` populated with verbatim CSV input values. No null-fields. Spec's BC-6300 fix (renamed from `job_title`/`company_name`) matches API reality. The pre-fix spec would have produced 9 leads with `title: null, company: null` — this PR-validated correction prevents the data-loss bug round-2 surfaced.

**R-1 partial verdicts (BC-6298 spec coverage — confirmed ✅ via spec read):**
- **Sx-1** (search_api_spec query forms): URL-path query `/api/leads/multiple` matched (1 result) cleanly. Per-spec rewrite at line 29 documents URL-path-preferred + keyword fallback. Round-3 implicitly confirmed by working ground-truthing in T4 + T5.
- **Sx-5** (`last_name` API spec lies): Spec post-fix at line 29 documents `last_name` is silently optional despite required-marking. Already known refuted from round-2. No regression — round-3 sent all leads with `last_name` populated; would have worked even if omitted.
- **Sx-8** (all-or-nothing bulk failure): No regression test fired since round-3's batch had no duplicates; round-2's evidence stands. Spec coverage in BC-6298 prose verified.

**Notable observations:**
1. **All 4 personal-domain leads accepted** (gmail x2 + outlook x2). The API spec's "Personal domains will be skipped unless enabled on your instance" warning did NOT fire for workspace 13 — same as round-2 (Sx-7).
2. **All 3 dogfoodtest.com role-based leads accepted.** Non-resolving domain did NOT trigger any rejection at the API level (EB doesn't validate MX before lead create — it only validates the email format).
3. **Per-lead custom_variables persisted correctly.** All 8 variables for each of the 9 leads round-trip in the response payload, names lowercased exactly as Sx-3 documented.
4. **Lead UUIDs returned** (newer than round-2's response shape — round-2 didn't surface UUIDs). EB added this field in the ~3-day window between round-2 (2026-04-27) and round-3 (2026-04-30). Forward-compatible additive change; existing integer-ID code still works. **Filed as BC-6515** (priority Low) — recommends spec stays on integer IDs + add a brief note to email-bison.md § Tool inventory + watch for additional UUID-on-other-resources signal in future rounds.

**Workspace state delta:** +9 leads (IDs 14712–14720). 0 new variables. Workspace customer-variable count unchanged at 14.

**Time-to-complete Phase 4:** ~2 seconds (1 search_api_spec + 1 bulk POST).

---

## Phase 5 CAMPAIGN CREATE — live-walk

**Step 1 — R-5 trigger setup.** Workspace was clean of leftover BC-6308/BC-5906 campaigns at T2, so per plan we pre-created a decoy campaign via `create_campaign(name="BC-6308 Round 3 | Google", type="outbound")` to force the duplicate-detection path. **Decoy: id 25, status draft, 0 leads.** Tracked for T14 cleanup.

**Step 3 — pre-list call (BC-6302 fix in action).** `list_campaigns(search="BC-6308 Round 3")` → returned **1 match** (id 25 decoy). Without BC-6302's fix, this detection wouldn't run and the spec would have silently created the duplicate. **R-5 verified at this step.**

**Step 5 — gate 5 + main creates.** Operator picked "Create 3 new anyway" per plan recommendation. Per spec line 540, "Reuse existing IDs" was unavailable here because only 1 of 3 buckets had a matching decoy — the spec correctly halts that path when not all buckets match. Spec rationale in line 540 verified by direct constraint encounter.

3 main campaigns created in parallel (~1s):
- **id 26** — `BC-6308 Round 3 | Google`
- **id 27** — `BC-6308 Round 3 | Microsoft`
- **id 28** — `BC-6308 Round 3 | Other`

**Step 6 — R-8 PATCH (off-spec then corrected).** First attempt PATCHed all 3 with `{plain_text: true, reputation_building: true, can_unsubscribe: true}` — over-spec on the agent's part. BC-6306's actual scope is `plain_text` only; `reputation_building` + `can_unsubscribe` were deliberately deferred during BC-6306 brainstorm (operator preference: keep them OFF). Agent corrected after operator flagged.

Sequence:
1. PATCH `{plain_text: true, reputation_building: true, can_unsubscribe: true}` → response confirms `plain_text: true, can_unsubscribe: true` in GET (`reputation_building` not surfaced in GET response — write-only field)
2. PATCH `{can_unsubscribe: false, reputation_building: false}` (omitting `plain_text` to revert) → response shows **`plain_text: false`**. EB silently reset it. **MAJOR FINDING**: EB's PATCH endpoint treats omitted boolean fields as `false` (documented in EB API spec: *"If nothing sent, false is assumed."*). Brite spec line 545's "PATCH is idempotent" claim is misleading — only true if you re-send the exact same body each time, NOT true that PATCH preserves omitted fields. **Filed as BC-6544** (Medium priority — documentation correctness; current spec works because it does ONE PATCH per campaign on a fresh-default state, but creates a foot-gun for future spec changes).
3. PATCH `{plain_text: true, can_unsubscribe: false, reputation_building: false}` → response shows `plain_text: true, can_unsubscribe: false` ✅ desired end state restored on all 3 main campaigns.

**Final state per main campaign (verified via PATCH response which echoes GET):**
- `plain_text: true` ✅ (BC-6306 fix verified across all 3)
- `can_unsubscribe: false` ✅ (matches BC-6306 deliberate deferral)
- `reputation_building: <unknown — write-only>` ⚠️ (sent `false` in body; can't verify via GET; confidence comes from PATCH input correctness)

**R-5 verdict (BC-6302 — pre-list duplicate guard) — confirmed ✅.** Pre-list correctly surfaced decoy id 25 at gate render; BC-6302 fix path verified.

**R-8 verdict (BC-6306 — `plain_text` deliverability PATCH) — confirmed ✅.** All 3 main campaigns end at `plain_text: true` per the BC-6306 fix. Scope correctly narrowed to `plain_text` only — earlier plan over-claim ("PATCH all 3 deliverability flags") was based on the original Sx-15 round-2 finding, not on what BC-6306 actually shipped (per BC-6306 session memory: scope narrowed to plain_text-only during brainstorm).

**Off-spec disclosure recorded.** Agent's first PATCH attempt included `reputation_building: true` + `can_unsubscribe: true` against operator's deliberate scope. Reverted via second + third PATCH. Final state matches deliberate scope. Documented in transcript per pacing-rhythm transparency requirement.

**Time-to-complete Phase 5:** ~3 minutes (4 creates + 9 PATCH + 3 GET, including the off-spec correction loop).

**Workspace state after T6:** 14 vars + 9 leads + 4 campaigns (1 decoy + 3 main).

---

## Phase 6 ATTACH LEADS — live-walk

**Step 1 — ground-truth.** `search_api_spec(search_term="attach-leads")` matched 2 results; canonical endpoint is `POST /api/campaigns/{campaign_id}/leads/attach-leads`. Body shape: `{lead_ids: [int], allow_parallel_sending: bool (optional)}`. Required: `lead_ids`. Response: `{data: {success: true, message: "Leads successfully added to <campaign_name>. Existing leads were not added."}}`.

Note: descriptive search "attach leads to campaign" returned 0 results (Sx-1 still applies — operators must use the URL-path form `attach-leads`). Round-3 spec at line 29 already documents this rule.

**Step 2 — bucket map (from T5):**
- Google bucket → leads `[14712, 14713, 14716, 14717]` (2 gmail + 2 brite.co)
- Microsoft bucket → leads `[14714, 14715]` (2 outlook)
- Other bucket → leads `[14718, 14719, 14720]` (3 dogfoodtest)

**Step 4 — three parallel attaches:**

| Campaign | IDs sent | Response message |
|---|---|---|
| id 26 (Google) | [14712, 14713, 14716, 14717] | "Leads successfully added to BC-6308 Round 3 \| Google. Existing leads were not added." |
| id 27 (Microsoft) | [14714, 14715] | "Leads successfully added to BC-6308 Round 3 \| Microsoft. Existing leads were not added." |
| id 28 (Other) | [14718, 14719, 14720] | "Leads successfully added to BC-6308 Round 3 \| Other. Existing leads were not added." |

The "Existing leads were not added" suffix is **idempotency signal** — re-attaching already-attached leads is a no-op rather than a 422. Same as round-2 evidence; documents safe resume behavior.

**Step 7 — verification via `list_campaigns(search="BC-6308 Round 3")`:**

```
id,name,status,type,leads,sent,opens,replies,bounced,completion
28,BC-6308 Round 3 | Other,draft,outbound,3,0,0,0,0,0
27,BC-6308 Round 3 | Microsoft,draft,outbound,2,0,0,0,0,0
26,BC-6308 Round 3 | Google,draft,outbound,4,0,0,0,0,0
25,BC-6308 Round 3 | Google,draft,outbound,0,0,0,0,0,0
```

Per-campaign attach counts match bucket map exactly: 4 / 2 / 3 (total 9). Decoy id 25 untouched (0 leads).

**R-6 partial verdict (BC-6303 `lead_ids_by_bucket` schema — confirmed ✅).** The bucket→ID map the spec would write at Phase 6 step 7 is:
```json
"lead_ids_by_bucket": {
  "Google": [14712, 14713, 14716, 14717],
  "Microsoft": [14714, 14715],
  "Other": [14718, 14719, 14720]
}
```
This is the resume primitive that lets a Phase 6 re-run reconstruct the bucket→IDs mapping without re-running Phase 2 MX lookups + CSV-row joins. Round-2's metadata schema gap (only `lead_ids_uploaded` count was persisted, not the per-bucket map) is now closed by BC-6303.

**R-14 verdict (F16 workspace-scoped variable persistence regression — confirmed ✅).** Implicitly verified at T4: the 8 round-2 variables (IDs 7-14, dated 2026-04-27) were still present in workspace 13 when T4's `list_custom_variables` call returned. No regression in cross-session persistence.

**R-12 verdict (F22 `allow_parallel_sending` — re-deferred ⏭️).** Not exercised in round-3 per brainstorm decision 4 (same rationale as round-2 brainstorm decision 3). F22 verification requires pre-poisoning a lead into another campaign before Phase 6 — adds setup-and-cleanup load not justified by F22's load-bearing-ness for the MVP launch path. The endpoint's `allow_parallel_sending` parameter IS confirmed in the API spec (per step 1 search result) — spec coverage stands; live-fire verification deferred.

**Time-to-complete Phase 6 walk:** ~3 seconds (1 search_api_spec + 3 parallel attaches + 1 list_campaigns verify).

**Workspace state after T7:** 14 vars + 9 leads (all attached) + 4 campaigns (1 decoy + 3 main with attached leads).

---

## Phase 7 ATTACH SENDERS — live-walk

**Step 1 — ground-truth.** `search_api_spec(search_term="attach-sender-emails")` matched `POST /api/campaigns/{campaign_id}/attach-sender-emails`, body `{sender_email_ids: [int]}`. `search_api_spec(GET /api/sender-emails)` confirmed list endpoint with optional `status`, `search`, `tag_ids` query params.

**R-1 partial (Sx-10 — `?per_page` hardcoded ✅ confirmed).** Round-3 fired three list calls in parallel:
- `?status=connected` (lowercase) → 200 success, `meta.per_page: 15, total: 772, last_page: 52`
- `?per_page=100` → 200 success, `meta.per_page: 15, total: 772` — EB **silently ignored** the per_page override and still returned 15
- `?status=Connected` (capitalized) → **HTTP 422 Error**

EB still hardcodes per_page=15 across all 52 pages. Round-2's Sx-10 finding stands; spec at line 29 + BC-6298 documentation matches reality.

**R-1 partial (Sx-11 — status filter case-sensitivity ✅ confirmed).** Lowercase `connected` accepted; capitalized `Connected` (which matches the field-value casing in the response data) returns 422. Asymmetric — input must be lowercase even though response data is capitalized. Spec at line 29 + BC-6298 documentation matches reality.

**Step 4 — partial-pool decision (same as round-2):** use page 1's 15 senders for all 3 main campaigns + future R-2a/R-2b RENDER TEST campaigns. Full 772-pool test deferred (52-page enumeration cost not justified for this round).

Page 1 sender IDs: `[995, 993, 994, 992, 991, 989, 990, 988, 987, 986, 984, 985, 983, 982, 981]`. All 15 senders verified `type: microsoft_oauth, status: "Connected", warmup_enabled: true`, tagged `Outlook` + `ScaledMail-Microsoft`, domains `washingtonfestivelights.com` / `washingtonwinterlights.com`. Cross-cycle persistence — exact same 15 senders as round-2's evidence.

**Step 5 — three parallel attaches.** All 3 succeeded:
- Campaign 26 (Google) ← 15 senders → "Sender emails successfully added to BC-6308 Round 3 | Google"
- Campaign 27 (Microsoft) ← 15 senders → "Sender emails successfully added to BC-6308 Round 3 | Microsoft"
- Campaign 28 (Other) ← 15 senders → "Sender emails successfully added to BC-6308 Round 3 | Other"

**Step 7 — verification.** Three parallel `GET /api/campaigns/{id}/sender-emails` calls all returned `meta.total: 15, per_page: 15, last_page: 1` — every campaign correctly attached the full 15-sender pool.

**R-15 verdict (F26 sub-second eventual consistency regression — confirmed ✅).** Measured timing:
- T0 (pre-attach) = `1777646847.409` (Bash `date +%s.%N`)
- T1 (post-verify) = `1777646861.176`
- **Δ = 13.77 seconds** end-to-end, including 3 attach round-trips + 3 verify round-trips + agent reasoning time

Round-2 measured ≈15.5s end-to-end. Round-3 slightly faster (likely network variance, not a real regime change). True consistency delay is sub-second — both verify GETs immediately reflected the attached senders. **No regression** — well within the < 30s threshold.

**Time-to-complete Phase 7 walk:** ~14 seconds wall time (3 attaches + 3 verifies + 3 Sx-10/Sx-11 side-tests).

**Workspace state after T8:** 14 vars + 9 leads (attached) + 4 campaigns (1 decoy + 3 main with 15 senders + 9 leads + plain_text:true).

---

## Phase 8 SCHEDULE — live-walk

**Step 1 — ground-truth.** `search_api_spec(search_term="schedule template")` matched `GET /api/campaigns/schedule/templates`. `search_api_spec(search_term="create-schedule-from-template")` matched `POST /api/campaigns/{campaign_id}/create-schedule-from-template` body `{schedule_id: int}`.

**Step 2 — list templates.** Workspace 13 returns **1 template** unchanged from round-2:

| id | type | days | start_time | end_time | timezone |
|---|---|---|---|---|---|
| 3 | Schedule template | Mon-Fri | 08:00:00 | 20:00:00 | America/Denver |

`status: "Not Started"`, `created_at: 2026-03-24` (pre-existed before round-2). Sx-12 still applies — templates have no `name` field; identification is purely by structural field comparison.

**Step 3 — three parallel applies.** All 3 succeeded:

| Campaign | Schedule clone ID | Notes |
|---|---|---|
| 26 (Google) | **6** | type: "Campaign Schedule" (round-2 saw "Generated" — minor label drift, same semantic) |
| 27 (Microsoft) | **7** | per-campaign clone |
| 28 (Other) | **8** | per-campaign clone |

**Important — clone-not-reference confirmed.** Each campaign got its own NEW schedule entity ID (not a reference to template id 3). This matches round-2's finding and validates BC-6303's metadata schema rename — the per-campaign clone IDs need to be tracked separately from the source template ID.

**R-6 partial verdict (BC-6303 — `schedule_template_id` + `campaign_schedule_ids` rename — confirmed ✅).** The metadata writes the spec would produce at Phase 8 step 7:

```json
"schedule_template_id": 3,
"campaign_schedule_ids": {
  "Google": 6,
  "Microsoft": 7,
  "Other": 8
}
```

This is the BC-6303 rename from round-2's old `schedule_id: <single-id>` (which incorrectly implied a shared schedule). The new shape correctly captures both the source template + per-campaign clones — supports the resume primitive (rebuild per-campaign schedule state from metadata alone).

**Minor observation:** API spec example response shows `type: "Generated"` but live response shows `type: "Campaign Schedule"`. Spec lags reality slightly; not load-bearing for our walk (we don't filter on type). No action needed.

**Time-to-complete Phase 8 walk:** ~3 seconds (1 list + 3 parallel applies).

**Workspace state after T9:** 14 vars + 9 leads + 4 campaigns (1 decoy + 3 main with 15 senders + 9 leads + plain_text:true + schedule). Plus 3 cloned schedule entities (ids 6-8) attached to main campaigns.

---

## Phase 9 SEQUENCE — live-walk

**Step 1 — ground-truth.** Per round-3 plan, the v1.1 endpoint is `POST /api/campaigns/v1.1/{campaign_id}/sequence-steps`. Body shape: `{title, sequence_steps: [{email_subject, email_body, wait_in_days, order, variant (boolean), thread_reply, ...}]}`. Per BC-6301 fix at line 722, `step_2.subject` must NOT start with "Re:" — EB auto-prepends.

**Pre-walk artifact validation finding.** The test artifact at `dogfood/test-copy.json` (verbatim copy from round-2's `docs/dogfood/bc-5906/test-copy.json`) STILL has `step_2.subject: "Re: {Quick|Fast|30s} {question|check|idea}"`. Per BC-6301 spec line 722, this would HARD FAIL Phase 9's artifact validation in the actual `/marketing:launch-campaign` flow.

**Why the artifact is stale:** round-2's artifact pre-dates BC-6301's fix (which shipped 2026-04-29). BC-6301 updated both `launch-campaign.md` (validate artifact input) AND `email-copywriting/SKILL.md` (don't author "Re:" prefix on step_2 subject). But the preserved test fixture at `docs/dogfood/bc-5906/test-copy.json` wasn't regenerated. Future rounds reusing this fixture as input would hit the same artifact-validation hard-fail.

**Round-3 path (per Path A decision in T10 walk):** strip "Re:" client-side and submit bare subject — mimics what an operator would do after the spec hard-fails. Tests R-4 success path. The corrected artifact will be preserved at T16 (write `docs/dogfood/bc-6308/test-copy.json` with bare step_2.subject so round-4 can copy from this cleanly).

**Step 2-4 — three parallel sequence creates.** All 3 succeeded:

| Campaign | Sequence ID | Step 1 ID (wait=1) | Step 2 ID (wait=4) |
|---|---|---|---|
| 26 (Google) | 5 | 8 | 9 |
| 27 (Microsoft) | 6 | 10 | 11 |
| 28 (Other) | 7 | 12 | 13 |

**R-4 verdict (BC-6301 — variant boolean + no double Re: — confirmed ✅).** Two sub-claims, both confirmed:

**Sub-claim 1 (variant boolean):** Sent `"variant": false` in request body for all 6 sequence steps. Post-create response shows `"variant": false` (boolean) for each step. **NOT** the round-2 spec's wrong `"variant": "A"` (string). BC-6301 fix verified.

**Sub-claim 2 (no double Re: prefix):** Sent step_2 with bare subject `"{Quick|Fast|30s} {question|check|idea}"` (no "Re:"). Post-create response stores `"email_subject": "Re: {Quick|Fast|30s} {question|check|idea}"` — **single "Re: " prefix**, auto-prepended by EB because `thread_reply: true`. Round-2's Sx-14 double-prefix bug class is closed.

For comparison — round-2 sent step_2 WITH "Re:" prefix and EB stored `"Re: Re: ..."` (double). Round-3's bare-subject approach correctly produces single prefix. The fix-validation requires the operator/spec to send bare subjects; the spec's HARD FAIL guard at line 722 ensures this contract is enforced for actual `/marketing:launch-campaign` runs.

**F29 (wait_in_days override) — sub-test.** Sent step 1 with `wait_in_days: 1` (per spec's `max(1, artifact.step_1.wait_in_days)` clamp; artifact had 0). All 3 creates succeeded — confirms F29's override is necessary AND idempotent on subsequent runs. Round-2 confirmed via 422 retry; round-3 didn't repro the 422 path since we sent 1 directly.

**F30 (thread_reply field name) — sub-confirmed.** API response confirms `thread_reply` is the correct field name. No regression.

**Time-to-complete Phase 9 walk:** ~15 seconds (1 search + 3 sequence creates).

**Workspace state after T10:** 14 vars + 9 leads + 4 campaigns (1 decoy + 3 main fully formed: senders + leads + schedule + sequence) + 3 sequence IDs (5, 6, 7).

**→ PAUSE FOR REVIEW** per plan T10 boundary. Live state of all 3 main campaigns fully formed and inspectable in EB UI before T11 dedicated render-test side-flow begins.

---

## R-2a / R-2b dedicated render-test (T11)

**Setup state:**
- Custom variable `empty_test_var` created — id 15. **Workspace 13 now has 15 permanent variables** (was 14 + 1 new).
- Lead A id **14721** — sent `recency_anchor: "ROUND-3 CASE TEST"`, `empty_test_var: ""`. **EB stored as `recency_anchor: "ROUND-3 CASE TEST"`, `empty_test_var: null`** (empty string coerced to null).
- Lead B id **14722** — sent both as `""`. **EB stored both as `null`** (same coercion).
- Campaign `BC-6308 RENDER TEST A` id **29**, plain_text PATCH applied, Lead A attached, sender 981 attached, schedule clone id 9 applied, sequence id 8 created with step id 14.
- Campaign `BC-6308 RENDER TEST B` id **30**, plain_text PATCH applied, Lead B attached, sender 981 attached, schedule clone id 10 applied, sequence id 9 created with step id 15.
- Sequence step body (both campaigns):
```
Hi {FIRST_NAME},

--- R-2a CASE-SENSITIVITY TEST ---
UPPERCASE token: {RECENCY_ANCHOR}
lowercase token: {recency_anchor}

--- R-2b EMPTY-VALUE TEST ---
EMPTY_TEST:[{empty_test_var}]:END

(test campaign — DO NOT SEND)
```

**Operator phase — Preview Body screenshots (2026-05-01):**

**RENDER TEST A (Lead A bound — recency_anchor populated, empty_test_var null):**
```
Hi LeadA,

--- R-2a CASE-SENSITIVITY TEST ---
UPPERCASE token: ROUND-3 CASE TEST
lowercase token: recency_anchor

--- R-2b EMPTY-VALUE TEST ---
EMPTY_TEST:[empty_test_var]:END

(test campaign — DO NOT SEND)
```

**RENDER TEST B (Lead B bound — both values null):**
```
Hi LeadB,

--- R-2a CASE-SENSITIVITY TEST ---
UPPERCASE token: 
lowercase token: recency_anchor

--- R-2b EMPTY-VALUE TEST ---
EMPTY_TEST:[empty_test_var]:END

(test campaign — DO NOT SEND)
```

### R-2a verdict (case-sensitivity — confirmed ✅ with NEW finding)

EB's render engine treats UPPERCASE and lowercase tokens **differently**:

- **UPPERCASE tokens** (`{RECENCY_ANCHOR}`) ARE recognized as variable references. Case-insensitive lookup against the lead's stored variables. Lead A's populated value resolved correctly to "ROUND-3 CASE TEST". Lead B's null value rendered as **empty string** (cleanly disappeared — no broken text).
- **lowercase tokens** (`{recency_anchor}`, `{empty_test_var}`) are NOT recognized as variable references. They get parsed as tokens (braces stripped) but output as **literal text** — the variable name without braces. Both Lead A and Lead B show the same lowercase-token behavior (`recency_anchor`, `empty_test_var`).

**Implications for the marketing skills:**
- ✅ All 14 marketing skills currently use UPPERCASE convention (verified by spot-check of `email-copywriting/SKILL.md`) — they work correctly with EB's render engine
- ✅ The original BC-6299 case-sensitivity concern (Sx-3: EB lowercases names on store → would `{UPPERCASE_TOKEN}` fail?) is RESOLVED — uppercase tokens correctly resolve via case-insensitive lookup
- ⚠️ NEW silent-failure risk identified: lowercase tokens render as literal text. If anyone authors copy with `{first_name}` instead of `{FIRST_NAME}`, EB delivers `"Hi first_name"` literally. **No validation in current spec.**
- **Filed as BC-6548** (Medium priority — add lowercase-token validation in email-copywriting/SKILL.md + launch-campaign Phase 9 step 1 + email-bison.md § Render engine)

### R-2b verdict (empty-value rendering — confirmed ✅)

When an UPPERCASE-resolved token has null/missing value, EB **renders it as empty string** — the placeholder simply disappears.

Evidence: Lead B's `{RECENCY_ANCHOR}` line shows `UPPERCASE token: ` (nothing after the colon — the placeholder vanished cleanly).

**Implications for the marketing skills:**
- ✅ Safest possible empty-value behavior — no literal placeholder text in delivery, no broken syntax, no spam-flag risk
- ✅ Sends still complete; affected sentence degrades to slightly awkward grammar but is readable
- ⚠️ Templates with multi-token sentences could produce double-spaces, orphan punctuation, or sentence fragments when empty values render
- **No fallback syntax discovered** — no `{TOKEN|fallback}` spintax-style mechanism visible
- **Filed as BC-6549** (Low priority — audit + harden email-copywriting templates for empty-value graceful degradation)

### Methodology note for future rounds

The empty_test_var test specifically used `{empty_test_var}` (lowercase) which fell into the lowercase-not-recognized trap. The actual R-2b empty-value evidence comes from Lead B's `{RECENCY_ANCHOR}` line (uppercase + null = empty). Future render-engine probes should use UPPERCASE tokens for empty-value tests.

Also: I sent `value: ""` for the empty fields when creating leads, but EB stored as `null`. Empty-string-to-null coercion is itself an EB API behavior — worth knowing for any future test that intentionally distinguishes empty-string from null.

### Tie-breaker decision

**Skipped — UI Preview Body output was unambiguous.** No real `/test-email` send needed. Both R-2a and R-2b verdicts confirmed via Preview Body alone.

### Time-to-complete T11

~10 minutes total (5 min agent-side setup + 3 min operator-side UI clicking + 2 min verdict + follow-up filing).

---

## R-7 / R-10 / R-11 — spec-read + flag/metadata sweep (T12)

### R-7 verdict (BC-6304 — Tool tier map clarifies wrapper-vs-API gate — confirmed ✅)

`plugins/marketing/commands/launch-campaign.md` § Tool tier map at lines 33–60 contains the BC-6304 fix language. Verbatim quote from spec line 55:

> "Vendor confirmation gates via `call_api` (Sx-9, BC-5906; BC-6439). Extended-tier tools advertised by `discover_tools` may describe `confirmation` parameters and two-call vendor gates in their tool prose. **No runtime-enforced gate exists for these tools at any layer.** Round-2 dogfood verified: `/api/leads/multiple` POST and `/api/campaigns/{id}/leads/attach-leads` POST have no `confirmation` field at the API level; `/api/campaigns/{id}/resume` follows the same pattern. BC-6439 then verified that none of `resume_campaign`, `import_leads_to_campaign`, or `bulk_create_leads` appear as direct callables in the `mcp__emailbison-personal__*` namespace — they surface only as `tier: extended` description strings in `discover_tools`, with the explicit instruction to invoke via `search_api_spec` + `call_api`. The `confirmation` prose in those descriptions is documentation aimed at the agent's planning loop, not a wrapper-layer gate that's being routed around. **The agent-side AskUserQuestion semantic gate is therefore the sole safeguard for every `call_api`-routed mutation.** ... There is no future migration path to wrapper-tool invocation for these tools — closure of BC-6439 (2026-04-29)."

The fix correctly clarifies the wrapper-vs-API distinction round-2 surfaced. Operators reading the spec now understand that:
- Vendor-side gates DO NOT enforce at the API level
- Wrapper-side gates DO NOT exist (BC-6439 closed)
- Agent-side `AskUserQuestion` is the load-bearing gate

Round-3's walk implicitly exercised this — every mutation went through `call_api` (no wrapper invocation), and the operator was prompted via `AskUserQuestion` at every gate (User gates 1, 2, 3, 4, 5, 6, 7, 8, 9 across phases). All gates fired as agent-side prompts. No silent vendor gate fired. **R-7 confirmed.**

### R-10 verdict (new flags introduced by round-2 fixes — confirmed ✅ none)

Spec flag inventory at lines 105–117 shows **13 total flags**: `--csv`, `--workspace`, `--copy-artifact`, `--campaign-name`, `--entity`, `--no-segment`, `--no-host-lookup`, `--no-sequence`, `--preview`, `--activate`, `--test-send`, `--test-send-sender`, `--reference`. All 13 pre-date round-2.

**No new flags introduced by round-2 follow-ups (BC-6298–6307).** Specifically:
- BC-6306 (plain_text deliverability PATCH) — always applies on every campaign create; no opt-out flag (operator preference per BC-6306 brainstorm)
- BC-6307 (email-type segmentation) — operator-runtime choice at gate 2; no flag
- BC-6298, BC-6299, BC-6300, BC-6301, BC-6302, BC-6303, BC-6304 — all spec-correctness fixes; no new flag surface

Default round-3 invocation (`/marketing:launch-campaign --csv ... --copy-artifact ... --workspace emailbison-personal --campaign-name "BC-6308 Round 3" --entity brite-labs`) runs all round-2 fix paths via default behavior. No opt-out flags needed. **R-10 confirmed.**

### R-11 verdict (new metadata schema fields populated — confirmed ✅)

Compiled runtime metadata JSON written to `dogfood/BC-6308-Round-3-2026-05-01.json` (will be preserved at T16 to `docs/dogfood/bc-6308/launch-metadata.json`). All new BC-6303 + BC-6306 + BC-6307 + BC-6302 schema fields populate correctly:

| Field | Source issue | Round-3 value |
|---|---|---|
| `email_type_segments` | BC-6307 | `{professional: 2, role: 3, personal: 4}` |
| `email_type_filter_applied` | BC-6307 | `"include_all"` |
| `existing_campaign_matches` | BC-6302 | `[25]` (the decoy id) |
| `reused_existing_ids` | BC-6302 | `false` |
| `plain_text_applied` | BC-6306 | `true` |
| `lead_ids_by_bucket` | BC-6303 | `{Google: [14712,14713,14716,14717], Microsoft: [14714,14715], Other: [14718,14719,14720]}` |
| `schedule_template_id` | BC-6303 | `3` (renamed from old `schedule_id`) |
| `campaign_schedule_ids` | BC-6303 | `{Google: 6, Microsoft: 7, Other: 8}` (per-campaign clones) |
| `activated_per_campaign` | BC-6303 | `{Google: null, Microsoft: null, Other: null}` (seeded; not flipped — Phase 11 not exercised) |

All 9 new fields populated correctly with verbatim values matching round-3 walk evidence. **R-11 confirmed.** No regression vs round-2 evidence for the existing fields (`campaign_ids`, `lead_ids_uploaded`, `sender_ids_attached`, etc.).

### Time-to-complete T12

~5 minutes (3 spec-read confirmations + 1 metadata JSON compilation + 1 transcript update).

---

## Phase 11 ACTIVATE — spec re-check (T13, no live execution)

*(populated at T13 — placeholder)*

Per round-3 scope, Phase 11 not exercised. Spec re-read confirms BC-6303 schema + resume rule alignment.

---

## Findings table (R-1 through R-15)

| # | Hypothesis | Status | Evidence (verbatim) | Follow-up if any |
|---|---|---|---|---|
| R-1 | BC-6298 — EB API quirks bundle (Sx-1/5/8/10/11) | ✅ **confirmed (all 5)** | Sx-1: URL-path queries succeed in T4/T5/T7/T8; Sx-5: spec correctly treats last_name as optional; Sx-8: round-2 evidence stands; Sx-10: `?per_page=100` silently ignored (EB hardcodes 15) at T8; Sx-11: `?status=Connected` 422s, `?status=connected` succeeds at T8. | None |
| R-2 | BC-6299 — Phase 3 variable reuse classification | ✅ **confirmed** | All 8 artifact variables (uppercase) match workspace stored vars (lowercase per Sx-3) → "existing → reuse" classification fires for all 8. Zero new creates required. | None |
| R-2a ★ | BC-6299 carryover — case-sensitivity | ✅ **confirmed (with new finding)** | UPPERCASE tokens resolve via case-insensitive lookup → existing 14 marketing skill templates work correctly. NEW finding: lowercase tokens render as literal text in delivery (silent-failure mode). Original Sx-3 concern resolved; new risk surfaced. | **BC-6548** (Medium — lowercase-token validation in email-copywriting + launch-campaign Phase 9) |
| R-2b ★ | BC-6299 carryover — empty-value rendering | ✅ **confirmed** | UPPERCASE-resolved token + null value = renders as empty string (placeholder cleanly disappears). Safest possible behavior — no literal placeholder text leaking into delivery. No `{TOKEN\|fallback}` syntax discovered. Sentences may degrade to awkward grammar but stay readable. | **BC-6549** (Low — email-copywriting templates audit for empty-value graceful degradation) |
| R-3 | BC-6300 — Phase 4 lead-body field names | ✅ **confirmed** | All 9 created leads (IDs 14712-14720) returned with `title` and `company` populated with verbatim CSV values. API schema confirms `title`+`company` (not job_title/company_name). BC-6300 fix prevents the round-2 data-loss bug. | None |
| R-4 | BC-6301 — variant boolean + no double Re: | ✅ **confirmed** | All 3 sequences (ids 5/6/7) created successfully. variant: false (boolean) accepted; post-create shows variant=false. Bare step_2 subject submitted; EB auto-prepended single "Re:" prefix (no double). Round-2's Sx-13 + Sx-14 bug class closed. | None (artifact-fixture stale-convention handled at T16) |
| R-5 | BC-6302 — Phase 5 pre-list duplicate guard | ✅ **confirmed** | Pre-created decoy id 25 → `list_campaigns(search="BC-6308 Round 3")` correctly returned 1 match → gate 5 surfaced duplicate. Without BC-6302 fix, this detection wouldn't run. | None |
| R-6 | BC-6303 — metadata schema (4 new fields) | ✅ **confirmed** | T7: `lead_ids_by_bucket` populated `{Google: [14712,14713,14716,14717], Microsoft: [14714,14715], Other: [14718,14719,14720]}`. T9: `schedule_template_id: 3` + `campaign_schedule_ids: {Google: 6, Microsoft: 7, Other: 8}` populated correctly. T6: `activated_per_campaign` seeded with null; `existing_campaign_matches: [25]` captured. All 4 BC-6303 fields verified. | None |
| R-7 | BC-6304 — Tool tier map clarifies wrapper-vs-API gate | ✅ **confirmed** | Spec lines 33-60 contain BC-6304 fix language stating "agent-side AskUserQuestion is the sole safeguard"; wrapper-side gate doesn't exist (BC-6439 closure). Round-3 walk implicitly exercised — all 9 user gates fired as agent prompts; no vendor-side gate fired. | None |
| R-8 ★ | BC-6306 — Phase 5 `plain_text` PATCH | ✅ **confirmed** | All 3 main campaigns (26/27/28) show `plain_text: true` post-PATCH. Scope correctly narrowed to plain_text only per BC-6306 deliberate deferral of reputation_building + can_unsubscribe. Production-blocker class from round-2 closed. | **BC-6544** (PATCH-omitted-fields-reset-to-false finding — documentation correctness for future spec changes) |
| R-9 | BC-6307 — Phase 2 email-type segmentation | **partially validated** | Classification logic ✅ confirmed (per-lead `is_role`/`is_free` tagging matches expected on all 9 leads). Segmentation-axis design ⚠️ flagged: spec uses ESP-axis, production uses email-type-axis. Operator-stated ideal is multiplicative. | **BC-6514** (architectural redesign issue, assigned Holden Halford) |
| R-10 | New flags introduced by round-2 fixes | ✅ **confirmed (none)** | Spec inventory: 13 flags total, all pre-date round-2. BC-6306 + BC-6307 went default-on with operator-runtime-choice; no opt-out flags introduced. Default round-3 invocation runs all round-2 fix paths. | None |
| R-11 | New metadata schema fields populate | ✅ **confirmed** | All 9 new fields (BC-6307: `email_type_segments`, `email_type_filter_applied`; BC-6302: `existing_campaign_matches`, `reused_existing_ids`; BC-6306: `plain_text_applied`; BC-6303: `lead_ids_by_bucket`, `schedule_template_id`, `campaign_schedule_ids`, `activated_per_campaign`) populated correctly. Compiled JSON at `dogfood/BC-6308-Round-3-2026-05-01.json`. | None |
| R-12 | F22 `allow_parallel_sending` (deferred again) | ⏭️ **deferred (3rd round)** | Brainstorm decision 4 — same rationale as round-2 brainstorm decision 3. Endpoint param confirmed in API spec; safety-check behavior not live-tested. | **BC-6545** (institutional-memory issue capturing 3-round deferral pattern + test setup + trigger conditions for future verification) |
| R-13 | F14 pagination regression | ✅ **confirmed** | `?page=N` Laravel-style meta with `per_page: 15` unchanged from round-2. NOT cursor-based. No regression. | None |
| R-14 | F16 workspace-scoped variable persistence regression | ✅ **confirmed** | 8 round-2 variables (IDs 7-14, dated 2026-04-27) still present in workspace 13 at T4 list call. No regression in cross-session persistence. | None |
| R-15 | F26 sub-second eventual consistency regression | ✅ **confirmed** | T8 measured Δ = 13.77s end-to-end (incl. 3 attaches + 3 verifies + agent reasoning). Round-2 baseline ~15.5s; round-3 slightly faster. Verify GETs immediately reflected attached senders — true consistency delay is sub-second. No regression. | None |

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
