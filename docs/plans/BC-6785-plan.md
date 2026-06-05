# Plan: BC-6785 — Round-5 launch-campaign dogfood walk

**Issue**: BC-6785 — BC-6554 round-5 launch-campaign dogfood — re-walk after Liquid + lead-create-case + regex fixes land
**Branch**: `corinne/bc-6785-bc-6554-round-5-launch-campaign-dogfood-re-walk-after-liquid`
**Tasks**: 13 (estimated ~6-7 hours)

> **Task-count rationale**: 13 exceeds the 12-task soft cap. A dogfood walk cannot be split across PRs — the convergence verdict (terminate vs. file round-6) depends on the full set of R-rows, the workspace pre/post state forms a single audit trail, and the per-phase pacing the operator chose maps 1-to-1 to commits. Tasks granularize commits, not deliverables.

## Prerequisites

- **Workspace `emailbison-personal` (workspace 13) is the production personal-email outbound workspace.** Live pre-state at round-5 start: 14,701 leads + 21 campaigns (incl. 1 completed production campaign with 2,433 sends and 48 replies) + 15 permanent custom variables. The "0 leads, 0 campaigns" claim in the BC-6785 issue body was archaeological — it referred to round-4's *cleanup of round-4 test data*, not to workspace emptiness. Round-5 walks against this production-populated workspace under an Isolation Discipline (see next section). Production data must remain intact at round close.
- All round-4 follow-ups landed: BC-6780 (PR #256), BC-6781 (PR #255), BC-6782 (PR #254), BC-6783 (Linear-only), BC-6784 (PR #257).
- Existing input artifacts (verified):
  - `docs/dogfood/bc-6308/test-leads.csv` (9 leads — 6 round-2 verbatim + 3 augmented role-based)
  - `docs/dogfood/bc-6308/test-copy.json` (clean — round-3 corrected, bare `step_2.subject` per BC-6301)
  - `docs/dogfood/bc-6554/test-copy-liquid.json` (BC-6781 rewritten with canonical `{% assign %}` form)
- Round-4 transcript at `docs/dogfood/bc-6554/round-4-transcript.md` is the regression baseline for R-rows that say "round-4 S-N regression."
- launch-campaign skill at `plugins/marketing/skills/launch-campaign/SKILL.md` is the live spec — every R-row's "Expected per spec" reads from this file (per BC-6784 task-1: live-vs-archaeological spec-value check).
- **CDR alignment**: skipped — CDR INDEX not indexed in Context7 for `/brite-nites/handbook`.
- **Precedent alignment**:
  - BC-6515 task-1 — live-verify before enshrining doc claims that trace to narrative-only artifacts.
  - BC-6780 task-1 — orchestrator must independently re-trace runtime; do not echo design vocabulary back.
  - BC-6781 task-1 — Liquid live-test was deferred from BC-6781 plan-gate to this round (R-25 ★).
  - BC-6784 task-1 — read live spec, not closed-issue body, at every R-row.
  - BC-6654 task-1 — simplify-pass + T12 self-read are complementary detectors (apply post-walk before close).
  - BC-6544/6548/6298 — plan-gate scope-expansion family; one applied at this plan-gate (R-28 sibling spot-check added).

## Isolation discipline (production-workspace overlay)

Round-5 mutations must be cleanly removable at round close without touching the 14,701 production leads or 21 production campaigns in workspace 13. Three rules apply to **every** task that creates a lead, campaign, or custom variable:

**Rule 1 — Lead tag.** Every round-5-created lead is tagged with `bc-6785-r5` immediately after creation. Cleanup at Task 13 filters by this tag in the EB UI; only tagged leads are deleted.

**Rule 2 — Campaign name prefix.** Every round-5-created campaign name starts with `BC-6785 |`. Cleanup at Task 13 filters campaigns by name prefix in the EB UI; only prefixed campaigns are archived/deleted. Sub-prefixes identify the walk variant:

- `BC-6785 | MAIN | {Email-type} | {ESP}` — multiplicative-grid main walk (Task 5).
- `BC-6785 | DECOY` — pre-created silent-duplicate-guard test campaign (R-9, Task 5).
- `BC-6785 | LIQUID` — Liquid live-test campaign (R-25 ★, Task 12).
- `BC-6785 | EMPTY-DEFAULT` — fail-closed gate test campaign (R-24, Task 12).
- `BC-6785 | LOWERCASE-TOKEN` — lowercase-token sad-path test campaign (R-26, Task 12).
- `BC-6785 | NO-HOST-LOOKUP` — combined `--no-host-lookup` walk campaign (R-27, Task 12).
- `BC-6785 | SINGLE-LEAD` — Phase 11 ACTIVATE single-lead test campaign (R-22 / R-23 ★, Task 11).

**Rule 3 — No new custom variables.** Custom variables cannot be deleted (no DELETE endpoint per round-3 Sx-4). Round-5 must not create any new permanent custom variables. Two consequences:

- The R-28 sibling-endpoint case-asymmetry probe MUST use an *existing* UPPERCASE-cased name (`RECENCY_ANCHOR` mapping to existing `recency_anchor`) — never a brand-new name. If a sibling endpoint silently lowercases and accepts, the existing variable's value is updated; no new permanent record is created.
- Any R-row that incidentally needs a new variable for the test design must be redesigned to reuse an existing one or skipped with rationale.

**Operator-email handling for Phase 10/11 + R-25 ★.** The single-lead test campaign in Task 11 uses a unique plus-addressed email (`corinne+bc-6785-r5@britenites.com`) so that any pre-existing `corinne@britenites.com` lead in workspace 13 is left untouched. Mail still routes to the operator's inbox via Gmail-style plus-addressing. The R-25 ★ Liquid test creates 3 net-new leads; their emails follow the pattern `r5-liquid-A@britenites.com` / `r5-liquid-B@britenites.com` / `r5-liquid-C@britenites.com` to keep them lexically separable from production.

**Verification of cleanability at every commit.** Each task that creates leads or campaigns ends its verify block by listing what new tagged/prefixed records exist; Task 13 close verifies the same list goes back to 0.

## Per-row protocol (applies to every R-row)

After each R-row's test, present a 3-way verdict to the operator before recording:

> **R-N output:** [verbatim API response or 2-3 sentence summary]
> **Expected per spec:** [what should have happened, per `plugins/marketing/skills/launch-campaign/SKILL.md` § Phase N]
> **Verdict:** ✅ Expected / ⚠️ Unexpected / 🔴 Needs round-6 follow-up
> **(If unexpected/follow-up):** Proposed framing: [agent error / spec drift / EB behavior change]
>
> Record as [verdict] and commit?

Operator confirms before transcript update. The 3-way verdict populates the R-row findings table at end of round. Source: auto-memory `feedback_dogfood_per_action_confirm.md` + round-4 protocol.

---

## Tasks

### Task 1: Worktree setup + workspace pre-state verification
**Files**: new worktree directory; new transcript stub at `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: Establish a clean working surface and confirm workspace 13 matches the documented pre-state before mutations begin.

**Implementation**:
1. Create worktree on branch `corinne/bc-6785-bc-6554-round-5-launch-campaign-dogfood-re-walk-after-liquid` (use the gitBranchName from Linear).
2. Inside worktree, copy input artifacts to `docs/dogfood/bc-6554-round-5/`:
   - `test-leads.csv` ← `docs/dogfood/bc-6308/test-leads.csv`
   - `test-copy.json` ← `docs/dogfood/bc-6308/test-copy.json`
   - `test-copy-liquid.json` ← `docs/dogfood/bc-6554/test-copy-liquid.json`
3. Stub round-5 transcript with header (date, workspace, branch, format, issue link), Walk parameters block, and empty Outcome summary table.
4. Verify EB workspace 13 identity + record live pre-state (production workspace — counts are background, not expected matches):
   - `mcp__emailbison-personal__get_active_workspace_info` → expect `active_workspace.id = "13"`, `name = "BriteNites Team"`, `is_primary: true`. **This is the only assertion** — workspace identity must be 13.
   - `mcp__emailbison-personal__list_leads` → record total lead count + first-page sample as background context for Task 13's diff (round-5 must not change the production lead count).
   - `mcp__emailbison-personal__list_campaigns` → record total campaign count + name list as background; round-5 cleanup at Task 13 must restore this same campaign roster.
   - `mcp__emailbison-personal__call_api` to `GET /api/custom-variables?per_page=50` → expect 15 entries matching round-4 cleanup roster (6 round-1-era + 8 round-2 + 1 `empty_test_var`). Custom variable count is the **only** workspace-state metric round-5 must hold constant (per Isolation Discipline Rule 3).
5. Record pre-state in transcript:
   - Workspace identity row (✅ if id=13, else 🔴 stop).
   - Production lead count + production campaign count + first-page samples (verbatim) as background.
   - 15-variable roster (verbatim, table form) as the cleanability baseline.
6. Apply per-row protocol to the **pre-state row** with this framing: ⚠️ if workspace 13 confirmed + 15 perm vars match + production state observed (this is the expected production-workspace verdict, not a 🔴 finding); 🔴 only if workspace identity ≠ 13 OR custom variable count ≠ 15 OR any of the 15 expected variable names is missing.

**Verify**:
- Worktree clean tree (only round-5 plan + new transcript + copied artifacts as untracked).
- Transcript stub exists with header + Walk parameters + Pre-state section + empty Outcome summary table.
- Pre-state row recorded with verbatim 15-variable list + production lead/campaign counts as background.
- Workspace identity confirmed = 13.

**Commit**: `BC-6785: round-5 setup — worktree + pre-state verification`

---

### Task 2: Phase 2 — multiplicative grid (R-1)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: Validate BC-6307 + BC-6654 multiplicative segmentation: email-type tagging + ESP MX classification + F12 prune.

**R-rows covered**: R-1.

**Implementation**:
1. Invoke `/marketing:launch-campaign` (planning-only, do not advance to Phase 3) with the round-5 inputs.
2. Observe Phase 2 step 1 output:
   - 9 leads tagged: 4 personal + 2 professional + 3 role per the 19+12 entry static lists per launch-campaign Phase 2 step 1.
   - Operator gate-2 choice: "Include all" (matches round-4).
3. Observe Phase 2 grid construction:
   - 9-cell grid (3 email-types × 3 ESP buckets).
   - F12 prune drops 5 empty cells → ~4 surviving.
4. Capture grid table verbatim into transcript.
5. Apply per-row protocol to R-1.

**Verify**:
- Transcript R-1 row populated with verdict (✅/⚠️/🔴) + verbatim grid table.

**Commit**: `BC-6785: Phase 2 walked — R-1 (multiplicative grid)`

---

### Task 3: Phase 3 — VARIABLES (R-2, R-3, R-4 ★)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: Validate Laravel pagination shape, persistent variable roster, and BC-6780 task-2 case-asymmetry fix (UPPERCASE artifact → lowercase EB-stored).

**R-rows covered**: R-2 (pagination), R-3 (15 perm vars present), R-4 ★ (BC-6780 task-2 fix-validation: 8 artifact UPPERCASE vars classify "existing → reuse" via `.lower()` comparison; zero new creates; zero 422 duplicates).

**Implementation**:
1. Continue launch-campaign through Phase 3.
2. Capture `list_custom_variables` response shape:
   - Verify Laravel `?page=N` paginated meta with hardcoded `per_page: 15` (R-2).
   - Iterate pages and collect all 15 perm vars (R-3).
3. Observe agent variable-classification output:
   - 8 UPPERCASE artifact names (`RECENCY_ANCHOR`, `VERTICAL_DESCRIPTOR`, etc.) all classified as "existing → reuse" by case-insensitive comparison per launch-campaign Phase 3 step 3.
   - Zero new-variable creates issued.
   - Zero 422 duplicate-name responses.
4. Apply per-row protocol to R-2, R-3, R-4 ★.

**Verify**:
- R-4 ★ keystone passes (no 422; no new creates).
- Transcript rows R-2, R-3, R-4 ★ populated with verdicts + evidence quotes.

**Commit**: `BC-6785: Phase 3 walked — R-2, R-3, R-4 (VARIABLES)`

---

### Task 4: Phase 4 — UPLOAD (R-5 ★, R-28 sibling spot-check, R-6, R-7)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: Validate BC-6780 task-1 case-asymmetry fix at lead-create binding + BC-6515 UUID forward-compat; spot-check sibling endpoints (R-28, added at plan-gate per 2026-05-07 issue comment).

**R-rows covered**: R-5 ★ (`POST /api/leads/multiple` happy path with lowercased `custom_variables[].name`), R-28 (sibling spot-check on `upsert_multiple_leads` + `bulk_create_leads_csv`), R-6 (forced duplicate-email atomic 422), R-7 (BC-6304 wrapper-vs-API spec read).

**Implementation**:
1. Continue launch-campaign through Phase 4 step 2.
2. R-5 ★: observe per-lead body-build:
   - `custom_variables[].name` lowercased at body-build per BC-6780 Phase 4 step 2 fix.
   - Pre-loop HARD FAIL guard verified by sanity-checking the rendered body (no UPPERCASE name should reach the wire).
   - Bulk-create succeeds; capture response with both `id` (int) and `uuid` (str) per BC-6515 forward-compat.
   - **Isolation Rule 1**: immediately after bulk-create succeeds, tag all 9 created leads with `bc-6785-r5` via `update_lead` per-lead OR a bulk tag-add call (whichever the EB API supports — verify against `search_api_spec` if needed). Confirm tag is set by re-reading one lead.
3. R-28 (sibling spot-check) — paused before next campaign mutation:
   - **Per Isolation Rule 3**: use the existing UPPERCASE-cased name `RECENCY_ANCHOR` — NEVER a brand-new variable name. Custom variables cannot be deleted from EB; a brand-new name would persist permanently in the production workspace.
   - Build a minimal payload with one lead containing `custom_variables: [{ name: "RECENCY_ANCHOR", value: "<test-value>" }]` and a unique synthetic email (e.g., `r5-sibling-test-A@britenites.com`).
   - Hit `mcp__emailbison-personal__call_api` against `POST /api/leads/upsert-multiple` with the payload — record HTTP status + response body.
   - Hit `POST /api/leads/bulk` (CSV-upload variant) with an inline CSV containing one UPPERCASE column header `RECENCY_ANCHOR` and a unique synthetic email (e.g., `r5-sibling-test-B@britenites.com`) — record HTTP status + response body.
   - Classify each result: (a) same 422 rule, (b) silent lowercasing (existing `recency_anchor` value updated), (c) other.
   - **Cleanup before resuming main walk**: tag any leads that were successfully created by the spot-check with `bc-6785-r5` (so they're caught by Task 13's filter), or delete them immediately via `mcp__emailbison-personal__call_api DELETE /api/leads/{id}`.
   - Verify net-new permanent variable count is still 15 after the spot-check (re-call `GET /api/custom-variables` and assert no new entries).
4. R-6: pre-load 1 of the 9 dogfood leads (e.g., `dogfood-test-01@gmail.com`) via direct `create_lead` (tag with `bc-6785-r5`), then resume Phase 4 to force a duplicate-email collision in a 9-lead chunk → expect all-or-nothing 422 per Sx-8. After the 422 fires, untag and re-attempt bulk via the main walk (or accept that the pre-loaded lead is the "real" one and skip the bulk's first lead in subsequent attaches — record whichever path is taken).
5. R-7: read launch-campaign Phase 4 spec for the wrapper-vs-API gate prose (BC-6304 / Sx-9). Confirm spec text still differentiates `mcp__*__create_lead` (wrapper, agent-side gate) vs `call_api POST /api/leads/multiple` (API direct).
6. Apply per-row protocol to R-5 ★, R-28, R-6, R-7.

**Verify**:
- R-5 ★ keystone passes.
- All 9 main-walk leads carry the `bc-6785-r5` tag (verify via `list_leads` filtered by tag — expect ≥9 results; if R-28 added more they'll appear here too).
- Permanent custom variable count is still 15 (no new variables created by R-28).
- R-28 produces a documented (a/b/c) classification per sibling endpoint with verbatim response evidence. If either sibling rejects with 422 or behaves divergently, file an issue body draft as a commit-time artifact for round-close (does not gate this commit).
- Transcript rows R-5 ★, R-28, R-6, R-7 populated.

**Commit**: `BC-6785: Phase 4 walked — R-5, R-28 (sibling spot-check), R-6, R-7 (UPLOAD)`

---

### Task 5: Phase 5 — CAMPAIGN CREATE (R-8 ★, R-9, R-10, R-11)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: Validate BC-6514 + BC-6654 multiplicative create + BC-6302 silent-duplicate guard + BC-6306 plain_text + BC-6544 PATCH-omit semantics.

**R-rows covered**: R-8 ★ (multiplicative create + naming + segments map), R-9 (BC-6302 silent-duplicate guard via pre-create decoy), R-10 (BC-6306 `plain_text: true` per campaign — no `reputation_building` / `can_unsubscribe`), R-11 (BC-6544 PATCH-omit live test).

**Implementation**:
1. Continue Phase 5 happy path:
   - ~4 surviving cells → ~4 campaigns created with naming `BC-6785 | MAIN | {Email-type} | {ESP}` per BC-6514 / BC-6654 + Isolation Rule 2. The `BC-6785 | MAIN |` prefix replaces the spec's `{base}` slot for round-5; record this deviation in the transcript with rationale (production-workspace overlay).
   - `metadata.segments` map keyed by `{email_type}|{esp}`.
2. R-9: before resuming Phase 5, pre-create one decoy campaign via `mcp__emailbison-personal__create_campaign` with the name `BC-6785 | DECOY | {one of the surviving cell keys}` — same logical name shape that the main walk would produce, so the silent-duplicate guard fires. Resume Phase 5 — verify the branched gate-5 render (silent-duplicate guard fires, operator presented with "skip / re-create / abort" options per F20). Choose "skip"; record what reuse path is taken. The decoy campaign carries the `BC-6785 |` prefix and is removed at Task 13.
3. R-10: read each created campaign via `get_campaign({id})` and confirm `plain_text: true` is set. Confirm `reputation_building` and `can_unsubscribe` are at their defaults (not modified) per BC-6306 actual scope and BC-6783 hypothesis correction.
4. R-11: pick one campaign and PATCH it via `update_campaign({id})` with a payload that *omits* `plain_text`. Re-read with `get_campaign` and observe `plain_text` reverts to `false` per BC-6544 PATCH-omit semantics. Restore via re-PATCH with `plain_text: true`.
5. Apply per-row protocol to R-8 ★, R-9, R-10, R-11.

**Verify**:
- R-8 ★ keystone passes.
- All round-5 campaigns created in this task carry the `BC-6785 |` name prefix.
- `list_campaigns` filtered by `search: "BC-6785"` returns the expected count (~4 main + 1 decoy = ~5).
- Transcript rows R-8 ★, R-9, R-10, R-11 populated with campaign IDs + verdicts.

**Commit**: `BC-6785: Phase 5 walked — R-8, R-9, R-10, R-11 (CAMPAIGN CREATE)`

---

### Task 6: Phase 6 — ATTACH LEADS (R-12, R-13 deferred)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: Validate F21/BC-6303 lead bucket mapping; defer F22/BC-6545 `allow_parallel_sending` per round-4 deferral.

**R-rows covered**: R-12 (lead bucket mapping + metadata), R-13 (DEFER per round-4 — BC-6545 spec-read suffices).

**Implementation**:
1. Continue Phase 6.
2. R-12: observe agent attaching leads to campaigns by cell. After all attaches complete, read campaigns and confirm:
   - Each campaign's lead-count matches the cell's bucket size.
   - launch-metadata records `lead_ids_by_bucket` + `lead_attach_counts` per cell key.
3. R-13: skip (deferred). Record in transcript with note: "Deferred — BC-6545 spec-read suffices; live-fire requires pre-poison setup not justified for institutional-memory-only check."
4. Apply per-row protocol to R-12.

**Verify**:
- Transcript row R-12 populated; R-13 marked DEFERRED with rationale.

**Commit**: `BC-6785: Phase 6 walked — R-12 (ATTACH LEADS); R-13 deferred`

---

### Task 7: Phase 7 — ATTACH SENDERS (R-14, R-15, R-16)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: Validate Laravel pagination + status-filter case-sensitivity + partial-pool decision + post-attach eventual-consistency.

**R-rows covered**: R-14 (F23/Sx-10/Sx-11 combined: pagination + per_page silently ignored + lowercase `connected` filter), R-15 (F24 partial-pool: 15 senders from page 1 attached to all N campaigns), R-16 (F26/R-15 sub-second post-attach Δ).

**Implementation**:
1. Continue Phase 7.
2. R-14: capture `list_sender_emails` request/response. Test `?per_page=N` is silently ignored (returns 15 per page regardless). Test `status` filter with `connected` (lowercase, expect success) vs `Connected` (titlecase, expect zero results or error).
3. R-15: observe agent partial-pool selection. 15 senders from page 1 attached to all N campaigns.
4. R-16: immediately after attach, call `get_campaign({id})` and confirm sender list reflects the attach (sub-second eventual-consistency).
5. Apply per-row protocol to R-14, R-15, R-16.

**Verify**:
- Transcript rows R-14, R-15, R-16 populated.

**Commit**: `BC-6785: Phase 7 walked — R-14, R-15, R-16 (ATTACH SENDERS)`

---

### Task 8: Phase 8 — SCHEDULE (R-17)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: Validate F27 + BC-6303 schedule_template_id rename + clone-per-campaign behavior.

**R-rows covered**: R-17.

**Implementation**:
1. Continue Phase 8.
2. R-17: confirm workspace 13 has 1 template (id 3, M-F 08:00-20:00 America/Denver). Observe agent attaching this template to all N main campaigns. Read launch-metadata and confirm:
   - `schedule_template_id: 3` (the source)
   - `campaign_schedule_ids: {<bucket>: <clone-id>}` map populated per BC-6303.
3. Apply per-row protocol to R-17.

**Verify**:
- Transcript row R-17 populated with metadata block.

**Commit**: `BC-6785: Phase 8 walked — R-17 (SCHEDULE)`

---

### Task 9: Phase 9 — SEQUENCE (R-18, R-19)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: Validate BC-6301 variant boolean + bare step_2.subject + Re: prepend; F29/F30 + BC-6548 wait_in_days clamp + UPPERCASE-only token rule.

**R-rows covered**: R-18 (variant boolean + Re: prepend), R-19 (wait_in_days clamp + thread_reply boolean + token rule happy-path).

**Implementation**:
1. Continue Phase 9.
2. R-18: observe sequence step build:
   - Step submitted with `"variant": false` (boolean, not int).
   - `step_2.subject` submitted bare (no `Re:` prefix).
   - Post-create read confirms stored subject has single `Re: ` prepend.
3. R-19: observe wait clamp:
   - `step_1.wait_in_days` clamped via `max(1, n)` per F29.
   - `thread_reply` set as boolean per v1.1 spec.
   - All token references in body+subject are UPPERCASE per BC-6548 rule (no HARD FAIL).
4. Apply per-row protocol to R-18, R-19.

**Verify**:
- Transcript rows R-18, R-19 populated; verbatim stored-subject quote captured for R-18.

**Commit**: `BC-6785: Phase 9 walked — R-18, R-19 (SEQUENCE)`

---

### Task 10: Phase 10 — PREVIEW (R-20, R-21 ★)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`
**Why**: First live-walk of Phase 10 in the chain. Validate Mode 1 local render + Mode 2 `--test-send` real-render; verify BC-6784 `{SENDER_*}` shadow.

**R-rows covered**: R-20 (Mode 1 local render + sanity checklist), R-21 ★ (Mode 2 `--test-send` real-render comparison).

**Implementation**:
1. Continue Phase 10 Mode 1:
   - Pick representative lead per spec (first lead in largest cell).
   - Agent renders step_1 + step_2 locally.
   - Sanity checks: no unresolved `{VAR}`, no unresolved spintax, no em-dash, no `<p>`, no `{{`.
   - Capture rendered preview verbatim.
2. R-21 ★: pick one of the multiplicative-grid campaigns (any `BC-6785 | MAIN | ...` campaign); invoke `/marketing:launch-campaign --test-send corinne+bc-6785-r5@britenites.com` (plus-addressing per Isolation Discipline) — or the equivalent direct API call per launch-campaign spec. Capture EB API response. Operator confirms email received in inbox (plus-addressed mail still routes to `corinne@britenites.com`).
3. Compare Mode 1 (local) render vs Mode 2 (real) delivery side-by-side in transcript:
   - `{SENDER_*}` resolution: Mode 1 shows artifact-default; Mode 2 should show the actual sender's first_name per BC-6784.
   - All other tokens should match.
4. Apply per-row protocol to R-20, R-21 ★.

**Verify**:
- R-21 ★ keystone passes (operator inbox receives test-send within minutes).
- Transcript rows R-20, R-21 ★ populated with both renders for diff comparison.

**Commit**: `BC-6785: Phase 10 walked — R-20, R-21 (PREVIEW)`

---

### Task 11: Phase 11 — ACTIVATE (R-22, R-23 ★)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`; new artifact `docs/dogfood/bc-6554-round-5/test-copy-single-lead.json`
**Why**: First live-walk of Phase 11 in the chain. Build separate single-lead test campaign with operator email, activate via `resume_campaign`, confirm queued state. **Round-5 closes here** per session decision.

**R-rows covered**: R-22 (single-lead test campaign build), R-23 ★ (resume_campaign + queued state confirmation).

**Implementation**:
1. R-22: build the single-lead test campaign from scratch (separate invocation, not part of multiplicative-grid):
   - Create `docs/dogfood/bc-6554-round-5/test-copy-single-lead.json` — 1 lead (`corinne+bc-6785-r5@britenites.com`, plus-addressed per Isolation Discipline), full 2-step sequence per artifact (variables resolvable for the single lead).
   - Tag the lead with `bc-6785-r5` post-create.
   - Walk Phases 3-9 inline for this campaign with `--no-host-lookup` to bypass multiplicative grid (one campaign with 1 lead). Campaign name: `BC-6785 | SINGLE-LEAD | activate-test`.
   - Capture campaign id.
2. R-23 ★: invoke `mcp__emailbison-personal__call_api` with `POST /api/campaigns/{id}/resume` (or use the wrapper `resume_campaign` per spec). Capture response.
3. Read campaign back via `get_campaign({id})` — confirm `status: "queued"` (or whatever queued shape EB uses; verify against current spec).
4. Apply per-row protocol to R-22, R-23 ★.

**Verify**:
- R-23 ★ keystone passes.
- Single-lead test campaign carries `BC-6785 | SINGLE-LEAD |` prefix; lead `corinne+bc-6785-r5@britenites.com` carries `bc-6785-r5` tag.
- Transcript rows R-22, R-23 ★ populated; campaign id + verbatim resume_campaign response + verbatim queued-state quote captured.
- **Round-5 main walk closes here** per session decision (delivery verification is post-close investigation surface).

**Commit**: `BC-6785: Phase 11 walked — R-22, R-23 (ACTIVATE)`

---

### Task 12: Side-flows (R-24, R-25 ★, R-26, R-27)
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`; side-flow copy variants under `docs/dogfood/bc-6554-round-5/`
**Why**: Validate fail-closed gate (R-24), Liquid live render via UI Preview Body (R-25 ★ — keystone keystone for BC-6781), lowercase-token sad path (R-26), and combined arg flags (R-27).

**R-rows covered**: R-24 (BC-6556 empty-default Phase 1 step 5 HARD FAIL), R-25 ★ (BC-6781 + BC-6782 paired live test of canonical Liquid `{% assign %}` form against 3 leads with varied custom_variable values), R-26 (BC-6548 lowercase-token HARD FAIL at Phase 1 step 6 OR Phase 9 step 2), R-27 (combined `--no-host-lookup` + `--no-segment` invocations).

**Implementation**:
1. R-24:
   - Build `test-copy-empty.json` — copy variant with `RECENCY_ANCHOR.default: ""` AND no Liquid wrapper around the token in body.
   - Run launch-campaign with this artifact through Phase 1 only (HARD FAIL is expected before any campaign or lead is created).
   - Expect HARD FAIL at Phase 1 step 5 with diagnostic citing empty-default + non-Liquid body.
2. R-25 ★ (Liquid keystone):
   - Use `test-copy-liquid.json` (BC-6781 rewritten with canonical `{% assign %}` form).
   - Build a 3-lead CSV (`test-leads-liquid.csv`) with varied custom_variable values **and uniquely-prefixed emails** per Isolation Discipline:
     - Lead A: `r5-liquid-A@britenites.com` — `recency_anchor` populated, `proof_point_company` populated.
     - Lead B: `r5-liquid-B@britenites.com` — `recency_anchor` empty, `proof_point_company` populated.
     - Lead C: `r5-liquid-C@britenites.com` — `recency_anchor` populated, `proof_point_company` empty.
   - Walk launch-campaign through Phase 9 with this artifact. Campaign name: `BC-6785 | LIQUID | live-test`. Tag the 3 created leads with `bc-6785-r5` post-create.
   - Use EB UI Preview Body on the resulting campaign for each of the 3 leads.
   - Verify per-lead rendering:
     - Pattern A (`{{ recency_anchor | default: "recently" }}`): renders the actual `recency_anchor` value when populated; renders `"recently"` fallback when empty.
     - Pattern B (`{% if proof_point_company %}...{% else %}NO_PROOF_POINT_company{% endif %}`): renders truthy branch when populated; renders `else` branch when empty.
   - Capture quotes/screenshots for each of the 6 render outputs (3 leads × Pattern A/B).
   - Test BC-6782 regex tightening: build a copy variant with naked Liquid form (no `{% assign %}` wrapper) and run through Phase 1 step 5 → expect HARD FAIL (no campaign/lead created).
3. R-26: build `test-copy-lowercase.json` with one lowercase `{first_name}` token in body. Run through Phase 1 → expect HARD FAIL at step 6 OR Phase 9 step 2 per BC-6548 (no campaign/lead created on HARD FAIL path; if Phase 9 is reached, campaign name = `BC-6785 | LOWERCASE-TOKEN | sad-path` and the leads carry `bc-6785-r5` tag). Record where the failure fires.
4. R-27:
   - (a) Run `--no-host-lookup` invocation: walks Phase 1 → skips Phase 2 → 1 combined campaign with all 9 leads. Campaign name: `BC-6785 | NO-HOST-LOOKUP | combined`. Reuse the `bc-6785-r5`-tagged main-walk leads — do not duplicate-create. If launch-campaign creates a fresh lead set, tag those with `bc-6785-r5` too.
   - (b) Run `--no-segment` invocation: expect arg-parse rejection per BC-6514 (this flag was removed; the rejection is the expected behavior — no leads or campaigns created).
5. Apply per-row protocol to R-24, R-25 ★, R-26, R-27.

**Verify**:
- R-25 ★ keystone passes (per-lead Liquid render verified across 3 leads × 2 patterns; regex tightening rejects naked form).
- All side-flow campaigns carry the `BC-6785 |` name prefix (filterable via `list_campaigns search: "BC-6785"`).
- All side-flow leads carry the `bc-6785-r5` tag (filterable via `list_leads tag_ids: [<bc-6785-r5 id>]`).
- No new permanent custom variables created (re-confirm 15 entries via `GET /api/custom-variables`).
- Transcript rows R-24, R-25 ★ (with 6 render quotes), R-26, R-27 populated.

**Commit**: `BC-6785: side-flows walked — R-24, R-25, R-26, R-27`

---

### Task 13: Close — transcript filing + workspace cleanup + loop-closing step
**Files**: `docs/dogfood/bc-6554-round-5/round-5-transcript.md`; possibly new round-6 issue
**Why**: Finalize transcript, clean workspace state, count blocking findings, decide convergent-close vs. round-6 file.

**Implementation**:
1. Finalize transcript:
   - Update Outcome summary table with verdict counts (✅ / ⚠️ / 🔴 / DEFERRED).
   - Add Round-5 follow-up candidates section listing every ⚠️/🔴 row with proposed framing.
   - Apply BC-6654 task-1 discipline: simplify-pass + T12 self-read on the finalized transcript before commit (these are complementary, not alternatives).
2. Clean up workspace 13 via EB UI — **filter strictly to round-5-tagged/prefixed records only; production data must remain intact**:
   - **Campaigns**: filter UI by name search "BC-6785" → expect ~6-8 results (4 main-grid + 1 decoy + 1 single-lead + 1 LIQUID + side-flow campaigns). Stop any active/queued ones first, then archive/delete each. **Do not touch any campaign without the `BC-6785 |` prefix.**
   - **Leads**: filter UI by tag `bc-6785-r5` → expect ~13-16 results (9 main-walk + ≤2 R-28 spot-check + 3 R-25 Liquid leads + 1 single-lead operator + any R-27 fresh leads). Delete all tagged leads. **Do not touch any untagged lead.**
   - **Custom variables**: re-call `GET /api/custom-variables` and assert count = 15 with the original roster intact. If a new entry exists, that is a 🔴 round-5 finding (Isolation Discipline Rule 3 violated by a sibling endpoint or by an unintended path); record in the transcript and file a follow-up — but the variable cannot be deleted (no DELETE endpoint).
   - **Production data check**: re-call `list_leads` (top-page sample) and `list_campaigns` (count + names); diff against the Task 1 pre-state record. The non-`BC-6785` campaigns and untagged leads must match the pre-state exactly. Any divergence is a 🔴 close-time finding.
3. Loop-closing step:
   - Count blocking findings (🔴 rows + any ⚠️ that the operator decides to escalate).
   - **If zero blocking findings**: mark BC-6785 Done with comment "Convergence achieved — chain terminates here. Convergent-dogfood pattern reached instance-3 → architecture-9 promotion-eligible."
   - **If ≥1 blocking findings**: file round-6 dogfood issue (new BC-NNNN) + spinoff follow-up issues; set blocked-by relationships per protocol; comment on BC-6785 with the round-6 issue link before marking it Done.
4. If R-28 found a sibling-endpoint divergence in Task 4, file that as a separate follow-up issue (independent of round-6 vs convergent decision).

**Verify**:
- Transcript Outcome summary populated.
- Round-5 lead set (`bc-6785-r5`-tagged) deleted from workspace 13 → tag-filtered `list_leads` returns 0.
- Round-5 campaign set (`BC-6785 |` prefix) archived/deleted → name-filtered `list_campaigns search: "BC-6785"` returns 0.
- Permanent custom variable count = 15 (unchanged from pre-state). If a new entry slipped in, it is recorded as a 🔴 finding (cannot be deleted).
- Production data unchanged: top-page `list_leads` sample and full `list_campaigns` roster diff against Task 1 pre-state record returns 0 differences for non-`BC-6785` records.
- BC-6785 either marked Done with convergence comment OR has a round-6 issue link before Done.

**Commit**: `BC-6785: round-5 close — transcript finalized + workspace cleaned + [convergent / round-6 filed]`

---

## Task Dependencies

- Task 1 must complete before Task 2 (worktree must exist; workspace identity must be confirmed = 13; production pre-state must be recorded as the cleanability baseline; custom variable roster must match the expected 15).
- Tasks 2 → 11 are sequential (each phase walks the live launch-campaign invocation; later phases depend on earlier-phase mutations).
- Task 12 (side-flows) is independent of Task 11 in *spec* but should run after Task 11 to keep workspace state coherent during the main walk; side-flow invocations create their own campaigns and don't interfere with the multiplicative-grid set.
- Task 13 must run last (depends on all R-rows being recorded + verdicts applied).
- Within Task 12, the four side-flow R-rows (R-24, R-25 ★, R-26, R-27) are independent and can be reordered, but R-25 ★ should run with the most attention since it's the keystone for BC-6781's deferred-verify (BC-6781 task-1).

## Verification Checklist

- [ ] All 27 R-rows from issue body + R-28 sibling spot-check have transcript entries with 3-way verdicts.
- [ ] R-13 marked DEFERRED with rationale.
- [ ] All 6 keystone rows (R-4 ★, R-5 ★, R-8 ★, R-21 ★, R-23 ★, R-25 ★) pass.
- [ ] All 5 round-4 follow-ups (BC-6780, BC-6781, BC-6782, BC-6783, BC-6784) confirmed fixed by their corresponding R-rows OR a round-6 follow-up filed for any unfixed.
- [ ] Transcript at `docs/dogfood/bc-6554-round-5/round-5-transcript.md` follows round-4 structure (header, walk parameters, outcome summary, inputs, workspace pre-state, R-rows by phase, side-flows, follow-up candidates).
- [ ] Workspace 13 round-5 lead set (`bc-6785-r5` tag) = 0 after Task 13 cleanup; round-5 campaign set (`BC-6785 |` prefix) = 0; permanent custom variable roster = 15 (unchanged from pre-state).
- [ ] Workspace 13 production state (untagged leads + non-`BC-6785` campaigns) is identical to the Task 1 pre-state record (modulo natural production activity outside the walk's window — operator judgment).
- [ ] BC-6785 marked Done with either convergence comment or round-6 issue link in comment.
- [ ] Out-of-scope: post-close delivery verification of Phase 11 sequence (step 1 + step 2 + threading) over ~4-5 days; if either step fails to deliver or threads incorrectly, file a separate follow-up investigation issue.

## Lint / build / test commands

This is a manual dogfood walk — no unit-test command applies. Project-level checks that DO apply at commit time (per CLAUDE.md):

- `./scripts/validate.sh` — Validate all plugins (CI-equivalent). Run before any commit that touches `plugins/<plugin>/{hooks,skills,commands,agents}/`.
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — Enforce CLAUDE.md size + anti-slop. This walk does not touch CLAUDE.md.

The plan's commits touch only `docs/dogfood/bc-6554-round-5/` (a docs-only path). No plugin version bumps required.
