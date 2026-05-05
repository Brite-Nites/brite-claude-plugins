---
title: BC-5906 — round-2 launch-campaign dogfood (live Phases 3–9 + F14-F31 hypothesis validation)
issue: https://linear.app/brite-nites/issue/BC-5906
created: 2026-04-27
status: pending-approval
target-pr: docs/dogfood + transcript artifact only — no command-spec changes in this PR (refutations file as follow-ups)
---

# BC-5906 — Round-2 Launch Dogfood Plan

> **Note (2026-05-05, BC-6654):** segmentation references in this plan reflect the pre-multiplicative ESP-axis spec. The current spec uses (email-type × ESP) cell segmentation per BC-6514 (`docs/designs/BC-6514-segmentation-axis-decision.md`); the metadata schema, naming convention, and `--no-segment` flag all changed. This plan is preserved as historical execution record.

Issue 1 of 5 in the Marketing Plugin: GTM Workflows MVP critical path. Validates `/marketing:launch-campaign` Phases 3–9 against the live `emailbison-personal` workspace by actually creating real EB state (custom variables, leads, campaigns, sender attaches, schedule, sequences) — Phase 11 stays off, no real emails sent. Surfaces reality-vs-spec gaps for hypotheses F14–F31 (paper-walked in BC-5826 round-1, never live-validated).

---

## Issue ↔ Ground-truth amendments

Per BC-5947 → BC-5832 → BC-2717 (architecture-9 amendments-table precedent), reconcile issue-body claims against current reality before tasks.

| # | Issue body says | Ground truth | Resolution |
|---|---|---|---|
| 1 | Blocked by BC-5826, BC-5904, BC-5905 | All three Done as of 2026-04-21 (PR #163, #185) | Unblocked. No prerequisite work needed. |
| 2 | Dogfood inputs at `.claude/worktrees/<branch>/dogfood/test-leads.csv + test-copy.json` | Round-1 worktree gitignored at commit time; preserved post-merge to `docs/dogfood/bc-5826/` via PR #185 | Copy from preserved location into BC-5906 worktree. Issue-body path was correct at issue creation time. |
| 3 | F22 (`allow_parallel_sending`) listed as hypothesis to validate | F22 requires pre-poisoning a lead into another campaign before Phase 6 — adds setup-and-cleanup load not present in the bare round-2 walk | Skip live-validation; document as deferred. Brainstorm decision 2026-04-27. File as separate follow-up if F22 confirmation becomes high-value later. |

---

## Brainstorm decisions (2026-04-27)

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Reuse round-1 inputs or fresh? | Reuse round-1 verbatim from `docs/dogfood/bc-5826/` | Known-good 6-lead test set (Google 4 / Microsoft 2 after MX resolution); focus session on F14-F31 not on input authoring |
| 2 | Single campaign or ESP-segmented? | ESP-segmented (default segmentation) | Mirrors prod launch path; validates F12 skip-empty (Other bucket=0), F20 multi-name collision, Phase 6 multi-campaign attach loop |
| 3 | F22 strategy | Skip; document as deferred | Pre-poisoning adds ~30 min and complicates cleanup; F22 isn't load-bearing for the MVP launch path |
| 4 | Refuted-hypothesis handling | Capture in transcript inline; batch-create Linear follow-ups at session end | Avoids context-switching mid-walk; keeps PR scope to "transcript + preserve artifacts" not "transcript + spec changes" |

---

## Path mechanics

- **Worktree:** `.claude/worktrees/bc-5906/` (created in Step 7 of session-start; branch `corinne/bc-5906-bc-5826-follow-up-x17-round-2-dogfood-full-phase-3-9` per Linear `gitBranchName`)
- **Dogfood inputs (gitignored):** `.claude/worktrees/bc-5906/dogfood/test-leads.csv` + `test-copy.json` — copied verbatim from `docs/dogfood/bc-5826/`. Required at this path so Phase 1 IV-3 dogfood-detection routes runtime metadata correctly.
- **Runtime metadata JSON (gitignored):** `.claude/worktrees/bc-5906/dogfood/BC-5906-Round-2-2026-04-27.json` — written progressively by the command per Phase 1 step 10 / phase-N append pattern.
- **Round-2 transcript (committed, preserved):** `docs/dogfood/bc-5906/round-2-transcript.md` — built up per-phase. Mirrors PR #185's pattern of preserving the round-1 transcript + inputs.
- **Preserved artifacts (committed):** `docs/dogfood/bc-5906/launch-metadata.json` (copy of runtime metadata at end of walk), `docs/dogfood/bc-5906/test-leads.csv` + `test-copy.json` (verbatim copies from round-1, for self-contained re-runs).

## Command invocation (settled)

```
/marketing:launch-campaign \
  --csv .claude/worktrees/bc-5906/dogfood/test-leads.csv \
  --copy-artifact .claude/worktrees/bc-5906/dogfood/test-copy.json \
  --workspace emailbison-personal \
  --campaign-name "BC-5906 Round 2" \
  --entity brite-labs
```

No `--activate`. No `--test-send`. No `--no-segment` (default segmentation ON to validate Phase 5 multi-campaign + Phase 6 attach loop). No `--reference`. The `--entity brite-labs --workspace emailbison-personal` cross-mapping triggers the Phase 1 step 3 dogfood-cross-mapping gate (expected, not an error per F2).

Expected campaign output (per round-1 ESP distribution):
- `BC-5906 Round 2 | Google` (4 leads)
- `BC-5906 Round 2 | Microsoft` (2 leads)
- *(Other bucket = 0 leads → F12 skip-empty drops it; expect 2 campaigns total, not 3)*

---

## Tasks

### T1 — Worktree + dogfood inputs setup

**Files:** `.claude/worktrees/bc-5906/dogfood/test-leads.csv`, `.claude/worktrees/bc-5906/dogfood/test-copy.json`

**Steps:**
1. Worktree created via Step 7 of session-start (`git worktree add .claude/worktrees/bc-5906 -b corinne/bc-5906-bc-5826-follow-up-x17-round-2-dogfood-full-phase-3-9`).
2. `mkdir -p .claude/worktrees/bc-5906/dogfood/`
3. Copy `docs/dogfood/bc-5826/test-leads.csv` → `.claude/worktrees/bc-5906/dogfood/test-leads.csv`
4. Copy `docs/dogfood/bc-5826/test-copy.json` → `.claude/worktrees/bc-5906/dogfood/test-copy.json`
5. Verify the 6 fake-email leads (`dogfood-test-NN@gmail.com`/`@outlook.com`/`@brite.co`) and the T2 municipalities copy artifact landed verbatim.

**Verification:** Both files exist at the worktree-relative paths above; `wc -l test-leads.csv == 7` (1 header + 6 rows); `jq .schema_version test-copy.json == "1.0"`.

### T2 — Transcript scaffolding

**File:** `docs/dogfood/bc-5906/round-2-transcript.md`

**Steps:**
1. Create `docs/dogfood/bc-5906/` directory.
2. Author transcript scaffold with these sections (sub-headings populate as each phase walks):
   - Header (date, workspace, leads, entity, preset, offer-tier, activate=OFF)
   - Outcome summary (filled at end)
   - Inputs used (cite `docs/dogfood/bc-5826/` provenance)
   - Per-phase live-walk (Phase 3, 4, 5, 6, 7, 8, 9 sub-sections)
   - Per-hypothesis findings table (F14–F31, columns: hypothesis, status [confirmed / refuted / needs-more-work / deferred], evidence, follow-up)
   - Workspace cleanup section
   - Follow-up Linear issues filed (filled at end)

**Verification:** File exists; the 7 phase sub-headings + the F14–F31 row-stubs in the findings table match the issue-body verbatim.

### T3 — Phase 3 VARIABLES (live walk + F14/F15/F16)

**Hypotheses:** F14 (pagination), F15 (conflict resolution), F16 (workspace-scope collision)

**Live actions:**
1. Phase 1 PRE-FLIGHT walks first (read-only; reuse round-1's findings — workspace-cross-mapping gate fires per F2, lead spot-check renders).
2. Phase 2 HOST LOOKUP walks live (Bash `dig` per F10) — confirms round-1's Google 4 / Microsoft 2 / Other 0 distribution still holds.
3. Phase 3 step 1: `search_api_spec` for `custom variable create` and `custom variable list`. Record verbatim tool names + endpoint paths.
4. Phase 3 step 3: call `list_custom_variables`. **F14 evidence:** record verbatim response shape — does it return a cursor field? a `next_page`? A flat array? Test pagination by re-calling with cursor (or page param) if present. **F16 evidence:** record total variable count in workspace (proves workspace-scope shared across all campaigns).
5. **F15 evidence:** check if any of our 8 variable names (RECENCY_ANCHOR, VERTICAL_DESCRIPTOR, SPECIFIC_FRICTION, PROOF_POINT_COMPANY, PROOF_POINT_NUMBER, PROOF_POINT_TIMEFRAME, FREE_ASSET_NOUN, SENDER_FIRST_NAME) collide with existing workspace variables. If yes: walk the conflict path (does EB silent-overwrite, hard-fail, or gate?). If no collision: mark F15 needs-more-work, note "would require seeding a same-name variable with different default before this run."
6. User gate 3 fires (semantic approval to create new + resolve conflicts). Operator approves; command creates the 8 variables (or skips existing).
7. Capture: variable IDs returned, any conflicts encountered, time-to-complete.

**Transcript section:** 1–2 paragraph narrative of what the live walk surfaced, plus F14/F15/F16 row updates in the findings table (with verbatim evidence quotes).

**Verification:** Metadata JSON's `custom_variables_created` array reflects what was actually created (empty if all 8 already existed; 8 if all new; subset if mixed). `last_completed_phase: 3`.

### T4 — Phase 4 UPLOAD (live walk + F17/F18/F19)

**Hypotheses:** F17 (last_name requirement), F18 (mid-chunk failure recovery), F19 (vendor prompt wording)

**Live actions:**
1. Phase 4 step 1: `search_api_spec` for `bulk create leads`. **F19 evidence:** record verbatim text of the vendor's first-call confirmation prompt.
2. Phase 4 step 2-4: build lead batches from CSV (6 leads, 1 chunk since 6 < 500). Show 3-lead sample.
3. **F17 evidence:** All 6 round-1 leads have `last_name` populated ("Testlead"). To test optionality cleanly, we'll do a side-test mid-walk: run a **separate** `bulk_create_leads` call via `call_api` with one synthetic lead missing `last_name` (e.g., `dogfood-test-99@brite.co`, no `last_name`). Record vendor response. If accepted: F17 confirmed (CSV `last_name` is genuinely optional). If rejected: F17 refuted (spec needs to upgrade `last_name` from optional → required). After verdict, delete the F17 test lead immediately (don't let it pollute Phase 6's attach plan).
4. **F18 evidence:** Inject a deliberate failure into a 2nd side-test — re-submit one of the just-created leads (duplicate email). Observe: does EB fail the whole chunk or skip the dup and succeed the rest? Record verbatim response.
5. User gate 4 (semantic approval — once for the full batch). Operator approves. Per-chunk turn-structure prompt fires once (1 chunk).
6. Phase 4 second call (`confirmation: true`). Capture returned lead IDs.

**Transcript section:** narrative + F17/F18/F19 rows in findings table.

**Verification:** Metadata JSON's `lead_ids_uploaded == 6`; `last_completed_phase: 4`. F17 + F18 side-test artifacts cleaned up before Phase 6 (the 6 main leads are the only ones reaching attach).

### T5 — Phase 5 CAMPAIGN CREATE (live walk + F20)

**Hypothesis:** F20 (name collision)

**Live actions:**
1. Phase 5 step 1: `search_api_spec` for `create campaign`. Record path.
2. Phase 5 step 2-3: name plan = `BC-5906 Round 2 | Google`, `BC-5906 Round 2 | Microsoft` (Other dropped per F12 skip-empty).
3. **F20 evidence:** Side-test before walking the main create — call `create_campaign` twice with identical name `BC-5906 Round 2 | F20-collision-test`. Observe: does the second call fail (uniqueness enforced), succeed (duplicates allowed), or gate (returns confirmation prompt asking about the existing one)? Record verbatim. Then delete the F20-test campaign(s).
4. User gate 5. Operator approves. Command creates the 2 main campaigns.
5. Capture campaign IDs.

**Transcript section:** narrative + F20 row.

**Verification:** Metadata `campaign_ids: {"Google": <id>, "Microsoft": <id>}`; `last_completed_phase: 5`. F20 collision-test campaign(s) deleted before Phase 6.

### T6 — Phase 6 ATTACH LEADS (live walk + F21, deferred F22)

**Hypotheses:** F21 (lead-id-to-bucket mapping), F22 (deferred per brainstorm)

**Live actions:**
1. Phase 6 step 1: `search_api_spec` for `attach leads to campaign`. Record path.
2. **F21 evidence:** Compare the metadata JSON's current state (`lead_ids_uploaded: 6` count) against what Phase 6 actually needs (per-bucket lead-ID arrays). Round-1 paper-walk noted only the count is persisted, not the IDs themselves. Confirm: do we need to keep the full ID list in session memory between Phase 4 and Phase 6, or can it be reconstructed? Document the answer + propose metadata schema change if needed.
3. Phase 6 step 2: build bucket map. Round-1 distribution → Google bucket = 4 lead IDs, Microsoft bucket = 2 lead IDs.
4. User gate 6. Operator approves. Per-campaign turn-structure prompts fire (2 campaigns).
5. Each campaign's `import_leads_to_campaign` call executes; counts verified.
6. **F22 deferred:** transcript table row reads "deferred — requires pre-poisoning a lead into another campaign before this walk; brainstorm decision 2026-04-27." Note in transcript that if F22 validation becomes high-value, file a follow-up issue scoped specifically to that test.

**Transcript section:** narrative + F21 row + F22 deferred row.

**Verification:** Metadata `lead_attach_counts: {Google: 4, Microsoft: 2}`; both campaigns' `get_campaign` reports lead count matches; `last_completed_phase: 6`.

### T7 — Phase 7 ATTACH SENDERS (live walk + F23/F24/F25/F26)

**Hypotheses:** F23 (pagination), F24 (payload size), F25 (status filter), F26 (eventual-consistency delay)

**Live actions:**
1. Phase 7 step 1: `search_api_spec` for `list sender emails` + `attach sender emails to campaign`. Record.
2. **F23 evidence:** Walk the `while True` pagination loop against `list_sender_emails` with `status: "connected"` filter. Record verbatim cursor mechanism (cursor token? page number? offset?), page size returned, total connected sender count. Note: the issue body cited 772 senders at issue-write time; current count may differ.
3. **F25 evidence:** Spot-check 3 senders from the returned list — confirm none are in warmup-only state (i.e., the `status: "connected"` filter genuinely excludes warmup-state senders).
4. **F24 evidence:** Build the `attach_sender_emails_to_campaign` body with the full sender ID array (all N connected senders). Submit in one call. Record: success → F24 confirmed (no payload limit at N senders); failure with size error → F24 refuted (EB imposes a limit, document the threshold). Test once for the Google campaign; if it succeeds, repeat for Microsoft.
5. User gate 7. Operator approves. Both campaigns get the full sender pool.
6. **F26 evidence:** Immediately after the `attach_sender_emails_to_campaign` second call returns 200, hit `get_campaign` (or equivalent) and check the campaign's attached-sender count. Record the gap. Repeat at +5s, +30s, +60s if mismatch persists. Document the eventual-consistency delay.
7. Phase 7 step 7 verification: scalar count check first; paginate only on mismatch (per spec). Confirm both campaigns' `attached_senders_count == N`.

**Transcript section:** narrative + F23/F24/F25/F26 rows.

**Verification:** Metadata `sender_ids_attached: [<full list>]`, `sender_attach_counts: {Google: N, Microsoft: N}` (equal); `sender_verify_mode` recorded; `last_completed_phase: 7`.

### T8 — Phase 8 SCHEDULE (live walk + F27/F28)

**Hypotheses:** F27 (templates exist on personal?), F28 (templates exist on b2b?)

**Live actions:**
1. Phase 8 step 1: `search_api_spec` for `schedule template`. Record.
2. **F27 evidence:** Call `get_schedule_templates` against `emailbison-personal`. Record: count, names, default-match status (any matching Mon-Fri 08:00-17:00?). If zero templates: HALT — F27 refuted, transcript marks this as a critical gap requiring spec-level fallback (e.g., "create template inline"). If non-zero: select the closest-to-default and proceed.
3. **F28 evidence:** Side-call against `emailbison-b2b` (read-only — `get_schedule_templates` doesn't mutate). Record same: count, names, default-match. Compare across workspaces.
4. User gate 8. Operator approves. Command applies the selected template to both campaigns.
5. Verify per-campaign schedule attachment.

**Transcript section:** narrative + F27/F28 rows. If F27 returns zero, transcript escalates this as a launch-blocker for personal-workspace dogfood and proposes follow-up.

**Verification:** Metadata `schedule_id: N`; both campaigns' `get_campaign` shows schedule attached; `last_completed_phase: 8`.

### T9 — Phase 9 SEQUENCE (live walk + F29/F30)

**Hypotheses:** F29 (`max(1, …)` override), F30 (`thread_reply` field name)

**Live actions:**
1. Phase 9 step 1: `search_api_spec` for `sequence steps create`. Record verbatim path + body shape.
2. **F30 evidence:** Compare the verbatim API spec against the launch-campaign.md spec's `thread_reply: true` field name. Confirm or refute the name. If refuted (e.g., actual field is `is_reply` or `thread`), document and propose spec correction.
3. **F29 evidence:** The copy artifact's `step_1.wait_in_days` is 0. The command spec applies `max(1, 0) = 1` before the API call. Side-test: temporarily build a request body with `wait_in_days: 0` directly (via `call_api`) and submit. Does EB accept it (override is unnecessary), reject (override is necessary), or coerce silently? Record. If override is unnecessary, propose spec simplification.
4. Build request body for both campaigns (step 1 wait=1, step 2 wait=4, step 2 subject starts `Re:`, step 2 thread_reply=true).
5. User gate 9. Operator approves. Command creates 2-step sequences on both campaigns.
6. Verify per-campaign 2 sequence steps with correct `wait_in_days` and `email_subject`.

**Transcript section:** narrative + F29/F30 rows.

**Verification:** Metadata `sequence_ids: {Google: <id>, Microsoft: <id>}`; both campaigns' sequence-list endpoint shows 2 steps with correct field shape; `last_completed_phase: 9`.

### T10 — Phase 11 ACTIVATE spec check (F31, no live execution)

**Hypothesis:** F31 (partial-success tracking schema)

**Steps:**
1. Re-read `plugins/marketing/commands/launch-campaign.md` § Phase 11 for the metadata-update logic — specifically the `activated: true / false` and `activated_at` fields, plus the per-campaign abort behavior in step 4.
2. **F31 evidence:** Per the current spec, `activated` is global (one boolean for the whole run) and flips to `true` only on Phase 11 success across ALL campaigns. There is no per-campaign `activated_at` map. If 1-of-2 campaigns activates and 2-of-2 fails, the spec's resume rule says "skip campaigns whose metadata shows they're already activated" — but the metadata as written has no per-campaign granularity to drive that skip. Propose schema change: `activated_per_campaign: {<bucket>: bool}` alongside the global `activated`. Document in transcript; this is spec-only signal, not a live test.

**Transcript section:** F31 row + 1-paragraph spec-correction proposal.

**Verification:** No EB state changed. Transcript captures the schema-gap diagnosis with verbatim quotes from the spec.

### T11 — Workspace cleanup

**Steps:**
1. Run `delete_campaign` (via `call_api`) on each of the 2 main campaigns + any side-test campaigns from T5/T6/T7. **Use `call_api` with `search_api_spec` first to ground-truth `delete_campaign` path** — it's likely extended-tier.
2. Delete the 6 main leads + any F17/F18 side-test leads created in T4. Use `call_api` with bulk-delete or per-lead delete (ground-truth via `search_api_spec`).
3. **Custom variables decision:** the issue says "delete custom variables (or document why they can stay)." If the 8 variables created in T3 are workspace-scoped and would be reused by future production runs (per F16's confirmed answer), document the decision to leave them. If they're test-specific (e.g., `dogfood-test-RECENCY_ANCHOR`), delete them. Default: delete unless they pre-existed before T3 (i.e., F15-collision case — those stay).
4. Run `list_campaigns` + `list_leads` post-cleanup against `emailbison-personal` to confirm zero residual state from this dogfood. Capture verification screenshot or response excerpt in transcript.

**Verification:** Workspace state pre-T3 == post-T11 modulo intentionally-retained variables (documented in transcript). `list_campaigns` doesn't return any `BC-5906 Round 2 *` results.

### T12 — File follow-up Linear issues (batched, session-end)

**Steps:**
1. Walk the F14–F31 findings table. For every row with status `refuted` or `needs-more-work`:
   - File a Linear issue in project "Brite Plugin Marketplace" (team Brite Company).
   - Title format: `BC-5906 follow-up: <short-description-of-finding>`.
   - Body: cite F-number, paste the verbatim evidence quote from the transcript, propose specific spec change in `plugins/marketing/commands/launch-campaign.md`, link back to BC-5906.
   - Priority: Medium for spec-correctness; High if the finding blocks production launch (e.g., F27 zero-templates).
2. Append the issue IDs to the round-2 transcript's "Follow-up Linear issues filed" section.

**Verification:** Every refuted/needs-more-work row has a corresponding Linear issue ID in the transcript.

### T13 — Preserve artifacts to docs/dogfood/bc-5906/

**Steps:**
1. Copy `.claude/worktrees/bc-5906/dogfood/test-leads.csv` → `docs/dogfood/bc-5906/test-leads.csv`.
2. Copy `.claude/worktrees/bc-5906/dogfood/test-copy.json` → `docs/dogfood/bc-5906/test-copy.json`.
3. Copy `.claude/worktrees/bc-5906/dogfood/BC-5906-Round-2-2026-04-27.json` (final state) → `docs/dogfood/bc-5906/launch-metadata.json`.
4. The transcript at `docs/dogfood/bc-5906/round-2-transcript.md` is already in place from T2 onward.

**Verification:** All 4 files exist under `docs/dogfood/bc-5906/`. The metadata JSON's `last_completed_phase == 9`, `activated == false`.

### T14 — Validation + PR-ready

**Steps:**
1. Run `./scripts/validate.sh` from repo root. Must exit 0.
2. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md`. Must exit 0.
3. Confirm no untracked or modified files outside `docs/dogfood/bc-5906/` (this PR is artifact-only — no command-spec changes, those go to follow-up issues per brainstorm decision 4).

**Verification:** Both scripts exit 0. `git diff --stat origin/main` shows changes only under `docs/dogfood/bc-5906/`.

---

## Verification checklist (objective, AC-aligned)

- [ ] `docs/dogfood/bc-5906/round-2-transcript.md` exists with all 7 phase sub-sections populated (Phase 3–9).
- [ ] F14–F31 findings table has 18 rows, every row marked `confirmed` / `refuted` / `needs-more-work` / `deferred`. F22 marked `deferred` per brainstorm. F31 marked spec-only per scope.
- [ ] Workspace cleanup verified — `list_campaigns` against `emailbison-personal` returns no `BC-5906 Round 2 *` results post-T11.
- [ ] Phase 10 (mode 1 local-render only) succeeded as part of Phase 1 spot-check / Phase 9 verification (no live preview endpoint call — F13 stays settled per BC-5904).
- [ ] No `--activate` invocation. No real emails sent.
- [ ] Follow-up Linear issues filed for every refuted / needs-more-work hypothesis; IDs listed in transcript.
- [ ] All preserved artifacts at `docs/dogfood/bc-5906/` (transcript + metadata + test-leads.csv + test-copy.json).
- [ ] `./scripts/validate.sh` exits 0.
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.
- [ ] Transcript attached as comment on BC-5906 (per AC).

---

## Pacing note

Per user memory (commits per task, pause at natural checkpoints):
- One commit per task T1–T9 (9 commits during the live walk).
- One commit at T10 (spec check), T11 (cleanup), T13 (preservation), T14 (validation).
- Pause for review after T9 — before cleanup, before filing follow-ups, while the live state is still inspectable in EB UI.
- T12 (Linear follow-ups) does not commit code; it mutates Linear state. Ask before filing each issue.

---

## Non-goals (explicit)

- Do NOT modify `plugins/marketing/commands/launch-campaign.md` in this PR. Spec corrections from refutations file as separate follow-up issues per brainstorm decision 4.
- Do NOT activate campaigns (`--activate` off; Phase 11 stays paper-spec-check only).
- Do NOT use `--test-send <email>`. Phase 10 mode 2 is out of scope.
- Do NOT pre-poison F22's `allow_parallel_sending` path. Deferred per brainstorm.
- Do NOT create new test inputs. Round-1's CSV + copy artifact are reused verbatim.
- Do NOT re-run `/marketing:tam-map`, `/marketing:list-building`, or `/marketing:email-copywriting`. This dogfood validates only `/marketing:launch-campaign` Phases 3–9.
