# BC-6303 — launch-campaign metadata schema (F21 + F31 + Phase 8 schedule_id rename)

**Issue:** [BC-6303](https://linear.app/brite-nites/issue/BC-6303)
**Scope:** Docs-only spec edit to `plugins/marketing/commands/launch-campaign.md`. No code, no tests, no MCP.
**Verification:** `./scripts/validate.sh` exits 0; `./scripts/check-guardrails.sh` exits 0; visual diff review.
**Closes the loop:** Last open spec-fix from BC-5906 round-2 dogfood chain (8 prior shipped: BC-6298, 6299, 6300, 6301, 6302, 6304, 6306, 6307).

---

## Pre-write decision points

### D1 — F21 shape (resolved by issue body)
Issue's "Proposed schema (consolidated)" picked `lead_ids_by_bucket: {bucket: [ids]}` over `lead_id_to_email_map`. Going with that. `lead_id_to_email_map` would force Phase 6 to re-derive bucket→IDs by joining email→bucket from CSV state at resume time; the direct map is the simpler resume primitive.

### D2 — Phase 8 vendor-API field vs metadata field
The vendor API request body `{"schedule_id": N}` is EB's parameter name and stays. Only the **metadata JSON field** renames `schedule_id`→`schedule_template_id`. Phase 8 steps 1, 5 (vendor body refs) keep `schedule_id`. Step 3 (operator prompt render) and step 7 (metadata write) get updated. This was implicit in the issue but worth calling out — confusing the two would either break the API or break the schema rename.

### D3 — `activated_per_campaign` initialization timing
Issue says "populate per loop iteration" in Phase 11 step 6. But Phase 5 (CAMPAIGN CREATE) creates `campaign_ids: {bucket: id}`. Two options:
- **(a)** Initialize `activated_per_campaign: {bucket: null}` keys at Phase 5 step 9 (when buckets are known), then set ISO-8601 timestamps in Phase 11 step 4 per-iteration.
- **(b)** Lazy-initialize the object at Phase 11; absent buckets implicitly `null`.

Going with **(a)** — explicit init mirrors the `campaign_ids` write pattern, downstream readers don't have to handle absent keys vs null keys differently, and the resume rule ("skip campaigns already activated") needs the bucket keys present to drive the iteration.

### D4 — Phase 11 step 6 timing
Issue says "Phase 11 step 6 — populate `activated_per_campaign[bucket]` per loop iteration." The current step 6 is the **finalize** step (single write at end of loop). The per-iteration write actually happens in step 4 (the loop body). Plan:
- **Step 4 (per-iteration)**: write `activated_per_campaign[bucket] = "<ISO-8601>"` immediately after each successful resume call (so a mid-loop crash records partial progress).
- **Step 6 (finalize)**: existing `activated: true`, `activated_at: "<final-ISO>"`. The global `activated` flips to true ONLY when every entry in `activated_per_campaign` is non-null.

This means the issue's "Phase 11 step 6" guidance is slightly imprecise — the per-iteration write belongs in step 4. I'll note this in the plan and write it in the right place; this is a docs-only correction inside the same intent.

---

## Tasks

### Task 1 — Schema § additions
**File:** `plugins/marketing/commands/launch-campaign.md`
**Section:** § Launch metadata schema (lines 131–186)

**Edits:**
1. In the JSON example block (lines 135–161), insert after `"lead_ids_uploaded": 127,` (line 148):
   ```
     "lead_ids_by_bucket": {"Google": [14706, 14707, 14708], "Microsoft": [14709], "Other": [14710, 14711]},
   ```
2. Rename `"schedule_id": 42,` (line 153) to `"schedule_template_id": 3,` and insert directly after:
   ```
     "campaign_schedule_ids": {"Google": 4, "Microsoft": 5, "Other": 6},
   ```
3. After `"activated_at": null,` (line 157), insert:
   ```
     "activated_per_campaign": {"Google": null, "Microsoft": null, "Other": null},
   ```
4. Append three new bullets to the "Optional fields written by specific phases" list (after line 182, before the schema-contract paragraph at line 184):
   - Phase 5 step 9 + Phase 11 step 4: `activated_per_campaign: {<bucket>: <ISO-8601> | null, ...}` — keys initialized at Phase 5 (one per bucket in `campaign_ids`); values flip from `null` to ISO-8601 timestamp at the moment each campaign's resume call returns. Global `activated` flips to `true` only when every entry is non-null.
   - Phase 6 step 7: `lead_ids_by_bucket: {<bucket>: [<lead_id>, ...], ...}` — per-bucket lead IDs; the resume primitive for re-running Phase 6 from metadata alone.
   - Phase 8 step 7: `schedule_template_id: <id>` (renamed from `schedule_id`) + `campaign_schedule_ids: {<bucket>: <cloned_schedule_id>, ...}` — the template ID applied (source) plus the per-campaign cloned schedule entity IDs returned by `create_schedule_from_template` (round-2 confirmed: each apply creates a new schedule entity, not a reference).
5. Update the prose paragraph at line 163 ("`last_completed_phase` advances monotonically...") — minor tweak: change "`activated` flips to `true` only on Phase 11 success" → "`activated` flips to `true` only when every entry in `activated_per_campaign` is non-null (Phase 11 finalization)."

**Verification:** `grep -n "lead_ids_by_bucket\|schedule_template_id\|campaign_schedule_ids\|activated_per_campaign" plugins/marketing/commands/launch-campaign.md` shows ≥4 hits each (1 in schema example, ≥1 in optional-fields list, ≥1 in phase steps).

---

### Task 2 — Phase 5 step 9 (initialize `activated_per_campaign` keys)
**File:** `plugins/marketing/commands/launch-campaign.md`
**Section:** § Phase 5 (the metadata write at end of Phase 5)

**Goal:** Initialize the `activated_per_campaign` object with bucket keys mapped to `null` at the same point `campaign_ids` is written. This avoids a separate code-path in Phase 11 that has to detect absent keys vs null keys.

**Edit:** Locate the Phase 5 metadata-write step (search `last_completed_phase: 5`). After the line that sets `campaign_ids: {...}`, append a sentence:
```
Also set `activated_per_campaign: {<bucket>: null}` for each bucket in `campaign_ids` — keys are pre-populated to null so Phase 11 step 4 can flip them per iteration without first probing for object presence.
```

**Verification:** Phase 5's metadata-write step (the one that sets `campaign_ids`) explicitly mentions `activated_per_campaign` initialization.

---

### Task 3 — Phase 6 step 7 populate `lead_ids_by_bucket`
**File:** `plugins/marketing/commands/launch-campaign.md`
**Section:** § Phase 6 step 7 (line 585)

**Current:** `7. **Append to metadata JSON.** The `campaign_ids` already list the per-campaign mapping. Add a sibling `lead_attach_counts` object mirroring `esp_segments`. Set `last_completed_phase: 6`.`

**Edit:** Replace with:
```
7. **Append to metadata JSON.** The `campaign_ids` already list the per-campaign mapping. Add `lead_attach_counts: {<bucket>: <count>, ...}` mirroring `esp_segments`. Add `lead_ids_by_bucket: {<bucket>: [<lead_id>, ...], ...}` from the bucket map built in step 2 — this is the resume primitive that lets a Phase 6 re-run reconstruct the bucket→IDs mapping without re-running Phase 2 MX lookups + CSV-row joins. Set `last_completed_phase: 6`.
```

**Verification:** `grep -n "lead_ids_by_bucket" plugins/marketing/commands/launch-campaign.md` shows a hit at the Phase 6 step 7 line.

---

### Task 4 — Phase 8 step 7 rename + per-campaign IDs
**File:** `plugins/marketing/commands/launch-campaign.md`
**Section:** § Phase 8 step 7 (line 688)

**Current:** `7. **Append to metadata JSON.** Set `schedule_id: N`, `last_completed_phase: 8`.`

**Edit:** Replace with:
```
7. **Append to metadata JSON.** Set `schedule_template_id: N` (the source template ID — same value the operator picked in step 4). For each campaign in `campaign_ids`, capture the cloned schedule ID returned by step 5's `create_schedule_from_template` call and write `campaign_schedule_ids: {<bucket>: <cloned_id>, ...}`. Round-2 of BC-5906 confirmed each apply creates a NEW schedule entity (clone), not a reference to the template — so per-campaign IDs are required to re-locate the schedule for resume / debug. Set `last_completed_phase: 8`.
```

**Sub-edit (Phase 8 step 3 prose render):** Line 675 currently reads `> Schedule template selected: \`{template-name}\` (ID {schedule_id})`. Change `{schedule_id}` → `{schedule_template_id}` for naming consistency with the metadata field (the operator-facing prompt should name the template, not the campaign clone).

**Sub-edit (Phase 8 step 5 — capture cloned IDs):** Currently reads `5. **Execute apply per campaign.** For each campaign ID, call `create_schedule_from_template` with `{"schedule_id": N}`.`. Append: `Capture the response's schedule ID per call — each apply returns a new cloned schedule entity (NOT a reference to the template); record into a scratch `campaign_schedule_ids` map keyed by bucket for the metadata write at step 7.`

**Sub-edit (Phase 8 vendor body refs):** Lines 671 (`Request body: {"schedule_id": N}`) and 686 (`call create_schedule_from_template with {"schedule_id": N}`) keep `schedule_id` — that's EB's API parameter name. Do NOT rename these.

**Verification:**
- `grep -n "schedule_template_id" plugins/marketing/commands/launch-campaign.md` shows ≥3 hits (schema example, optional-fields list, Phase 8 step 3 prose, Phase 8 step 7).
- `grep -n "campaign_schedule_ids" plugins/marketing/commands/launch-campaign.md` shows ≥3 hits.
- `grep -nE '"schedule_id":\s*N' plugins/marketing/commands/launch-campaign.md` still shows the 2 vendor-body hits at Phase 8 steps 1 and 5 (NOT renamed).

---

### Task 5 — Phase 11 step 4 per-iteration write of `activated_per_campaign`
**File:** `plugins/marketing/commands/launch-campaign.md`
**Section:** § Phase 11 step 4 (line 901, the per-campaign vendor gate loop)

**Current:** Step 4 has sub-bullets for first call, vendor gate, second call, abort branch. There's no metadata write per iteration.

**Edit:** Add a per-iteration metadata write inside the loop, right after the second `call_api` returns success. Wording:
```
   - **Per-iteration metadata write.** Immediately after the second `call_api` returns success, set `activated_per_campaign[<bucket>] = "<ISO-8601-of-the-second-call-response>"` in the metadata JSON. This is the resume primitive: if Phase 11 fails or aborts mid-loop, the metadata authoritatively records exactly which campaigns activated. The global `activated: true` does NOT flip yet — that's step 6's finalization, gated on every bucket key being non-null.
```

**Sub-edit (Phase 11 step 6 finalize):** Current line 912 reads `6. **Finalize metadata JSON.** Set `activated: true`, `activated_at: "<ISO-8601-of-final-resume-call>"`, `last_completed_phase: 11`.`. Replace with:
```
6. **Finalize metadata JSON.** Confirm every entry in `activated_per_campaign` is non-null. Set `activated: true` only when that holds, otherwise leave `activated: false` (a partial-success state — phase ran, some campaigns activated, the operator aborted before the rest). Set `activated_at: "<ISO-8601-of-final-resume-call>"` (the timestamp of the LAST successful per-iteration call, not a wall-clock now()). Set `last_completed_phase: 11` regardless — `last_completed_phase` tracks "phase ran", not "phase fully succeeded"; partial-success state is encoded in `activated_per_campaign`.
```

**Sub-edit (Phase 11 step 2 prose):** Line 894 currently reads `> Metadata will update \`activated: true\` and \`activated_at\` on success.`. Update to: `> Metadata will update \`activated_per_campaign[<bucket>]\` per campaign as each resume call succeeds. Global \`activated: true\` flips only when every campaign activates; partial success leaves it false with per-campaign timestamps recording exactly which ones ran.`

**Verification:**
- `grep -n "activated_per_campaign" plugins/marketing/commands/launch-campaign.md` shows ≥6 hits (schema example, optional-fields list, Phase 5 init, Phase 11 step 2 prose, Phase 11 step 4 per-iteration write, Phase 11 step 6 finalize, Error recovery row).
- The new per-iteration write references "second `call_api`" not "first" (per the BC-2707 turn-structure pattern).

---

### Task 6 — Error recovery overview Phase 11 row
**File:** `plugins/marketing/commands/launch-campaign.md`
**Section:** § Error recovery — overview, Phase 11 row (line 951)

**Current:** `| 11 ACTIVATE | Some campaigns Queued, others still Draft | \`activated: true\` only if ALL campaigns completed | Re-run with --activate; Phases 1–10 re-execute as no-ops; Phase 11 picks up at first un-activated campaign |`

**Edit:** Replace the metadata-state column to reference the new field:
```
| 11 ACTIVATE | Some campaigns Queued, others still Draft | `activated_per_campaign` records per-bucket timestamps; `activated: true` only when every entry is non-null | Re-run with `--activate`; Phases 1–10 re-execute as no-ops; Phase 11 reads `activated_per_campaign` and picks up at the first bucket whose value is still `null` |
```

**Verification:** `grep -n "activated_per_campaign" plugins/marketing/commands/launch-campaign.md | grep "11 ACTIVATE"` finds the row.

---

### Task 7 — Validate
Run from repo root:
```
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```
Both must exit 0.

Spot-check by re-reading the schema example end-to-end and confirming:
- Old `schedule_id` is gone from the schema example (vendor API body refs in Phase 8 steps 1/5 remain).
- New fields `lead_ids_by_bucket`, `schedule_template_id`, `campaign_schedule_ids`, `activated_per_campaign` all appear once in the example.
- All four also appear in the "Optional fields written by specific phases" bullet list.
- All four are referenced at their populating phase step.

---

## Out of scope (explicit non-goals)

- Do NOT change EB API request bodies — `{"schedule_id": N}` in vendor calls stays; only metadata field renames.
- Do NOT touch Phase 4 `lead_ids_uploaded` (count) — F21's `lead_ids_by_bucket` is additive, not a replacement.
- Do NOT add `lead_id_to_email_map` (the alternative F21 shape the issue listed) — issue's consolidated schema picked `lead_ids_by_bucket`.
- Do NOT update `docs/dogfood/bc-5906/launch-metadata.json` — that's historical evidence of round-2's actual state, not a contract artifact (per BC-6301 task-1 precedent: dogfood artifacts reflect historical truth, not current truth).
- No code, no tests, no MCP — this is docs-only. `./scripts/validate.sh` is the only check.

## Rollback

`git restore plugins/marketing/commands/launch-campaign.md` reverts everything; no other files touched.
