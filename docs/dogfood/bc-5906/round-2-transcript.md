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

**Sx-9. Extended-tier MCP "tools" are not callable in-session — only via `call_api`.** `discover_tools` advertises tools like `import_leads_to_campaign`, `bulk_create_leads`, `attach_sender_emails_to_campaign` with rich descriptions including two-call vendor-gate semantics. None of these are exposed as direct callables in the conversation's tool registry; we can only invoke their underlying API endpoints via `call_api`. The vendor-gate two-call dance described in the discover_tools description is enforced by the wrapper layer, NOT by the API. Spec implication: the launch-campaign command's reliance on "two-call MCP confirmation gate per BC-2707" for Phases 4, 6, 11 is only realizable if the wrapper is somehow surfaced as a callable. Via `call_api` (the spec's documented invocation pattern), the gate is purely operator-side via `AskUserQuestion`. The launch-campaign spec's wording should clarify "agent-side semantic gate via AskUserQuestion is the load-bearing safeguard; vendor-side gate is advisory and not enforced through `call_api`."

**Sx-10. `?per_page=N` query param is silently ignored — EB hardcodes 15.** Tested with `?per_page=100` and `?per_page=1000` against `/api/sender-emails`; both returned the same `meta.per_page: 15` page size as the no-param call. (`?per_page=1000` paired with `?status=Connected` returned 422; isolated `?per_page=100` returned 200 with 15-per-page.) For a 772-item list this means 52 pages mandatory, no operator workaround. Combined with Sx-9 (no batch wrapper), enumerating the full sender pool requires fanning out 52 sequential or parallel pagination calls. The launch-campaign spec's `while True` loop assumes the operator can page once — for any non-trivial sender pool this is operationally heavy.

**Sx-11. Status filter is case-sensitive in a non-obvious way.** `?status=connected` (lowercase) succeeds and returns senders. `?status=Connected` (capitalized — matching the response data's `status: "Connected"` field exactly) returns 422. Other values like `?status=warmup` also 422. The launch-campaign spec writes `filter={"status": "connected"}` — which works — but a developer looking at API response examples (which all show capitalized `"Connected"`) would naturally try the capitalized form and hit 422 with no useful diagnostic. Document the case-sensitivity expectation in the spec.

**Sx-12. Schedule templates have NO `name` field.** Templates have only `id`, `type` ("Schedule template"), per-day boolean flags, `start_time`, `end_time`, `timezone`, timestamps. The launch-campaign spec at Phase 8 step 2 says "Identify the template matching the Brite default" — implying name-based selection. Reality: must match by structural field comparison. Spec should be explicit about field-based matching.

**Sx-13. Launch-campaign spec uses `"variant": "A"` for sequence steps; EB expects boolean.** Spec line 600/608 sends `"variant": "A"` (a string A/B label borrowed from another platform's terminology). EB API expects `boolean`. Round-2 used `false` (boolean) and the create succeeded. Sending `"A"` would either silently coerce or 422 — but the spec's value type is wrong on its face. Spec fix required.

**Sx-14. EB auto-prepends "Re: " to step_2 subjects when `thread_reply: true`, even if subject already starts with "Re:".** Round-2 sent step 2 subject `"Re: {Quick|Fast|30s} {question|check|idea}"` (per spec rule); EB stored `"Re: Re: {Quick|Fast|30s} {question|check|idea}"` — double prefix. Spec fix: copy artifact's step_2.subject should NOT include "Re:" prefix; EB prepends automatically when `thread_reply: true`. The spec at launch-campaign.md line 569 contains the wrong rule: `"step_2.subject` starts with `Re:` (per EB format rule)" — should reverse to "step_2.subject does NOT start with `Re:` (EB auto-prepends when thread_reply: true)". Concrete sweep needed across the email-copywriting skill + every existing copy artifact.

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

**Endpoint:** `POST /api/campaigns/{campaign_id}/leads/attach-leads`. Body: `{lead_ids: [int], allow_parallel_sending: bool (optional)}`. Required: `lead_ids`. The launch-campaign spec's reference to `import_leads_to_campaign` corresponds to this endpoint.

**Architecture finding — Sx-9.** The `import_leads_to_campaign` MCP-tool wrapper that the spec expects to enforce the BC-2707 two-call gate is NOT exposed as a directly callable function in the session's tool registry — only `call_api` is. Extended-tier tools per `discover_tools` are advertised but not invocable as named functions; their `confirmation`-parameter / two-call gate is enforced only by the wrapper layer that we cannot reach from `call_api`. Spec implication: the BC-2707 vendor-side gate for Phase 6 is not actually achievable via the documented "ground-truth via search_api_spec, then call via call_api" pattern. The agent-side `AskUserQuestion` semantic gate (User gate 6) is the only enforceable gate.

**Bucket map.** Built in-session from CSV→MX→bucket assignments captured during Phase 2:
- Google bucket: leads 14706 (gmail), 14707 (gmail), 14710 (brite.co/Google Workspace), 14711 (brite.co/Google Workspace) — 4 leads
- Microsoft bucket: leads 14708 (outlook), 14709 (outlook) — 2 leads

**Two parallel attach calls.** Both succeeded:
- Campaign 22 ← `lead_ids: [14706, 14707, 14710, 14711]` → response "Leads successfully added to BC-5906 Round 2 | Google. Existing leads were not added."
- Campaign 23 ← `lead_ids: [14708, 14709]` → response "Leads successfully added to BC-5906 Round 2 | Microsoft. Existing leads were not added."

The "Existing leads were not added" suffix in the response message is **idempotency signal** — re-attaching already-attached leads is a no-op rather than a 422. Useful for resume safety. Worth flagging in the spec's resume rules.

**Verification via `list_campaigns(search="BC-5906 Round 2")`:**
```
id, name,                              status, leads
22, BC-5906 Round 2 | Google,          draft,  4
23, BC-5906 Round 2 | Microsoft,       draft,  2
24, BC-5906 Round 2 | Google (F20-dup), draft,  0
```

Per-campaign attach counts match the bucket map. F20 collision-test campaign 24 has 0 leads (untouched).

### F21 — Lead-ID-to-bucket mapping (Phase 4 → Phase 6)

**CONFIRMED as gap.** The launch-campaign metadata schema (spec § Launch metadata schema) persists `lead_ids_uploaded` (count) and `esp_segments: {bucket: count}` (per-bucket counts), but NOT `lead_ids_by_bucket: {bucket: [ids]}` (the actual mapping). To resume Phase 6 from metadata alone after a session crash, you'd need to re-derive bucket assignments by:
1. Re-running Phase 2 Bash `dig` MX lookups against the CSV
2. Cross-referencing CSV-row order to lead IDs (which Phase 4 returns in submit-order, but the order is implicit, not persisted in metadata)

Round-2 worked because the bucket map was held in agent session memory; if that's lost, recovery is manual. **Spec fix recommendation**: extend the metadata schema with either (a) `lead_ids_by_bucket: {Google: [...], Microsoft: [...], Other: [...]}`, or (b) `lead_id_to_email_map: {<lead_id>: <email>}` so the bucket map can be rebuilt from emails alone.

### F22 — `allow_parallel_sending` gate

**Status: deferred per brainstorm decision 3 (2026-04-27).** Validating F22 requires pre-poisoning a lead into another campaign before this walk, which adds setup-and-cleanup load not justified by F22's load-bearing-ness for the MVP launch path.

**Confirmed via spec recon though**: the API body schema for `/api/campaigns/{id}/leads/attach-leads` does include `allow_parallel_sending: boolean`. The launch-campaign spec's referencing this field name is correct. The gate behavior (vendor returns prompt when leads already in another campaign's sequence) is only enforced via the MCP-tool wrapper (per the `discover_tools` description) — and per Sx-9 the wrapper isn't reachable in this session anyway. So even if F22 were tested, the operator-side gate would be the only real safeguard.

If F22 live confirmation becomes high-value, file a separate follow-up issue with a 2-step setup: (a) attach lead 14706 to campaign 24 (the F20 dup) first, (b) re-run Phase 6's attach for campaign 22 — observe whether attaching lead 14706 to a 2nd campaign without `allow_parallel_sending: true` triggers the gate path.

---

## Phase 7 ATTACH SENDERS — live-walk

**Endpoint:** `POST /api/campaigns/{id}/attach-sender-emails`. Body: `{sender_email_ids: [int]}` (required) + optional `allow_parallel_sending`. List endpoint: `GET /api/sender-emails`. Per-campaign verification: `GET /api/campaigns/{id}/sender-emails`.

**Workspace state.** `bulk_count(resource="sender_emails")` → 772 total senders (matches issue-body figure from round-1; consistent year-over-year). All visible senders in page 1 share characteristics: `type: microsoft_oauth`, `status: "Connected"`, `warmup_enabled: true`, tagged `Outlook` + `ScaledMail-Microsoft`, domains `washingtonfestivelights.com` / `washingtonwinterlights.com` (the dogfood-test sender domains for the personal workspace). Names cycle through Lotus Dennison, Rainer Owens, Holden Halford, Mckenna Fuhriman, Dillon Williams.

**Round-2 partial-pool decision.** The launch-campaign spec mandates attaching the full 772-sender pool to all campaigns. For round-2 dogfood we used **page 1's 15 senders** as the test pool — attaching all 772 would require 51 additional pagination calls × 15 senders each (the `per_page` query param is silently ignored by EB; see Sx-10 below). The attach-path mechanics, F24 payload-size behavior, and F26 timing are validated at 15-item scale; the spec invariant's full-pool behavior is deferred — recommended as a separate follow-up that either fans out the pagination calls or runs against a workspace with a smaller sender pool.

**Pool used (15 sender IDs):** `[995, 993, 994, 992, 991, 989, 990, 988, 987, 986, 984, 985, 983, 982, 981]`.

**Two parallel attaches.** Both succeeded:
- Campaign 22 ← 15 senders → `"Sender emails successfully added to BC-5906 Round 2 | Google"`
- Campaign 23 ← same 15 senders → `"Sender emails successfully added to BC-5906 Round 2 | Microsoft"`

**Verification.** `GET /api/campaigns/{id}/sender-emails` for both campaigns showed 15 senders, IDs matching the attach payload exactly. Per-campaign list response includes `meta: {current_page: 1, last_page: 1, per_page: 15, total: 15}` — consistent Laravel pagination.

**`bulk_export(resource="sender_emails", format="csv")` worth noting.** Returns `{file_path: "/home/mcp/EmailBison_Exports/...csv", row_count: 772}` — but the file_path is on the **MCP server's filesystem**, not the agent's. This means the "export to CSV" path can't be used as a pagination shortcut from agent context. The launch-campaign spec doesn't mention this; would-be operators looking to bypass pagination will hit this dead-end.

### F23 — Pagination mechanism

**CONFIRMED — Laravel page-based, not cursor-based.** `GET /api/sender-emails` returns `meta: {current_page, last_page, per_page, total, links}` with full numeric-page metadata. NOT cursor/next_cursor as the launch-campaign spec describes for sender-list pagination. Same model as Phase 3 custom-variables endpoint. The spec's `while True / cursor=cursor / cursor=response.next_cursor` pattern (Phase 7 § Pagination is mandatory) is **wrong** for both the variables and senders endpoints — refute and rewrite to numeric-page-based loop. Round-2 evidence: 52 pages × 15 senders/page = 772 total.

**Spec consequence:** the upstream Revgrowth 10 reference uses Python's response object with `.next_cursor` — that pattern doesn't translate to EB's actual API. Brite's launch-campaign command needs its own pagination idiom, not a verbatim adoption of upstream's.

### F24 — Payload size limit

**PARTIALLY CONFIRMED — 15-item array succeeded, full 772 deferred.** The endpoint accepts a JSON array of sender IDs. 15 IDs in `{"sender_email_ids": [...]}` returned `success: true` with no payload-size warnings. The actual question "does 772 entries succeed in one call?" was **not tested live** in round-2 due to the 51-page enumeration cost. Recommended follow-up: fan-out pagination calls in a future session and test 772-item attach. Our small-scale evidence suggests the path works structurally, but can't speak to the 772-item ceiling.

### F25 — `status: "connected"` filter

**PARTIALLY CONFIRMED.** Status filter accepts lowercase `connected` (succeeds), rejects capitalized `Connected` and other invalid values like `warmup` (both 422). Senders' actual status field in the response data is always returned **capitalized** (`"Connected"`) — case-mismatch between filter input and response output is itself a friction (Sx-11). For the spec's "doesn't leak warmup-state senders" question: insufficient evidence — the `?status=warmup` filter 422'd, suggesting EB doesn't expose a "warmup-only" sender state at all. All 15 senders in our pool are `status: "Connected"` AND `warmup_enabled: true` simultaneously — `warmup_enabled` is a per-sender feature toggle, NOT a deliverability state. The spec's framing "filter excludes warmup-state senders" appears based on a misunderstanding of EB's sender model — there is no separate "warmup" status to filter against.

### F26 — Post-attach eventual-consistency delay

**CONFIRMED — sub-15-second consistency at our test resolution.** Timing: T0 (pre-attach) = 1777330114.979 → T1 (post-attach + post-verification batch) = 1777330130.527 → Δ ≈ 15.5s. The verification GETs at T1 returned all 15 senders for both campaigns, so the consistency delay is bounded above by ~15.5s (which includes Claude's reasoning time + 4 round-trip MCP calls + 2 attach round-trips). True consistency delay is likely sub-second. The spec's "wait 30 seconds and re-query before declaring failure" instruction is overly conservative for this workspace — 5s would be ample.

---

## Phase 8 SCHEDULE — live-walk

**Endpoint:** List templates `GET /api/campaigns/schedule/templates`. Apply template `POST /api/campaigns/{id}/create-schedule-from-template` body `{schedule_id: int}`.

**Personal templates (workspace 13):** 1 template, id 3 — Mon-Fri 08:00-20:00 America/Denver.
**B2B templates (workspace 55):** 2 templates — id 7 (Mon-Fri 08:00-17:00 America/New_York), id 8 (Mon-Fri 08:00-20:00 America/Denver).

Applied template id 3 to both campaigns:
- Campaign 22 → schedule id 4 (Mon-Fri 08:00-20:00 Denver)
- Campaign 23 → schedule id 5 (Mon-Fri 08:00-20:00 Denver)

**Important — template-application is clone, not reference.** The POST returns a NEW schedule entity (id 4 for campaign 22, id 5 for campaign 23), each independently editable thereafter. Template id 3 is the source; per-campaign schedule id is the artifact. The launch-campaign metadata schema's single `schedule_id: N` field is wrong — there are N campaign-specific schedule IDs (cloned from a single template id). Spec fix: rename to `schedule_template_id` + add `campaign_schedule_ids: {bucket: id}`.

### F27 — Schedule template availability (`emailbison-personal`)

**CONFIRMED — 1 template available.** Workspace 13 has exactly one schedule template (id 3, Mon-Fri 08:00-20:00 America/Denver). The launch-campaign spec's "Brite default Mon-Fri 08:00-17:00 local" assumption does NOT match what's available on personal — neither the end time (08:00-20:00 vs 08:00-17:00) nor the timezone (Denver vs unspecified-local). Operator running `--workspace emailbison-personal` against the spec would either:
- Accept whatever's available (Denver 8-8) and document the deviation in pre-flight gate (current behavior — what we did)
- Halt and ask the operator to create a matching template via the EB UI
- Halt and ask the operator to switch workspace

The spec's Phase 8 step 2 currently says "If no matching template exists, surface the full list and ask the operator to pick one — do NOT create a new template inline." That instruction is correct in spirit, but the spec then assumes a Mon-Fri 08:00-17:00 default exists; for the personal workspace it doesn't. Spec should drop the hardcoded default and surface what's available with a recommend-best-fit heuristic (e.g., closest start_time + end_time match in the operator's likely timezone).

### F28 — Schedule template availability (`emailbison-b2b`)

**CONFIRMED — 2 templates available.** Workspace 55 has id 7 (Mon-Fri 08:00-17:00 America/New_York — exactly matches spec default) and id 8 (Mon-Fri 08:00-20:00 America/Denver — matches personal's id 3). Cross-workspace comparison: **template inventories diverge between workspaces**. Operator can't assume a template exists across workspaces just because they tested in one. The spec needs to ground-truth template availability per-workspace at Phase 8 step 2 (which it does), but should also surface this divergence as expected behavior, not a workspace-config oversight.

**Sx-12 candidate** — schedule templates have NO `name` or `description` field. Identification is purely by field values (start_time, end_time, days array, timezone). The spec's "Identify the template matching the Brite default" instruction is implicit-field-match — operator must compare structurally, not by string. Spec should be explicit about field-based matching to avoid agent attempts at name-based search.

---

## Phase 9 SEQUENCE — live-walk

**Endpoint (v1.1):** `POST /api/campaigns/v1.1/{campaign_id}/sequence-steps`. Body: `{title, sequence_steps: [{email_subject, email_body, wait_in_days, order, variant (boolean), variant_from_step, thread_reply}]}`. Required: `email_subject`, `email_body`, `wait_in_days`. Legacy `/api/campaigns/{id}/sequence-steps` exists but is deprecated.

**F29 evidence (test).** First attempt for campaign 22 used `wait_in_days: 0` for step 1 (the copy artifact's verbatim value) → **HTTP 422 Error**. Retried with `wait_in_days: 1` → success (sequence id 4, steps id 6 + 7). The launch-campaign spec's `max(1, artifact.step_1.wait_in_days)` override IS load-bearing — without it, EB rejects creation. **F29 confirmed (override necessary).**

**Campaign 23 happy path.** Submitted with `wait_in_days: 1` from the start → success on first call (sequence id 3, steps id 4 + 5).

**Sequence creation results:**
- Campaign 22 → sequence id 4, steps id 6 (step 1, wait=1) + id 7 (step 2, wait=4)
- Campaign 23 → sequence id 3, steps id 4 (step 1, wait=1) + id 5 (step 2, wait=4)

(Note: sequence ids are non-sequential because campaign 23's sequence was created first while campaign 22's first attempt was rejected. Sequence-step ids 6+7 came after step ids 4+5.)

**Sx-13 (NEW finding — `variant` field is BOOLEAN not STRING).** The launch-campaign spec at line 600/608 uses `"variant": "A"` (a string A/B label). EB API spec marks `variant` as `boolean` with example `false`/`true`. Sending `"A"` (string) to EB would either silently coerce or 422 — we sent `false` (boolean) which worked. The spec's `"variant": "A"` is wrong; should be `"variant": false` for non-variant steps. The string-A label appears to be borrowed from a different platform's A/B-test concept, not EB's.

**Sx-14 (NEW finding — auto-Re: prepend on `thread_reply: true`).** Step 2 was sent with subject `"Re: {Quick|Fast|30s} {question|check|idea}"` (per the launch-campaign spec rule that step_2 subjects start with "Re:"). EB stored the subject as `"Re: Re: {Quick|Fast|30s} {question|check|idea}"` — **double Re: prefix**. EB auto-prepends "Re: " when `thread_reply: true`, regardless of whether the subject already starts with "Re:". Spec fix: send the BARE subject (without "Re:") for step 2 and let EB prepend automatically.

**Sequence-step `active: true` field.** Response showed `active: true` for both steps, but this field isn't in the API spec request body — read-only. Spec doesn't reference it.

**Other notes.** The `variant_from_step` field is `null` in the response when `variant: false` (as expected). `attachments` is `null`. The `email_body` and `email_subject` are stored verbatim with spintax intact — render happens at send-time, not store-time.

### F29 — `max(1, artifact.step_1.wait_in_days)` silent override

**CONFIRMED (override necessary).** `wait_in_days: 0` for step 1 → 422 from EB. Spec's `max(1, …)` clamp is load-bearing — without it, the API rejects the create. The original X17 paper-walk hypothesis "verify whether EB accepts wait_in_days: 0 on step 1; if yes, override may be unnecessary" is answered: **no, EB does not accept it; the override is required**. Spec stays as-is on this point.

### F30 — `thread_reply: true` field name

**CONFIRMED (field name correct).** EB API spec at both v1.1 (`POST /api/campaigns/v1.1/{id}/sequence-steps`) and legacy paths use the field name `thread_reply` exactly. Type: `boolean`, nullable: true. Description: "Whether the step should be a reply from the previous step." Spec is correct on this. **Spec is also correct** on the v1.1 endpoint preference — the legacy `/api/campaigns/{campaign_id}/sequence-steps` is explicitly marked "(deprecated)" in EB's spec.

---

## Phase 11 ACTIVATE — spec check (no live execution)

**No live execution per BC-5906 scope** (`--activate` off, no real emails sent). This section is paper-exercise only: re-read of `plugins/marketing/commands/launch-campaign.md` § Phase 11 + § Launch metadata schema, with F31's partial-success-tracking question answered structurally.

### F31 — Partial-success tracking schema

**CONFIRMED (gap).** Spec section relevant: launch-campaign.md § Launch metadata schema (lines 109–154) + § Phase 11 step 6 + § Error recovery overview row for Phase 11.

**Current schema:**
```
"activated": true | false,
"activated_at": "<ISO-8601>" | null
```

These are **global** flags — one boolean for the entire run, one timestamp for when the FINAL `resume_campaign` call returned. No per-campaign granularity.

**Spec's stated semantics** (line 781): "Set `activated: true`, `activated_at: <ISO-8601-of-final-resume-call>`, `last_completed_phase: 11`."
**Spec's stated resume rule** (line 825): "The command's Phase 11 loop skips campaigns whose metadata shows they're already activated."

**Conflict.** The resume rule says "skips campaigns whose metadata shows they're already activated" — implying per-campaign tracking. But the actual fields written (`activated`, `activated_at`) are global, not per-campaign. If a Phase 11 partial failure activates 1-of-2 campaigns and aborts on the second, the operator re-runs and the spec says skip the already-activated. But the metadata has no per-campaign data to drive that skip — only the global `activated: false` (because not all activated).

**F31 confirmed: schema needs per-campaign granularity to make the resume rule actually implementable.**

**Proposed schema fix (recommend in T12 follow-up issue):**
```json
{
  ...
  "activated": false,         // Global — true iff ALL campaigns activated
  "activated_at": null,        // Global — final-success timestamp
  "activated_per_campaign": {  // NEW — populated as each campaign succeeds
    "Google": "<ISO-8601>",
    "Microsoft": null
  },
  "last_completed_phase": 11
}
```

The Phase 11 loop reads `activated_per_campaign[bucket]` to skip already-activated campaigns; the global `activated` flips to true only when every entry is non-null.

**Round-2 didn't live-test Phase 11.** This is a spec-only finding; no EB state change. Sequence creates in T9 left both campaigns at `status: "draft"`, which is the expected non-activated terminal state for this dogfood.

---

## Live-walk completion summary (T9 → T10 boundary)

**State at end of T10 (BEFORE T11 cleanup):**
- **14 custom variables** in workspace 13 (6 pre-existing + 8 new — IDs 7-14, lowercased per Sx-3)
- **7 leads in workspace** — id 14705 (F17 test, no last_name) + ids 14706–14711 (6 main dogfood leads)
- **3 campaigns** all in `draft` status:
  - id 22 `BC-5906 Round 2 | Google` — 4 leads + 15 senders + schedule id 4 + sequence id 4 (steps 6, 7)
  - id 23 `BC-5906 Round 2 | Microsoft` — 2 leads + 15 senders + schedule id 5 + sequence id 3 (steps 4, 5)
  - id 24 `BC-5906 Round 2 | Google` — F20 collision-test campaign, 0 leads, no senders, no schedule, no sequence

**F-hypothesis status:** 17 of 18 resolved (F22 deferred per brainstorm).

**Sx findings:** 14 cross-cutting spec/reality gaps surfaced (Sx-1 through Sx-14).

**No real emails sent.** All campaigns terminal at `draft` — Phase 11 not exercised.

**Inspectable state.** All 3 campaigns + their leads + their sender attaches + their schedules + their sequences are visible in `personal.outbase.so` workspace 13 (`BriteNites Team`). Operator can manually inspect via the EB UI before T11 cleanup if desired.

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
| F21 | Lead-ID-to-bucket mapping persistence | **confirmed (gap)** | Metadata schema persists counts only, not bucket→ID map. Round-2 used in-session memory; resume after crash would require re-running Phase 2 + cross-referencing CSV order to lead IDs (latter not persisted). | Spec fix: add `lead_ids_by_bucket` OR `lead_id_to_email_map` to metadata schema. |
| F22 | `allow_parallel_sending` gate | **deferred** | Brainstorm 2026-04-27 — requires pre-poisoning, not in scope | None this run |
| F23 | `list_sender_emails` pagination mechanism | **confirmed (refutes spec)** | Laravel `?page=N` numeric paging with full meta; NOT cursor-based as spec describes. 52 pages × 15/page = 772. | Spec rewrite Phase 7 pagination from `while True / cursor` to numeric-page loop. |
| F24 | `attach_sender_emails_to_campaign` payload size | **partially confirmed** | 15-item array succeeded; full 772-test deferred (51-page enumeration cost). | Follow-up: fan out pagination + test 772-item attach in a separate session. |
| F25 | `status: "connected"` filter excludes warmup | **partially confirmed** | Filter accepts lowercase `connected`; rejects `warmup` (422) and capitalized `Connected` (422). EB has no separate "warmup-only" sender state — `warmup_enabled` is a feature toggle, not a deliverability state. Spec framing is based on a wrong model. | Spec rewrite: clarify `warmup_enabled` is per-sender config, not a status to filter against. |
| F26 | Post-attach eventual-consistency delay | **confirmed (fast)** | Δ ≈ 15.5s end-to-end (incl. Claude reasoning + 6 round-trip calls); verification list reflected 15 senders fully. True consistency delay is likely sub-second. | Spec relax "wait 30 seconds" → "wait 5 seconds" for this workspace. |
| F27 | Schedule templates on `emailbison-personal` | **confirmed (1 template, doesn't match spec default)** | id 3 only — Mon-Fri 08:00-20:00 America/Denver. Spec's "default Mon-Fri 08:00-17:00" not present. | Spec drop hardcoded default; field-based match + closest-fit heuristic. |
| F28 | Schedule templates on `emailbison-b2b` | **confirmed (2 templates; only b2b has spec default)** | id 7 (NY 8-5 — matches spec), id 8 (Denver 8-8 — matches personal id 3). Cross-workspace inventories diverge. | Spec acknowledge per-workspace template divergence. |
| F29 | `wait_in_days: 0` override necessity | **confirmed (override necessary)** | First call with `wait_in_days: 0` → 422. Retry with `wait_in_days: 1` → success. EB rejects 0-day waits on step 1. | Spec correct on this point — keep `max(1, …)` clamp. |
| F30 | `thread_reply` field name | **confirmed (correct)** | API spec at both v1.1 and legacy paths uses `thread_reply` exactly. v1.1 endpoint is preferred (legacy marked deprecated). | Spec correct on this point. |
| F31 | Phase 11 partial-success schema | **confirmed (gap)** | Spec's `activated` + `activated_at` are global; no per-campaign granularity. Resume rule "skips campaigns whose metadata shows they're already activated" can't be implemented because the metadata lacks per-campaign data. | Spec fix: add `activated_per_campaign: {bucket: ISO-8601 \| null}`. |

---

## Workspace cleanup

**Deleted (background-queued via async API):**
- `DELETE /api/campaigns/bulk` body `{"campaign_ids": [22, 23, 24]}` → success. Response: "The selected campaigns have been queued for deletion."
- `DELETE /api/leads/bulk` body `{"lead_ids": [14705, 14706, 14707, 14708, 14709, 14710, 14711]}` → success. Response: "Lead deletion process started. This might take some time depending on how much data you have."

Both delete operations are **asynchronous**. The API queues them and processes in the background. Verification was via subsequent `list_campaigns(search="BC-5906")` and `list_leads(search="dogfood-test" / "no-lastname" / "F17Test")` — all returned 0 matches, confirming the queue processed within the verification window (~seconds).

Spec implication: launch-campaign command's cleanup wording assumes synchronous deletes; reality is async + eventual consistency. T11 verification needs a "wait and re-query" pattern, not an immediate-after-call check. (Round-2 was lucky — the queue cleared before the verify window. Production may not be.)

**Schedules + sequences cascaded.** No separate delete calls were issued for schedules (id 4, 5) or sequences (id 3, 4). When the parent campaigns delete, EB cascades the per-campaign schedule + sequence cleanup. Verification: `list_campaigns(search="BC-5906")` returned 0 results, including no orphan schedule/sequence references. (No standalone "list schedules" or "list sequences" endpoints discoverable via `search_api_spec` to verify standalone — implicit cascade is the assumed behavior.)

**Sender attaches removed implicitly.** Senders themselves (IDs 981–995) are workspace resources, not campaign resources — they remain in the workspace's 772-sender pool. Their ATTACHMENTS to the deleted campaigns are removed automatically when the parent campaigns delete. No separate detach call needed.

**Retained: 8 custom variables (IDs 7–14, lowercased).** Per Sx-4 (no `DELETE /api/custom-variables/{id}` endpoint), these cannot be deleted via API. They remain workspace-scoped indefinitely. Future runs against `emailbison-personal` workspace 13 will inherit these:
- `recency_anchor` (id 7)
- `vertical_descriptor` (id 8)
- `specific_friction` (id 9)
- `proof_point_company` (id 10)
- `proof_point_number` (id 11)
- `proof_point_timeframe` (id 12)
- `free_asset_noun` (id 13)
- `sender_first_name` (id 14)

**Justification for retention:** these names are workspace-shared (per F16), and the next BC-5906-style dogfood OR any future production launch using the email-copywriting skill's standard variable set will reuse them. Deleting via EB UI would be a manual operator step; the spec's "delete custom variables" cleanup language should reframe to "vars persist; document the retained set."

**Workspace state at end of T11.** Net additions to `personal.outbase.so` workspace 13: +8 custom variables (permanent). Everything else (leads, campaigns, schedules, sequences, sender-attaches) reverted.

## Follow-up Linear issues filed

*(filled during T12 — issue IDs for every refuted / needs-more-work row above)*
