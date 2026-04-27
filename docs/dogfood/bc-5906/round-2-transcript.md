# BC-5906 Round-2 Launch Dogfood — Transcript

**Date:** 2026-04-27
**Workspace:** `emailbison-personal` (id 13, BriteNites Team)
**Leads:** 6 (reused verbatim from BC-5826 round-1 — `dogfood-test-NN@gmail.com`/`@outlook.com`/`@brite.co`)
**Entity:** brite-labs
**Preset:** list-building / municipalities
**Offer tier:** T2
**Activate:** OFF (draft-only — no real emails sent)
**Round-1 reference:** `docs/dogfood/bc-5826/dogfood-transcript.md`

## Outcome

*(filled at end of walk)*

## Inputs used

**CSV** — `.claude/worktrees/bc-5906/dogfood/test-leads.csv` (verbatim copy of `docs/dogfood/bc-5826/test-leads.csv`). 6 leads, 3 distinct domains: gmail.com (×2), outlook.com (×2), brite.co (×2). All `dogfood-test-NN@…` fake local-parts so no real mail can be sent even if `--activate` were fat-fingered.

**Copy artifact** — `.claude/worktrees/bc-5906/dogfood/test-copy.json` (verbatim copy of `docs/dogfood/bc-5826/test-copy.json`). T2 free-asset, list-building preset, municipalities vertical. 8 custom variables in step_1 body, 1 in step_2 body, 0 in either subject (all spintax in subjects).

**Brainstorm decisions (2026-04-27):**
1. Reuse round-1 inputs verbatim (no new lead authoring).
2. ESP-segmented (default — Google + Microsoft after F12 skip-empty drops Other).
3. F22 deferred (requires pre-poisoning; not load-bearing for MVP launch path).
4. Refuted/needs-more-work hypotheses captured inline in this transcript; Linear follow-ups filed batched at session end.

## Command invocation

```
/marketing:launch-campaign \
  --csv .claude/worktrees/bc-5906/dogfood/test-leads.csv \
  --copy-artifact .claude/worktrees/bc-5906/dogfood/test-copy.json \
  --workspace emailbison-personal \
  --campaign-name "BC-5906 Round 2" \
  --entity brite-labs
```

Default segmentation ON. No `--activate`, `--no-segment`, `--no-host-lookup`, `--no-sequence`, `--preview`, `--test-send`, or `--reference`.

---

## Phase 1 PRE-FLIGHT — pre-walk summary

Skipped formal walk (read-only; round-1 validated). Verified inputs in place at `.claude/worktrees/bc-5906/dogfood/`: 6 leads (1 header + 6 rows in CSV), copy artifact `schema_version: "1.0"`. The `--entity brite-labs --workspace emailbison-personal` cross-mapping is expected per F2 (dogfood) — metadata write path will route under `.claude/worktrees/bc-5906/dogfood/` per IV-3.

## Phase 2 HOST LOOKUP — pre-walk summary

Bash `dig` MX resolution against the 3 unique domains in the CSV (gmail.com, outlook.com, brite.co):

- `gmail.com` → MX `gmail-smtp-in.l.google.com` family → **Google bucket**
- `outlook.com` → MX `outlook-com.olc.protection.outlook.com` → **Microsoft bucket**
- `brite.co` → MX `aspmx.l.google.com` (Google Workspace) → **Google bucket** (matches round-1's non-obvious finding)

Distribution: **Google 4 / Microsoft 2 / Other 0**. F12 skip-empty drops Other → 2 segments survive (Google + Microsoft).

---

## Spec-vs-reality findings — pre-execution recon (worth flagging up front)

These four findings emerged from `search_api_spec` recon BEFORE any creates fired. They cross-cut the F14–F31 hypotheses and warrant separate follow-up issues:

**Sx-1. `search_api_spec` matches URL paths + summary, not descriptive phrases.** Searching for `"custom variable list"` and `"custom variable create"` returned no matches; `"/api/custom-variables"`, `"custom-variables"`, and `"variables"` all matched. Operators following the spec's "ground-truth via `search_api_spec`" instruction will hit dead-ends if they search by descriptive operation name. Spec wording should suggest URL-path-style queries or known partial keywords. Cross-cuts every Phase 3–11 ground-truth step.

**Sx-2. Custom variables have NO `default` field at the API level.** `POST /api/custom-variables` accepts only `{name}` (required). `GET /api/custom-variables` returns `{id, name, created_at, updated_at}`. The launch-campaign.md spec's framing of "create variables with defaults" and Phase 3 step 4's "default in workspace: '<value>'" rendering are spec fictions. Defaults exist only at the lead level (per `bulk_create_leads`'s `custom_variables: [{name, value}]` per-lead array). This invalidates Phase 3's conflict-resolution gate (the "keep existing default vs overwrite with artifact default" choice has no real referent).

**Sx-3. EB lowercases variable names on create.** Sent `RECENCY_ANCHOR` (uppercase, per the copy artifact); EB stored `recency_anchor` (lowercase). Same for all 8 of our SCREAMING_SNAKE_CASE names. Render-engine case-sensitivity is unknown; Phase 4 + Phase 10 lead spot-check will reveal whether `{RECENCY_ANCHOR}` in body resolves to the lowercase-stored value. If render is case-sensitive, every existing copy artifact in the codebase that uses uppercase merge tokens silently fails to render.

**Sx-4. NO DELETE endpoint for `/api/custom-variables`.** `search_api_spec` with method=DELETE returns "no matching endpoints". Custom variables created during this dogfood persist in the workspace forever (only deletable via EB UI). The launch-campaign spec's cleanup wording "delete custom variables (or document why they can stay)" implies the option to delete via the dogfood flow — which is impossible. T11 cleanup is variables-can't-be-deleted by default.

**Sx-5. EB API spec lies about required fields.** `/api/leads` POST schema marks `last_name` (and `first_name`, `email`) as `"required": [...]`, but the API silently accepts a body without `last_name` and stores `null`. `search_api_spec` results cannot be trusted to determine optional-vs-required; ground-truthing requires actual API call. Cross-cuts every Phase that builds request bodies from the spec. Also implicates F17 — the spec's claim was wrong, the actual launch-campaign spec was right.

**Sx-6. Launch-campaign spec Phase 4 step 2 lead-body field names are wrong.** Spec builds `{job_title, company_name, company_domain}`; EB API uses `{title, company}` and has no `company_domain` field. Fields like `job_title` are silently ignored on POST (verified — leads created with `title: null` if `title` is not sent). The current command file at `plugins/marketing/commands/launch-campaign.md:332-347` will produce leads with NULL `title`/`company` if executed as written. Hard fail for production — data loss disguised as success.

**Sx-7. Personal-domain skip warning is workspace-conditional.** API spec for `/api/leads/multiple` says "Personal domains will be skipped unless enabled on your instance." For `emailbison-personal` workspace 13, the warning did NOT fire — all 4 gmail/outlook leads were created. Spec consumer cannot rely on the warning text alone; instance-level config dictates behavior. Mitigation: the launch-campaign spec should ground-truth via a single test-lead POST to a personal-domain address before assuming the skip-or-create behavior.

**Sx-8. Bulk-POST is all-or-nothing on validation failure.** A duplicate-email entry in a bulk batch fails the WHOLE batch with 422; valid entries in the same batch are NOT created. The `call_api` wrapper exposes only `{"error": "HTTP 422 Error"}` — no per-lead detail. Launch-campaign Phase 4 step 8's "surface the rejected rows for operator review" can't be implemented as written. Recovery requires inspecting EB UI to determine actual state, not API response.

---

## Phase 3 VARIABLES — live-walk

**Tools used:** `discover_tools(category="variables")` → confirmed `list_custom_variables` + `create_custom_variable` are both extended-tier. `search_api_spec(search_term="custom-variables")` → revealed the URL paths `GET /api/custom-variables` and `POST /api/custom-variables`. (Descriptive search failed — see Sx-1 above.)

**Pre-create state.** `GET /api/custom-variables` returned 6 pre-existing variables (IDs 1–6, all created 2025-11-14): `company address`, `company linkedin url`, `company phone`, `company website`, `person job title`, `person linkedin url`. Pagination meta showed `current_page: 1, last_page: 1, per_page: 15, total: 6` — Laravel-style page-based pagination, not cursor-based. ZERO collisions with our 8 SCREAMING_SNAKE_CASE names.

**F15 side-test.** `POST /api/custom-variables` with `{"name": "company website"}` (existing) → **HTTP 422 Error**. Clean refusal. No silent dup. No gate prompt. F15 confirmed as hard-fail-on-duplicate.

**Main creates.** 8 parallel POSTs for our 8 names. All returned `success: true` with auto-incremented IDs 7–14. **Notable:** EB silently lowercased every name on store (Sx-3). Spec assumption "create with `{name, default}`" is wrong — only `{name}` works (Sx-2).

**Post-create state.** Workspace now has 14 custom variables total (6 pre-existing + 8 new). All persist permanently (Sx-4 — no DELETE endpoint).

**Time-to-complete.** ~7 seconds for 9 parallel POSTs (1 F15 test + 8 main creates).

### F14 — `list_custom_variables` pagination

**CONFIRMED.** Pagination is `?page=N` query param with Laravel-style metadata:
```json
"meta": {
  "current_page": 1, "from": 1, "last_page": 1, "per_page": 15, "to": 6, "total": 6,
  "links": [...prev/numbered/next URLs...],
  "path": "https://personal.outbase.so/api/custom-variables"
}
```
Default `per_page` is 15. NOT cursor-based as the launch-campaign spec describes for `list_sender_emails`'s `while True` loop. Two distinct pagination styles co-exist in EB — Phase 7 will test the sender variant. Mixed pagination model is itself worth flagging for Phase 7.

### F15 — Conflicting-variable resolution

**CONFIRMED (hard-fail variant).** Duplicate-name POST returns HTTP 422 with no body details exposed via `call_api` (just `{"error": "HTTP 422 Error", "hint": "..."}`). Behavior: clean refusal, no silent overwrite, no gate prompt, no state change. Combined with Sx-2 (no `default` field exists), F15's original framing "creating with same name + different default" is moot — defaults aren't a variable-level concept. The actual F15 question is just "what happens on duplicate name?" and the answer is **422**.

Spec implication: Phase 3 step 3's classification of variables as "conflicting (name matches but default differs)" should reduce to "existing (will reuse) — duplicate POST would 422, so we skip the create". The 3-way classification (new / existing / conflicting) collapses to 2-way (new / existing).

### F16 — Workspace-scoped collision

**CONFIRMED.** Pre-existing 6 variables (Nov 2025 timestamps) prove variables persist beyond any single session/campaign. Combined with Sx-4 (no DELETE endpoint), variables are workspace-scoped + permanent. Future runs against `emailbison-personal` will inherit the 14 vars. Test campaigns across the workspace share the same variable namespace.

---

## Phase 4 UPLOAD — live-walk

**Tools used:** `discover_tools(category="leads", search="bulk")` revealed `bulk_create_leads` extended-tier. `search_api_spec(endpoint="/api/leads", method=POST)` returned 6 endpoints; the canonical bulk path is **`POST /api/leads/multiple`** (NOT `/api/leads/bulk` as the launch-campaign spec implies). Body shape: `{leads: [{first_name, last_name, email, title, company, notes, custom_variables[]}]}`.

**Path mechanics — used `call_api` directly.** Bypasses the `bulk_create_leads` MCP-tool wrapper. Per the wrapper's `discover_tools` description, `bulk_create_leads` does NOT advertise a `confirmation` parameter (unlike `import_leads_to_campaign`, which explicitly does). The launch-campaign spec's "two-call vendor gate" claim for Phase 4 was hedged ("may or may not be vendor-gated — treat it as gated regardless"); reality via `call_api` is **no vendor gate at all**.

**F17 side-test.** Single `POST /api/leads` body `{first_name: "F17Test", email: "bc5906-f17-no-lastname@brite.co"}` (no `last_name`) → `success: true`, lead id **14705** created with `last_name: null`. **F17 refuted** (the launch-campaign spec correctly treats CSV `last_name` as optional; the EB API spec lies about it being required).

**Main bulk POST.** Single call to `/api/leads/multiple` with all 6 leads from `test-leads.csv`, fully-populated `custom_variables` array (8 entries each, lowercase variable names matching what EB stored in Phase 3). Time: <1s. Result: **all 6 leads created, IDs 14706–14711**. Notable surprises:

- **All 4 gmail/outlook leads accepted** — the spec warning "Personal domains will be skipped unless enabled on your instance" did NOT fire. This workspace either has personal-domain mode enabled or the warning is conditional/inaccurate. Either way, F12 skip-empty's expected Other=0 distribution holds; Google=4 / Microsoft=2 still correct.
- **All custom_variables persisted per-lead** — verified in the response payload. Lowercase names from Phase 3 round-trip cleanly.
- **No vendor confirmation prompt** — the call returned the lead array directly, no two-call dance.

**F18 side-test.** `POST /api/leads/multiple` body `{leads: [{...dup of dogfood-test-01@gmail.com}, {...new lead bc5906-f18-newlead@brite.co}]}` → **HTTP 422 Error** for the whole batch. The new lead did NOT get created despite being valid; the duplicate caused the entire request to fail. **F18 confirmed (all-or-nothing failure).** The launch-campaign spec's recovery path "delta the unsuccessful leads and re-run" is infeasible because (a) the API returns no per-lead detail in the 422 response (the `call_api` wrapper exposes only `{"error": "HTTP 422 Error", "hint": "..."}`), and (b) NONE of the leads in a partial-failure batch get created.

**Post-Phase-4 state.** Workspace now has 7 new leads (1 F17 test + 6 main bulk). The F18 retry created zero new leads. Total state for cleanup:
- Lead 14705: F17Test (no last_name) — to delete in T11
- Leads 14706–14711: 6 main dogfood leads — to delete in T11

### F17 — `last_name` requirement

**REFUTED.** Single POST `/api/leads` with no `last_name` field → `success: true`, lead 14705 stored with `last_name: null`. The API spec at `search_api_spec(/api/leads, POST)` shows `"required": ["first_name", "last_name", "email"]`, but reality is that `last_name` is genuinely optional. The launch-campaign spec correctly treats CSV `last_name` as optional. F17's premise is moot: there is no enforced last_name requirement; the spec already aligns with reality. **Tangentially exposes a class-level finding** (Sx-5 below): the EB API spec's `required` markings cannot be trusted.

### F18 — Mid-chunk failure recovery

**CONFIRMED — all-or-nothing.** Bulk POST containing 1 duplicate (existing email) + 1 new email → HTTP 422 for the entire batch. The new lead was NOT created. The 422 response from the `call_api` wrapper exposes only the error code, not per-lead detail. Spec implication: launch-campaign Phase 4 step 8's "verify lead count, surface the rejected rows for operator review" can't be implemented as written — the API doesn't surface which leads failed. Operator must inspect EB UI to determine state and manually delta the CSV before retry.

### F19 — Vendor prompt wording

**REFUTED — no vendor prompt at the `call_api` layer.** The first `POST /api/leads/multiple` returned the created leads directly with no confirmation gate. The spec's "two-call MCP confirmation gate required per BC-2707 precedent" wording in Phase 4 over-applies — that pattern fires for `import_leads_to_campaign` (per its `discover_tools` description) but NOT for `bulk_create_leads` (which has no confirmation parameter advertised). The agent-side AskUserQuestion gate (semantic operator-intent) is the only gate that actually fires for Phase 4 via `call_api`. The MCP-tool-wrapper layer (`bulk_create_leads` invoked directly, not via `call_api`) was not exercised in this dogfood; if invoked, the wrapper might add its own gate, but the API itself doesn't.

---

## Phase 5 CAMPAIGN CREATE — live-walk

**Tools used:** `create_campaign` (core tier — directly callable, no `call_api`+`search_api_spec` dance). Body: `{name, type}`. `type: "outbound"` is the default per spec.

**Main creates.** 2 parallel calls in <1s. Both succeeded:
- **id 22** — `BC-5906 Round 2 | Google`, status `draft`
- **id 23** — `BC-5906 Round 2 | Microsoft`, status `draft`

Response shape: `{success, message, campaign: {id, name, status, type}}`. Notable — the response message includes a hint: `"Use update_campaign to configure settings like max_emails_per_day, open_tracking, etc."` The launch-campaign spec doesn't reference `update_campaign` for Phase 5 (settings are deferred to Phase 8 Schedule + downstream phases via separate endpoints). The hint is not actionable for the round-2 walk; flag as noise that may confuse a less-experienced operator.

**F20 side-test.** Same-name create with `BC-5906 Round 2 | Google` (already exists as id 22) → `success: true`, **new id 24** with the same name. EB allows duplicate names silently. No 422, no gate, no warning text in the response.

**Post-Phase-5 state.** 3 new campaigns in workspace: id 22 (Google main), id 23 (Microsoft main), id 24 (F20 collision test — to clean up in T11). All in `draft` status.

### F20 — Name collision

**CONFIRMED (silent duplicate allowed).** Two campaigns with identical name `BC-5906 Round 2 | Google` co-exist in the workspace (id 22 + id 24). No deduplication, no warning. The launch-campaign spec's Phase 5 step 5 "Execute creates" assumes successful returns implies unique campaigns — false. Operator-side risk: re-running the command on a partial-failure resume could spawn duplicate campaign sets if the metadata JSON is missing the `campaign_ids` map. **Recommended spec fix**: Phase 5 step 1 should pre-call `list_campaigns(search=base_name)` and either skip existing matches or fire an explicit gate ("3 campaigns already exist with prefix 'BC-5906 Round 2 |' — proceed and create more, abort, or reuse existing IDs?"). The user-side gate (User gate 5) should surface "0 existing matches; will create N new" or "M existing matches found — surface IDs" to make the duplication risk visible.

---

## Phase 6 ATTACH LEADS — live-walk

*(populated during execution)*

### F21 — Lead-ID-to-bucket mapping (Phase 4 → Phase 6)

*(populated during execution — confirm whether full ID list needs metadata persistence or session-memory suffices)*

### F22 — `allow_parallel_sending` gate

**Status: deferred per brainstorm decision 3 (2026-04-27).** Validating F22 requires pre-poisoning a lead into another campaign before this walk, which adds setup-and-cleanup load not justified by F22's load-bearing-ness for the MVP launch path. If F22 confirmation becomes high-value later, file as a separate scoped follow-up issue.

---

## Phase 7 ATTACH SENDERS — live-walk

*(populated during execution)*

### F23 — Pagination mechanism

*(populated during execution — verbatim cursor/page mechanism, page size, total connected sender count)*

### F24 — Payload size limit

*(populated during execution — full sender ID array submitted in one `attach_sender_emails_to_campaign` call)*

### F25 — `status: "connected"` filter

*(populated during execution — spot-check excludes warmup-state senders)*

### F26 — Post-attach eventual-consistency delay

*(populated during execution — measure gap between attach completion and list-reflect)*

---

## Phase 8 SCHEDULE — live-walk

*(populated during execution)*

### F27 — Schedule template availability (`emailbison-personal`)

*(populated during execution — `get_schedule_templates` count + names + default-match status)*

### F28 — Schedule template availability (`emailbison-b2b`)

*(populated during execution — read-only side-call; comparison across workspaces)*

---

## Phase 9 SEQUENCE — live-walk

*(populated during execution)*

### F29 — `max(1, artifact.step_1.wait_in_days)` silent override

*(populated during execution — side-test submitting `wait_in_days: 0` directly via `call_api` to determine if the override is necessary)*

### F30 — `thread_reply: true` field name

*(populated during execution — verbatim API spec field name from `search_api_spec` for sequence-steps body shape)*

---

## Phase 11 ACTIVATE — spec check (no live execution)

### F31 — Partial-success tracking schema

*(populated during T10 — re-read of `plugins/marketing/commands/launch-campaign.md` § Phase 11 metadata-update logic; propose schema change if per-campaign granularity is missing)*

---

## Findings table (F14–F31)

| # | Hypothesis | Status | Evidence (verbatim) | Follow-up |
|---|---|---|---|---|
| F14 | `list_custom_variables` pagination | **confirmed** | `?page=N` query-param + Laravel meta (`current_page`, `last_page`, `per_page=15`, `total`, `links[]`); NOT cursor-based | Mixed pagination model (vs cursor-based `list_sender_emails` per spec) — flag for spec-authoring follow-up |
| F15 | Conflicting-variable resolution | **confirmed (hard-fail)** | `POST {"name":"company website"}` (existing) → HTTP 422; no silent dup, no gate. Sx-2 invalidates the "default differs" sub-question. | Spec collapse 3-way (new/existing/conflicting) → 2-way (new/existing) |
| F16 | Workspace-scoped variable collision | **confirmed** | Pre-existing 6 vars from Nov 2025 prove cross-session persistence; combined with Sx-4 (no DELETE endpoint) → permanent workspace state | Spec note + cleanup AC update — see follow-ups for Sx-4 |
| F17 | `bulk_create_leads` `last_name` requirement | **refuted** | Single POST `/api/leads` with no `last_name` → `success: true`, lead 14705 stored `last_name: null`. API spec marks required, reality is optional (Sx-5). | Spec is correct as-is; remove F17 paper-walk note. |
| F18 | Mid-chunk failure recovery | **confirmed (all-or-nothing)** | Bulk POST `[dup, new]` → 422, NEITHER created. No per-lead detail in 422 response. | Spec needs Phase 4 step 8 rewrite — recovery via EB UI, not API. |
| F19 | Vendor prompt wording (Phase 4) | **refuted (no vendor gate via call_api)** | First call returned data directly; no confirmation parameter on `bulk_create_leads` MCP wrapper either (vs `import_leads_to_campaign` which has one). | Spec's "two-call vendor gate" claim for Phase 4 over-applies; remove or qualify. |
| F20 | Campaign name collision | **confirmed (silent duplicate)** | Same-name `create_campaign` call → new campaign id 24 with identical name as id 22; no error, no gate. Spec offers no guard against this. | Spec fix: Phase 5 step 1 pre-list existing campaigns and surface to user gate. |
| F21 | Lead-ID-to-bucket mapping persistence | *pending* | | |
| F22 | `allow_parallel_sending` gate | **deferred** | Brainstorm 2026-04-27 — requires pre-poisoning, not in scope | None this run |
| F23 | `list_sender_emails` pagination mechanism | *pending* | | |
| F24 | `attach_sender_emails_to_campaign` payload size | *pending* | | |
| F25 | `status: "connected"` filter excludes warmup | *pending* | | |
| F26 | Post-attach eventual-consistency delay | *pending* | | |
| F27 | Schedule templates on `emailbison-personal` | *pending* | | |
| F28 | Schedule templates on `emailbison-b2b` | *pending* | | |
| F29 | `wait_in_days: 0` override necessity | *pending* | | |
| F30 | `thread_reply` field name | *pending* | | |
| F31 | Phase 11 partial-success schema | *pending (spec-only)* | | |

---

## Workspace cleanup

*(filled during T11 — list of campaigns archived/deleted, leads deleted, custom variables deleted/retained-with-justification)*

## Follow-up Linear issues filed

*(filled during T12 — issue IDs for every refuted / needs-more-work row above)*
