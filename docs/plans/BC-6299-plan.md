# Plan: BC-6299 — launch-campaign Phase 3 VARIABLES reality gaps

**Issue**: BC-6299 — BC-5906 follow-up: launch-campaign Phase 3 VARIABLES — custom-variables reality gaps (Sx-2/3/4 + F15)
**Branch**: `corinne/bc-6299-bc-5906-follow-up-launch-campaign-phase-3-variables-custom`
**Tasks**: 5 (estimated 15-20 min execution + review/ship)

## Prerequisites
- BC-5906 round-2 transcript at `docs/dogfood/bc-5906/round-2-transcript.md` § Phase 3 + § Spec-vs-reality findings (Sx-2/3/4) is the source of truth
- Design doc at `docs/designs/BC-6299-launch-campaign-phase-3-variables.md` is approved (in scope: 7 spec edits + EB ref co-update + BC-6308 guardrail + version bump; out of scope: lowercasing convention, richer defaults, render testing)
- Plan file co-located with worktree per BC-6300 task-2: written here in main for approval, copy to worktree on creation, delete from main in same op
- **CDR alignment**: Skipped — Context7 quota exceeded this session
- **Precedent alignment**: 4th application of BC-6298 dogfood-bundle co-update pattern; honors BC-6300 task-1 (no CLAUDE.md promotion attempt — user already declined at 3rd-instance threshold); honors BC-6000 version-bump invariant; honors BC-5870 verification-side-effects (defer render tests to BC-6308 round-3 with guardrail, not absorb into this PR)

## Tasks

### Task 1: Edit launch-campaign.md Phase 3 — 7 sub-edits per issue body
**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Make Phase 3 spec match EB's verified API behavior (Sx-2/3/4 + F15). Stop pretending EB has a workspace-level `default` field, a 3-way classification, or a DELETE endpoint.

**Implementation** — apply these 7 edits in order to lines 278-313:

1. **Step 2 (line 287)** — keep "Each entry has `{name, default}`" but append: " The `default` is consumed in Phase 4 as the per-lead fill-in value when the CSV row lacks a column for this variable (see Phase 4 step 2 line 364) — it is NOT a workspace-scoped property of the variable in EB."
2. **Step 3 (lines 288-291)** — collapse 3-way classification to 2-way. Remove the "Conflicting" bullet entirely. Keep "New" and "Existing". Update the "Existing" bullet to: "**Existing** — name matches; will NOT re-create (EB returns 422 on duplicate `POST /api/custom-variables`). Reuse as-is."
3. **Step 4 (lines 292-298)** — remove the "default in workspace" rendering. Replace the example with:
   > Variables to create in workspace `{workspace}`:
   > - `{RECENCY_ANCHOR}` (new) — will register name only; per-lead values applied at Phase 4
   > - `{PROOF_POINT_COMPANY}` (new)
   > - `{FREE_ASSET_NOUN}` (existing — will reuse name registration)
4. **Step 5 (lines 299-305)** — User gate prompt. Remove the "{M-conflicting} conflicts to resolve" wording. Replace the gate text with: "Create {N-new} new variables in `{workspace}`? Existing ones will be reused as-is (EB rejects duplicate POSTs)." Reduce options to: "Yes, create new + reuse existing (Recommended)" / "Abort — fix the artifact or workspace state".
5. **Step 6 (line 306)** — change call signature. Replace "call `create_custom_variable` with `{name, default}`" with: "call `create_custom_variable` with `{name}` only (per Sx-2 — EB's `POST /api/custom-variables` accepts only `name`; sending `default` is silently ignored)."
6. **Step 7 (line 307)** — note the response shape. Replace "Set `custom_variables_created: [<list-of-names>]`" with: "Persist `custom_variables_created: [{id, name}]` from each create response (response body is `{id, name, created_at, updated_at}` — no `default` field). **Note (Sx-3):** EB silently lowercases names on store (`RECENCY_ANCHOR` → `recency_anchor`). Render-engine case-sensitivity is unverified — flagged for verification at BC-6308 round-3 Phase 4 lead spot-check."
7. **Phase 3 failure paragraph (line 309)** — update cleanup language. Replace "deletes the partial set if desired via the EB UI" with: "**Note (Sx-4):** there is no `DELETE /api/custom-variables/{id}` endpoint. Custom variables persist workspace-scoped indefinitely; only the EB UI can remove them. Operator inspects the workspace and either retains the partial set (recommended for next re-run, since duplicate POSTs return 422) or manually removes via the UI; then re-runs the phase from scratch — the metadata's `custom_variables_created` list is authoritative for what's on the vendor side."

**Verify**: `grep -n "Conflicting\|default in workspace\|{name, default}" plugins/marketing/commands/launch-campaign.md` returns no matches in the Phase 3 block (lines 278-313). `grep -n "Sx-2\|Sx-3\|Sx-4" plugins/marketing/commands/launch-campaign.md` returns at least 3 matches in Phase 3.

---

### Task 2: Add 3 EB API gotcha bullets to email-bison.md
**Files**: `plugins/marketing/tools/integrations/email-bison.md`
**Why**: 4th application of BC-6298 dogfood-bundle co-update pattern. Keep the canonical EB reference doc in sync with launch-campaign.md spec edits — Sx-2/3/4 are EB API behaviors, so they belong in the canonical EB ref alongside the procedural fix.

**Implementation**:

1. Locate the `## Known gotchas` section (or `### Known gotchas` subsection — grep for the heading first to confirm exact placement). If a Custom Variables sub-bullet group exists, append; otherwise add a new sub-group.
2. Append these 3 bullets verbatim:

   ```markdown
   - **Custom variables: no `default` field at the API.** `POST /api/custom-variables` accepts only `{name}` (Sx-2, BC-6299). Workspace-level fallback text does NOT exist — defaults live per-lead via `bulk_create_leads`'s `custom_variables: [{name, value}]` array. Phase 4 of `/marketing:launch-campaign` consumes the artifact's `default` field as the per-lead fill-in.
   - **Custom variable names are silently lowercased on store.** Sent `RECENCY_ANCHOR`; EB stores `recency_anchor` (Sx-3, BC-6299). Per-lead `custom_variables` array values must use lowercase names to match EB's stored form (verified Phase 4 round-2). Render-engine case-sensitivity (whether `{UPPERCASE_TOKEN}` in body resolves against lowercase-stored variable) is unverified — pending BC-6308 round-3 lead spot-check.
   - **No DELETE endpoint for `/api/custom-variables`.** `search_api_spec(method=DELETE)` returns no match (Sx-4, BC-6299). Custom variables persist workspace-scoped indefinitely; deletion is EB-UI-only. Cleanup wording in any spec referencing `/api/custom-variables` should reframe as "vars persist; document the retained set" rather than "delete via API".
   ```

**Verify**: `grep -c "Sx-2, BC-6299\|Sx-3, BC-6299\|Sx-4, BC-6299" plugins/marketing/tools/integrations/email-bison.md` returns 3.

---

### Task 3: Update BC-6308 issue body — add Phase 4 spot-check guardrail
**Files**: (Linear API mutation only — no local file edit)
**Why**: Lock the case-sensitivity AND empty-value render verifications into BC-6308's spec so round-3 cannot quietly skip them. Per BC-5870 verification-side-effects pattern — defer the verification, but make the next planned live-walk explicitly accountable.

**Implementation**:

1. Read current BC-6308 issue body via `mcp__linear__get_issue` with `id: "BC-6308"`.
2. Append a new section to the existing body (do NOT replace existing content):

   ```markdown
   ## BC-6299 verification carryover (added 2026-04-29)

   Round-3 Phase 4 lead spot-check MUST verify both render-engine behaviors deferred from BC-6299. Record outcomes in the round-3 transcript; file spinoff issue if either test reveals broken behavior (per BC-5870 verification-side-effects pattern — do NOT absorb the fix into round-3's PR).

   **Verification 1 — Case sensitivity (Sx-3 carryover).** Create at least one lead with a custom variable value populated (e.g., `recency_anchor: "ROUND-3 CASE TEST"`). Send a sequence step body containing both forms: `{RECENCY_ANCHOR}` and `{recency_anchor}`. Trigger `/test-email` to a verifiable inbox. Inspect rendered output:
   - If both resolve to "ROUND-3 CASE TEST" → render is case-insensitive; no further action.
   - If only `{recency_anchor}` resolves → render is case-sensitive; file spinoff to lowercase the artifact convention across the 14 marketing skills + email-bison.md merge-token guidance.

   **Verification 2 — Empty-value render (BC-6299 brainstorm carryover).** Create a second lead with the SAME variable explicitly empty (`recency_anchor: ""`). Send the same sequence step body. Inspect rendered output:
   - If empty-value renders as blank text → operator-facing risk; file spinoff to bake non-empty defaults into the email-copywriting artifact templates.
   - If empty-value renders as the literal `{recency_anchor}` placeholder → file spinoff for visible-template-error mitigation (operator pre-flight requirement to never upload empty values).
   - If EB has graceful spintax-style fallback (e.g., `{TOKEN|fallback text}` syntax) → file spinoff to document the syntax in email-bison.md and update email-copywriting templates accordingly.
   ```

3. Save via `mcp__linear__save_issue` with `id: "BC-6308"` and the merged body.

**Verify**: `mcp__linear__get_issue` returns BC-6308 with the new section present. The section header `## BC-6299 verification carryover (added 2026-04-29)` is grep-able in the returned body.

---

### Task 4: Bump marketing plugin version (plugin.json + marketplace.json)
**Files**: `plugins/marketing/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Why**: BC-6000 invariant — any change under `plugins/<plugin>/{hooks,skills,commands,agents}/**` requires version bump in the SAME commit. Tasks 1+2 touch `plugins/marketing/commands/` and `plugins/marketing/tools/` — both trigger the cache-staleness rule.

**Implementation**:

1. Edit `plugins/marketing/.claude-plugin/plugin.json` — change `"version": "0.3.11"` to `"version": "0.3.12"` (patch bump — docs-only spec edit, no functional behavior change).
2. Edit `.claude-plugin/marketplace.json` — change the marketing entry's `"version": "0.3.11"` to `"version": "0.3.12"`. Use grep to find the exact line first (`grep -n '"name": "marketing"' .claude-plugin/marketplace.json` then look 3 lines below).

**Verify**: `grep '"version"' plugins/marketing/.claude-plugin/plugin.json` returns `0.3.12`. `grep -A 4 '"name": "marketing"' .claude-plugin/marketplace.json | grep version` returns `0.3.12`.

---

### Task 5: Validate, commit, push for review
**Files**: (no edits — verification + commit only)
**Why**: Final ship-readiness gate. Catches any schema breakage from edits + locks the work into a single atomic commit per BC-6000 cache-invariant.

**Implementation**:

1. Run `./scripts/validate.sh` — must exit 0. Address any failures (likely none for docs-only edits but possible if `plugin.json` schema check trips).
2. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — must pass (no CLAUDE.md edits this PR, but run defensively).
3. Stage files explicitly (NEVER `git add .` per repo CLAUDE.md):
   ```
   git add plugins/marketing/commands/launch-campaign.md
   git add plugins/marketing/tools/integrations/email-bison.md
   git add plugins/marketing/.claude-plugin/plugin.json
   git add .claude-plugin/marketplace.json
   git add docs/designs/BC-6299-launch-campaign-phase-3-variables.md
   git add docs/plans/BC-6299-plan.md   # if still in main repo at this point
   ```
4. Commit with message:
   ```
   BC-6299: launch-campaign Phase 3 VARIABLES — match EB API reality

   - launch-campaign.md Phase 3: 7 sub-edits (Sx-2/3/4 + F15) — no
     workspace-level default, 2-way classification, no DELETE endpoint
   - email-bison.md: 3 EB API gotcha bullets (canonical ref co-update,
     4th application of BC-6298 pattern)
   - BC-6308: issue-body guardrail for round-3 case-sensitivity +
     empty-value render verification (BC-5870 verification-side-effects)
   - marketing plugin: 0.3.11 → 0.3.12 (BC-6000 cache invariant)
   ```
5. Push branch — `git push -u origin <branch>`.

**Verify**: `./scripts/validate.sh` exits 0. `git log -1 --stat` shows the 4 expected files (5 incl. design+plan). `git status` clean.

---

## Task Dependencies
- Tasks 1, 2, 3 are independent (Tasks 1+2 are local file edits; Task 3 is Linear API mutation) — can run in parallel
- Task 4 depends on Tasks 1+2 having edits in `plugins/marketing/` (the version bump rule trigger)
- Task 5 depends on Tasks 1, 2, 4 (all local edits must land before commit). Task 3 is Linear-only — no commit dependency

## Verification Checklist
- [ ] `./scripts/validate.sh` exits 0
- [ ] Phase 3 (lines 278-313) of launch-campaign.md has 0 references to "Conflicting", "default in workspace", or `{name, default}` as a create-call signature
- [ ] launch-campaign.md Phase 3 has at least 3 grep matches for "Sx-2", "Sx-3", "Sx-4"
- [ ] email-bison.md has 3 new gotcha bullets each citing "BC-6299"
- [ ] BC-6308 Linear issue body contains the `## BC-6299 verification carryover (added 2026-04-29)` section
- [ ] `plugins/marketing/.claude-plugin/plugin.json` version is `0.3.12`
- [ ] `.claude-plugin/marketplace.json` marketing entry version is `0.3.12`
- [ ] Single atomic commit captures all 4 file changes (per BC-6000)

## Ship-phase notes (not tasks — handled by /workflows:ship)
- Precedent trace candidates: (a) 4th application of BC-6298 dogfood-bundle pattern — promotion candidate but BC-6300 task-1 deferred; revisit at /workflows:promote-precedent. (b) defer-with-guardrail shape (convert "test now" to "test at next planned live-walk with locked spot-check") — reusable for future spec-vs-reality unknowns; promotion-eligible if 2nd instance later.
- Best-practices audit + handbook drift check fire at ship time per usual.
