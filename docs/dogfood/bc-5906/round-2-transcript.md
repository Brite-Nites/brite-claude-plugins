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

*(populated during execution)*

### F17 — `last_name` requirement

*(populated during execution — side-test with synthetic `dogfood-test-99@brite.co` missing `last_name`)*

### F18 — Mid-chunk failure recovery

*(populated during execution — side-test with duplicate-email re-submit)*

### F19 — Vendor prompt wording

*(populated during execution — verbatim transcription of first-call confirmation prompt)*

---

## Phase 5 CAMPAIGN CREATE — live-walk

*(populated during execution)*

### F20 — Name collision

*(populated during execution — side-test creating two campaigns with identical names)*

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
| F17 | `bulk_create_leads` `last_name` requirement | *pending* | | |
| F18 | Mid-chunk failure recovery | *pending* | | |
| F19 | Vendor prompt wording (Phase 4) | *pending* | | |
| F20 | Campaign name collision | *pending* | | |
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
