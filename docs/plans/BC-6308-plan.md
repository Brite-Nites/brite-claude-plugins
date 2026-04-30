---
title: BC-6308 — round-3 launch-campaign dogfood (live Phases 3–9 + R-1 through R-15 fix-validation)
issue: https://linear.app/brite-nites/issue/BC-6308
created: 2026-04-30
status: pending-approval
target-pr: docs/dogfood + transcript artifact only — no command-spec changes in this PR (refutations file as round-4 follow-ups; this round VALIDATES the round-2 fix landings)
---

# BC-6308 — Round-3 Launch Dogfood Plan

3rd iteration of the convergent-dogfood chain on `/marketing:launch-campaign` (round-1 BC-5826, round-2 BC-5906, round-3 THIS). Re-walks Phases 3–9 against `emailbison-personal` workspace 13 with all 9 round-2 follow-ups now landed (BC-6298–6304 + BC-6306–6307). The new dimension this round: **fix-validation** — every shipped follow-up gets a paired R-row to verify the corrections behave correctly in practice.

The walk also resolves two BC-6299 carryover unknowns (R-2a case-sensitivity, R-2b empty-value rendering) that the design doc explicitly deferred to round-3 with locked-in spot-check requirements.

---

## Issue ↔ Ground-truth amendments

Per BC-5947 → BC-5832 → BC-2717 (architecture-9 amendments-table precedent), reconcile issue-body claims against current reality before tasks.

| # | Issue body says | Ground truth | Resolution |
|---|---|---|---|
| 1 | Blocked by all 9 round-2 follow-ups | All 9 Done as of 2026-04-30 (PRs #228, #229, #230, #231, #232, #233, #234, #237, #238) | Unblocked. Spec contains all R-1 through R-9 fix targets at expected line ranges. |
| 2 | R-2a/R-2b require a real `/test-email` send to a verifiable inbox; "exception to the no-real-emails rule" | EB has a UI-side **Preview Body** button (per operator screenshot 2026-04-30) that resolves spintax, binds to a random attached lead, and resolves custom variables — without sending. The issue body's framing was based on round-2's claim that EB has no preview endpoint, which checked the API but not the UI. | Replace `/test-email` send with **UI Preview Body** as primary path. Real-email send retained ONLY as tie-breaker if UI preview shows ambiguous behavior. Documented as round-3 deviation from issue-body protocol. |
| 3 | "scoped to a single throwaway campaign + 2 test leads" | UI Preview Body picks a random lead from attached leads on each click; Refresh Email Variation cycles subject + body + lead + sender simultaneously. Single-campaign + 2-leads + refresh-until-both-cycle is probabilistic; deterministic targeting requires 1 lead per campaign. | Use **two** dedicated single-lead test campaigns (`BC-6308 RENDER TEST A` + `BC-6308 RENDER TEST B`) instead of one throwaway with 2 leads. Adds ~5 min setup; eliminates click-lottery noise from the case-sensitivity and empty-value evidence. |
| 4 | F22 (`allow_parallel_sending`) listed as R-12 | Round-2 brainstorm deferred F22 because it requires pre-poisoning a lead into another campaign before Phase 6 — adds setup-and-cleanup load not justified by F22's load-bearing-ness for the MVP launch path | Re-defer F22 unless operator explicitly requests live-validation at user gate 6. Same rationale as round-2 brainstorm decision 3. |

---

## Brainstorm decisions (2026-04-30)

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Reuse round-2 inputs verbatim or augment? | **Augment with 3 role-based addresses** — copy `docs/dogfood/bc-5906/test-leads.csv` + `test-copy.json` into round-3 worktree, append 3 rows: `info@dogfoodtest.com`, `sales@dogfoodtest.com`, `contact@dogfoodtest.com` | Round-2's pool was thin on the email-type axis (4 personal + 2 professional, 0 role). R-9 (BC-6307) needs role-based leads to verify Phase 2's new email-type segmentation. Fake `dogfoodtest.com` is non-resolving — safe even if `--activate` were fat-fingered. |
| 2 | Email-type filter at user gate 2 | **"Include all"** (max R-9 signal — all 3 email-type buckets exercised) | Conservative "Default" (skip role + personal) collapses to 1 brite.co campaign, leaving R-9 weakly verified. "Include all" routes all 9 leads into ESP segmentation → 3 main campaigns. |
| 3 | R-2a / R-2b path | **UI Preview Body in 2 dedicated single-lead test campaigns** (operator clicks the button, screenshots, reports rendering); real-email send to corinne@britenites.com retained as tie-breaker if UI preview ambiguous | Discovered by operator 2026-04-30 — EB has a UI-only preview that resolves spintax + custom variables without sending. Lower cost than real send, no reputation impact, deterministic targeting via 1-lead-per-campaign. Issue body's `/test-email` framing was based on round-2 only checking the API for a preview endpoint. |
| 4 | F22 (`allow_parallel_sending`) | **Re-defer** unless operator explicitly requests at gate 6 | Same as round-2 brainstorm decision 3. F22 isn't load-bearing for MVP launch path. |
| 5 | R-5 collision-trigger strategy | **Detect-and-decide in Phase 1 pre-flight** — if leftover round-2 campaigns or async-pending round-3 campaigns are present, pre-list naturally surfaces them and R-5 self-verifies. If clean, pre-create one fake `BC-6308 Round 3 \| Google` campaign just before main Phase 5 to force the duplicate path. | Avoids an unnecessary 6th campaign if workspace state already provides the trigger; ensures R-5 has a guaranteed trigger if not. |
| 6 | New permanent custom variable | **Yes — `empty_test_var`** for R-2b empty-value test. Documented as 9th permanent variable in workspace 13 (Sx-4 — no DELETE endpoint) | Reusing an existing variable (e.g., temporarily setting Lead B's `recency_anchor: ""`) overloads the variable's meaning. Dedicated `empty_test_var` is clearer for the round-3 transcript and any future round inheriting workspace state. |
| 7 | RENDER TEST A/B campaign topology | **Apply schedule template id 3 to each test campaign for symmetry with main campaigns**, even though schedule isn't a Preview Body prereq (Preview Body only requires leads + senders + sequence step) | Round-2 confirmed schedule application is sub-second; cleanup cascades automatically with parent delete. Eliminates "does Preview Body behave differently on a partially-formed campaign" as an unknown. Easy to skip during execution if it slows the walk. |
| 8 | Refuted-hypothesis handling | Capture in transcript inline; batch-create round-4 follow-up Linear issues at session end IF any blocking findings | Mirrors round-2 brainstorm decision 4. Convergence call at T15 — zero blockers → terminate chain; ≥1 blockers → file round-4 dogfood issue blocked-by new follow-ups. |

---

## Path mechanics

- **Worktree:** `.claude/worktrees/bc-6308/` (created in Step 7 of session-start; branch `corinne/bc-6308-bc-5906-round-3-launch-campaign-dogfood-re-walk-phases-3-9` per Linear `gitBranchName`)
- **Dogfood inputs (gitignored):** `.claude/worktrees/bc-6308/dogfood/test-leads.csv` (round-2 verbatim + 3 role-based rows appended) + `test-copy.json` (round-2 verbatim, no edits)
- **Runtime metadata JSON (gitignored):** `.claude/worktrees/bc-6308/dogfood/BC-6308-Round-3-2026-04-30.json` — written progressively by the command per Phase 1 step 10
- **Round-3 transcript (committed, preserved):** `docs/dogfood/bc-6308/round-3-transcript.md` — built up per-phase
- **Preserved artifacts (committed):** `docs/dogfood/bc-6308/launch-metadata.json`, `docs/dogfood/bc-6308/test-leads.csv` (augmented), `docs/dogfood/bc-6308/test-copy.json` (verbatim from round-2)

## Command invocation (settled)

```
/marketing:launch-campaign \
  --csv .claude/worktrees/bc-6308/dogfood/test-leads.csv \
  --copy-artifact .claude/worktrees/bc-6308/dogfood/test-copy.json \
  --workspace emailbison-personal \
  --campaign-name "BC-6308 Round 3" \
  --entity brite-labs
```

No `--activate`. No `--test-send` (UI Preview Body replaces it). No `--no-segment`. No `--no-host-lookup`. No `--reference`. No `--no-deliverability-defaults` (R-8 verifies the auto-PATCH path).

Expected campaign output post-segmentation (with augmented CSV + "Include all" at gate 2):
- `BC-6308 Round 3 | Google` (4 leads — 2 gmail + 2 brite.co/Google Workspace)
- `BC-6308 Round 3 | Microsoft` (2 leads — 2 outlook)
- `BC-6308 Round 3 | Other` (3 leads — 3 dogfoodtest.com role-based)

Plus 2 dedicated render-test campaigns created via direct `call_api` at T11:
- `BC-6308 RENDER TEST A` (1 lead — Lead A with `recency_anchor: "ROUND-3 CASE TEST"`, `empty_test_var: ""`)
- `BC-6308 RENDER TEST B` (1 lead — Lead B with `recency_anchor: ""`, `empty_test_var: ""`)

Plus 0–1 R-5 collision-trigger campaign depending on Phase 1 pre-flight state.

**Total at peak: 5–6 campaigns**, all draft, all deleted at T14 cleanup.

---

## Tasks

### T1 — Worktree + dogfood inputs + transcript scaffolding

**Files:** `.claude/worktrees/bc-6308/dogfood/test-leads.csv`, `.claude/worktrees/bc-6308/dogfood/test-copy.json`, `docs/dogfood/bc-6308/round-3-transcript.md`

**Steps:**
1. Worktree created via Step 7 of session-start.
2. `mkdir -p .claude/worktrees/bc-6308/dogfood/`
3. Copy `docs/dogfood/bc-5906/test-leads.csv` → `.claude/worktrees/bc-6308/dogfood/test-leads.csv`
4. Append 3 role-based rows: `info@dogfoodtest.com`, `sales@dogfoodtest.com`, `contact@dogfoodtest.com` (synthetic first_name, empty last_name, `company_domain: dogfoodtest.com`, populated proof_point variables matching round-2 pattern).
5. Copy `docs/dogfood/bc-5906/test-copy.json` → `.claude/worktrees/bc-6308/dogfood/test-copy.json` (no edits).
6. `mkdir -p docs/dogfood/bc-6308/`
7. Author transcript scaffold at `docs/dogfood/bc-6308/round-3-transcript.md` with sections:
   - Header (date, workspace, leads = 9, entity, preset, offer-tier, activate=OFF, gate-2 choice = "Include all")
   - Outcome summary (filled at end — convergence verdict)
   - Inputs used (cite `docs/dogfood/bc-5906/` provenance + augmentation)
   - Per-phase live-walk (Phase 1, 2, 3, 4, 5, 6, 7, 8, 9 sub-sections)
   - R-2a/R-2b dedicated render-test sub-section
   - R-1 through R-15 findings table
   - Workspace cleanup section
   - Convergence call (zero blockers → terminate; ≥1 → file round-4)

**Verification:** Worktree exists. CSV: `wc -l test-leads.csv == 10` (1 header + 6 round-2 + 3 augmented). `jq .schema_version test-copy.json == "1.0"`. Transcript scaffold exists with all R-row stubs.

### T2 — Phase 1 PRE-FLIGHT + R-5 trigger detection

**Hypotheses:** R-5 prep (collision-trigger detection)

**Live actions:**
1. Run `/marketing:launch-campaign` with the invocation above. Phase 1 pre-flight walks (read-only).
2. Within Phase 1's checks, call `list_campaigns(search="BC-6308")` and `list_campaigns(search="BC-5906")` via direct `call_api`. Record any leftover matches.
3. **R-5 trigger decision:** ≥1 leftover match → R-5 self-verifies later at main Phase 5 user gate 5. Zero matches → mark TODO to pre-create one collision-trigger campaign (`BC-6308 Round 3 | Google` placeholder) right before main Phase 5 step 4 (between step 3's pre-list and step 5's main creates).
4. Confirm Phase 1 user gate 1 fires; operator approves the pre-flight report (entity ↔ workspace cross-mapping warning is expected per F2 dogfood).

**Transcript section:** Phase 1 narrative + R-5 trigger plan recorded.

**Verification:** Phase 1 user gate 1 reached and approved. Metadata `last_completed_phase: 1`. Trigger-decision recorded.

### T3 — Phase 2 HOST LOOKUP + R-9 (email-type segmentation)

**Hypotheses:** R-9 main (BC-6307 — email-type segmentation correctly buckets role + personal + professional)

**Live actions:**
1. Phase 2 step 1 (email-type detection) runs per-lead pre-filter. Expected for the 9 leads:
   - 3 `@dogfoodtest.com` role addresses → tagged `role`
   - 4 personal-domain (gmail x2, outlook x2) → tagged `personal`
   - 2 brite.co → tagged `professional`
2. **R-9 evidence:** Verify `email_type_segments: {professional: 2, role: 3, personal: 4}` populates correctly. Record verbatim.
3. User gate 2 fires with 5 filter options. **Pick "Include all"** per brainstorm decision 2.
4. Phase 2 steps 2–3 (ESP MX resolution) runs on all 9 leads. Expected:
   - Google bucket: 4 (2 gmail + 2 brite.co)
   - Microsoft bucket: 2 (2 outlook)
   - Other bucket: 3 (dogfoodtest.com — non-resolving routes to Other; if instead routed to invalid_domain_rows, that's a sub-finding to record)
5. F12 skip-empty drops zero buckets — expected: 0 dropped.

**Transcript section:** Phase 2 narrative + R-9 row with verbatim evidence.

**Verification:** Metadata `email_type_segments` populated; `email_type_filter_applied: "include_all"`; `esp_segments` populated; 3 buckets survive; `last_completed_phase: 2`.

### T4 — Phase 3 VARIABLES + R-2 (variable reuse) + R-13 regression

**Hypotheses:** R-2 main (BC-6299 — Phase 3 classifies the 8 leftover round-2 vars as "existing → reuse"), R-13 (F14 pagination still Laravel-style page-based)

**Live actions:**
1. Phase 3 step 1: `search_api_spec` for `custom-variables`. Confirm round-2's findings.
2. Phase 3 step 3: `list_custom_variables`. Expected: 14 pre-existing vars (6 from round-1 + 8 from round-2).
3. **R-13 evidence:** Verify pagination meta is still `?page=N` Laravel-style with `per_page: 15`.
4. **R-2 evidence:** Phase 3's classification logic should mark all 8 of the artifact's variables as "existing → reuse." Confirm classification renders correctly at user gate 3.
5. Phase 3 step 5/6: zero new variable creates expected. Record `custom_variables_created: []`.
6. **No `empty_test_var` create here** — deferred to T11's R-2a/R-2b sub-flow.

**Transcript section:** Phase 3 narrative + R-2 + R-13 rows.

**Verification:** Metadata `custom_variables_created: []`; `last_completed_phase: 3`. Workspace still has 14 variables.

### T5 — Phase 4 UPLOAD + R-3 (lead-body field names) + R-1 partial (Sx-1/5/8)

**Hypotheses:** R-3 main (BC-6300 — `title`/`company` not `job_title`/`company_name`), R-1 partial (Sx-1 query forms, Sx-5 last_name optionality, Sx-8 all-or-nothing failure)

**Live actions:**
1. Phase 4 step 1: `search_api_spec` for `bulk create leads`. **R-1/Sx-1 evidence:** confirm both URL-path query (`/api/leads/multiple`) and keyword query work post-Sx-1 spec rewrite.
2. Phase 4 step 2-4: build 9-lead body. **R-3 evidence:** confirm body shape uses `title` and `company` (not `job_title`/`company_name`); `company_domain` either dropped or stashed in `custom_variables`.
3. User gate 4 + per-batch turn-structure prompt. Operator approves.
4. Submit `POST /api/leads/multiple` with 9 leads.
5. **R-3 verification:** GET one of the created leads (e.g., a dogfoodtest.com role-based lead) and inspect stored `title` and `company` — must be non-null and match CSV input.
6. **R-1/Sx-5 + Sx-8 evidence:** record reference to round-2's already-confirmed findings; no new side-test (BC-6298 spec coverage is the verification).

**Transcript section:** Phase 4 narrative + R-3 + R-1 (partial) rows.

**Verification:** Metadata `lead_ids_uploaded: 9`; `last_completed_phase: 4`. Spot-check lead's `title` + `company` populated.

### T6 — Phase 5 CAMPAIGN CREATE + R-5 (pre-list duplicate guard) + R-8 (deliverability PATCH)

**Hypotheses:** R-5 main (BC-6302 — Phase 5 step 3 pre-list call surfaces existing matches at user gate 5), R-8 main ★ (BC-6306 — Phase 5 step 8 PATCHes plain_text + reputation_building + can_unsubscribe)

**Live actions:**
1. **R-5 trigger setup (if T2 found zero leftover matches):** create a placeholder campaign via `call_api` named `BC-6308 Round 3 | Google` BEFORE Phase 5 step 3 runs. Track placeholder ID for cleanup.
2. Phase 5 step 1: `search_api_spec` for `create_campaign`.
3. **R-5 evidence:** Phase 5 step 3's `list_campaigns(search="BC-6308 Round 3")` runs. Expected: ≥1 match. Verify gate render at step 5 surfaces matched ID + adds "Reuse existing IDs" 4th option.
4. User gate 5: pick **"Create N new campaigns anyway"** (acknowledge duplicate, proceed). Record gate-5 render verbatim.
5. Phase 5 step 5: 3 main campaigns created (Google, Microsoft, Other). Capture IDs.
6. **R-8 evidence ★:** Phase 5 step 6 should automatically PATCH `plain_text: true`, `reputation_building: true`, `can_unsubscribe: true`. Verify post-PATCH by GETting each campaign and confirming all 3 toggles ON.
7. Phase 5 step 9: metadata writes include `existing_campaign_matches`, `reused_existing_ids: false`, `plain_text_applied: true`, `activated_per_campaign` seeded with null per bucket.

**Transcript section:** Phase 5 narrative + R-5 + R-8 rows; R-5 trigger-source recorded.

**Verification:** Metadata `campaign_ids: {Google: <id>, Microsoft: <id>, Other: <id>}`; `existing_campaign_matches` non-empty; `plain_text_applied: true`; `activated_per_campaign` seeded; `last_completed_phase: 5`. R-8: all 3 campaigns return `plain_text: true, reputation_building: true, can_unsubscribe: true`.

### T7 — Phase 6 ATTACH LEADS + R-6 partial (lead_ids_by_bucket) + R-14 regression + R-12 re-defer

**Hypotheses:** R-6 partial (BC-6303 — `lead_ids_by_bucket` populated), R-14 (F16 workspace-scoped variable persistence regression), R-12 (F22 `allow_parallel_sending` re-deferred unless operator requests)

**Live actions:**
1. Phase 6 step 1: ground-truth `attach-leads` endpoint.
2. Phase 6 step 2: build bucket map. Google = 4 IDs, Microsoft = 2 IDs, Other = 3 IDs.
3. **R-6 partial evidence:** verify Phase 6 step 7's metadata write includes `lead_ids_by_bucket: {Google: [...], Microsoft: [...], Other: [...]}`.
4. User gate 6 + per-campaign turn-structure prompts (3 campaigns). Operator approves each.
5. Each campaign's `attach-leads` call executes; counts verified.
6. **R-14 evidence:** the 8 round-2 variables were reused at T4 — re-confirms F16 workspace-scoped persistence. Record.
7. **R-12 re-defer:** if operator does not request `allow_parallel_sending` test at gate 6, re-defer per brainstorm decision 4.

**Transcript section:** Phase 6 narrative + R-6 partial + R-14 + R-12 (deferred) rows.

**Verification:** Metadata `lead_attach_counts: {Google: 4, Microsoft: 2, Other: 3}`; `lead_ids_by_bucket` populated; each campaign's `get_campaign` reports lead count match; `last_completed_phase: 6`.

### T8 — Phase 7 ATTACH SENDERS + R-1 partial (Sx-10/11) + R-15 regression

**Hypotheses:** R-1 partial (Sx-10 `?per_page` ignored, Sx-11 status filter case-sensitive), R-15 (F26 sub-second eventual-consistency regression)

**Live actions:**
1. Phase 7 step 1: ground-truth `list_sender_emails` + `attach-sender-emails`.
2. **R-1/Sx-10 evidence:** Re-test `?per_page=100` against `/api/sender-emails` — verify EB still hardcodes 15.
3. **R-1/Sx-11 evidence:** Re-test `?status=Connected` (capitalized) → expect 422; `?status=connected` (lowercase) → expect 200. Verify spec's case-sensitivity documentation matches reality.
4. **Round-3 partial-pool decision: same as round-2** — page 1's 15 senders for all 3 main campaigns + the 2 RENDER TEST campaigns at T11 + R-5 trigger placeholder if created at T6. Full 772-pool deferred.
5. User gate 7. Operator approves. Three parallel attaches execute.
6. **R-15 evidence:** measure post-attach Δ via `get_campaign({id})` immediately after attach return. Round-2 ≈15.5s end-to-end. Confirm Δ < 30s (regression check).
7. Phase 7 step 7: scalar count check; verify all 3 main campaigns' `attached_senders_count == 15`.

**Transcript section:** Phase 7 narrative + R-1 partial (Sx-10, Sx-11) + R-15 rows.

**Verification:** Metadata `sender_ids_attached: [<15 IDs>]`; `sender_attach_counts: {Google: 15, Microsoft: 15, Other: 15}`; `last_completed_phase: 7`.

### T9 — Phase 8 SCHEDULE + R-6 partial (schedule_template_id + campaign_schedule_ids)

**Hypotheses:** R-6 partial (BC-6303 — `schedule_template_id` and `campaign_schedule_ids` populate per renamed schema)

**Live actions:**
1. Phase 8 step 1: ground-truth `get_schedule_templates` + `create-schedule-from-template`.
2. Phase 8 step 2: list templates on `emailbison-personal`. Expected (per round-2): 1 template, id 3 — Mon-Fri 08:00-20:00 America/Denver.
3. User gate 8: operator approves the template choice.
4. Apply template to all 3 main campaigns. Each gets its own NEW schedule entity ID (clone, not reference — round-2 finding).
5. **R-6 partial evidence:** verify Phase 8 step 7's metadata write includes:
   - `schedule_template_id: 3` (renamed from old `schedule_id`)
   - `campaign_schedule_ids: {Google: <new_id_1>, Microsoft: <new_id_2>, Other: <new_id_3>}`

**Transcript section:** Phase 8 narrative + R-6 partial row.

**Verification:** Metadata `schedule_template_id: 3`; `campaign_schedule_ids` populated with 3 distinct cloned IDs; `last_completed_phase: 8`.

### T10 — Phase 9 SEQUENCE + R-4 (variant boolean + no double Re:)

**Hypotheses:** R-4 main (BC-6301 — `variant: false` boolean; no double-Re: prefix on step 2 subject)

**Live actions:**
1. Phase 9 step 1: ground-truth `create_sequence_steps` v1.1 endpoint + body shape.
2. Build 2-step sequences for all 3 main campaigns.
3. **R-4 evidence (variant boolean):** verify spec sends `"variant": false` (boolean), not `"variant": "A"` (string). Confirm by inspecting request payload pre-submit.
4. **R-4 evidence (no double Re:):** verify `step_2.subject` from copy artifact does NOT start with "Re:" (per BC-6301 fix — EB auto-prepends when `thread_reply: true`). Submit with bare subject. Inspect post-create response: stored subject should have single "Re: " prefix.
5. User gate 9 + per-campaign turn-structure prompts. Operator approves.
6. Submit `POST /api/campaigns/v1.1/{id}/sequence-steps` for all 3 campaigns.
7. Verify each campaign's stored sequence steps: step 1 with `wait_in_days: 1` (per F29 confirmed override); step 2 with single "Re: " prefix.

**Transcript section:** Phase 9 narrative + R-4 row with verbatim post-create subject capture.

**Verification:** Metadata `sequence_ids: {Google: <id>, Microsoft: <id>, Other: <id>}`; each campaign's stored step_2 subject starts with single "Re: " (not double); `last_completed_phase: 9`.

**→ PAUSE FOR REVIEW** before T11. Live state of all 3 main campaigns is fully formed and inspectable in EB UI.

### T11 — R-2a / R-2b dedicated render-test side-flow (UI Preview Body)

**Hypotheses:** R-2a ★ (case-sensitivity — does `{RECENCY_ANCHOR}` resolve when EB stored `recency_anchor`?), R-2b ★ (empty-value rendering — what does EB show when a custom variable's value is blank?)

**Per BC-6299 carryover guardrail + brainstorm decision 3 — primary path is UI Preview Body. Real-email tie-breaker only if UI preview ambiguous.**

**Setup phase (agent-side, all via direct `call_api`):**

1. Create `empty_test_var` custom variable: `POST /api/custom-variables {name: "empty_test_var"}`. Record ID. **This is the 9th permanent variable in workspace 13 (Sx-4 — no DELETE endpoint).** Documented in transcript and final BC-6308 comment.
2. Build 2 test leads via `bulk_create_leads`:
   - **Lead A:** email `bc6308-r2a-leadA@brite.co`, first_name "LeadA", custom_variables `[{name: "recency_anchor", value: "ROUND-3 CASE TEST"}, {name: "empty_test_var", value: ""}]`
   - **Lead B:** email `bc6308-r2b-leadB@brite.co`, first_name "LeadB", custom_variables `[{name: "recency_anchor", value: ""}, {name: "empty_test_var", value: ""}]`
3. Create 2 test campaigns:
   - `BC-6308 RENDER TEST A` — capture ID
   - `BC-6308 RENDER TEST B` — capture ID
4. Apply R-8 PATCH to both: `update_campaign` with `plain_text: true`, `reputation_building: true`, `can_unsubscribe: true`.
5. **Attach leads (Preview Body prereq #1):** Lead A → RENDER TEST A; Lead B → RENDER TEST B (1 lead each, deterministic targeting).
6. **Attach 1 sender (Preview Body prereq #2):** any from page 1's 15 senders → both campaigns.
7. Apply schedule template id 3 to each (per brainstorm decision 7 — symmetry with main campaigns; not strictly required for Preview Body).
8. Build sequence step body containing the 3 test tokens:
   ```
   Hi {FIRST_NAME},

   Recency anchor uppercase: {RECENCY_ANCHOR}
   Recency anchor lowercase: {recency_anchor}
   Empty-value sentinel: EMPTY_TEST:[{empty_test_var}]:END

   — test
   ```
   Submit `POST /api/campaigns/v1.1/{id}/sequence-steps` for each test campaign with this body as step 1 (`variant: false`, `thread_reply: false`).

**At this point both test campaigns have: 1 lead attached + 1 sender attached + sequence step in place + schedule attached. Preview Body is now reachable.**

**Operator phase (manual UI step — operator clicks Preview Body):**

9. Operator opens `personal.outbase.so` → workspace 13 → Campaigns → `BC-6308 RENDER TEST A`
10. Operator navigates to the sequence step
11. Operator clicks **Preview Body**
12. Operator screenshots/notes the rendered subject + body. Specifically reports:
    - **R-2a:** What does `{RECENCY_ANCHOR}` resolve to?
      - Expected if case-insensitive: "ROUND-3 CASE TEST"
      - Expected if case-sensitive: literal `{RECENCY_ANCHOR}` text
    - **R-2a control:** What does `{recency_anchor}` resolve to? (Should always work — "ROUND-3 CASE TEST".)
13. Operator clicks **Refresh Email Variation** once or twice to confirm spintax variability (documents UI behavior).
14. Operator opens `BC-6308 RENDER TEST B` campaign, repeats Preview Body.
    - **R-2b:** What does `EMPTY_TEST:[{empty_test_var}]:END` resolve to?
      - Blank → `EMPTY_TEST:[]:END`
      - Literal placeholder → `EMPTY_TEST:[{empty_test_var}]:END`
      - Some fallback syntax → other
15. Operator reports findings to agent. Agent records verbatim in transcript R-2a + R-2b rows.
16. **Tie-breaker decision:** if either R-2a or R-2b shows ambiguous UI preview, fall back to single real `/test-email` send to corinne@britenites.com. Otherwise skip the real send.

**Transcript section:** R-2a + R-2b rows with verbatim Preview Body screenshots/quotes; tie-breaker decision recorded.

**Verification:** R-2a verdict recorded (case-insensitive | case-sensitive | ambiguous-tie-breaker-needed). R-2b verdict recorded (blank | literal | fallback-syntax). If verdict reveals broken behavior per BC-6299 design doc, **file spinoff issue per BC-5870 verification-side-effects pattern** — do NOT absorb fixes into this PR.

**→ PAUSE FOR REVIEW** before T12. R-2a/R-2b verdicts are the most operationally consequential findings of the round; confirm before proceeding.

### T12 — R-7 spec-read + R-10/R-11 (new flags + new metadata fields)

**Hypotheses:** R-7 (BC-6304 — Tool tier map clarifies wrapper-vs-API gate), R-10 (any new flags introduced by round-2 fixes work as documented), R-11 (any new metadata schema fields populate correctly)

**Live actions:**
1. **R-7 evidence:** Read `plugins/marketing/commands/launch-campaign.md` § Tool tier map (lines ~33–60). Verify it states: agent-side `AskUserQuestion` is the sole safeguard; `confirmation` prose in `discover_tools` is documentation, not a runtime gate; closure of BC-6439. Record verbatim quote.
2. **R-10 evidence:** Identify any new flags introduced by round-2 fixes (`--no-deliverability-defaults`?, `--include-role`?). Cross-check spec's flag inventory. Default round-3 invocation does NOT use any opt-out flag — verify auto-PATCH path runs (R-8 covers this).
3. **R-11 evidence:** Compile metadata JSON post-walk. Verify new schema fields populated:
   - `email_type_segments: {professional, role, personal}` (BC-6307)
   - `email_type_filter_applied: "include_all"` (BC-6307)
   - `existing_campaign_matches: [<id>, ...]` (BC-6302)
   - `reused_existing_ids: false` (BC-6302)
   - `plain_text_applied: true` (BC-6306)
   - `lead_ids_by_bucket` (BC-6303)
   - `schedule_template_id` + `campaign_schedule_ids` (BC-6303)
   - `activated_per_campaign` (BC-6303)
4. Record verbatim metadata JSON excerpt.

**Transcript section:** R-7 + R-10 + R-11 rows.

**Verification:** R-7 spec-quote recorded; R-10 flags inventoried; R-11 metadata schema completeness verified.

### T13 — Phase 11 ACTIVATE spec re-check (no live execution)

**Status:** Same as round-2 T10 — Phase 11 stays paper-spec-check only. No `--activate`; no real emails sent.

**Steps:**
1. Re-read `plugins/marketing/commands/launch-campaign.md` § Phase 11. Confirm BC-6303's per-campaign `activated_per_campaign` schema is in spec (R-6 partial) and resume rule references it correctly.
2. No EB state change. Record in transcript that Phase 11 was not exercised.

**Transcript section:** Phase 11 paper-check note.

**Verification:** No metadata mutation. Sequences from T10 left all 3 main campaigns at `status: "draft"`. RENDER TEST A/B from T11 also `status: "draft"`.

### T14 — Workspace cleanup

**Steps:**
1. **Bulk-delete campaigns:** `DELETE /api/campaigns/bulk` with `{campaign_ids: [<all 5–6 IDs>]}` — Google + Microsoft + Other main + RENDER TEST A + RENDER TEST B + (R-5 trigger placeholder if T6 created one).
2. **Bulk-delete leads:** `DELETE /api/leads/bulk` with `{lead_ids: [<all 11 IDs>]}` — 9 main leads + Lead A + Lead B from T11.
3. **Wait for async drain (Sx-8):** poll `list_campaigns(search="BC-6308")` and `list_leads(search="bc6308")` until both return 0. Round-2 measured ~seconds; if >60s, escalate as deletion-latency regression.
4. **Custom variables:** the 8 leftover round-2 variables stay (no DELETE endpoint). The new `empty_test_var` from T11 also stays — workspace 13 now has **9 permanent variables**. Document in transcript and BC-6308 Done comment.
5. **Sender attaches:** removed implicitly when parent campaigns delete.
6. **Schedules + sequences:** cascaded with parent campaign deletes.

**Verification:** `list_campaigns(search="BC-6308")` returns 0; `list_leads(search="bc6308")` returns 0. Workspace state: +1 net new permanent variable (`empty_test_var`); everything else reverted.

### T15 — Convergence call (REQUIRED per issue body)

**Steps:**
1. Walk R-1 through R-15 findings table. **Count blocking findings** — defined as: a fix-validation R-row marked `refuted` (fix did not behave as documented) OR an R-2a/R-2b verdict that reveals broken render-engine behavior requiring downstream skill changes.
2. **If zero blocking findings:** mark BC-6308 status `Done`. Post comment:
   > Convergence achieved — spec matches reality across all 15 R-rows. Chain terminates here. No round-4 issue filed.
3. **If ≥1 blocking findings:** file new round-4 follow-up issues (one per blocker; or batched per round-2's batch-of-9 pattern if multiple share a theme). Then file round-4 dogfood issue:
   - Title: `BC-XXXX round-4 launch-campaign dogfood — re-walk after round-3 fixes land + recurse if needed`
   - Body: mirror BC-6308's structure; `blockedBy` all newly-filed round-4 follow-ups
   - Comment on BC-6308 summarizing what recursed
4. Post final summary comment on BC-6308 with: R-1 through R-15 verdict table, convergence verdict, links to any round-4 issues.

**Verification:** BC-6308 has final convergence comment. Either Done with terminate-comment OR Done with file-round-4 path executed.

### T16 — Preserve artifacts to docs/dogfood/bc-6308/

**Steps:**
1. Copy `.claude/worktrees/bc-6308/dogfood/test-leads.csv` → `docs/dogfood/bc-6308/test-leads.csv` (augmented version).
2. Copy `.claude/worktrees/bc-6308/dogfood/test-copy.json` → `docs/dogfood/bc-6308/test-copy.json` (verbatim from round-2).
3. Copy `.claude/worktrees/bc-6308/dogfood/BC-6308-Round-3-2026-04-30.json` → `docs/dogfood/bc-6308/launch-metadata.json` (final state).
4. Transcript at `docs/dogfood/bc-6308/round-3-transcript.md` already in place from T1.

**Verification:** All 4 files exist under `docs/dogfood/bc-6308/`. Metadata JSON's `last_completed_phase == 9`, `activated == false`.

### T17 — Validation + PR-ready

**Steps:**
1. Run `./scripts/validate.sh`. Must exit 0.
2. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md`. Must exit 0.
3. Confirm no untracked or modified files outside `docs/dogfood/bc-6308/`.

**Verification:** Both scripts exit 0. `git diff --stat origin/main` shows changes only under `docs/dogfood/bc-6308/`.

---

## Verification checklist (objective, AC-aligned)

- [ ] `docs/dogfood/bc-6308/round-3-transcript.md` exists with all 9 phase sub-sections + R-2a/R-2b sub-section populated.
- [ ] R-1 through R-15 findings table has 15 rows, every row marked `confirmed` / `refuted` / `confirmed-with-caveat` / `deferred`.
- [ ] R-2a + R-2b carryover verifications executed via UI Preview Body; verdicts recorded; spinoffs filed if either reveals broken behavior.
- [ ] Workspace cleanup verified — `list_campaigns(search="BC-6308")` returns 0; `list_leads(search="bc6308")` returns 0.
- [ ] No `--activate` invocation. No real emails sent (UNLESS R-2a/R-2b tie-breaker fired — ONE email to corinne@britenites.com, documented).
- [ ] All preserved artifacts at `docs/dogfood/bc-6308/`.
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.
- [ ] Convergence comment posted to BC-6308.
- [ ] If round-4 needed: round-4 issue filed with `blockedBy` set per protocol.

---

## Pacing note

Per user memory (commits per task, pause at natural checkpoints):
- One commit per task T1–T13 (13 commits during the live walk).
- One commit each at T14 (cleanup), T16 (preservation), T17 (validation). T15 is Linear-only mutations.
- **Pause for review after T10** — before R-2a/R-2b dedicated test (T11). Live state of main campaigns fully formed and inspectable.
- **Pause for review after T11** — R-2a/R-2b verdict is the most operationally consequential finding of the round (case-sensitivity blast radius across 14 marketing skills).
- T15 (convergence call) does not commit code; mutates Linear state. Ask before filing round-4 issues if needed.

---

## Non-goals (explicit)

- Do NOT modify `plugins/marketing/commands/launch-campaign.md` in this PR. R-row refutations file as round-4 follow-up issues (per brainstorm decision 8 + issue body convergence pattern).
- Do NOT activate campaigns (`--activate` off; Phase 11 stays paper-spec-check only).
- Do NOT use `--test-send` unless R-2a/R-2b UI preview is ambiguous (tie-breaker only).
- Do NOT pre-poison F22's `allow_parallel_sending` path. Re-deferred per brainstorm decision 4.
- Do NOT lowercase the artifact convention across 14 marketing skills based on R-2a's verdict in this PR — BC-6299 design doc explicitly says R-2a verdict feeds a SPINOFF issue, not in-PR change.
- Do NOT re-run `/marketing:tam-map`, `/marketing:list-building`, or `/marketing:email-copywriting`. This dogfood validates only `/marketing:launch-campaign` Phases 3–9 + the BC-6299 carryover render-engine tests.
