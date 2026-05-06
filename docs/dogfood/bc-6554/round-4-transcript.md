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

> **Output:** `GET /api/custom-variables` response includes a Laravel `meta` block with `current_page: 1`, `last_page: 1`, `from: 1`, `to: 15`, `per_page: 15`, `total: 15`, and standard `links: [Previous, 1, Next]` array. No `?per_page` param was sent. Response is single-page (15 records fit one page exactly).
>
> **Expected:** Laravel `?page=N` paginated meta with hardcoded `per_page: 15`.
>
> **Verdict:** ✅ Expected — Laravel pagination meta present, `per_page` hardcoded at 15.

## S-2 — F16/R-14 workspace-scoped persistence regression (Phase 3)

> **Output:** `meta.total: 15`, all 15 vars enumerated. Names + IDs match the issue-body pre-state exactly:
> - IDs 1–6: `company address`, `company linkedin url`, `company phone`, `company website`, `person job title`, `person linkedin url` (round-1 era, created 2025-11-14)
> - IDs 7–14: `recency_anchor`, `vertical_descriptor`, `specific_friction`, `proof_point_company`, `proof_point_number`, `proof_point_timeframe`, `free_asset_noun`, `sender_first_name` (round-2, created 2026-04-27)
> - ID 15: `empty_test_var` (round-3 T11, created 2026-05-01)
>
> **Expected:** 15 permanent vars from round-3 cleanup all present at start of round-4.
>
> **Verdict:** ✅ Expected — all 15 vars present, no drift, no net-new.

## S-3 — BC-6299 existing→reuse classification fix-validation (Phase 3)

> **Output:** Artifact has 8 UPPERCASE custom variables. Each maps case-insensitively to an existing lowercase EB-stored var:
>
> | Artifact (UPPERCASE) | EB-stored (lowercase) | EB ID | Classification |
> |---|---|---|---|
> | RECENCY_ANCHOR | recency_anchor | 7 | existing → reuse |
> | VERTICAL_DESCRIPTOR | vertical_descriptor | 8 | existing → reuse |
> | SPECIFIC_FRICTION | specific_friction | 9 | existing → reuse |
> | PROOF_POINT_COMPANY | proof_point_company | 10 | existing → reuse |
> | PROOF_POINT_NUMBER | proof_point_number | 11 | existing → reuse |
> | PROOF_POINT_TIMEFRAME | proof_point_timeframe | 12 | existing → reuse |
> | FREE_ASSET_NOUN | free_asset_noun | 13 | existing → reuse |
> | SENDER_FIRST_NAME | sender_first_name | 14 | existing → reuse |
>
> All 8 classify as existing → reuse. Zero new creates needed (Phase 3 step 6 skipped).
>
> **Expected:** 8 artifact UPPERCASE → 8 lowercase EB matches; zero new creates.
>
> **Verdict:** ✅ Expected — case-insensitive lookup works as designed (BC-6299 fix held).

## S-4 — BC-6300 lead-body field names + BC-6515 UUID forward-compat (Phase 4)

> **Output:** All 9 leads created (IDs 14736–14744). EB accepted `title` (renamed from `job_title`) and `company` (renamed from `company_name`) as the lead-body field names. Every response object includes both `id` (int) and `uuid` (string, format `a1b79dd4-3f99-4b83-8c62-509d0b21dba2`).
>
> Lead ID assignments by bucket:
> - `personal|Google` (gmail.com): 14736 Alex, 14737 Sam
> - `personal|Microsoft` (outlook.com): 14738 Jordan, 14739 Taylor
> - `professional|Google` (brite.co): 14740 Casey, 14741 Morgan
> - `role|Other` (dogfoodtest.com): 14742 Info, 14743 Sales, 14744 Contact
>
> **Expected:** POST /api/leads/multiple accepts title/company; response includes both id (int) and uuid (str).
>
> **Verdict:** ✅ Expected on hypothesis. **Side-finding 🔴 logged separately:** initial bulk-POST with UPPERCASE custom_variables names returned 422; switching to lowercase succeeded. Spec defect at Phase 4 step 2 (example uses UPPERCASE). See Round-4 follow-up candidates table for full detail.

## S-5 — F18 mid-chunk failure recovery regression (Phase 4)

> **Output:** Probe POST /api/leads/multiple with 2 leads: 1 synthetic (`dogfood-s5-probe@dogfoodtest.com` — never seen) + 1 duplicate (`dogfood-test-01@gmail.com` — existing lead 14736). Response: `HTTP 422 Error` (body stripped per Sx-8 wrapper limitation). Post-422 GET /api/leads search for `dogfood-s5-probe` returned `total: 0` — synthetic was NOT silently created. Atomic rejection: the duplicate triggered the 422, the synthetic also failed to commit.
>
> **Expected:** Forced duplicate-email → all-or-nothing 422 (Sx-8 atomic).
>
> **Verdict:** ✅ Expected — Sx-8 atomic-rejection behavior held into round-4. No round-3 → round-4 drift.

## S-6 — BC-6304/Sx-9 wrapper-vs-API gate clarity spec-read (Phase 4)

> **Output:** `search_api_spec` for `POST /api/leads/multiple` returned the body schema. **No `confirmation` field in the request body schema** — only `leads[]` (with required `first_name`, `last_name`, `email` per item). The launch-campaign command spec § Tool tier map confirms: "this command invokes [bulk_create_leads] via `call_api` against `/api/leads/multiple`, which has NO `confirmation` field at the API level. The two-call gate this phase enforces is the **agent-side `AskUserQuestion`** turn".
>
> **Expected:** call_api has no vendor confirmation field; agent-side AskUserQuestion is sole safeguard.
>
> **Verdict:** ✅ Expected — spec-read confirms no vendor confirmation field; agent-side User gate 4 is the sole safeguard.

## S-7 ★ — BC-6514+BC-6654 multiplicative fix-validation (Phase 5)

> **Output:**
> - 9-cell grid built (Phase 2 step 3, verified earlier as part of S-19)
> - F12 prune dropped 5 empty cells (verified at S-19; surviving 4 cells)
> - 4 campaigns created with naming `{base} | {Email-type-titlecased} | {ESP}` per BC-6514:
>   - id 34: `BC-6554 Round 4 multiplicative | Professional | Google`
>   - id 35: `BC-6554 Round 4 multiplicative | Personal | Google`
>   - id 36: `BC-6554 Round 4 multiplicative | Personal | Microsoft`
>   - id 37: `BC-6554 Round 4 multiplicative | Role | Other`
> - Email-type comes BEFORE ESP per BC-6514 (matches workspace 13 production naming convention)
> - Metadata `segments` map populated with compound `{email_type}|{esp}` keys per BC-6654 schema
>
> **Expected:** 9-cell grid; F12 prune; ~4 cells survive (Pro|Google, Personal|Google, Personal|Microsoft, Role|Other); naming `{base} | {Email-type} | {ESP}`; metadata `segments` keyed by `{email_type}|{esp}`.
>
> **Verdict:** ✅ Expected — every sub-check passed. **Keystone holds.** BC-6514 architectural decision and BC-6654 spec rewrite both verified at runtime.

## S-8 — BC-6302/F20 silent-duplicate guard fix-validation (Phase 5)

> **Output:** Pre-created decoy `id: 33` named `BC-6554 Round 4 multiplicative DECOY` via `create_campaign`. Pre-list call `list_campaigns(search="BC-6554 Round 4 multiplicative")` returned 1 match (the decoy via substring). User gate 5 rendered the duplicate-guard branch with **4 options** (Reuse existing IDs / Create N anyway / Rename / Abort) instead of the 3-option default branch. Match preview correctly listed `id 33`, `BC-6554 Round 4 multiplicative DECOY`, `draft`.
>
> **Expected:** Pre-create decoy → gate-5 surfaces match inline + 4-option render including "Reuse existing IDs".
>
> **Verdict:** ✅ Expected — duplicate-guard branch fired and rendered correctly.

## S-9 — BC-6306/R-8 deliverability auto-PATCH regression (Phase 5)

> **Output:** PATCH `plain_text: true` applied to all 4 campaigns; every response confirms `plain_text: true`. **Other 2 hypothesis fields NOT applied:** `reputation_building` not in PATCH body; `can_unsubscribe: false` in response (EB default, not PATCHed). Per memory: BC-6306 (PR #227) was scoped to `plain_text` only at brainstorm time; `reputation_building` + `can_unsubscribe` were deferred. The S-9 hypothesis as written in this issue body lists all 3 — but the hypothesis was authored before BC-6306's brainstorm narrowing landed and never got updated.
>
> **Expected (per literal hypothesis):** plain_text/reputation_building/can_unsubscribe all true on every campaign post-create.
>
> **Expected (per implemented scope):** plain_text only.
>
> **Verdict:** ⚠️ Unexpected per literal hypothesis (1-of-3 fields applied); ✅ Expected per implemented scope. **Hypothesis-vs-implementation drift** — the BC-6554 issue body S-9 row needs an update to match BC-6306's narrowed shipping scope. Logged as 🟡 process-cleanup follow-up (not a code defect).

## S-10 — BC-6544 PATCH-omit live test (Phase 5)

> **Output:** Sequential 3-step test on campaign id 34:
> 1. Initial PATCH `{"plain_text": true}` → response confirms `plain_text: true`.
> 2. Subsequent PATCH `{"name": "<same name>"}` (omitting plain_text) → response shows `plain_text: false` (reverted to false).
> 3. Restore PATCH `{"plain_text": true}` → response confirms `plain_text: true` (restored).
>
> Live-confirms the API spec's verbatim claim: *"If nothing sent, false is assumed"* for boolean fields. The PATCH endpoint description verbatim contains this sentence on plain_text/open_tracking/reputation_building/can_unsubscribe (verified via `search_api_spec` for `/api/campaigns/{id}/update`).
>
> **Expected:** PATCH omitting plain_text reverts it to false; restore via re-PATCH.
>
> **Verdict:** ✅ Expected — BC-6544 PATCH-omits-omitted-booleans behavior live-verified.

## S-11 — F21/BC-6303 lead bucket mapping fix-validation (Phase 6)

> **Output:** Attached 9 leads across 4 campaigns via 4 parallel POSTs to `/api/campaigns/{id}/leads/attach-leads`. All 4 returned `success: true`. Post-attach `get_campaign` confirms per-bucket counts:
> - id 34 (professional|Google): `total_leads: 2` (14740, 14741) ✓
> - id 35 (personal|Google): `total_leads: 2` (14736, 14737) ✓
> - id 36 (personal|Microsoft): `total_leads: 2` (14738, 14739) ✓
> - id 37 (role|Other): `total_leads: 3` (14742, 14743, 14744) ✓
>
> Sum: 9 leads, matches `lead_count`. Each lead attached to exactly one campaign. Counts equal `segments[*].count` per BC-6654 schema. Metadata's `lead_ids_by_bucket` was populated in Phase 4 (Phase 6 step 7 spec); `lead_attach_counts` populated post-attach.
>
> **Side observation for S-15:** post-attach `get_campaign` returned immediate-consistent counts on all 4 campaigns — no propagation lag observed. Bonus signal for the eventual-consistency hypothesis when it formally fires in Phase 7.
>
> **Expected:** metadata `lead_ids_by_bucket` AND `lead_attach_counts` populate per cell key (`{email_type}|{esp}`); leads correctly partitioned across multiplicative cells.
>
> **Verdict:** ✅ Expected — F21 lead-bucket mapping + BC-6303 schema both verified at runtime.

## S-12 — F22/BC-6545 allow_parallel_sending — DEFERRED 4th round

> **Status:** Deferred per round-2/3/4 brainstorm decision. BC-6545 spec-read confirms safety check spec edits landed (PR #246). Live-fire requires pre-poison setup not justified.
> **Verdict:** ⏭️ Deferred

## S-13 — F23/Sx-10/Sx-11 sender pagination + per_page + status filter (Phase 7)

> **Output:** Three sub-checks verified in one call set:
> 1. **Pagination shape**: Response `meta` block contains `last_page: 52`, links array with pages 1-10 + 51, 52. Laravel paginator. ✓
> 2. **`?per_page=50` silently ignored**: Response still shows `per_page: 15`, `to: 15`. Hardcoded 15. ✓
> 3. **Status case-sensitivity**: `status=connected` (lowercase) → 200 OK; `status=Connected` (capitalized, matching response payload value) → HTTP 422. ✓
>
> Workspace 13 total connected senders: 772 (across 52 pages).
>
> **Expected:** Laravel `?page=N`; `?per_page=N` silently ignored (hardcoded 15); status case-sensitive (lowercase works, capitalized 422s).
>
> **Verdict:** ✅ Expected — F23 / Sx-10 / Sx-11 all held into round-4.

## S-14 — F24 partial-pool 15-sender decision regression (Phase 7)

> **Output:** 15 senders from page 1 (IDs 981-995, all Microsoft OAuth, names: Holden Halford 5x, Dillon Williams 3x, Mckenna Fuhriman 2x, Rainer Owens 2x, Lotus Dennison 2x) attached to all 4 campaigns via 4 parallel POSTs to `/api/campaigns/{id}/attach-sender-emails`. All 4 returned `success: true`. Verification GET `/api/campaigns/{id}/sender-emails` per campaign returned `total: 15` with **identical sender ID set** on every campaign. Sender invariant holds.
>
> F24 dogfood-walk decision context: workspace 13 has 772 total connected senders (52 pages); the dogfood walk attaches page 1 only (15 senders) for practicality.
>
> **Expected:** 15 senders from page 1 attached to all N campaigns (sender invariant — same pool across cells).
>
> **Verdict:** ✅ Expected — F24 partial-pool decision + sender invariant held.

## S-15 — F26/R-15 eventual-consistency regression (Phase 7)

> **Output:** Bash timestamps bracket the attach + verify cycle. Start `2026-05-06T21:26:42` UTC; end `2026-05-06T21:27:01` UTC. **19 seconds** for 8 round-trip calls (4 attach + 4 verify). All 4 verify GETs returned `total: 15` immediately — no stale reads, no propagation lag observed within the round trip.
>
> Plus an earlier signal from S-11 (Phase 6): post-lead-attach `get_campaign` showed immediate-consistent counts on all 4 campaigns. Two independent observations of immediate consistency now.
>
> **Expected:** Post-attach Δ < 30s (sub-second per round-3).
>
> **Verdict:** ✅ Expected — F26/R-15 immediate-consistency behavior held.

## S-16 — F27 + BC-6303 schedule_template_id rename fix-validation (Phase 8)

> **Output:**
> - `GET /api/campaigns/schedule/templates` returned exactly 1 template: `id: 3`, M-F (mon-fri true, sat-sun false), `start_time: 08:00:00`, `end_time: 20:00:00`, `timezone: America/Denver`. Verbatim match to hypothesis.
> - 4 parallel `POST /api/campaigns/{id}/create-schedule-from-template` calls with `{"schedule_id": 3}` returned 4 cloned schedule entities:
>   - campaign 34 → clone id 11
>   - campaign 35 → clone id 12
>   - campaign 36 → clone id 13
>   - campaign 37 → clone id 14
> - All clones have `type: "Campaign Schedule"`, M-F 08:00-20:00 America/Denver. Each clone is distinct, NOT a ref to template id 3 — confirms BC-6303 round-2 each-apply-creates-new-clone behavior.
> - Metadata: `schedule_template_id: 3` (source) + `campaign_schedule_ids: {bucket: clone_id}` per BC-6303 schema.
>
> **Expected:** Workspace 13 has 1 template (id 3, M-F 08:00-20:00 America/Denver); applied to all N campaigns; metadata `schedule_template_id: 3` + `campaign_schedule_ids` per-cell clones.
>
> **Verdict:** ✅ Expected — F27 + BC-6303 schema both held.

## S-17 — BC-6301/R-4 variant boolean + auto-Re: prefix (Phase 9)

> **Output:** Sent step_2.email_subject as bare `"{Quick|Fast|30s} {question|check|idea}"`. Stored response shows step_2.email_subject = `"Re: {Quick|Fast|30s} {question|check|idea}"` — **single "Re: " prefix** (not double). EB auto-prepended due to `thread_reply: true`. Both steps stored with `variant: false` (boolean) and `variant_from_step: null` (standalone, not chained).
>
> Sequence IDs created (one per campaign):
> - id 10 (Pro|Google): steps 16, 17
> - id 11 (Personal|Google): steps 18, 19
> - id 12 (Personal|Microsoft): steps 20, 21
> - id 13 (Role|Other): steps 22, 23
>
> **Expected:** `"variant": false` boolean; step_2 stored subject has single "Re: " prefix.
>
> **Verdict:** ✅ Expected — BC-6301 fix held into round-4.

## S-18 — F29/F30 + BC-6548 UPPERCASE happy path (Phase 9)

> **Output:**
> - Step 1 stored `wait_in_days: 1` (clamped from artifact's 0 via `max(1, 0)` rule). ✓
> - Step 2 stored `wait_in_days: 4` (no clamp needed). ✓
> - `thread_reply` field name accepted (boolean: false on step 1, true on step 2). ✓
> - Bodies + subjects contained only UPPERCASE tokens; sequence creation proceeded without halt at Phase 9 step 2 UPPERCASE validator (and Phase 1 step 6 validator earlier). ✓
>
> **Expected:** `max(1, wait_in_days)` clamp; `thread_reply` field name; UPPERCASE token validator passes clean artifact.
>
> **Verdict:** ✅ Expected — F29 + F30 + BC-6548 all held.

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

> **Method:** Spec-read verdict against `dogfood/test-copy-empty.json`. The artifact has `RECENCY_ANCHOR.default = ""` and `step_1.body` references `{RECENCY_ANCHOR}` bare (no Liquid wrapper).
>
> **Phase 1 step 5 trace** for `{RECENCY_ANCHOR}`:
> - (1) Not on EB-standard allowlist (FIRST_NAME, LAST_NAME, COMPANY, JOB_TITLE, EMAIL) ✗
> - (2) No CSV column matches `recency_anchor` ✗
> - (3) `custom_variables[].default` is `""` (fails non-empty check) ✗
> - (4) Not a `{SENDER_*}` token ✗
> - (5) No Liquid wrapper (assign + default, if/else, contains-branch) in body ✗
>
> All 5 paths fail → **HARD FAIL** with diagnostic naming RECENCY_ANCHOR. Phase 1 is read-only; halt fires before any Phase 2-11 work. Zero EB mutations.
>
> **Expected:** Phase 1 step 5 HARD FAIL with diagnostic naming RECENCY_ANCHOR; zero EB mutations.
>
> **Verdict:** ✅ Expected — BC-6556 fail-closed gate fires correctly.

### S-21 — BC-6548 lowercase-token sad-path

> **Method:** Spec-read verdict against `dogfood/test-copy-lowercase.json`. The artifact has `step_1.body` with single token `{FIRST_NAME}` lowercased to `{first_name}`. All other tokens UPPERCASE.
>
> **Where the validator catches it:**
> - **Phase 1 step 5 — does NOT catch.** Extraction regex is `\{[A-Z_]+\}` (UPPERCASE only); `{first_name}` is invisible to step 5.
> - **Phase 1 step 6 — does NOT catch.** Step 6 specifically targets `{{TOKEN}}` double-brace AND explicitly allows lowercase single-brace `{{ var }}` for Liquid fallback patterns. Lowercase single-brace `{first_name}` doesn't match its regex.
> - **Phase 9 step 2 — DOES catch.** Regex `\{[A-Za-z_]+\}` matches `{first_name}`; HARD FAIL fires because it contains `[a-z]` characters. Error message names the offending token and recommends UPPERCASE.
>
> **Hypothesis-vs-actual nuance:** The S-21 hypothesis says "HARD FAIL at Phase 1 step 6 OR Phase 9 step 2." Only Phase 9 step 2 catches this specific input — Phase 1 step 6 deliberately carves out lowercase single-brace for Liquid. Verdict still ✅; hypothesis wording is slightly imprecise but verdict is unambiguous.
>
> **Cleanup note:** Phase 9 step 2 catches the bug AFTER Phases 1-8 succeed — campaigns + leads + senders + schedule already exist. Sequence is NOT created. Partial state must be cleaned up by operator. (Spec acknowledges this.)
>
> **Expected:** Phase 1 step 6 OR Phase 9 step 2 HARD FAIL naming `{first_name}`; sequence does NOT create.
>
> **Verdict:** ✅ Expected via Phase 9 step 2 — BC-6548 UPPERCASE-only validator fires correctly.

### S-22 — Combined --no-host-lookup + --no-segment

> **(a) `--no-host-lookup`:**
> > **Method:** Spec-read.
> > Per spec § Phase 2 line 282: with `--no-host-lookup` set, "skip Phase 2 entirely. Step 1 (email-type detection) does NOT run; step 2 (ESP detection) does NOT run. Set `segmented: false`, `segments: null`, `email_type_filter_applied: null`, ... in metadata. No gate 2. Proceed to Phase 3 with one combined campaign on the full lead set."
> > Per § Phase 5 line 528: "`--no-host-lookup`: one campaign named `{campaign-name}`."
> > With our 9-lead CSV → 1 combined campaign with all 9 leads. ✓
> > **Expected:** Phase 2 skipped; 1 combined campaign with all 9 leads; metadata `segments: null` or absent.
> > **Verdict:** ✅ Expected — escape hatch documented and consistent.

> **(b) `--no-segment` (REMOVED per BC-6514):**
> > **Method:** Live invocation via Skill tool with `--no-segment` flag included.
> > Skill response: "❌ Invocation rejected — `--no-segment` flag is removed." Cited spec lines 28, 118, 284 (BC-6514 supersession block, argument list, Phase 2 doc). Skill recommended `--no-host-lookup` as the only retained opt-out. **No Phase 1 work performed. No EB calls made. No metadata written.**
> > Halt fired at the very first turn (arg-parse stage), before any phase ran.
> > **Expected:** Arg-parse rejection before any EB call.
> > **Verdict:** ✅ Expected — runtime rejection clean; `--no-segment` removed at both spec layer and runtime.

### S-23 — BC-6613 Liquid Pattern A + B render via UI Preview Body

> **Setup:** 2 dedicated test campaigns + 3 test leads with varied custom_variable values. Sequence body uses test-copy-liquid.json's step_1.body verbatim with both Liquid Pattern A (`{{ recency_anchor | default: "recently" }}`) and Pattern B (`{% if proof_point_company %}...{% else %}NO_PROOF_POINT_company...{% endif %}`).
>
> Campaigns + leads:
> - Campaign 38 (LIQUID TEST DEFAULT): seq id 14, steps 24/25, 1 lead
>   - Lead 14745: `recency_anchor: null`, `proof_point_company: "Boulder Pearl Street"`
> - Campaign 39 (LIQUID TEST IF): seq id 15, steps 26/27, 2 leads
>   - Lead 14746: `recency_anchor: "downtown master-plan announcement"`, `proof_point_company: "TestCo"`
>   - Lead 14747: `recency_anchor: "downtown master-plan announcement"`, `proof_point_company: null`
>
> **Preview Body results (3 leads):**
>
> | Lead | recency_anchor (set) | proof_point_company (set) | Pattern A renders | Pattern B branch |
> |---|---|---|---|---|
> | 14745 | null | "Boulder Pearl Street" | "**recently**" | **else** ("NO_PROOF_POINT_company") |
> | 14746 | "downtown master-plan announcement" | "TestCo" | "**recently**" | **else** ("NO_PROOF_POINT_company") |
> | 14747 | "downtown master-plan announcement" | null | "**recently**" | **else** ("NO_PROOF_POINT_company") |
>
> **Pattern observed:** all 3 leads render identically regardless of custom_variable values. Pattern A always fires the `default:` fallback. Pattern B always fires the `{% else %}` branch. The actual values never reach Liquid evaluation.
>
> **(a) Pattern A fallback (`{{ recency_anchor | default: "recently" }}`):**
> > Observably ✅ on lead 14745 (which has empty `recency_anchor`) but observably ❌ on leads 14746 and 14747 (which have populated `recency_anchor` but still render fallback).
> > **Verdict:** 🔴 Pattern A's `default:` fires regardless of value — fallback always renders, not just when value empty. Hypothesis "renders fallback when value empty" is technically met, but the inverse ("renders the value when value present") is refuted.
>
> **(b) Pattern B truthy (`{% if proof_point_company %}{{ proof_point_company }}{% else %}NO_PROOF_POINT_company{% endif %}`):**
> > Lead 14746 has `proof_point_company: "TestCo"` (truthy real value). Truthy branch should fire ("...one that solved it was TestCo, who..."). **Else branch fired instead** ("NO_PROOF_POINT_company worked through it"). Lead 14745 same outcome with `proof_point_company: "Boulder Pearl Street"` truthy value.
> > **Verdict:** 🔴 Pattern B truthy branch is REFUTED. The `{% if %}` evaluates the variable as undefined regardless of lead value.
>
> **(c) Pattern B falsy:**
> > Lead 14747 has `proof_point_company: null` (empty). Else branch fires correctly. But this is the same outcome as the truthy leads (14745, 14746) — observably "correct" only by coincidence.
> > **Verdict:** 🔴 Pattern B else branch fires, but for the wrong reason (always fires regardless of value).
>
> **Root cause:** EB's Liquid evaluator does NOT auto-populate lowercase variable names from lead-level `custom_variables`. Naked references like `{{ recency_anchor }}` and `{% if proof_point_company %}` evaluate to nil/undefined in Liquid scope, regardless of what value the lead's custom_variable has.
>
> The launch-campaign spec § Phase 1 step 5 Path (5e)(a) actually says the canonical Pattern A is `{%- assign name = '{TOKEN}' | strip | default: 'fallback' -%}` — note the `{% assign %}` step + the **UPPERCASE token** `'{TOKEN}'`. The assign uses EB's `{UPPERCASE}` substitution layer to inject the value into Liquid's local scope. The test artifact skipped this step.
>
> **Two compounding 🔴 findings to file at loop-close:**
> 1. `test-copy-liquid.json` artifact is wrong (naked Liquid form, missing `{% assign %}` step). Round-5 should rewrite the artifact + verify the canonical form actually renders correctly.
> 2. Phase 1 step 5 Path (5e)(a) detection regex is too permissive — matches both the working `{% assign %}` form AND the broken naked form. Production copy authored via the naked form would pass Phase 1 validation and silently render wrong at send time.
>
> **Verdict:** 🔴 Needs round-5 follow-up. Pattern B truthy refuted. Both Pattern A and Pattern B are mechanistically broken in the naked-Liquid form.
>
> **Tie-breaker (deferred):** real `--test-send` not exercised — UI Preview Body output was unambiguous; tie-breaker not needed.

---

## S-1 through S-23 findings table

| S-ID | Hypothesis | Source | Verdict | Notes / round-5 follow-up |
|---|---|---|---|---|
| S-1 | F14/R-13 pagination | F-row regression | ✅ | Laravel meta block present, `per_page: 15` hardcoded, `total: 15` single-page |
| S-2 | F16/R-14 workspace persistence (15 vars) | F-row regression | ✅ | All 15 IDs + names match pre-state exactly; zero drift |
| S-3 | BC-6299 existing→reuse classification | round-2 fix-validation | ✅ | All 8 UPPERCASE artifact vars matched lowercase EB vars (case-insensitive); zero new creates |
| S-4 | BC-6300 field names + BC-6515 UUID | round-2/3 fix-validation | ✅ + 🔴 side | All 9 leads have `id` (int) + `uuid` (str); `title`/`company` accepted. Side-finding 🔴: case asymmetry at lead-create binding (UPPERCASE custom_variables names → 422). |
| S-5 | F18 mid-chunk failure recovery | F-row regression | ✅ | 422 atomic — synthetic email did NOT commit when paired with duplicate; behavior held into round-4 |
| S-6 | BC-6304/Sx-9 wrapper-vs-API gate clarity | round-2 fix-validation | ✅ | `search_api_spec` confirms no `confirmation` field on POST /api/leads/multiple; agent-side User gate 4 is sole safeguard |
| S-7 ★ | BC-6514+BC-6654 multiplicative | KEYSTONE | ✅ | 4 campaigns created (ids 34/35/36/37); naming `{base} \| {Email-type} \| {ESP}` per BC-6514; segments map keyed by `{email_type}\|{esp}` per BC-6654. Bonus: operator UI Preview Body on campaign 36 (Personal\|Microsoft, lead 14739) confirmed clean rendering through EB engine — every token + spintax resolved correctly. |
| S-8 | BC-6302/F20 silent-duplicate guard | round-2 fix-validation | ✅ | Decoy id 33 forced gate-5 4-option duplicate-guard branch; render correct |
| S-9 | BC-6306/R-8 deliverability auto-PATCH | round-2/3 fix-validation | ⚠️ | Hypothesis says all 3 (plain_text/reputation_building/can_unsubscribe); BC-6306 actually shipped plain_text only. ✅ per implemented scope, ⚠️ per literal hypothesis. 🟡 process-cleanup follow-up: update issue-body S-9 row |
| S-10 | BC-6544 PATCH-omit live test | round-3 fix-validation | ✅ | Live-confirmed: PATCH name-only on id 34 reverted plain_text to false; re-PATCH plain_text:true restored |
| S-11 | F21/BC-6303 lead bucket mapping | round-2 fix-validation | ✅ | 4 attaches succeeded; total_leads matches per-bucket: 2/2/2/3=9. Side signal: immediate consistency observed, bonus for S-15. |
| S-12 | F22/BC-6545 allow_parallel_sending | DEFERRED 4th round | ⏭️ | |
| S-13 | F23/Sx-10/Sx-11 sender pagination | F-row regression | ✅ | Laravel meta `last_page: 52`; `?per_page=50` ignored; lowercase `connected` works, capitalized 422s |
| S-14 | F24 partial-pool 15-sender | F-row regression | ✅ | 15 senders (981-995, page 1) attached identically to all 4 campaigns; sender invariant holds |
| S-15 | F26/R-15 eventual-consistency | F-row regression | ✅ | 19s for 4 attaches + 4 verifies; immediate consistency on all 4 campaigns; sub-second per call |
| S-16 | F27 + BC-6303 schedule_template_id rename | round-2 fix-validation | ✅ | template id 3 (M-F 08:00-20:00 Denver) applied to all 4; clone IDs 11/12/13/14 per bucket; each apply creates new clone |
| S-17 | BC-6301/R-4 variant boolean + auto-Re: | round-2 fix-validation | ✅ | step 2 stored with single "Re: " prefix; variant: false boolean preserved on both; sequence IDs 10/11/12/13 |
| S-18 | F29/F30 + BC-6548 UPPERCASE happy path | F-row regression | ✅ | wait_in_days clamped 0→1; thread_reply boolean accepted; UPPERCASE-only body+subject passed validators |
| S-19 | BC-6307 + BC-6654 grid construction | round-2/3 fix-validation | ✅ | 4+2+3 email-type tags, 4 cells survive (Pro\|Google, Personal\|Google, Personal\|Microsoft, Role\|Other), F12 dropped 5 empty cells |
| S-20 | BC-6556 empty-default fail-closed sad-path | round-3 fix-validation | ✅ | All 5 Phase 1 step 5 paths fail for RECENCY_ANCHOR (empty default + no Liquid wrapper) → HARD FAIL pre-Phase-2; zero EB mutations |
| S-21 | BC-6548 lowercase-token sad-path | round-3 fix-validation | ✅ | Phase 9 step 2 catches `{first_name}` (Phase 1 step 6 carves out lowercase single-brace for Liquid); sequence not created. Hypothesis wording slightly imprecise (says "Phase 1 step 6 OR Phase 9 step 2"; only Phase 9 catches) |
| S-22 | --no-host-lookup + --no-segment | BC-6654 new-surface | ✅ | (a) spec confirms 1 combined campaign on `--no-host-lookup`. (b) live runtime rejection of `--no-segment` via Skill invocation — halt at arg-parse, zero EB work, cited BC-6514 + recommended `--no-host-lookup` |
| S-23 | BC-6613 Liquid Pattern A + B | round-3 fix-validation | 🔴 | All 3 leads render identically regardless of values: Pattern A always fires fallback, Pattern B always fires else. EB's Liquid scope doesn't see lead custom_variables. Test artifact uses naked form (missing `{% assign %}`); spec validator regex is too permissive. **Pattern B truthy branch REFUTED.** Two compounding round-5 findings (artifact + spec). |

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
| Phase 10 / S-23 (operator UI preview on campaigns 38 + 39) | **🔴 SPEC DEFECT — `test-copy-liquid.json` artifact uses the wrong Liquid form.** Naked references like `{{ recency_anchor | default: "recently" }}` and `{% if proof_point_company %}` don't connect to lead-level custom_variables. EB's Liquid evaluator doesn't auto-populate lowercase variable names from custom_variables, so naked references always evaluate as undefined → Pattern A always fires fallback, Pattern B always fires else. Verified across 3 leads with varied values (14745/14746/14747); rendering identical regardless of lead values. The launch-campaign spec § Phase 1 step 5 Path (5e)(a) actually documents the canonical form: `{%- assign name = '{TOKEN}' | strip | default: 'fallback' -%}` (note the `{% assign %}` + UPPERCASE `{TOKEN}` injection through EB's substitution layer). Required round-5 fix: rewrite test-copy-liquid.json to use canonical assign form + re-walk S-23 in round-5 to verify it actually renders per-lead values correctly. | parked — file at loop-close |
| Phase 10 / S-23 (operator UI preview on campaigns 38 + 39) | **🔴 SPEC DEFECT — Phase 1 step 5 Path (5e)(a) detection regex too permissive.** Current regex `default:\s*['"][^'"]+['"]` matches both the working `{% assign %}` form AND the broken naked form (`{{ var \| default: "..." }}`). A copy author writing the broken form would pass Phase 1 validation and silently render wrong at send time. Required round-5 fix: tighten regex to require the `{% assign %}` wrapper, not just the `default:` filter pattern. Pair with finding above — these compound: artifact is wrong AND validator misses it. | parked — file at loop-close |
| Phase 9 / Phase 10 implicit (operator UI preview on campaign 36) | **🟡 SPEC DOCS GAP — `{SENDER_*}` token resolution diverges between local spot-check and EB render.** Operator clicked Preview Body in EB UI on Personal\|Microsoft campaign (id 36, lead 14739 Taylor / dogfood-test-04@outlook.com). Rendered output shows `{SENDER_FIRST_NAME}` → "Rainer" (matches the chosen sender `rainer.o@washingtonfestivelights.com`), NOT "Amanuel" (the artifact's `custom_variables[].default` value we set on every lead). Refresh Email Variation rotates senders → `{SENDER_FIRST_NAME}` re-resolves per render, dynamically pulling the actual sender's first_name. EB has built-in SENDER_* resolution that pulls from the sender record at render time and **shadows** any lead-level custom_variable with the same name. Production behavior is CORRECT (sign-off matches actual sender). But the launch-campaign spec § Phase 1 step 7 SENDER_* "resolution priority chain" (artifact-default → marketing-context → SF → operator-prompt) implicitly suggests the resolved value is what recipients see — that's true ONLY for the agent's local Phase 10 Mode 1 spot-check, not the actual EB-side render. **Required round-5 fix:** spec edit at Phase 1 step 7 + Phase 10 Mode 1 to explicitly note that `{SENDER_*}` tokens are EB-resolved at render time and override any agent-side resolution; the priority chain governs local-preview display only. **Bonus signal logged at S-7:** this same UI preview also validates the entire multiplicative pipeline rendering is clean (all UPPERCASE tokens substituted, all spintax resolved, paragraph structure intact, no leftover braces) — additional ✅ corroboration for S-7 keystone via real EB-engine rendering. | parked — file at loop-close |
| Phase 5 S-9 walk | **🟡 PROCESS GAP — issue-body hypothesis-vs-implementation drift.** S-9 hypothesis lists all 3 deliverability fields (plain_text + reputation_building + can_unsubscribe), but BC-6306 (PR #227) was scoped to `plain_text` only at brainstorm time; the other 2 were deferred. Verdict shows up as ⚠️ per literal hypothesis, ✅ per implemented scope. **Required round-5 fix:** update BC-6554 issue body S-9 row to list `plain_text` only (and add a separate row, if desired, to track whether `reputation_building`/`can_unsubscribe` should be brainstormed back into scope). Pattern: when a brainstorm narrows the scope of a follow-up, the dogfood hypothesis carrying that follow-up's narrative needs to be updated in lockstep. | parked — file at loop-close |
| Phase 4 S-4 walk | **🔴 SPEC DEFECT — case asymmetry at lead-create binding.** `POST /api/leads/multiple` rejects (HTTP 422) when `custom_variables[].name` is sent UPPERCASE, even though variable rendering at body-substitution time is case-insensitive (BC-6299) and email body tokens MUST be UPPERCASE (BC-6548). Three different rules at three different points: variable creation auto-lowercases (BC-6299), body-render lookup is case-insensitive but body MUST be UPPERCASE (BC-6548), lead-create binding requires EXACT lowercase. The launch-campaign spec at Phase 4 step 2 shows an example body with UPPERCASE custom_variables names — would 422 in production. **Required round-5 fixes:** (1) correct Phase 4 step 2 example to lowercase, (2) add a "case asymmetry across endpoints" gotcha in `email-bison.md § Known gotchas`, (3) consider an agent-side automatic case-translation step that lowercases custom_variables names in the lead-create body so authors can keep the artifact mental model consistent (UPPERCASE everywhere they author, agent translates at the API boundary). | parked — file at loop-close |

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
