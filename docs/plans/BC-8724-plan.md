# BC-8724 — Implement `/marketing:plan-campaign` orchestrator

**Issue:** [BC-8724](https://linear.app/brite-nites/issue/BC-8724) (GTM T4-I)
**Branch / worktree:** `holden/bc-8724-plan-campaign` at `.claude/worktrees/bc-8724/`
**Base:** `origin/main` @ `5925680`
**Complexity:** L (15-step orchestrator; 4 modules: command + canonicals reader + Linear/SF/EB integration glue + tests)

## Scope

Author `plugins/marketing/commands/plan-campaign.md` — the campaign-scaffolding orchestrator. One invocation creates one campaign across all 4 layers:

1. **Plugin filesystem** — `docs/campaigns/{entity}/{slug}/manifest.json` (the cross-layer index)
2. **Linear** — 1 milestone in "Brite GTM" project + 8 standard sub-issues + up to 2 optional sub-issues, all blocked-by-chained
3. **Salesforce** — 1 Campaign record (auto-create via `/revops:create-sf-campaign`, soft-fail)
4. **Email Bison workspace assignment** — recorded in manifest only (no EB campaign created here; that lives in `/marketing:launch-campaign`)

Soft-fail philosophy: SF auto-create failure does NOT halt scaffolding. Manifest gets `salesforce.campaign_id: null`; operator manually reconciles via `/marketing:sync-campaign-status` (or by re-invoking `/revops:create-sf-campaign` directly).

## Key architectural decisions (locked from BC-8717 respec + ADR-015/016)

- **Composition via `Skill` tool**, not direct MCP write tools. The originally-planned `mcp__plugin_revops_salesforce__create_sf_campaign` write tool does not exist — the upstream `@salesforce/mcp` is not Brite-owned. Plan-campaign invokes `/revops:create-sf-campaign` (BC-8717) and reads the single-line JSON it emits on stdout. Same pattern for status sync via `/revops:update-sf-campaign-status` (BC-8723).
- **Canonicals are local filesystem reads** (ADR-016). Read `plugins/marketing/data/canonicals/_manifest.yaml` + `{vertical}.yaml` directly — no `gh api` or context7 calls.
- **Slug format**: `{vertical}-{persona}-{offer}-fy{YY}-m{MM}` standard; `cross-entity-{theme}-fy{YY}-m{MM}` exception. Same regex as BC-8717: `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$`.
- **Tuple validity**: a `(vertical, persona, offer)` is valid if (a) all three exist in canonicals AND (b) if `offer.target_personas` is non-empty, persona must appear in that list. Empty `target_personas` means "all personas valid for this offer." Lint already enforces (a) and the referential integrity of (b); plan-campaign enforces (b) at runtime.
- **Brief template fetch strategy**: fetch handbook `campaign-brief-template.md` via `gh api repos/brite-nites/handbook/contents/marketing/go-to-market/templates/campaign-brief-template.md` at scaffold time, slot-substitute `{{vertical}}` / `{{persona}}` / `{{offer}}` / `{{entity}}` / `{{launch_date}}` / `{{owner_email}}` / `{{slug}}`. If gh fetch fails, fall back to an inline minimal 8-section skeleton (no ICP/offer extraction in v1 — leave operator-fill placeholders).
- **Launch-date default**: when `--launch-date` not provided, default to `{year}-{month:02d}-01` (first day of the target month). Surface the computed default at the dry-run preview so operator can override.
- **Owner-email resolution chain**: (1) `/revops:create-sf-campaign` is the SF-side authority for "is this a valid owner"; we pre-validate by trying `mcp__plugin_revops_salesforce__get_username` and deriving an email; (2) fall back to `--owner-email`; (3) fall back to `AskUserQuestion`. Plan-campaign captures the resolved value into manifest + into the `/revops:create-sf-campaign --owner-email` invocation.
- **No `__c` field changes** — BC-8713 already shipped `Persona__c`, `Offer__c`, `Entity__c`, `Substatus__c`. Plan-campaign just maps to those.

## Caller-contract corrections vs issue spec

The issue spec is mostly accurate, but predates the BC-8717/BC-8723 respec. These corrections apply:

1. **`allowed-tools` should list `Skill`, not `mcp__plugin_revops_salesforce__create_sf_campaign`.** The MCP write tool doesn't exist.
2. **Validation example tuple** in the spec (`Municipalities × Public Works Director × Free ROP Audit`) does not match canonicals (`municipalities` has personas `parks-rec-director`, `city-manager`, `downtown-events-manager`; offers are `parks-bond` / `downtown-revitalization` / etc — no `free-rop-audit`). Use a valid tuple in the test harness, e.g. `municipalities × parks-rec-director × parks-bond × M05`.
3. **Cohort-1 worked example** in README §3.6 uses `hotels-resorts × director-of-resort-experience × holiday-anchor-audit × M02` — verify against `hotels-resorts.yaml`; if mismatched, use whatever the canonical actually says.

## Tasks

### Task 1 — Author `plan-campaign.md` skeleton + frontmatter

**File**: `.claude/worktrees/bc-8724/plugins/marketing/commands/plan-campaign.md`

Write the frontmatter and the top-level structure (no phase bodies yet):

```yaml
---
description: Scaffold one GTM campaign across all 4 layers — Linear milestone + 8-10 sub-issues + plugin manifest.json + Salesforce Campaign (via /revops:create-sf-campaign soft-fail) + Email Bison workspace assignment. Hybrid flag-or-prompt mode. Triggers on "plan campaign", "scaffold campaign", "new GTM campaign", or direct /marketing:plan-campaign invocation.
argument-hint: --vertical <slug> --persona <slug> --offer <slug> [--month <1-12>] [--year <YYYY>] [--entity <nites|supply|labs|cross-entity>] [--launch-date <YYYY-MM-DD>] [--owner-email <email>] [--eb-workspace <emailbison-personal|emailbison-b2b>] [--theme <slug>] [--situation-mining] [--creative-angles] [--dry-run]
allowed-tools: Read, Write, Bash, AskUserQuestion, Skill, mcp__plugin_workflows_linear-server__list_projects, mcp__plugin_workflows_linear-server__list_milestones, mcp__plugin_workflows_linear-server__save_milestone, mcp__plugin_workflows_linear-server__save_issue, mcp__plugin_revops_salesforce__get_username, mcp__plugin_revops_salesforce__run_soql_query
---
```

Top-level sections to stub: `# /marketing:plan-campaign` heading + one-paragraph intro + `## Inputs / outputs / precedent` + `## Soft-fail philosophy` + an outline of all 11 steps (just headings).

**Verify**: `./scripts/validate.sh` passes the frontmatter lint.

### Task 2 — Step 1 (operator invocation + flag parsing + interactive fallback)

Add Step 1 to plan-campaign.md. Spec the flag table verbatim from the issue. For each REQUIRED flag (`--vertical`, `--persona`, `--offer`) that's missing, prompt via `AskUserQuestion` ONE QUESTION AT A TIME (per `feedback_one_question_at_a_time.md` + `feedback_interview_chunking.md`). Auto-derive defaults where possible:

- `--month` / `--year` default to current month/year (read via `date +%Y` / `date +%m` shell-out).
- `--entity` auto-detected for single-entity verticals: read `{vertical}.yaml`, if it has a `default_entity` key (none currently — add as future enhancement), use it; otherwise prompt.
- `--launch-date` default `{year}-{month:02d}-01` (announce in dry-run preview).
- `--owner-email` resolves per chain above.
- `--eb-workspace` resolves from entity per the map (`nites` → `emailbison-personal`; `supply`/`labs` → `emailbison-b2b`; `cross-entity` → prompt).

**Verify**: stub the step, mark "implementation provided by Claude executing this skill at runtime" — the markdown is prompt-template, not Python code.

### Task 3 — Step 2 (canonicality validation)

Spec the validation logic:

1. Read `plugins/marketing/data/canonicals/_manifest.yaml` via `Read` tool; assert `--vertical` ∈ `verticals[]`. On miss, HARD-FAIL with a clear error pointing to `/marketing:new-vertical` (BC-8725).
2. Read `plugins/marketing/data/canonicals/{vertical}.yaml`; assert `--persona` ∈ `personas[].slug`. On miss, HARD-FAIL pointing to `/marketing:new-persona` (BC-8725).
3. Assert `--offer` ∈ `offers[].slug`. On miss, HARD-FAIL pointing to `/marketing:new-offer` (BC-8725).
4. For the matched offer, if `target_personas` is non-empty, assert `--persona` ∈ `target_personas`. On miss, HARD-FAIL: `Offer '{offer}' targets personas [{list}] — '{persona}' is not in this list. Either pick a valid persona OR update {vertical}.yaml's offer.target_personas via PR.`

**Verify**: stub the step with full error messages. The orchestrator runtime does the actual reads.

### Task 4 — Step 3 (slug compute + collision check)

Spec slug computation:

- Standard: `{vertical}-{persona}-{offer}-fy{YY}-m{MM}` where YY = `year % 100`, MM = `{month:02d}`.
- Cross-entity: `cross-entity-{theme}-fy{YY}-m{MM}` requires `--theme`. Reject if `--entity=cross-entity` AND `--theme` is empty.
- Regex check: `^[a-z0-9-]+-fy\d{2}-m\d{2}(-v\d+)?$` (matches BC-8717's regex; max length implicitly bounded by component slugs).

Collision check:

1. `list_projects(query="Brite GTM")` → resolve `<gtm-project-id>`. (Cache: re-use if also needed in Step 8a.)
2. `list_milestones(projectId=<gtm-project-id>, query=<slug>)` → if any milestone's name === slug, prompt the operator: "Same-month collision. Append `-v2` (or `-v3`, etc.) to slug?" via `AskUserQuestion` with options `[Append -v2, Cancel scaffold]`. On `-v2`, re-check collision recursively; if `-v2` exists, propose `-v3`.

**Verify**: stub the step including the collision-prompt wording.

### Task 5 — Step 4 (entity ↔ EB workspace + owner_email resolution)

Spec the EB workspace map (table verbatim from issue spec, plus cross-entity prompt path). Spec the owner-email resolution chain:

1. `mcp__plugin_revops_salesforce__get_username` returns `{ username }` (literal SF username, per `gotcha_sf_mcp_username_not_alias.md`). If the returned username is a valid email format (regex `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$`), use it. Otherwise skip to (2).
2. If `--owner-email` flag provided, use it.
3. `AskUserQuestion`: "Resolve SF Campaign owner email" with default option set to `marketingadmin@britenites.com` (the GTM service account per README §3.6.7).

Store resolved value as `<owner-email>` for Step 8b.

### Task 6 — Step 5 (dry-run preview)

Spec the preview block — exactly what the operator sees. Include: slug, entity, vertical, persona, offer, year, month, launch_date, EB workspace, owner-email, manifest.json path, full SF Campaign payload preview (call `/revops:create-sf-campaign --dry-run ...` via Skill tool and pass-through the JSON), and the 8 standard + N optional sub-issue titles with blocked-by edges.

If `--dry-run` was passed, exit here (no writes).

**Verify**: stub spec. Include sample dry-run output as a code block.

### Task 7 — Step 6 (two-call confirm gate, per BC-2707)

Spec the gate per `docs/precedents/BC-2707.md`:

1. First Bash call prints "Confirm? (y/n)" (or — better — `AskUserQuestion` with options `[Proceed, Cancel]`).
2. Operator answers in the next turn.
3. Second tool call proceeds only on affirmative consent. Per BC-2707, "yes" / "approved" / "go ahead" / "proceed" / "do it" all count as affirmative; ambiguous answers re-prompt.
4. The anti-pattern being blocked is "issuing both writes in the same turn without an operator turn between them."

### Task 8 — Step 7 (plugin dir + manifest.json)

Spec the write:

- Path: `docs/campaigns/{entity}/{slug}/manifest.json` (one directory per campaign, holding the manifest + future per-campaign artifacts like enriched CSV / learnings.md).
- Use the FULL schema from the issue spec (12 top-level keys + `linear` / `salesforce` / `email_bison` nested objects, all 4 timestamp fields populated where known).
- `created_at` is ISO-8601 with timezone (use `date -u +%Y-%m-%dT%H:%M:%SZ`).
- `scaffolded_by: "/marketing:plan-campaign"`.
- Initial state: `linear.milestone_id: null` and `salesforce.campaign_id: null` (filled in Steps 8a / 8b).

After write, `Read` it back and `Bash` `git status --short docs/campaigns/{entity}/{slug}/manifest.json` to confirm tracking. (Don't commit; that's `/workflows:ship`.)

### Task 9 — Step 8a (Linear milestone create with brief template)

Spec the milestone create:

1. Reuse `<gtm-project-id>` from Step 3 (or re-look-up if not cached).
2. Fetch the brief template via `Bash`:
   ```
   gh api repos/brite-nites/handbook/contents/marketing/go-to-market/templates/campaign-brief-template.md \
     -q .content | base64 -d
   ```
   If gh fails (auth missing, file missing), use the inline fallback (Task 9b).
3. Slot-substitute `{{vertical}}` → `{{persona}}` → `{{offer}}` → `{{entity}}` → `{{slug}}` → `{{launch_date}}` → `{{owner_email}}` in the template body.
4. `save_milestone` with:
   - `name`: slug
   - `description`: the substituted brief template body
   - `projectId`: `<gtm-project-id>`
5. Apply labels per README §3.6 Step 8a: `slug:{slug}`, `entity:{entity}`, `vertical:{vertical}`, `persona:{persona}`, `offer:{offer}`, `year:{YYYY}`, `month:{MM with leading zero}`, `status:planning`. (Labels are applied via separate `save_issue` calls on the milestone parent, or — if Linear MCP doesn't support milestone labels directly — via convention encoded in the milestone name/description; verify at impl time.)
6. Capture milestone ID + URL from `save_milestone` response; update manifest's `linear.milestone_id` + `linear.milestone_url`.

**Verify**: stub the step. Cite README §3.6 Step 8a as the source of the label set.

#### Task 9b — Inline brief-template fallback

If gh fetch fails, embed a minimal 8-section template directly in plan-campaign.md (~50 lines). Sections:

1. Overview
2. Goals
3. Audience (Persona + ICP placeholders)
4. Messaging (Angles placeholder)
5. Channels
6. Assets
7. Budget
8. Success Metrics

Each section has a one-line operator instruction (`<!-- Fill in from handbook/{vertical}/README.md -->`).

### Task 10 — Step 8b (SF Campaign auto-create via /revops:create-sf-campaign)

Spec the Skill-tool invocation:

```
Skill(skill: "revops:create-sf-campaign", args: "--slug=<slug> --entity=<entity> --vertical=<vertical> --persona=<persona> --offer=<offer> --year=<year> --month=<month> --owner-email=<owner-email> --launch-date=<launch-date>")
```

Parse the returned single-line JSON:

- Success shape: `{"campaign_id": "<id>", "campaign_url": "<url>", "campaign_name": "<slug>"}`
  → Update manifest `salesforce.campaign_id` + `salesforce.campaign_name`.
- Error shape (soft-fail): `{"error": "<kind>", ...}` for kinds `duplicate_slug` / `missing_owner` / `sf_cli_error` / `invalid_slug_format`
  → Update manifest `salesforce.campaign_id` to `null`, log a WARN line citing the error kind, append the reconciliation reminder to the Step 11 summary. DO NOT halt — proceed to Step 9.
- `duplicate_slug` special handling: extract `existing_id`, write that into manifest as if it were our own (since it's an idempotent re-run); log INFO not WARN.

### Task 11 — Step 9 (8 standard sub-issues with blocked-by chain)

Spec the 8 sub-issue creates. For each, list:

- **Title**: `Brief approved` / `Target list built` / `Copy written + approved` / `Salesforce setup` / `Pre-launch QA` / `Launch executed` / `Active management — weekly reviews` / `Campaign closed + debrief`
- **Sub-issue role description** (1-2 sentences each — see README §3.6 Step 9)
- **Expected plugin command** referenced in description (e.g., `/marketing:list-building` for #2; `/marketing:email-copywriting` for #3; `/revops:create-sf-campaign` reconciliation for #4; `/marketing:launch-campaign` for #6; `/marketing:campaign-analysis` for #7; `/marketing:campaign-debrief` for #8)
- **Handbook citation** (e.g., for #1 cite `marketing/go-to-market/templates/campaign-brief-template.md`)

Wire the blocked-by chain via `save_issue`'s `parentId` + a second pass that sets `blockedBy` relations:

- `#1` (Brief) blocks `#2` … `#8` (gate)
- `#2` blocks `#3` blocks `#4` blocks `#5` blocks `#6` blocks `#7` blocks `#8`

Per `gotcha_linear_save_issue_parent_id.md`: parent linkage is `parentId`, not `parent`. Per the Linear MCP `save_issue` contract: blockedBy relations may need a follow-up `save_issue` call with `blockedById` (verify shape at impl time; if `blockedBy` not directly settable on create, file a follow-up to set relations post-create).

Each sub-issue's `parentId` is the milestone's parent issue — BUT wait, milestones aren't issues. Verify at impl time: Linear sub-issues have an issue parent, not a milestone parent. The pattern may be: create a single "Container" issue per campaign that's the parent of the 8 sub-issues, with the milestone as the project-milestone marker. OR: the 8 sub-issues live directly under the project, tagged with the milestone via `projectMilestoneId`. The README §3.6 Step 9 implies the latter ("Each `save_issue` call sets parentId=milestone_id") — but milestones don't accept child issues directly. Resolve this at impl-time via Linear MCP introspection.

### Task 12 — Step 10 (optional sub-issues)

- `--situation-mining`: enforce Labs entity via canonicals check. Reject for non-Labs with: `Situation Mining is a Brite Labs framework. To use it on a non-Labs campaign, escalate to GTM lead.`
- `--creative-angles`: no entity restriction; add as sub-issue #10.

Both optional sub-issues:

- Have `blockedBy: [<#1 Brief approved>]` (per README §3.6 Step 10: "parallel with #2-#3").
- Use the same `save_issue` shape as Task 11.

### Task 13 — Step 11 (summary output)

Spec the summary print:

- Milestone URL + slug + manifest path + sub-issue count + sub-issue IDs (BC-XXXX list).
- If σ3 SF auto-create soft-failed: explicit reminder: `WARN: SF Campaign auto-create returned {error}. Reconcile manually via /revops:create-sf-campaign --slug={slug} ...` followed by the recovery hint from the error kind (per BC-8717's error catalog).
- For `status:paused` / `status:killed` Linear transitions: recommend `/marketing:sync-campaign-status` (T2-FA / BC-8752).

### Task 14 — Bump plugin version

Bump in the SAME commit (per CLAUDE.md plugin-cache gotcha):

- `plugins/marketing/.claude-plugin/plugin.json`: `0.3.38` → `0.3.39`
- `.claude-plugin/marketplace.json` marketing entry: `0.3.38` → `0.3.39`

### Task 15 — Validation harness

Add a fixture-driven shell test that exercises the dry-run path. File: `plugins/marketing/tests/test_plan_campaign_dry_run.sh`. Pattern modeled on `plugins/marketing/scripts/bw-run.test.sh` (existing in-repo precedent).

Cover these scenarios:

1. **happy path** (valid tuple, dry-run): asserts dry-run output contains `manifest.json` path + the 8 standard sub-issue titles + the SF Campaign payload preview.
2. **invalid vertical**: HARD-FAIL with new-vertical pointer.
3. **invalid persona for offer** (target_personas mismatch): HARD-FAIL with the offer's actual target_personas list.
4. **cross-entity without --theme**: HARD-FAIL.
5. **cross-entity with --theme**: produces correct slug `cross-entity-{theme}-fy{YY}-m{MM}`.
6. **--situation-mining on non-Labs entity**: HARD-FAIL.
7. **--situation-mining on Labs entity**: includes sub-issue #9 in dry-run.

Note: scenarios that touch Linear / SF can NOT run unattended — those are dogfood scenarios for BC-8727 (T6-O). Test harness covers parse + canonicals + slug + dry-run path only.

**Verify**: shell-test passes locally; wire into `scripts/validate.sh` (mirroring the lint_canonicals.py hook from BC-8718).

### Task 16 — Update GTM README + project-plan-refined

- `docs/gtm-campaign-orchestration-README.md` §3.6 Step 8b: confirm Skill-tool invocation framing is current (it is, per pre-merge); add a note that BC-8724 has shipped if the README's status indicator is stale.
- `docs/project-plan-refined.md` T4-I section: replace any remaining `mcp__plugin_revops_salesforce__create_sf_campaign` references with the Skill-tool composition pattern.
- README §7 status table: flip T4-I row to ✅.

### Task 17 — Self-review and ship

1. Run `./scripts/validate.sh` (must pass).
2. Run `./scripts/check-guardrails.sh --claude-md CLAUDE.md` (must pass).
3. Run `bash plugins/marketing/tests/test_plan_campaign_dry_run.sh` (must pass).
4. `git status` — confirm only intended files changed.
5. `git diff` review.
6. Stage + commit with `Closes BC-8724` in the trailer.
7. Hand off to `/workflows:review` before `/workflows:ship`.

## Out of scope (explicit non-goals)

- Real Linear writes against the production project — BC-8727 covers the first dogfood.
- Real SF Campaign creation against brite-prod — happens in dogfood via the existing `/revops:create-sf-campaign` command.
- σ3 trigger automation — that's BC-8752 (T2-FA), which DEPENDS on this.
- Creating the EB campaign — that's `/marketing:launch-campaign` (BC-2707-era code) invoked at sub-issue #6.
- Filling out the brief content (Audience / Messaging / etc.) — those are operator-fill at sub-issue #1 (Brief approved gate).
- Handling `--reference <campaign-id>` for cloning — already exists in `launch-campaign`; not part of plan-campaign's scope.

## Risks + mitigations

| Risk | Mitigation |
|---|---|
| Linear MCP `save_milestone` may not support `labels` directly | Test in dogfood (BC-8727); if not supported, encode label-equivalent metadata into milestone description + apply labels to the parent issue instead. Add to follow-up issue. |
| `parentId` on a sub-issue may need to point to an issue, not a milestone | Resolve at impl-time via Linear MCP introspection. If issue-only, create a "campaign container" issue under the milestone first and parent the 8 sub-issues to it. |
| `gh api` handbook fetch may fail in CI / non-authed environments | Inline fallback template (Task 9b) ensures the milestone always has a description, even if degraded. |
| The Skill-tool invocation of `/revops:create-sf-campaign` may not parse the slash-command output as JSON cleanly | Bash-shell the underlying `sf` CLI command directly as a fallback, OR write a thin helper script `plugins/marketing/scripts/invoke_create_sf_campaign.sh` that wraps the Skill invocation and stdout capture. Defer to dogfood findings. |
| Brief template handbook path may not exist yet | Issue BC-8731 (per CLAUDE.md project memory) or a sibling tracks template authorship in the handbook. If missing, ship with inline fallback only and file a follow-up. |
| Slug collision auto-suffix recursion could loop on rapid same-month re-runs | Cap at `-v9`; abort with a clear error and require operator to pass an explicit `--slug` override. |

## Verification

Validation criteria from the issue:

- [ ] Command file at `plugins/marketing/commands/plan-campaign.md` with valid frontmatter declaring all `allowed-tools` per Task 1.
- [ ] Dry-run on a valid Municipalities tuple (e.g., `parks-rec-director × parks-bond × M05`) prints a coherent plan and exits without writing anything.
- [ ] `--entity cross-entity --theme america-250 --month 5 --year 2026` produces slug `cross-entity-america-250-fy26-m05`.
- [ ] `--entity cross-entity` without `--theme` errors clearly.
- [ ] `--situation-mining` on a non-Labs entity errors clearly.
- [ ] `--situation-mining` on Labs adds 9th sub-issue.
- [ ] Slug collision auto-suffixes `-v2` with operator confirmation prompt.
- [ ] Plugin version bumped in plugin.json + marketplace.json.
- [ ] Test harness passes (`bash plugins/marketing/tests/test_plan_campaign_dry_run.sh`).
- [ ] `./scripts/validate.sh` passes.

Real-run validation (manifest schema completeness, sub-issue blockedBy chain, SF auto-create) deferred to BC-8727 dogfood.

## Estimate

~6-8 hours of focused work:

- Tasks 1-2: 0.5h (frontmatter + Step 1 spec)
- Tasks 3-7: 2h (Steps 2-6 spec + collision logic)
- Task 8: 0.5h (manifest.json schema spec)
- Tasks 9-10: 1.5h (Linear milestone + SF Skill-tool composition spec)
- Tasks 11-12: 1.5h (sub-issue chain + optional sub-issues spec)
- Tasks 13-14: 0.5h (summary + version bump)
- Task 15: 1-1.5h (shell test harness — 7 scenarios)
- Task 16: 0.5h (doc updates)
- Task 17: 0.5h (validate + review + commit)
