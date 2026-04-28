# Plan: BC-6306 — launch-campaign Phase 5 plain_text deliverability default

**Issue**: BC-6306 — BC-5906 follow-up: launch-campaign Phase 5 — set plain_text + other deliverability defaults on campaign create
**Branch**: `corinne/bc-6306-launch-campaign-plain-text-default`
**Tasks**: 6 (estimated 25–35 min)

## Prerequisites

- Design doc reviewed and approved: `docs/designs/bc-6306-launch-campaign-plain-text-default.md`
- Working tree clean on `main` (untracked `docs/campaigns/` is pre-existing dogfood scratch — leave alone)
- **CDR alignment**: skipped (Context7 quota exceeded this session — handbook CDR INDEX unreachable)
- **Precedent alignment**: BC-2707 (verified `update_campaign` is not on the two-call gate list → single MCP call per PATCH); BC-5906 task-2 (live-walk validation deferred to round-3 dogfood BC-6308, not this PR)
- **Scope narrowing intent**: BC-6306 ships `plain_text` only. `reputation_building` + `can_unsubscribe` deferred (no successor issues filed yet — operator wants to think them through separately).

## Tasks

### Task 1: Narrow BC-6306 Linear issue title + scope

**Files**: Linear issue BC-6306 (no repo files)
**Why**: Issue currently says "+ other deliverability defaults" — we're shipping plain_text only. Narrowing prevents future readers from thinking BC-6306 covers all 3 fields, and prevents PR reviewer scope confusion.

**Implementation**:
1. Edit BC-6306 title via `mcp__linear__save_issue` from:
   `BC-5906 follow-up: launch-campaign Phase 5 — set plain_text + other deliverability defaults on campaign create`
   to:
   `BC-5906 follow-up: launch-campaign Phase 5 — set plain_text deliverability default on campaign create`
2. Edit BC-6306 description: in the `## Scope` section, replace the bulleted edit list (currently lists 5 numbered items + email-bison.md item, scoped for 3 fields `plain_text` + `reputation_building` + `can_unsubscribe`) with the narrowed-scope version that:
   - Lists only `plain_text: true` as the field being set
   - Removes references to `--no-deliverability-defaults` flag (no flag added)
   - Replaces `deliverability_defaults_applied: bool` metadata field with `plain_text_applied: bool`
   - Adds a `### Deferred from this issue` subsection under Scope listing `reputation_building` and `can_unsubscribe` as "deferred for separate operator decision; no successor issue filed yet"
3. Leave the `## Finding (Sx-15)`, `## Round-2 evidence`, and `## Sources` sections unchanged — they're historical record of the round-2 walk and shouldn't be rewritten.

**Test**:
- Run: re-fetch BC-6306 via `mcp__linear__get_issue id=BC-6306`
- Expected: title contains `plain_text deliverability default` and not `+ other deliverability defaults`; description's `## Scope` section mentions `plain_text` only and contains a `### Deferred from this issue` subsection.

**Verify**: title + scope section read cleanly to a reader who has not seen this brainstorm; nothing implies reputation_building or can_unsubscribe is in this PR.

---

### Task 2: launch-campaign.md Phase 5 — insert PATCH step + user-gate surface + partial-failure note

**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Core spec change. Today Phase 5 stops at create_campaign (HTML mode by EB default); after this task it always PATCHes plain_text: true post-create.

**Implementation**:
1. **Insert new step 6** between current step 5 (`Execute creates`, line 409) and current step 6 (`Verify IDs`, line 410). Renumber existing steps 6 → 7 and 7 → 8. New step 6 body:

   > **6. Apply plain_text deliverability default.** For each campaign ID returned in step 5, call `update_campaign` (path `PATCH /api/campaigns/{id}/update` per `email-bison.md` § Tool inventory + verified via `search_api_spec`) with `plain_text: true`. This PATCH is **always** applied — it is a deliverability invariant for cold outreach (the only use case `/marketing:launch-campaign` serves) and has no operator opt-out. EB defaults `plain_text` to `false` on create, which sends emails as HTML; HTML mode for cold B2B carries tracking pixels, link rewrites, and image references that signal "automated marketing" to spam filters. The copy artifacts produced by `email-copywriting` use `<br><br>` for paragraph breaks and contain spintax — both assume plain-text rendering. Note: `update_campaign` is NOT on `email-bison.md` § MCP confirmation gates list; this is a single MCP call per campaign, no two-call cycle. PATCH is idempotent (re-asserting `plain_text: true` against an already-plain-text campaign is a no-op), so resume can re-run this loop blindly without harm.

2. **Edit user gate 5 (current step 4, lines 402–408)** — append a line before "Yes, create these campaigns (Recommended)" so the operator sees the plain_text application:

   Before:
   ```
   > Create {N} empty campaigns with the names above? Campaigns start in `Draft` state — no sends until Phase 11.
   ```

   After:
   ```
   > Create {N} empty campaigns with the names above? Campaigns start in `Draft` state — no sends until Phase 11. After create, each campaign will be PATCHed with `plain_text: true` (cold-outreach deliverability default — no opt-out).
   ```

3. **Edit Phase 5's "If Phase 5 fails mid-loop" paragraph (line 413)** — extend to cover partial-PATCH state. Replace the entire paragraph with:

   > **If Phase 5 fails mid-loop:** partial campaigns exist in the workspace. Metadata JSON lists the ones that succeeded and records `plain_text_applied: true` only when the PATCH loop completed for ALL campaigns. If `last_completed_phase: 5` was written but `plain_text_applied: false`, partial-PATCH state may exist (some campaigns plain-text, others HTML). Operator inspects EB UI, decides whether to delete the partial campaigns or resume by running a reduced version of Phase 5 that creates only the missing ones. On resume after partial-PATCH, the spec re-runs the PATCH loop on every campaign in `campaign_ids` regardless of prior state — PATCH is idempotent, so already-plain-text campaigns are no-ops. No automatic partial-resume.

4. **Edit current step 7 (Append to metadata, line 411)** — after renumbering to step 8, extend to also write `plain_text_applied`:

   Before:
   ```
   7. **Append to metadata JSON.** Set `campaign_ids: {"Google": 5551, "Microsoft": 5552, "Other": 5553}` (adjust keys per actual segmentation), `last_completed_phase: 5`.
   ```

   After (step 8, post-renumber):
   ```
   8. **Append to metadata JSON.** Set `campaign_ids: {"Google": 5551, "Microsoft": 5552, "Other": 5553}` (adjust keys per actual segmentation), `plain_text_applied: true` (only if step 6 PATCH loop completed for ALL campaigns; else `false`), `last_completed_phase: 5`.
   ```

**Test**:
- Run: `grep -n "plain_text" plugins/marketing/commands/launch-campaign.md`
- Expected: at least 4 hits in Phase 5 (new step 6 body, user gate 5, partial-failure paragraph, metadata write step). Zero hits in Phases 1–4 or 6–11.
- Run: `grep -n "^[0-9]\+\. \*\*" plugins/marketing/commands/launch-campaign.md | sed -n '/Phase 5/,/Phase 6/p'` — verify Phase 5 step numbering 1, 2, 3, 4, 5, 6, 7, 8 monotonic with no gaps.

**Verify**: read Phase 5 top-to-bottom — it should flow create → PATCH → verify → metadata-write without numbering gaps; user gate 5 mentions plain_text; partial-failure paragraph mentions plain_text_applied + idempotent resume.

---

### Task 3: launch-campaign.md § Launch metadata schema — add plain_text_applied field

**Files**: `plugins/marketing/commands/launch-campaign.md`
**Why**: Schema documentation needs to reflect the new metadata field so consumers (campaign-debrief skill, future audits) know it exists.

**Implementation**:
1. **Edit the JSON schema example (lines 113–137)** — add `"plain_text_applied": true,` line immediately after the existing `"campaign_ids":` line (line 126). Position: keep alphabetical/logical-progression neighbors — campaign_ids → plain_text_applied → sender_ids_attached.
2. **Edit the "Optional fields written by specific phases" listing (lines 141–151)** — add a new bullet for Phase 5:
   ```
   - Phase 5 step 6 / step 8: `plain_text_applied: <bool>` (true only if PATCH loop completed for all campaigns; false if partial)
   ```
   Insert in numerical order — after the Phase 2 IV-4 line and before the Phase 6 step 7 line.

**Test**:
- Run: `grep -n "plain_text_applied" plugins/marketing/commands/launch-campaign.md`
- Expected: 4–5 hits (1 in JSON example, 1 in Optional-fields listing, 2–3 in Phase 5 step 6 + partial-failure paragraph + step 8 metadata-write).
- Run: `python3 -c "import json,re; c=open('plugins/marketing/commands/launch-campaign.md').read(); m=re.search(r'\`\`\`json\n(\{.*?\})\n\`\`\`', c, re.DOTALL); json.loads(m.group(1))"` — verify the JSON example still parses cleanly with the new field added.
- Expected: command exits 0 (JSON valid).

**Verify**: schema example is still valid JSON; Optional-fields list is in numerical order by phase.

---

### Task 4: email-bison.md — add launch-campaign plain_text PATCH note

**Files**: `plugins/marketing/tools/integrations/email-bison.md`
**Why**: Integration guide should document that the launch-campaign command sets plain_text: true post-create, so future spec authors / readers know why update_campaign appears in the Phase 5 flow.

**Implementation**:
1. Edit the "Launch a campaign end-to-end (8 MCP calls)" subsection (around line 203 — confirm exact line via `grep -n "Launch a campaign end-to-end" plugins/marketing/tools/integrations/email-bison.md`). The header says "8 MCP calls" — this addition makes it 9 in segmented mode (or N+1 where N is the unsegmented count). Add the new call after the existing campaign-create line, before the lead-import line. Update the section header count if it's a literal number that's now wrong.
2. Edit the "Known gotchas" section (line 258+). Add a new bullet:
   ```
   - **`plain_text` defaults to `false` on `create_campaign`.** EB sends in HTML mode by default; for cold-outreach the spec follow-up is `update_campaign` with `plain_text: true` (single PATCH, idempotent — `update_campaign` is not on the two-call confirmation gate list). The launch-campaign command's Phase 5 applies this automatically; any net-new spec doing cold outreach should mirror that pattern. HTML mode for cold-B2B carries tracking pixels + link rewrites that signal "automated marketing" to spam filters and degrade deliverability.
   ```

**Test**:
- Run: `grep -n "plain_text" plugins/marketing/tools/integrations/email-bison.md`
- Expected: 1+ hits in the Known gotchas section.
- Run: `grep -n "Launch a campaign end-to-end" plugins/marketing/tools/integrations/email-bison.md` — verify the call-count number in the header matches the actual count of MCP calls listed in the subsection.

**Verify**: Known gotchas now includes the plain_text default note; if the launch-end-to-end count changed, header reflects it.

---

### Task 5: Bump marketing plugin version (plugin.json + marketplace.json)

**Files**: `plugins/marketing/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Why**: CLAUDE.md gotcha is explicit — "Bump plugin version in the SAME commit as any edit under `plugins/<plugin>/{hooks,skills,commands,agents}/**`." Tasks 2+3 edit `plugins/marketing/commands/launch-campaign.md` → must bump. Costly precedent BC-6000 cited in CLAUDE.md — version not bumped meant 4+ ship sessions served stale cached content.

**Implementation**:
1. Bump `plugins/marketing/.claude-plugin/plugin.json` `"version"` from `0.3.8` to `0.3.9` (patch bump — additive spec change, no behavior break for existing spec consumers).
2. Bump `.claude-plugin/marketplace.json` line 20 — the marketing plugin entry's `"version"` from `"0.3.8"` to `"0.3.9"`.

**Test**:
- Run: `grep -E '"version"' plugins/marketing/.claude-plugin/plugin.json`
- Expected: shows `"version": "0.3.9"`.
- Run: `python3 -c "import json; m=json.load(open('.claude-plugin/marketplace.json')); v=[p for p in m['plugins'] if p['name']=='marketing'][0]['version']; assert v=='0.3.9', f'got {v}'"` — exits 0.
- Run: `diff <(grep '"version"' plugins/marketing/.claude-plugin/plugin.json | head -1) <(python3 -c "import json; m=json.load(open('.claude-plugin/marketplace.json')); v=[p for p in m['plugins'] if p['name']=='marketing'][0]['version']; print(f'  \"version\": \"{v}\"')")` — verify versions match between the two files.

**Verify**: both files at 0.3.9; numbers agree.

---

### Task 6: Validate

**Files**: none (read-only validation pass)
**Why**: Catch any structural issues with the spec edits before review. CI-equivalent per CLAUDE.md.

**Implementation**:
1. Run `./scripts/validate.sh`. This is the marketplace-wide validator and runs all guardrail checks.
2. Run `./scripts/check-guardrails.sh --claude-md plugins/marketing/commands/launch-campaign.md` if the script supports per-file invocation (check `--help` first; if not supported, skip).
3. Spot-check Phase 5 numbering by reading the file: confirm `## Phase 5 — CAMPAIGN CREATE` section steps are 1, 2, 3, 4, 5, 6, 7, 8 monotonically, no `## Phase 5b` or other inadvertent header creation.
4. Confirm no other Phase or section was accidentally renumbered or edited (Task 2 should ONLY touch Phase 5 between lines 383–415; Task 3 should ONLY touch the metadata schema between lines 109–155).

**Test**:
- Run: `./scripts/validate.sh`
- Expected: exits 0 with all checks passing. (If a guardrail flag fires for line count or anti-slop, address it before declaring done — do not skip.)
- Run: `git diff --stat main -- plugins/marketing/commands/launch-campaign.md plugins/marketing/tools/integrations/email-bison.md plugins/marketing/.claude-plugin/plugin.json .claude-plugin/marketplace.json`
- Expected: exactly these 4 files modified, nothing else under `plugins/marketing/` or `.claude-plugin/`.

**Verify**: validate.sh green; diff scope matches plan exactly (4 files); spec reads coherently when re-read top to bottom.

---

## Task Dependencies

- **Task 1** (Linear narrowing) is independent — can run first or last. Recommended first to lock scope before editing.
- **Tasks 2 + 3** edit the same file (`launch-campaign.md`) in different sections — sequential preferred to avoid merge confusion in the diff. Task 2 first (Phase 5), then Task 3 (schema section).
- **Task 4** (email-bison.md) is independent of Tasks 2 + 3 — could parallelize, but trivial enough to keep sequential.
- **Task 5** (version bump) depends on Tasks 2 + 3 having committed at least one edit under `commands/`. Run after Tasks 2 + 3 land.
- **Task 6** (validate) is the final gate. Runs after Tasks 2–5.

Recommended execution order: 1 → 2 → 3 → 4 → 5 → 6.

## Verification Checklist

- [ ] Linear issue BC-6306 title + Scope section narrowed to plain_text only (Task 1)
- [ ] Phase 5 has new step 6 between create and verify-IDs that PATCHes `plain_text: true` per campaign (Task 2)
- [ ] Phase 5 step numbering monotonic 1–8 (Task 2)
- [ ] User gate 5 mentions `plain_text: true` deliverability default (Task 2)
- [ ] Phase 5 partial-failure paragraph documents idempotent resume + `plain_text_applied` metadata semantics (Task 2)
- [ ] § Launch metadata schema JSON example includes `plain_text_applied: true` (Task 3)
- [ ] § Launch metadata schema "Optional fields" list includes Phase 5 step 6/8 entry (Task 3)
- [ ] email-bison.md Known gotchas section documents the `plain_text` default and the launch-campaign auto-PATCH (Task 4)
- [ ] email-bison.md launch-end-to-end MCP-call count updated if it referenced a literal number (Task 4)
- [ ] `plugins/marketing/.claude-plugin/plugin.json` bumped to 0.3.9 (Task 5)
- [ ] `.claude-plugin/marketplace.json` marketing entry bumped to 0.3.9 (Task 5)
- [ ] `./scripts/validate.sh` exits 0 (Task 6)
- [ ] `git diff --stat` shows exactly 4 files modified (Task 6)
- [ ] No file outside the planned scope was edited (Task 6)
