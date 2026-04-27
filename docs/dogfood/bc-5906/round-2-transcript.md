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

*(read-only — re-runs round-1's pre-flight steps; expected: cross-mapping flag fires per F2, all 13 sanity checks pass, lead spot-check renders deterministically with first-option spintax)*

## Phase 2 HOST LOOKUP — pre-walk summary

*(read-only — Bash `dig` per F10; expected ESP distribution: Google 4 / Microsoft 2 / Other 0 → F12 skip-empty drops Other; 2 segments survive)*

---

## Phase 3 VARIABLES — live-walk

*(populated during execution)*

### F14 — `list_custom_variables` pagination

*(populated during execution)*

### F15 — Conflicting-variable resolution

*(populated during execution)*

### F16 — Workspace-scoped collision

*(populated during execution)*

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
| F14 | `list_custom_variables` pagination | *pending* | | |
| F15 | Conflicting-variable resolution | *pending* | | |
| F16 | Workspace-scoped variable collision | *pending* | | |
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
