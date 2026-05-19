# 015. GTM σ3 — Salesforce Campaign auto-create + status sync via revops plugin commands

**Status:** Accepted (2026-05-13); **amended 2026-05-19** — implementation surface respec'd from MCP write tools to slash commands; design intent unchanged.
**Date:** 2026-05-13 / amended 2026-05-19
**Linear:** [BC-8717](https://linear.app/brite-nites/issue/BC-8717) (`/revops:create-sf-campaign`), [BC-8723](https://linear.app/brite-nites/issue/BC-8723) (`/revops:update-sf-campaign-status`), [BC-8752](https://linear.app/brite-nites/issue/BC-8752) (trigger automation)
**Related ADRs:** [ADR-007](007-revops-plugin-design.md), [ADR-013](013-gtm-three-layer-split.md), [ADR-014](014-gtm-salesforce-portfolio-rollup.md)
**Companion docs:** [`docs/gtm-campaign-orchestration-README.md`](../gtm-campaign-orchestration-README.md) §3 (SF box) + §3.6 (worked example Step 7), [`docs/designs/gtm-campaign-orchestration-design.md`](../designs/gtm-campaign-orchestration-design.md) §7.5 + §7.8

## Context

The D4 sub-issue template (per ADR-012 + design doc Section 2) has sub-issue #4 "Salesforce setup" — historically a manual step where Corinne logged into SF and created the Campaign record by hand. Manual-step-often-forgotten was a known failure mode.

After ADR-014 (SF = portfolio rollup home), accurate SF state became load-bearing: missing SF Campaign records mean missing rollup rows. The original O11 question (Salesforce vs Linear orchestration) resolved to **σ3** — keep ADR-013's 3-layer split, but automate the SF Campaign create + status sync.

## Decision Drivers

- **Manual sub-issue #4 was high-defect** — every forgotten SF Campaign created portfolio rollup gaps.
- **revops:salesforce MCP** (per ADR-007) already exists with run_soql_query + metadata-deploy + run_apex_test (read-only / metadata surfaces). Per-record writes are NOT served by upstream `@salesforce/mcp@0.30.5` (Salesforce-published npm package) — adding write tools to that namespace would require a new Brite-owned MCP server. With only two write surfaces in scope (T2-E + T2-F), slash commands sit below the threshold where a fresh MCP server earns its boilerplate.
- **Soft-fail required** — SF write failure cannot halt `/marketing:plan-campaign` (BC-8724); operator must be able to scaffold even when SF is down (manifest gets `campaign_id: null`).
- **Status transitions must auto-fire** — sub-issue 6 close → SF "In Progress"; sub-issue 8 close → SF "Completed". Operators forget manual status flips; portfolio rollup needs accurate state.
- **`paused` overlay** doesn't fit in SF's single-valued Status field — requires a custom `Substatus__c` field.

## Decision

**σ3 = auto-create SF Campaign at scaffold time + auto-sync status on Linear transitions**, via two new slash commands in the revops plugin (each calling upstream `mcp__plugin_revops_salesforce__run_soql_query` for prechecks + `sf` CLI via Bash for the write):

### 1. `/revops:create-sf-campaign --slug --entity --vertical --persona --offer --year --month --owner-email --launch-date [--target-org] [--dry-run]`

Creates SF Campaign with `Name=slug`, `Vertical__c`, `Persona__c`, `Offer__c`, `Entity__c`, `Status="Planned"`, `StartDate=launch_date`, `OwnerId` from owner_email lookup. Called by `/marketing:plan-campaign` Step 7b (BC-8724) via the Skill tool. Returns single-line `{ campaign_id, campaign_url, campaign_name }` JSON on stdout for manifest.json. Soft-fails (exit 0 with structured `{ error: "..." }` JSON) on duplicate slug, missing owner, invalid slug format, missing required flag, or `sf` CLI error.

### 2. `/revops:update-sf-campaign-status --slug --linear-status --linear-substatus`

Looks up SF Campaign by `Name=slug`. Maps Linear status → SF Campaign Status per the locked table:

| Linear label | SF Campaign Status | SF Substatus__c |
|---|---|---|
| `planning` | Planned | — |
| `active` | In Progress | — |
| `active` + `paused` | In Progress | Paused |
| `completed` | Completed | — |
| `killed` | Aborted | — |

Soft-fails (returns `warning: campaign_not_found`) when SF Campaign doesn't exist.

### 3. Trigger automation (BC-8752 / T2-FA, audit-fix)

Without trigger wiring, the slash command from #2 only fires on manual operator invocation — defeating σ3's intent. BC-8752 wires:

- `launch-campaign` final phase → `/revops:update-sf-campaign-status --slug=<slug> --linear-status=active` after EB launch
- `campaign-debrief` Workflow 4 (post-append) → `/revops:update-sf-campaign-status --slug=<slug> --linear-status=completed`
- `/marketing:sync-campaign-status` new command for manual `paused` / `killed` triggers (which don't auto-fire from sub-issue closes)

### 4. New SF custom field

`Substatus__c` (picklist `{null, Paused}`) — required because SF Status is single-valued and the O1 `paused` label is a stackable overlay on `active`.

## Consequences

- Sub-issue #4 ("Salesforce setup") redefined: post-σ3 it's SF Campaign reconciliation (verify auto-create succeeded) + audience members (CampaignMember records linked from EB lead suppress export) + Opportunity links. Not the creation step anymore.
- Plugin command surface gains `/marketing:sync-campaign-status` as the manual-trigger fallback for paused/killed transitions.
- `learnings.md` regen path (in `campaign-debrief`) gains a status-sync call after the append.
- Plugin filesystem (`manifest.json`) carries `salesforce.campaign_id` as the cross-system identity anchor.
- ADR-014's portfolio rollup depends on accurate SF state; σ3 is the upstream mechanism that delivers it.

## Alternatives Considered

| Alternative | Rejected because |
|---|---|
| Keep sub-issue #4 manual (no σ3) | Manual step is high-defect; missing SF Campaigns break ADR-014 rollup |
| Linear webhook → SF status sync (no plugin call sites) | Webhook infrastructure doesn't exist; adds runtime dep that's harder to reason about than skill-call-site triggers |
| Single mega-command `/revops:sync-sf-campaign` instead of create + update separately | Creates ambiguity about idempotency (insert vs update); two commands have crisper semantics |
| Skip Substatus__c, use prose in Description field | Not filterable in SF list views; ADR-014's "include paused, exclude killed" filter would have no field to query |
| **Add `create_sf_campaign` + `update_sf_campaign_status` as MCP write tools** (original ADR-015 framing, 2026-05-13) | `mcp__plugin_revops_salesforce__*` is upstream `@salesforce/mcp@0.30.5` (Salesforce-published npm package) — Brite cannot extend it without forking. Two write surfaces is below the ~5-tool threshold where a Brite-owned MCP server earns its boilerplate. Slash commands compose naturally with `/marketing:plan-campaign` via the Skill tool. Respec'd 2026-05-19. |
| Stand up a new Brite-owned `revops:campaign` MCP server | L-sized + rename cascade for two write tools; below the threshold. Path 1 above. |

## Cross-references

- README §3.6 — worked example Step 7 (SF auto-create at scaffold)
- README §7 — Tier 2 BCs in critical path
- Design doc §7.5 — σ3 lock
- Design doc §7.8 — σ3 scope expansion + status mapping table
- ADR-014 — the consumer of σ3's outputs
