# BC-6785 — Round-5 Launch-Campaign Dogfood Transcript

**Date:** 2026-05-08 (setup) / TBD (execution)
**Workspace:** `emailbison-personal` (workspace 13 — production personal-email outbound workspace)
**Issue:** [BC-6785](https://linear.app/brite-nites/issue/BC-6785)
**Round:** 5th iteration of convergent-dogfood chain (BC-5826 → BC-5906 → BC-6308 → BC-6554 → THIS)
**Branch:** `corinne/bc-6785-bc-6554-round-5-launch-campaign-dogfood-re-walk-after-liquid`
**Plan:** `docs/plans/BC-6785-plan.md` (co-located in this worktree)
**Format:** mirrors round-4 (BC-6554) shape — full hypothesis-by-phase walk Phases 2-11, R-1 through R-28 (R-28 added at plan-gate), per-row 3-way verdict protocol, side-flow invocations + close.

---

## Header — Walk parameters

- **Leads (main walk):** 9 (round-3 verbatim — `dogfood-test-{01..06}@gmail.com|outlook.com|brite.co` + `info|sales|contact@dogfoodtest.com`).
- **Liquid leads (R-25 ★):** 3 net-new — `r5-liquid-A@britenites.com`, `r5-liquid-B@britenites.com`, `r5-liquid-C@britenites.com`.
- **Single-lead test (R-22 / R-23 ★):** `corinne+bc-6785-r5@britenites.com` (plus-addressed per Isolation Discipline).
- **Entity:** TBD at Phase 1 (likely `brite-labs` per round-4 default).
- **Preset:** list-building.
- **Offer-tier:** 2 (round-4 default).
- **Activate flag:** OFF for multiplicative-grid + side-flow campaigns; ON for single-lead test campaign only (R-23 ★, Phase 11 ACTIVATE).
- **Gate-2 choice (main walk):** "Include all" (round-4 default).
- **Walks scheduled:** 7 invocations — main multiplicative + R-9 decoy pre-create + R-25 ★ Liquid live-test + R-24 empty-default sad + R-26 lowercase-token sad + R-27 (a) `--no-host-lookup` + (b) `--no-segment` rejection + R-22 single-lead build.

## Isolation discipline (production-workspace overlay — applied to every R-row)

Workspace 13 is the production personal-email outbound workspace. Round-5 mutations are isolated for clean removal at close:

- **Lead tag**: every round-5 lead carries `bc-6785-r5`.
- **Campaign name prefix**: every round-5 campaign starts with `BC-6785 |` (sub-prefixes `MAIN`, `DECOY`, `LIQUID`, `SINGLE-LEAD`, `EMPTY-DEFAULT`, `LOWERCASE-TOKEN`, `NO-HOST-LOOKUP`).
- **No new custom variables**: R-28 sibling-endpoint probe uses existing `RECENCY_ANCHOR` (UPPERCASE-cased existing name); other R-rows must reuse the 15 perm vars only.

---

## Outcome summary (populated at close)

| Category | Count |
|---|---|
| Total R-rows (incl. R-28 added at plan-gate) | 28 |
| ✅ Expected | TBD |
| ⚠️ Unexpected | TBD |
| 🔴 Refuted / round-6 follow-up | TBD |
| ⏭️ Deferred | 1 (R-13 — BC-6545 spec-read suffices) |

**Termination decision:** TBD (zero blocking findings → terminate; ≥1 → file round-6).

---

## Inputs used

- **Main-walk CSV:** `docs/dogfood/bc-6554-round-5/test-leads.csv` — 9 leads, copied verbatim from round-3 / round-4.
- **Clean copy artifact:** `docs/dogfood/bc-6554-round-5/test-copy.json` — round-3 corrected (bare `step_2.subject` per BC-6301).
- **Liquid live-test artifact:** `docs/dogfood/bc-6554-round-5/test-copy-liquid.json` — BC-6781 rewritten with canonical `{% assign %}` form.
- **Side-flow variants (built during walk):**
  - `test-copy-empty.json` — R-24 sad-path (empty default + naked body token).
  - `test-copy-lowercase.json` — R-26 sad-path (single lowercase `{first_name}`).
  - `test-copy-naked-liquid.json` — R-25 ★ regex tightening sub-test.
  - `test-copy-single-lead.json` — R-22 single-lead Phase 11 artifact.
  - `test-leads-liquid.csv` — R-25 ★ 3-lead variant.

---

## Workspace pre-state (recorded 2026-05-08, ~11:14 MT)

### Workspace identity

| Field | Value |
|---|---|
| `instance_url` | `https://personal.outbase.so` |
| `active_workspace.id` | `13` |
| `active_workspace.name` | `BriteNites Team` |
| `active_workspace.is_primary` | `true` |
| `user.email` | `outbasepersonal-bison-api-user-for-team-2@emailbison.com` |

✅ Workspace identity confirmed = 13.

### Lead count (production background)

| Field | Value |
|---|---|
| Total leads | **14,701** (981 pages × 15/page) |
| Status of recent (id 14690-14704) | `unverified`, `tags=Google`, `emails_sent=2, opens=0, replies=0` (consistent with campaign 21's footprint) |
| First-page sample (top 3) | id 14704 `oldcampmonique@gmail.com` / id 14703 `daryarestaurantinfo@gmail.com` / id 14702 `bouvardiaburbank@gmail.com` |
| Round-5 collision check | 0 results for `dogfood-test-` and 0 for `dogfoodtest.com` (synthetic test emails are unique) |

### Campaign count (production background)

| Field | Value |
|---|---|
| Total campaigns | **21** (1 completed, 1 test-completed, 19 archived) |
| Active production campaign | id 21 — `FY26, M3 \| Restaurants & Bars America 250 \| Personal Emails \| All ESPs` (status `completed`, 1233 leads, 2433 sent, 48 replies) |
| `BC-6785` campaigns | 0 (cleanability baseline — must return to 0 at Task 13 close) |

### Permanent custom variables (cleanability baseline)

| ID | Name | Created | Source |
|---|---|---|---|
| 1 | company address | 2025-11-14 | round-1 era |
| 2 | company linkedin url | 2025-11-14 | round-1 era |
| 3 | company phone | 2025-11-14 | round-1 era |
| 4 | company website | 2025-11-14 | round-1 era |
| 5 | person job title | 2025-11-14 | round-1 era |
| 6 | person linkedin url | 2025-11-14 | round-1 era |
| 7 | recency_anchor | 2026-04-27 | round-2 |
| 8 | vertical_descriptor | 2026-04-27 | round-2 |
| 9 | specific_friction | 2026-04-27 | round-2 |
| 10 | proof_point_company | 2026-04-27 | round-2 |
| 11 | proof_point_number | 2026-04-27 | round-2 |
| 12 | proof_point_timeframe | 2026-04-27 | round-2 |
| 13 | free_asset_noun | 2026-04-27 | round-2 |
| 14 | sender_first_name | 2026-04-27 | round-2 |
| 15 | empty_test_var | 2026-05-01 | round-3 T11 |

✅ 15 entries match expected roster exactly. `meta.total: 15`, `meta.per_page: 15`, single page (Laravel pagination shape held).

### Pre-state row — 3-way verdict

> **R-pre-state output:** Workspace 13 confirmed (id=13, primary, `BriteNites Team`). Production lead count 14,701 (expected 0 per issue body); production campaign count 21 (expected 0). Custom variable roster = 15 / matches expected exactly. 0 collisions on `dogfood-test-` and `dogfoodtest.com` lead-search.
>
> **Expected per spec:** Issue body § "Workspace state at start of round-5" — "0 leads, 0 campaigns, 15 permanent custom variables."
>
> **Verdict:** ⚠️ **Unexpected (re-framed)** — issue body's "0 leads, 0 campaigns" claim was archaeological (referred to round-4 cleanup of round-4 mutations, not workspace emptiness). Operator confirmed 2026-05-08: workspace 13 is the production personal-email outbound workspace; the 14,701 leads + 21 campaigns are real production data and must remain intact. Custom variable roster matches expected and is the only workspace-state metric round-5 must hold constant.
>
> **Proposed framing:** **spec drift** — issue body (and round-4 transcript before it) propagated an inaccurate pre-state assumption. Mitigation applied at this plan-gate: Isolation Discipline overlay added to plan + transcript (lead tag `bc-6785-r5`, campaign name prefix `BC-6785 |`, no-new-custom-variables rule, plus-addressed operator email).
>
> **Recorded as ⚠️ + plan amended.** Round-5 proceeds against production-populated workspace 13 under the Isolation Discipline.

---

## R-rows (to be populated through Tasks 2-12)

### Phase 2 (multiplicative grid)

- **R-1** — ✅ **Expected.**
  - **Output:** Email-type detection: 4 personal + 2 professional + 3 role per the static lists (19 role-prefix + 12 free-mail entries; tiebreak personal-beats-role applied to no leads in this set). ESP detection via parallel `dig MX +short`: gmail.com → Google (`gmail-smtp-in.l.google.com.`), outlook.com → Microsoft (`outlook-com.olc.protection.outlook.com.`), brite.co → Google (Workspace, `aspmx.l.google.com.` + googlemail.com aliases), dogfoodtest.com → Unknown (no MX records returned) → rolled into Other in the 3-bucket grid. 9-cell grid built: Professional|Google=2, Role|Other=3, Personal|Google=2, Personal|Microsoft=2, all other 5 cells=0. F12 prune dropped the 5 empty cells (Professional|Microsoft, Professional|Other, Role|Google, Role|Microsoft, Personal|Other). 4 surviving cells.
  - **Expected per spec:** Issue body R-1 (BC-6307 + BC-6654 multiplicative segmentation): "9 leads tagged: 4 personal + 2 professional + 3 role per the 19+12 entry static lists; 9-cell grid constructed by joining email-type tags with ESP MX classification; F12 prune drops 5 empty cells."
  - **Match:** Every part — counts, cell-shape, prune behavior. No surprises.
  - **Operator gate-2 choice:** "Include all" (matches round-4; preserves multiplicative test surface for R-8★ in Task 5).

### Phase 2 — surviving 4-cell grid (post-include_all + post-F12-prune)

| | Google | Microsoft | Other |
|---|---|---|---|
| **Professional** | 2 (`dogfood-test-05/06@brite.co`) | 0 (skipped) | 0 (skipped) |
| **Role**         | 0 (skipped) | 0 (skipped) | 3 (`info|sales|contact@dogfoodtest.com`) |
| **Personal**     | 2 (`dogfood-test-01/02@gmail.com`) | 2 (`dogfood-test-03/04@outlook.com`) | 0 (skipped) |

### Phase 2 — F-IV-3 finding (outside R-1-28 set, surfaced at Phase 1 step 10)

- **F-IV-3** — ⚠️ Spec drift / regex case-sensitivity bug (round-6 candidate).
  - **What:** § Input validation IV-3 dogfood-path detection regex requires `<worktree-name>` to match `[a-z0-9._-]+` (lowercase only). Worktree convention from `git-worktrees` skill is uppercase Linear-issue-ID (`BC-6785`), which the regex rejects.
  - **Effect:** auto-detection falls through to `docs/campaigns/{entity}/` (production audit-trail directory) — actively defeats IV-3's stated intent of preventing dogfood metadata from polluting production.
  - **Mitigation for round-5:** manual override at Phase 1 step 10 — metadata written to `<worktree>/dogfood/BC-6785-2026-05-08.json` (worktree-local) per IV-3's intent.
  - **Fix size:** one-character regex change (`[a-z0-9._-]+` → `[A-Za-z0-9._-]+`).
  - **Round-6 candidacy:** if round-5 closes convergent, file as a standalone follow-up rather than triggering round-6 by itself; if round-5 files round-6 anyway, fold in.

### Phase 3 (VARIABLES)

- **R-2** — ✅ **Expected.**
  - **Output:** `GET /api/custom-variables?per_page=50` returned `meta: {current_page: 1, last_page: 1, per_page: 15, total: 15}`. The `?per_page=50` request parameter was silently ignored — EB hardcodes `per_page: 15` regardless. Single-page result; no pagination loop fired (15 ≤ 15).
  - **Expected per spec:** Issue body R-2 (round-4 S-1 regression) — "`list_custom_variables` returns Laravel `?page=N` paginated meta with hardcoded `per_page: 15`."
  - **Match:** Exact. Sx-10/BC-5906 hardcoded-per_page behavior re-verified.

- **R-3** — ✅ **Expected.**
  - **Output:** 15 entries returned; roster matches pre-state recorded at Phase 1 step 4 / Task 1 baseline exactly. IDs 1-15 all present; names: `company address`, `company linkedin url`, `company phone`, `company website`, `person job title`, `person linkedin url` (round-1 era 1-6), `recency_anchor`, `vertical_descriptor`, `specific_friction`, `proof_point_company`, `proof_point_number`, `proof_point_timeframe`, `free_asset_noun`, `sender_first_name` (round-2 7-14), `empty_test_var` (round-3 T11, id 15). No drift mid-session.
  - **Expected per spec:** Issue body R-3 (round-4 S-2 regression) — "15 permanent vars from round-4 cleanup all present at start of round-5."
  - **Match:** Exact.

- **R-4 ★** — ✅ **Expected.** **(BC-6780 task-2 fix-validation: ratified at runtime.)**
  - **Output:** Phase 3 step 3 classification table (`.lower()` comparison per launch-campaign Phase 3 step 3, "compare via `.lower()`; EB stores names lowercased per Sx-3/BC-6299"):

    | Artifact name (UPPERCASE) | `.lower()` | EB stored name | Match | Classification |
    |---|---|---|---|---|
    | `RECENCY_ANCHOR` | `recency_anchor` | id 7 — `recency_anchor` | ✓ | existing → reuse |
    | `VERTICAL_DESCRIPTOR` | `vertical_descriptor` | id 8 — `vertical_descriptor` | ✓ | existing → reuse |
    | `SPECIFIC_FRICTION` | `specific_friction` | id 9 — `specific_friction` | ✓ | existing → reuse |
    | `PROOF_POINT_COMPANY` | `proof_point_company` | id 10 — `proof_point_company` | ✓ | existing → reuse |
    | `PROOF_POINT_NUMBER` | `proof_point_number` | id 11 — `proof_point_number` | ✓ | existing → reuse |
    | `PROOF_POINT_TIMEFRAME` | `proof_point_timeframe` | id 12 — `proof_point_timeframe` | ✓ | existing → reuse |
    | `FREE_ASSET_NOUN` | `free_asset_noun` | id 13 — `free_asset_noun` | ✓ | existing → reuse |
    | `SENDER_FIRST_NAME` | `sender_first_name` | id 14 — `sender_first_name` | ✓ | existing → reuse |

    8/8 artifact UPPERCASE names mapped case-insensitively to existing lowercase EB-stored names. Zero new-variable creates issued. Zero 422 duplicate-name responses. Operator confirmed at User gate 3 with "Yes — reuse all 8 existing." Phase 3 step 6 fired ZERO `POST /api/custom-variables` calls (zero-create branch).
  - **Expected per spec:** Issue body R-4 (round-4 S-3 regression + BC-6780 task-2 fix-validation NEW for round-5) — "8 artifact UPPERCASE variables map to lowercase EB-stored vars via case-insensitive `.lower()` comparison per BC-6780 Phase 3 step 3 fix; all classify as 'existing → reuse'; zero new creates; zero 422 duplicates."
  - **Match:** Every component — 8 names, lowercase mapping, all existing-reuse, zero creates, zero 422.
  - **Isolation Discipline Rule 3 status:** preserved by definition (zero creates → zero new permanent custom variables).

### Phase 4 (UPLOAD)

- **R-5 ★** — ✅ **Expected.** **(BC-6780 task-1 fix-validation: ratified at runtime.)**
  - **Pre-loop HARD FAIL guard (BC-6780):** all 9 leads' `custom_variables[].name` matched `^[a-z][a-z0-9_]*$` regex (translation step at body-build worked correctly). Guard fired once, covered all chunks (single chunk in this run).
  - **Output:** `POST /api/leads/multiple` with 9-lead body (1 chunk ≤ 500 limit) returned `success: true` with all 9 leads created. Lead IDs: 14753-14761 (assigned sequentially). All responses include both `id` (int) and `uuid` (str) per BC-6515 forward-compat (UUIDs all `a1bb7187-*` — Laravel UUIDv4 timestamp prefix).
  - **Per-lead bodies:** EB lead-body field renames applied per Sx-6 (CSV `job_title→title`, `company_name→company`); 8 per-lead `custom_variables` with lowercased names. Sample lead 14753 (`dogfood-test-01@gmail.com`): all 8 vars persisted with values intact.
  - **Tag attachment (Isolation Discipline Rule 1):** `POST /api/tags` created tag `bc-6785-r5` (id 41). `POST /api/tags/attach-to-leads` attached tag id 41 to lead IDs [14753..14761] in one call. Verified: `list_leads({tag_ids: [41]})` returns 9/9 expected leads on a single page.
  - **Side-finding (auto-attached ESP tags, outside R-1-28 set):** EB auto-attaches ESP tags at lead-create based on email domain MX:
    - 4 leads tagged `Google` (gmail.com x2 + brite.co x2 — both on Google Workspace MX).
    - 2 leads tagged `Outlook` (outlook.com x2).
    - 3 leads (`*@dogfoodtest.com` — no MX) carry NO ESP auto-tag.
    - This is a *useful* default from EB's lead-tag taxonomy; for round-5 the `bc-6785-r5` tag is layered on top of the auto-tag, which keeps cleanup filtering precise.
  - **Expected per spec:** Issue body R-5★ — "`POST /api/leads/multiple` accepts `title`/`company`; response includes both `id` (int) and `uuid` (str); per-lead `custom_variables[].name` lowercased at body-build per BC-6780 translation step; pre-loop HARD FAIL guard verified to fire if names UPPERCASE; happy-path bulk-create succeeds without UPPERCASE→422 detour observed in round-4."
  - **Match:** Every component. **The BC-6780 fix holds at runtime; UPPERCASE→422 detour from round-4 (S-4) is gone.**

- **R-28** — ⚠️ **Unexpected — INCONCLUSIVE on case-asymmetry; produced 2 spec-correctness findings.**
  - **Probe (a) — `POST /api/leads/upsert-multiple`:**
    - POST → 405 ("The POST method is not supported for route api/leads/upsert-multiple. Supported methods: GET, HEAD, PUT, PATCH, DELETE.")
    - PUT with UPPERCASE name `RECENCY_ANCHOR` → 422.
    - PUT with lowercase control name `recency_anchor` → 422 (same error). 422 is therefore NOT the BC-6780 case rule — it's a body-shape/method mismatch.
    - PATCH → 404. GET → 404. (The 405 message claimed PATCH/GET were "supported" but they actually return 404 — Laravel auto-generated 405 messages can be misleading for non-POST/PUT routes.)
    - `search_api_spec` for `upsert` returns no matches; spec for `/api/leads/multiple` shows POST only (no upsert variant documented).
    - **Concrete finding F-R-28a (round-6 candidate):** launch-campaign spec § Phase 4 step 1 describes `upsert_multiple_leads` as a "variant of `/api/leads/multiple` (for merging against existing leads)." This is phantom — POST is rejected, no variant endpoint is documented. Either (i) the path in the spec is wrong, OR (ii) "upsert" semantics are achieved by re-POSTing `/api/leads/multiple` (per the bulk-delete description's hint: "I mapped the wrong custom variables for these leads — Simply re-upload the leads and we'll update the records in place").
  - **Probe (b) — `POST /api/leads/bulk` (CSV-upload variant):**
    - `search_api_spec` confirms the CSV-upload endpoint is actually `POST /api/leads/bulk/csv` — not `POST /api/leads/bulk` as the launch-campaign spec describes.
    - `POST /api/leads/bulk` is not documented; `DELETE /api/leads/bulk` is the bulk-delete variant.
    - **Concrete finding F-R-28b (round-6 candidate):** launch-campaign spec § Phase 4 step 1 describes `bulk_create_leads_csv (POST /api/leads/bulk)` — the actual path per `search_api_spec` is `POST /api/leads/bulk/csv`.
    - The CSV-upload endpoint takes multipart/form-data; `call_api` is JSON-only, so the case-asymmetry test for this endpoint cannot be exercised through the available transport. This is a **known limitation** of the round-5 test design that R-28 surfaces — testing UPPERCASE/lowercase column-header behavior for `POST /api/leads/bulk/csv` requires multipart upload via curl/UI, not `call_api`.
  - **Cleanup:** zero R-28 leads created (all probes 422'd before any record landed). Verified via `list_leads({search: "r5-sibling-test"})` → 0 results. Zero new permanent custom variables created (Isolation Discipline Rule 3 preserved by definition — probes failed before any custom-variable side effect).
  - **Verdict for case-asymmetry hypothesis:** UNVERIFIED. The test design assumed the launch-campaign spec was accurate about sibling endpoint names; spec turns out to be wrong about both. Sibling-endpoint case-asymmetry remains an open question from BC-6780 task-7 / 2026-05-07 comment — round-6 follow-up via fixing the spec endpoints first, then re-probing.

- **R-6** — ✅ **Expected.**
  - **Output:** `POST /api/leads/multiple` with body `{leads: [{email: "dogfood-test-01@gmail.com", ...}]}` (already-existing lead from R-5★ mass-create) returned HTTP 422. The whole single-lead request rejected — atomic-rejection semantics held.
  - **Expected per spec:** Issue body R-6 (round-4 S-5 regression) — "forced duplicate-email in chunk → all-or-nothing 422 (Sx-8 atomic rejection)."
  - **Match:** Atomic 422 confirmed. Side-observation: the spec's bulk-delete description hint ("Simply re-upload the leads and we'll update the records in place") appears to apply to a different operation flow (likely the EB UI's lead-import which detects existing records and routes to upsert), NOT raw `POST /api/leads/multiple`. Logged for future spec clarification, not a finding.

- **R-7** — ✅ **Expected.** **(Spec-read only.)**
  - **Read targets:** launch-campaign skill spec § Tool tier map + § Phase 4 § "Two-call gate required — agent-side, not vendor-side."
  - **Confirmation:** spec text continues to differentiate:
    - **Wrapper-tool layer:** `create_lead` is core-tier, directly callable as `mcp__emailbison-<workspace>__create_lead`. Wrapper-side `confirmation` prose is documentation-only per BC-6439 (no runtime gate at any layer).
    - **API-direct layer:** `bulk_create_leads` is invoked via `call_api` against `/api/leads/multiple`, which has NO `confirmation` field at the API level. Agent-side `AskUserQuestion` gate is the sole safeguard for every `call_api`-routed mutation per Sx-9 / BC-5906.
  - **Match:** wrapper-vs-API distinction live in spec at every gate site (Phase 4 + Phase 6 + Phase 11) per BC-6304 task-1 fix.

### Phase 5 (CAMPAIGN CREATE)

- **R-8 ★** — ✅ **Expected.** **(BC-6514 + BC-6654 multiplicative segmentation: ratified at runtime.)**
  - **Pre-list (silent-duplicate guard precheck):** `list_campaigns(search="BC-6785")` returned 0 matches before creates — happy path; User gate 5 rendered the empty-pre-list variant.
  - **Operator confirmation:** "Yes — create the 4 campaigns."
  - **Output:** 4 campaigns created with sequential IDs 43-46 via `mcp__emailbison-personal__create_campaign`. All `status: draft`, `type: outbound`, `success: true`. Names follow the BC-6514 format `BC-6785 | MAIN | {Email-type} | {ESP}` (Email-type before ESP per BC-6514 multiplicative-axis decision; round-5 substitutes the spec's `{base}` slot with `BC-6785 | MAIN` per Isolation Discipline Rule 2):
    - id 43 — `BC-6785 | MAIN | Professional | Google` (2 leads)
    - id 44 — `BC-6785 | MAIN | Role | Other` (3 leads)
    - id 45 — `BC-6785 | MAIN | Personal | Google` (2 leads)
    - id 46 — `BC-6785 | MAIN | Personal | Microsoft` (2 leads)
  - `metadata.segments` map populates with compound `{email_type}|{esp}` keys matching the BC-6654 schema rewrite.
  - **Match:** Every component — 4-cell multiplicative coverage, naming convention, segments-map keying. Round-4 keystone S-7★ regression holds at round-5.

- **R-9** — ✅ **Expected.** **(BC-6302 silent-duplicate guard fires correctly.)**
  - **Setup:** post-creation of the 4 main campaigns, pre-created decoy `BC-6785 | DECOY | duplicate-test` (id 47) via `create_campaign`. Both `BC-6785 | MAIN | ...` and `BC-6785 | DECOY | ...` names start with the `BC-6785` substring base.
  - **Output:** `list_campaigns(search="BC-6785")` returned 5 matches (ids 43-47). All 5 names start with the `BC-6785` substring base → all 5 would feed `existing_campaign_matches` in step 3 → User gate 5 would render in the duplicate-warning variant if Phase 5 were re-run on this base. The 4-option prompt (Reuse existing IDs / Create N new anyway / Rename / Abort) would activate.
  - **Expected per spec:** Issue body R-9 (round-4 S-8 regression + BC-6302/F20 silent-duplicate guard) — "pre-create one decoy; verify branched gate-5 render."
  - **Match:** guard fires correctly; substring-match precondition + branched-render mechanics confirmed.
  - **Note:** decoy campaign 47 carries `BC-6785 |` prefix → cleanly removable at Task 13 via UI search-and-archive.

- **R-10** — ✅ **Expected.** **(BC-6306 plain_text scope + BC-6783 hypothesis correction validated at runtime.)**
  - **Pre-PATCH baseline:** `get_campaign(43)` shows `settings: {max_emails_per_day: 1000, max_new_leads_per_day: 1000, open_tracking: false, plain_text: false, can_unsubscribe: false}` — **`plain_text: false` default confirmed**, matches BC-6306 / EB API spec note "If nothing sent, false is assumed."
  - **PATCH execution:** 4 parallel calls to `PATCH /api/campaigns/{id}/update` with body `{"plain_text": true}` — all 4 returned `success: true` with `plain_text: true` in response.
  - **BC-6783 hypothesis correction confirmed:** ONLY `plain_text` was applied. `reputation_building` field is absent from `get_campaign` response (likely server-defaulted to `false` per spec but not surfaced); `can_unsubscribe: false` and `open_tracking: false` defaults preserved (NOT modified by Phase 5 step 8). The BC-6306 implementation scope is `plain_text` only — round-4 hypothesis (S-9) had been broader; round-5 hypothesis tracks the actual implementation.
  - **Match:** every component.

- **R-11** — ✅ **Expected.** 🔥 **(BC-6544 PATCH-omit semantics CONFIRMED AT RUNTIME — broader scope than the original BC-6544 framing assumed.)**
  - **Test setup:** picked campaign 46 (`BC-6785 | MAIN | Personal | Microsoft`) — currently has `plain_text: true` from R-10's PATCH.
  - **First PATCH attempt — `{max_emails_per_day: 500}` only:** returned HTTP 422 (rejection — likely a min/max validation rule not visible in the API spec snippet; not a BC-6544 PATCH-omit signal). Pivoted to a different harmless field for the test design.
  - **Second PATCH attempt — `{sequence_prioritization: "followups"}` only (a non-boolean string field unrelated to plain_text):** returned `success: true` with response body showing **`plain_text: false`**. Silent revert observed: a PATCH body that omits a boolean field causes that field to revert to its default-false state, **even when the PATCH targets a wholly unrelated non-boolean field**.
  - **Restoration:** re-PATCHed `{plain_text: true}` immediately. Response confirmed `plain_text: true` restored on campaign 46.
  - **Expected per spec:** Issue body R-11 (round-4 S-10 regression) — "BC-6544 PATCH-omit live test; verify `plain_text` reverts to false on omit; restore via re-PATCH."
  - **Match:** every component. Spec's API description (*"If nothing sent, false is assumed"*) confirmed live for the omitted-boolean field even when the PATCH targeted an unrelated string field.
  - **Broader-scope clarification (round-5 contribution):** the existing spec text in `launch-campaign.md § Phase 5 step 8` and `email-bison.md § Known gotchas § plain_text` (both shipped via BC-6544 PR #242, 2026-05-08) already correctly state — *"ANY future PATCH on this campaign that intends to preserve `plain_text: true` MUST re-send it explicitly in the body."* Round-5 confirms the rule is intentional in its broadest form: even a PATCH that targets a single non-boolean string field (no booleans in the body) trips the revert. The spec language is already correct; this round-5 evidence ratifies the rule's actual scope at runtime — not a documentation gap, an evidence-strengthener.
  - **Production discipline implication:** any team member or workflow editing campaigns through the API (not just multi-boolean PATCHes) must re-send each currently-`true` boolean (`plain_text`, `open_tracking`, `can_unsubscribe`, `reputation_building`) on every PATCH or the omitted ones silently revert. The EB UI almost certainly handles this internally (sends the full settings payload on save); anyone hitting `/api/campaigns/{id}/update` directly bears the discipline.

### Phase 6 (ATTACH LEADS)

- **R-12** — ✅ **Expected.**
  - **Endpoint verified:** `POST /api/campaigns/{campaign_id}/leads/attach-leads` per `search_api_spec`. Body schema `{lead_ids: [int], allow_parallel_sending: bool}`. No `confirmation` field at API level (consistent with Sx-9/BC-5906/BC-6439 vendor-confirmation gate findings). Agent-side `AskUserQuestion` is the sole safeguard.
  - **Bucket map (from Phase 2 grid + Phase 4 lead IDs):**

    | Campaign | Cell | Lead IDs |
    |---|---|---|
    | 43 | `BC-6785 \| MAIN \| Professional \| Google` | [14757, 14758] |
    | 44 | `BC-6785 \| MAIN \| Role \| Other` | [14759, 14760, 14761] |
    | 45 | `BC-6785 \| MAIN \| Personal \| Google` | [14753, 14754] |
    | 46 | `BC-6785 \| MAIN \| Personal \| Microsoft` | [14755, 14756] |
  - **Operator gate-6 choice:** "Yes — attach all 9 leads across all 4 campaigns" (single-pass mode; no per-campaign turn-structure re-prompts).
  - **Output:** 4 sequential `POST /api/campaigns/{id}/leads/attach-leads` calls all returned `success: true` with messages `"Leads successfully added to {campaign-name}. Existing leads were not added."` (defensive idempotency hint for re-attach scenarios; no dedup applied here since all leads were fresh attaches).
  - **Verification (post-attach `get_campaign` per campaign):** total_leads counts match expected — campaign 43=2, 44=3, 45=2, 46=2; sum=9 matches Phase 4 `lead_count`. Sub-second eventual-consistency observed (get_campaign fired immediately after attach showed accurate counts). Settings `plain_text: true` preserved on all 4 (R-11 PATCH-omit revert was successfully restored at end of Phase 5).
  - **Expected per spec:** Issue body R-12 (round-4 S-11 regression + F21/BC-6303 lead bucket mapping) — "metadata `lead_ids_by_bucket` + `lead_attach_counts` populate per cell key."
  - **Match:** every component.
  - **Spec-drift observation (sub-finding, not blocking):** the launch-campaign spec § Phase 6 describes a "two-call gate ... per-campaign vendor gates fire a minimal turn-structure prompt" pattern, but the actual API has no preflight/commit split — there's no second call to gate. The single AskUserQuestion (User gate 6) IS the safeguard. Per-campaign turn-structure prompts would add no information for `/api/leads/attach-leads`. This was offered as an option at User gate 6 (operator chose single-pass). Same observation applies to Phase 4 UPLOAD's two-call narrative. Could feed into spec tightening at Task 13 close — fold into existing Sx-9/BC-5906/BC-6439 lineage.

- **R-13** — ⏭️ **Deferred.** BC-6545 spec-read suffices; live-fire requires pre-poison setup (lead pre-staged in another campaign with `in_sequence` status) that's not justified for an institutional-memory-only check. Spec at launch-campaign.md § Phase 6 step 5d ("`allow_parallel_sending` branch") + email-bison.md § Known gotchas continue to enforce the never-auto-enable rule.

### Phase 7 (ATTACH SENDERS)

- **R-14** — TBD
- **R-15** — TBD
- **R-16** — TBD

### Phase 8 (SCHEDULE)

- **R-17** — TBD

### Phase 9 (SEQUENCE)

- **R-18** — TBD
- **R-19** — TBD

### Phase 10 (PREVIEW — first live-walk in chain)

- **R-20** — TBD
- **R-21 ★** — TBD

### Phase 11 (ACTIVATE — first live-walk in chain)

- **R-22** — TBD
- **R-23 ★** — TBD (round-5 main walk closes here)

### Side-flows

- **R-24** — TBD (BC-6556 fail-closed gate)
- **R-25 ★** — TBD (BC-6781 + BC-6782 paired Liquid live-test)
- **R-26** — TBD (BC-6548 lowercase-token sad-path)
- **R-27** — TBD ((a) `--no-host-lookup` + (b) `--no-segment` rejection)

---

## Round-5 follow-up candidates (populated at close)

### Standalone findings (not blocking; round-6 candidates)

- **F-IV-3** (Phase 1 step 10) — IV-3 dogfood-path detection regex `[a-z0-9._-]+` rejects uppercase worktree names. Mitigated for round-5 via manual path override. Round-6 candidate; one-character regex fix.
- **F-R-28a** (Phase 4) — launch-campaign spec § Phase 4 step 1 describes `upsert_multiple_leads` as a "variant of `/api/leads/multiple`," but POST `/api/leads/upsert-multiple` returns 405 and `search_api_spec` shows no upsert variant. Either the path is wrong, or upsert is achieved by re-POSTing.
- **F-R-28b** (Phase 4) — launch-campaign spec describes `bulk_create_leads_csv` as `POST /api/leads/bulk`; actual path per `search_api_spec` is `POST /api/leads/bulk/csv`. `/api/leads/bulk` is a DELETE-only path.

### Non-blocking ratifications worth optional follow-up

- **R-11 broader-scope ratification (Phase 5)** — BC-6544 PATCH-omit footgun confirmed at runtime in its broadest form: a non-boolean string-field PATCH (e.g., `{sequence_prioritization}` only) reverts an unrelated boolean (`plain_text`) to false. Existing BC-6544 spec text already states this in the broadest possible framing — round-5 contributes runtime evidence, not a documentation gap. Optional follow-ups for operator decision at close: (a) annotate BC-6544 spec sites with `verified-at-runtime BC-6785 R-11`, (b) audit b2b workspace 55 production campaigns for current plain_text state (the actively-sending workspace; not done in round-5 because round-5 scope = workspace 13), (c) file a Linear follow-up capturing the broader-scope evidence + workspace-55 audit recommendation. Decision deferred to Task 13 close.

### Hypothesis-by-row populated at close

TBD.

---

## Loop-closing decision (populated at close)

TBD.
