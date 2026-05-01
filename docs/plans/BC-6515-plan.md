# BC-6515 — EB lead-create now returns `uuid` (forward-compat additive)

**Issue:** [BC-6515](https://linear.app/brite-nites/issue/BC-6515) — Low priority
**Branch:** `corinne/bc-6515-bc-6308-follow-up-eb-now-returns-uuid-on-lead-create`
**Scope:** Single-file docs edit to `plugins/marketing/tools/integrations/email-bison.md`. No skill/command/version bump (edit is under `tools/`, not `{hooks,skills,commands,agents}`).
**Expected verdict:** TRIVIAL (12th in BC-5906 → BC-6308 chain).

## Live verification (captured 2026-05-01 20:41 UTC, workspace 13)

`POST /api/leads/multiple` body:
```json
{"leads": [{"first_name": "BC-6515", "last_name": "Verify", "email": "bc-6515-verify@brite.co", "title": "Test Verifier", "company": "Test Co"}]}
```

Response (literal, captured live):
```json
{
  "success": true,
  "data": [{
    "id": 14723,
    "uuid": "a1ad8f8d-2e14-45e7-b78a-4593983613fd",
    "first_name": "BC-6515",
    ...
  }]
}
```

Test lead cleaned up via `DELETE /api/leads/14723`.

## Tasks

### Task 1 — Add Leads subsection forward-compat note

**File:** `plugins/marketing/tools/integrations/email-bison.md`
**Section:** `## Tool inventory` → `### Leads (15 tools)` (currently lines 127–129)

**Current:**
```
### Leads (15 tools)

Lead create, bulk create (up to 500 per call), upsert, blacklist. See rate limits below for the 500-per-call cap ([WIP §6 Q6](...)).
```

**Replace with** (one paragraph appended, single sentence):
```
### Leads (15 tools)

Lead create, bulk create (up to 500 per call), upsert, blacklist. See rate limits below for the 500-per-call cap ([WIP §6 Q6](...)).

Lead-create responses (`POST /api/leads`, `POST /api/leads/multiple`) include both `id` (integer) and `uuid` (string) fields; use `id` for downstream API calls — every other EB endpoint that takes a lead reference accepts the integer form. The `uuid` field is forward-compatible additive (verified live 2026-05-01 — added in the ~3-day window between BC-5906 round-2 (2026-04-27) and BC-6308 round-3 (2026-04-30)).
```

**Validation:** grep for `uuid` in the file should now return exactly the new sentence(s).

### Task 2 — Prepend Last verified entry

**File:** `plugins/marketing/tools/integrations/email-bison.md`
**Section:** `## Last verified` (currently top entry is 2026-04-29 BC-6301)

**Insert as new top entry (before the existing 2026-04-29 line):**
```
`2026-05-01` — BC-6515: appended forward-compat note to § Tool inventory § Leads (15 tools) flagging that lead-create responses now include both `id` (integer) and `uuid` (string) fields. Verified live via `POST /api/leads/multiple` against `emailbison-personal` workspace 13 (lead ID 14723 created + deleted; raw response captured in `docs/plans/BC-6515-plan.md`). API spec response schema (`search_api_spec(POST /api/leads/multiple)`) does NOT yet list `uuid` — runtime added it ahead of spec docs.
```

(Demote existing `2026-04-29` BC-6301 entry to "Prior:" form, matching the existing chain pattern.)

**Validation:** the file's `## Last verified` first dated entry should now be `2026-05-01`.

### Task 3 — Run guardrails

```bash
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```

Expected: pass (no CLAUDE.md edits, only docs touch).

## Out of scope

- Any edit to `plugins/marketing/commands/launch-campaign.md` (issue §2 explicitly: "Spec stays on integer IDs").
- Any new `## Known gotchas` bullet (additive forward-compat, not a foot-gun).
- Plugin-version bump (edit is in `tools/`, not `{hooks,skills,commands,agents}`).
- Spec-doc-lag observation (per plan-gate scope-expansion question 2026-05-01 — user kept scope tight; can file separately later if it surfaces a real friction).
- Investigation of whether other resources (campaigns, sequences) also got `uuid`. Tracked for round-4 (BC-6554).

## Acceptance criteria

- [ ] Tool inventory § Leads paragraph mentions both `id` and `uuid` fields with guidance to use `id`.
- [ ] § Last verified top entry is `2026-05-01` BC-6515.
- [ ] `grep -n uuid plugins/marketing/tools/integrations/email-bison.md` returns ≥ 2 hits (both in the two new locations).
- [ ] No other file modified.
- [ ] No plugin-version bump.
