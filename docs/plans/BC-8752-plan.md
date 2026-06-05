# BC-8752 — Wire σ3 status-sync triggers — Plan

**Issue**: [BC-8752](https://linear.app/brite-nites/issue/BC-8752) — Tier 2 — revops:salesforce MCP writes (call-site wiring)
**Branch**: `holden/bc-8752-status-sync-triggers` (worktree at `.claude/worktrees/bc-8752/`)
**Blocked by**: BC-8723 ✓ (PR #331), BC-8724 ✓ (PR #333)
**Blocks**: BC-8731 (portfolio-snapshot)

## Goal

Wire the σ3 SF Campaign status sync to fire automatically as the launch/debrief flow progresses, plus a manual fallback for paused/killed Linear label transitions.

| Trigger | Calls /revops:update-sf-campaign-status with |
|---|---|
| sub-issue 6 close (Launch executed) = launch-campaign Phase 11 ACTIVATE success | `--linear-status=active` → SF "In Progress" |
| sub-issue 8 close (Campaign closed + debrief) = campaign-debrief Workflow 4 append success | `--linear-status=completed` → SF "Completed" |
| operator runs `/marketing:sync-campaign-status --status=killed` | `--linear-status=killed` → SF "Aborted" |
| operator runs `/marketing:sync-campaign-status --status=active --substatus=paused` | `--linear-status=active --linear-substatus=paused` → SF Substatus__c="Paused" |

## Respec note

The issue body references calling `mcp__plugin_revops_salesforce__update_sf_campaign_status`. **That MCP tool no longer exists** — BC-8723 was respec'd 2026-05-19 to a slash command (`/revops:update-sf-campaign-status`) because the upstream `@salesforce/mcp` package isn't Brite-owned. The session-memory entry `session_bc_8724.md` captures the same respec pattern: orchestrators compose `/revops:*` commands via the `Skill` tool. This plan follows that pattern; the issue body's MCP-tool wording is stale.

## Slug resolution: the manifest

Both launch-campaign and campaign-debrief need a `<slug>` to pass to `/revops:update-sf-campaign-status`. The slug lives in the GTM manifest authored by `/marketing:plan-campaign` (Step 7) at:

```
docs/campaigns/<entity>/<slug>/manifest.json   ← .slug field is the canonical source
```

**Convention**: the `--campaign-name` flag passed to `/marketing:launch-campaign` (and the `{campaign-name}` Gate 4 answer in campaign-debrief) is THE slug — that's how plan-campaign feeds them. So the lookup is:

```
docs/campaigns/<entity>/<campaign-name>/manifest.json
```

**Soft-fail on missing manifest**: legacy / standalone launches (no prior plan-campaign scaffold) won't have a manifest. In that case the SF sync silently skips with a stderr note — the launch/debrief continues. This preserves backward compat for tests that use synthetic campaign-name like `test-spring-promo` without GTM scaffold.

## Files to change

| File | Change | Step |
|---|---|---|
| `plugins/marketing/commands/launch-campaign.md` | Add Phase 11 step 7 (SF sync) + frontmatter `allowed-tools` `Skill` | 1 |
| `plugins/marketing/skills/campaign-debrief/SKILL.md` | Add Workflow 4 step 5 (SF sync) + frontmatter `allowed-tools` `Skill` | 2 |
| `plugins/marketing/commands/sync-campaign-status.md` | NEW — operator-facing wrapper for paused/killed manual trigger | 3 |
| `plugins/marketing/commands/plan-campaign.md` | Verify Step 11.2 already has guidance (it does — line 851-852, BC-8724 pre-wired); no-op | 4 |
| `plugins/marketing/.claude-plugin/plugin.json` | `0.3.39` → `0.3.40` | 5 |
| `.claude-plugin/marketplace.json` | matching marketing entry `0.3.39` → `0.3.40` | 5 |

## Implementation steps

### Step 1 — launch-campaign Phase 11 SF sync

Insert a new step between current step 6 (Finalize metadata) and step 7 (Final report) — making the existing step 7 become step 8. Place the new step inside `### Steps` block, after the metadata-finalization paragraph (line 965), before the final operator report (line 966).

**New step 7 text** (added under `### Steps`):

```markdown
7. **Sync Salesforce Campaign status to "In Progress" (soft-fail).** After `activated: true` is finalized, mirror the new active state into SF via `/revops:update-sf-campaign-status`. Only fires when every campaign activated cleanly (global `activated: true`); on partial-success (`activated: false`), the operator will reconcile manually via `/marketing:sync-campaign-status` after fixing the un-activated buckets.

   1. Try `Read` `docs/campaigns/<entity>/<campaign-name>/manifest.json`. If the file does not exist OR JSON parse fails OR `.slug` is absent, log a single line to stderr — `[BC-8752] No GTM manifest for "<campaign-name>"; skipping σ3 SF sync (standalone launch — no plan-campaign scaffold).` — and continue to step 8. This is the standalone-launch fall-through path; no Linear or SF Campaign record is expected to exist.
   2. Extract `<slug>` from `manifest.slug`. Invoke the sibling slash command:

      ```
      Skill(
        skill: "revops:update-sf-campaign-status",
        args: "--slug=<slug> --linear-status=active"
      )
      ```

   3. Parse the single-line JSON returned on stdout. Cases:
      - `{"campaign_id":"<id>", ...}` (success or noop) → log `[BC-8752] SF Campaign synced: <slug> → In Progress (campaign_id=<id>).` Continue to step 8.
      - `{"warning":"campaign_not_found", ...}` → log `[BC-8752] SF Campaign for slug "<slug>" not found — σ3 auto-create at plan-campaign Step 8b may have failed. Reconcile via /revops:create-sf-campaign then re-run /marketing:sync-campaign-status --slug=<slug> --status=active.` Continue to step 8.
      - `{"error":"<kind>", ...}` → log `[BC-8752] σ3 sync soft-fail: <kind>. Detail: <stringified error>. Launch succeeded; SF status is stale until reconciliation.` Continue to step 8.
   4. The σ3 sync is **soft-fail**: no SF response — success, warning, or error — halts the launch flow. Phase 11 success is owned by EB activation, not by SF mirroring.
```

Then renumber the existing "step 7 Final report" → step 8 (single mechanical renumber inside the `### Steps` block).

**Frontmatter change** (line 4):

```diff
-allowed-tools: mcp__emailbison-b2b__*, mcp__emailbison-personal__*, mcp__plugin_marketing_salesforce__*, Read, Write, Glob, Grep, Bash, AskUserQuestion
+allowed-tools: mcp__emailbison-b2b__*, mcp__emailbison-personal__*, mcp__plugin_marketing_salesforce__*, Read, Write, Glob, Grep, Bash, AskUserQuestion, Skill
```

**Verification checklist update** (line 1021): add the `Skill` mention so the in-file checklist stays in sync.

### Step 2 — campaign-debrief Workflow 4 SF sync

Insert a new step 5 in Workflow 4 (currently 4 steps; lines 305-312), after "Write full file":

**New step 5 text**:

```markdown
5. **Sync Salesforce Campaign status to "Completed" (soft-fail).** After the learnings.md append succeeds, mirror the closed state into SF via `/revops:update-sf-campaign-status`. This fires the σ3 trigger for sub-issue 8 close per BC-8752.
   1. Try `Read` `docs/campaigns/{entity}/{campaign-name}/manifest.json`. If the file does not exist OR JSON parse fails OR `.slug` is absent, log to stderr `[BC-8752] No GTM manifest for "{campaign-name}"; skipping σ3 SF sync (retroactive / no plan-campaign scaffold).` and exit Workflow 4 normally. The append already landed; SF sync is the optional secondary effect.
   2. Extract `<slug>` from `manifest.slug` and invoke:

      ```
      Skill(
        skill: "revops:update-sf-campaign-status",
        args: "--slug=<slug> --linear-status=completed"
      )
      ```

   3. Parse the single-line JSON. Cases mirror the launch-campaign Phase 11 step 7 fan-out:
      - success / noop (`campaign_id` present) → log `[BC-8752] SF Campaign synced: <slug> → Completed.`
      - `warning: campaign_not_found` → log the reconciliation reminder.
      - `error: *` → log the soft-fail detail.
   4. Soft-fail invariant: no SF response halts the debrief. The learnings.md entry IS the source of truth for the marketing flywheel; SF mirroring is downstream cosmetic state.
```

**Frontmatter change** (line 5):

```diff
-allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Glob, Grep
+allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__emailbison-b2b__*, mcp__emailbison-personal__*, Read, Write, Glob, Grep, Skill
```

**Tools-this-skill-calls table** (line 132-138): add a row at the bottom:

```markdown
| Sync SF Campaign status (post-append, σ3) | `Skill` → `/revops:update-sf-campaign-status` | Local plugin (soft-fail) | BC-8752 |
```

### Step 3 — NEW `plugins/marketing/commands/sync-campaign-status.md`

Operator-facing wrapper. Thin pass-through to `/revops:update-sf-campaign-status` with marketing-friendly flag names. Required for the manual paused/killed paths that don't auto-fire from sub-issue closes.

**File contents** (≈100 lines):

- **Frontmatter**: `description`, `argument-hint: --slug <slug> --status <planning|active|completed|killed> [--substatus <paused>]`, `allowed-tools: Read, Skill`.
- **Body sections**:
  - **Purpose**: when to run this manually (paused/killed label toggles, retroactive sync after σ3 soft-fail).
  - **Flags**: `--slug` (required, no regex check — defer to /revops command's Phase 1 validation), `--status` (∈ {planning, active, completed, killed}), `--substatus` (∈ {paused}, optional, only valid with `--status=active`).
  - **Flag validation**: hard-fail at parse time if `--status` is not in the four-value set OR `--substatus` is provided without `--status=active`. Echo what was got vs expected. Soft-fail philosophy applies to runtime errors only, not flag-parse errors.
  - **Mapping**: `--status` → `--linear-status`; `--substatus` → `--linear-substatus`. Pass through unchanged.
  - **Invocation**: `Skill(skill: "revops:update-sf-campaign-status", args: "--slug=<slug> --linear-status=<status>[ --linear-substatus=<substatus>]")`.
  - **Output**: render the response JSON in operator-readable form — `success: campaign <id> now Status=<sf-status> Substatus=<sf-substatus>` / `warning: ...` / `error: ...`. Exit 0 in every case (the underlying revops command also exits 0; this wrapper preserves that contract).
  - **Idempotency note**: cite the underlying command's Phase 5 noop short-circuit — repeated calls with the same target state are cheap noops.
  - **When to use vs auto-trigger**: explain that sub-issue 6 close auto-fires `--status=active` via launch-campaign; sub-issue 8 close auto-fires `--status=completed` via campaign-debrief; this command exists for paused/killed (no sub-issue triggers those) AND for retroactive reconciliation after a σ3 soft-fail.

### Step 4 — plan-campaign Step 11.2 — verify no-op

Already in the file (line 846-853), authored as part of BC-8724:

> When toggling `status:paused` or `status:killed` labels on the milestone, run `/marketing:sync-campaign-status` (T2-FA) manually — those are NOT auto-triggered.

Confirm the exact text is still present after Step 1/2/3 edits (none of which touch plan-campaign.md). No file edit required.

### Step 5 — Plugin version bump

Bump `plugins/marketing/.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json` `marketing` entry from `0.3.39` → `0.3.40` in the same commit (per CLAUDE.md plugin-cache gotcha). Single atomic commit with all file edits.

### Step 6 — Validate

Run from the worktree root:

```bash
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```

Both must exit 0.

## Validation criteria mapping (issue body → this plan)

| Issue AC | Plan step |
|---|---|
| Launch-campaign final phase fires → SF "In Progress" within 10s | Step 1 |
| Campaign-debrief Workflow 4 → SF "Completed" | Step 2 |
| `/marketing:sync-campaign-status --status=active --substatus=paused` → Substatus=Paused | Step 3 |
| `--status=killed` → Status="Aborted" | Step 3 |
| All four O6.Q1 mapping rows exercised | Steps 1+2+3 collectively |
| Soft-fail when SF Campaign doesn't exist (warning, no halt) | Steps 1+2 step-fan-outs |
| Plugin version bumped in both manifests | Step 5 |

## Out of scope

- The MCP-tool path in the issue body is dead (BC-8723 respec'd to slash command). Not implementing.
- Live SF integration test (requires `brite-sandbox` access + a real Campaign record). The `--dry-run` flag in `/revops:update-sf-campaign-status` provides static verification; live test is a separate post-merge dogfood (BC-8727 cohort-1).
- portfolio-snapshot (BC-8731) — separate issue; this BC unblocks it but does not implement it.
- Behavioral tests for sync-campaign-status — small enough that the in-line flag-validation rules + the underlying revops command's full test suite cover it. Add iff /workflows:review flags coverage gap.

## Risk + mitigation

| Risk | Mitigation |
|---|---|
| Manifest path convention mismatch (launch-campaign `--campaign-name` ≠ slug) | Soft-fail to skip; legacy launches keep working. Plan-campaign authors the manifest under slug, and slug IS what operators pass as `--campaign-name`. |
| Skill invocation pattern wrong (`revops:` vs `/revops:`) | Match plan-campaign line 568 verbatim — that's the proven pattern from BC-8724. |
| Concurrent edit on launch-campaign by another iter-3 branch | Worktree off main isolates; rebase before push. |
| sync-campaign-status overlaps semantically with /revops:update-sf-campaign-status | Documented in sync-campaign-status body: "wraps with operator-friendly flags". The /revops command is the orchestrator-facing surface; /marketing is the operator-facing surface. |

## Task list (10 tasks)

1. Worktree setup (done — branch `holden/bc-8752-status-sync-triggers` off origin/main)
2. Step 1 — edit launch-campaign Phase 11
3. Step 2 — edit campaign-debrief Workflow 4
4. Step 3 — author sync-campaign-status.md
5. Step 4 — verify plan-campaign Step 11.2 unchanged
6. Step 5 — bump plugin.json + marketplace.json
7. Run validate.sh
8. Run check-guardrails.sh
9. Stage commit + verify diff
10. Hand off to /workflows:review
