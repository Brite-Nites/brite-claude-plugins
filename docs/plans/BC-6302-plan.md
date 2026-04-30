# BC-6302 — launch-campaign Phase 5 silent-duplicate guard plan

**Issue:** [BC-6302](https://linear.app/brite-nites/issue/BC-6302) — `BC-5906 follow-up: launch-campaign Phase 5 — guard against silent duplicate campaigns (F20)`
**Branch:** `corinne/bc-6302-bc-5906-follow-up-launch-campaign-phase-5-guard-against`
**Scope:** Edit `plugins/marketing/commands/launch-campaign.md` Phase 5. Docs-only change. No code, no schema migration.

## What's wrong today (F20 evidence)

EB API allows arbitrary duplicate campaign names without warning. From BC-5906 round-2 transcript:

- `create_campaign(name="BC-5906 Round 2 | Google", type="outbound")` called twice → returned IDs 22 and 24, both `success: true`, no error.
- `list_campaigns(search="BC-5906 Round 2")` returned 22, 23, 24 — i.e., the duplicate pair was visible at list time but never surfaced at create time.

Phase 5 step 5 ("Execute creates") and step 6 ("Verify IDs") today both treat `success: true` as proof of unique campaigns. False on a workspace that already has matching names from a prior partial run.

Production impact: a partial-failure resume could silently spawn duplicate campaign sets, undetectable from API responses alone — leading to lead-attach to the wrong copy and double sends.

## What we're changing (3 surgical edits)

All inside `plugins/marketing/commands/launch-campaign.md` Phase 5 (file lines 397–428).

### Edit 1 — insert new step 3 (pre-list call), shift downstream numbering

Between current step 2 (Determine campaign names) and current step 3 (Render the create plan), insert:

> **3. Pre-list existing campaigns by base name.** Call `list_campaigns(search="{campaign-name-base}")` (core-tier, directly callable per § Tool tier map) before User gate 5. Capture any returned campaigns whose `name` equals or starts with the base — these are pre-existing matches the operator must reconcile. Empty match set is the happy path; non-empty triggers the duplicate-guard render in step 5.

After this edit:
- Old step 3 (Render create plan) → step 4
- Old step 4 (User gate 5) → step 5
- Old step 5 (Execute creates) → step 6
- Old step 6 (Verify IDs) → step 7
- Old step 7 (PATCH plain_text) → step 8
- Old step 8 (Append metadata) → step 9

The "If Phase 5 fails mid-loop" trailing paragraph references "step 7 PATCH loop" several times — those references update to "step 8 PATCH loop" in lockstep. Same for the metadata schema bullet at line 151 (`Phase 5 step 7 / step 8` → `Phase 5 step 8 / step 9`).

### Edit 2 — extend User gate 5 (now step 5) to surface duplicate matches and offer reuse

Replace the current gate render so the conditional duplicate warning appears only when step 3's pre-list returned matches:

> **5. User gate 5.** Ask via `AskUserQuestion`:
>
> If step 3's pre-list is empty, render the existing prompt:
>
> > Create {N} empty campaigns with the names above? Campaigns start in `Draft` state — no sends until Phase 11. After create, each campaign will be PATCHed with `plain_text: true` (cold-outreach deliverability default — no opt-out).
> >
> > - Yes, create these campaigns (Recommended)
> > - Rename — I'll supply a different suffix convention
> > - Abort
>
> If step 3's pre-list returned `M` matches, prepend a duplicate warning and add a fourth option:
>
> > ⚠️ {M} campaigns already exist matching `{campaign-name-base}`:
> >   - id 22 — `{name}` ({status})
> >   - id 24 — `{name}` ({status})
> >   - … (cap at 10; if more, append "and {K} more")
> >
> > Create {N} new campaigns anyway, or reuse existing IDs?
> >
> > - Reuse existing IDs (Recommended if names match exactly per bucket)
> > - Create {N} new campaigns anyway
> > - Rename — I'll supply a different suffix convention
> > - Abort

The "Recommended" annotation flips between paths because the safer default differs: when nothing matches, create; when matches exist, reuse.

### Edit 3 — branch step 6 (Execute creates) and step 7 (Verify IDs) on the gate decision

Replace step 6 (Execute creates) and step 7 (Verify IDs) with a branched form:

> **6. Execute creates or reuse existing IDs.** Branch on User gate 5 decision:
>
> - **"Reuse existing IDs":** For each bucket from step 2, find the matching campaign ID in step 3's pre-list (exact name match required). Map bucket → ID. Skip the `create_campaign` calls entirely. If any bucket has zero exact matches in the pre-list, halt and surface which bucket has no match — operator must Rename or fall back to Create.
> - **"Create … anyway" or empty pre-list:** For each name in the plan, call `create_campaign`. Capture the returned campaign ID. Map bucket → ID.
>
> **7. Verify IDs.** Confirm every bucket has a campaign ID (created or reused). If any campaign create fails, halt and surface the specific bucket + error. Do NOT retry automatically — a partial campaign set is easier to audit than a silently-retried one.

Step 8 (PATCH plain_text) is unchanged in body — the PATCH loop is idempotent on reused campaigns and re-asserting `plain_text: true` against an already-plain-text campaign is a no-op (already documented in current step 7 text).

Metadata write (now step 9) gets one extra field:

> Set `campaign_ids: {…}`, `plain_text_applied: …`, `last_completed_phase: 5`, **`reused_existing_ids: <bool>`** (true if User gate 5 selected "Reuse existing IDs").

Add the new field to the launch-metadata schema documentation block at lines ~111–151:

> - Phase 5 step 6: `reused_existing_ids: <bool>` — true if operator selected "Reuse existing IDs" at User gate 5; false on fresh creates.

## Out of scope

- No EB API change (EB has no dedup primitive; this is a spec-side guard).
- No automatic dedup or merge — operator decides at the gate.
- Not adding a similar guard to Phase 6/7/8/9 — duplicates only matter at create time; downstream phases operate on the already-mapped `campaign_ids`.
- Not changing `--reference` handling in step 1 (line 401) — `get_campaign(reference_id)` is independent of the dup-name search.

## Tasks

1. **Worktree.** `git checkout -b corinne/bc-6302-bc-5906-follow-up-launch-campaign-phase-5-guard-against`. Verify `./scripts/validate.sh` passes on a clean tree (already known good — main is at `583a8f1`).
2. **Insert new step 3 (pre-list)** in `plugins/marketing/commands/launch-campaign.md` between current steps 2 and 3.
3. **Renumber downstream steps** (3→4, 4→5, 5→6, 6→7, 7→8, 8→9) and update intra-phase references in the trailing "If Phase 5 fails mid-loop" paragraph and the launch-metadata schema bullet at line 151.
4. **Replace step 5 (User gate 5)** with the conditional render: empty-pre-list keeps the 3-option prompt; non-empty surfaces the warning + 4th "Reuse" option.
5. **Replace steps 6+7 (Execute / Verify)** with the branched form: reuse path or create path; verify after either.
6. **Update step 9 (metadata write)** to add `reused_existing_ids` field, and add the matching bullet to the launch-metadata schema doc block at lines ~111–151.
7. **Bump versions** — `plugins/marketing/.claude-plugin/plugin.json` and the matching `marketing` entry in `.claude-plugin/marketplace.json`. Match the BC-5906-chain cadence (patch bump).
8. **Validate** — `./scripts/validate.sh` exits 0; `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0.
9. **Verification per issue AC**:
   - Phase 5 step 3 includes the pre-list call ✓
   - User gate 5 surfaces existing-campaign matches ✓
   - Phase 5 step 6 has the reuse path ✓
   - `./scripts/validate.sh` exits 0 ✓

## Precedents applied

- **BC-6301 task-2** — 5x pattern-match brainstorm-skip rule. This is the 7th in the BC-5906 round-2 chain; brainstorm skipped, plan written directly.
- **BC-6000** — bump plugin version in the same commit as edits under `plugins/marketing/commands/`.
- **Factual-anchor recipe (BC-5797 → BC-5953 check #8)** — verified `list_campaigns` is core-tier (directly callable, no `search_api_spec` round-trip needed) per § Tool tier map line 41 before referencing it in the new step 3.
- **BC-5828 task plan-inheritance check** — exact step renumbering called out (3→4, 4→5, …, 8→9) so downstream metadata refs at line 151 don't drift silently.

## Risks

- **Renumbering churn.** Eight steps shift index. Risk: a stale step reference elsewhere in the file or in the metadata schema block. Mitigation — grep for `Phase 5 step \d` and `step [3-8]` in the file before commit; update every hit.
- **`list_campaigns` search semantics.** EB's `search` parameter is documented as substring match. F20 evidence shows `search="BC-5906 Round 2"` returned all three buckets (22, 23, 24), which proves substring match works as expected.
- **None on data integrity** — no API mutation added, only a read + spec branch.
