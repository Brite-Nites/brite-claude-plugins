# 015. GTM σ3 — Salesforce Campaign auto-create + status sync via revops plugin commands

**Status:** Accepted (2026-05-13); **amended 2026-05-19** — implementation surface respec'd from MCP write tools to slash commands; design intent unchanged. **Amended 2026-05-22** — σ3 sibling-parity backport pattern locked across both SF-write commands (BC-10510 + BC-10511).
**Date:** 2026-05-13 / amended 2026-05-19 / amended 2026-05-22
**Linear:** [BC-8717](https://linear.app/brite-nites/issue/BC-8717) (`/revops:create-sf-campaign`), [BC-8723](https://linear.app/brite-nites/issue/BC-8723) (`/revops:update-sf-campaign-status`), [BC-8752](https://linear.app/brite-nites/issue/BC-8752) (trigger automation), [BC-10510](https://linear.app/brite-nites/issue/BC-10510) (Phase 0 cache backport), [BC-10511](https://linear.app/brite-nites/issue/BC-10511) (`--target-org` regex backport)
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

## Amendment 2026-05-22 — σ3 sibling-parity backport pattern (BC-10510 + BC-10511)

Two patterns introduced by `/revops:update-sf-campaign-status` (BC-8723, shipped 2026-05-19 via PR #331) are backported to `/revops:create-sf-campaign` so both σ3 SF-write commands behave identically on metadata resolution and input validation. The amendment locks the patterns as canonical: both commands MUST share them, and any future σ3 SF-write sibling MUST adopt them.

### Pattern 1 — Phase 0 metadata cache (BC-10510)

Both commands call `sf org display --target-org <target-org> --json` EXACTLY ONCE at command start (skipping only on `--dry-run`). The response's `.result.username` and `.result.instanceUrl` are cached for the lifetime of the invocation. Downstream phases consume the cache:

- `<sf-username>` → Phase 2 + Phase 3 MCP `run_soql_query` calls (the upstream MCP rejects aliases — see `memory/gotcha_sf_mcp_username_not_alias.md`)
- `<instance-url>` → success-URL construction (avoids a second metadata round-trip)

The single-call contract collapses 2+ metadata fetches into 1 (saves ~200ms per σ3 fire). It is auditable: a contract test asserts `body.count("sf org display") == 1` (count-based per BC-8729 round-2 review pattern, NOT substring-absence — per `memory/gotcha_soql_substring_absence_assertions_fragile.md`).

If Phase 0's `sf org display` itself fails, no separate error is emitted — Phase 2/3 calls surface as the existing `sf_cli_error` path, and Phase 6 falls back to the deterministic instanceless URL placeholder with `warning: instance_url_unknown`. The cache is a soft optimization, not a precondition.

### Pattern 2 — `--target-org` regex shell-injection guard (BC-10511)

Both commands validate `--target-org` (when explicitly supplied) against regex `^[a-zA-Z0-9._@-]+$` (SF org alias / username character set) at Phase 1, before any shell-out. Mismatch emits `{"error":"invalid_target_org","value":"<value>"}` exit 0 — soft-fail per the σ3 contract.

The character class is deliberately tight: blocks shell metacharacters (`$`, backticks, `;`, `&`, `|`, `>`, `<`, quotes, whitespace, parentheses) while accepting every character SF aliases and usernames legitimately use (alphanumerics, dot, underscore, at, hyphen). `--target-org` flows into `sf` CLI invocations in Phase 0 + Phase 5 + (pre-backport) Phase 6, so the guard is a defense-in-depth for shell-injection.

### Audit invariants (contract-tested in `plugins/revops/tests/test_create_sf_campaign_contracts.py`)

1. Phase 0 section header present + both cache variables (`<sf-username>`, `<instance-url>`) documented verbatim
2. EXACTLY one `sf org display` invocation in the command body (count-based)
3. `--target-org` regex appears verbatim in the command body
4. `--target-org` regex is **byte-identical** to the sibling `/revops:update-sf-campaign-status` regex — sibling drift surfaces immediately on either side's test run
5. `invalid_target_org` appears in the soft-fail error-key roster (6 keys total now: `missing_required_flag`, `invalid_slug_format`, `invalid_target_org`, `duplicate_slug`, `missing_owner`, `sf_cli_error`)

The byte-identity test (#4) is the canonical lock: a unilateral edit to one sibling's regex fails the OTHER sibling's test — neither command can drift in isolation. Identical contract tests live in `test_update_sf_campaign_status_contracts.py`.

### Future σ3 sibling #3

If a third σ3 SF-write command is added, it MUST:

- Adopt Pattern 1 (Phase 0 metadata cache, single `sf org display` invocation).
- Adopt Pattern 2 (`--target-org` regex with the same character class).
- Add a byte-identity contract test against this canonical pair.
- Be listed in this amendment's Linear refs.

The ~5-tool threshold (per the 2026-05-19 amendment for when a Brite-owned MCP server earns its boilerplate) still bounds the slash-commands-vs-MCP-server decision — but inside the slash-commands choice, σ3 siblings MUST be uniform.

## Cross-references

- README §3.6 — worked example Step 7 (SF auto-create at scaffold)
- README §7 — Tier 2 BCs in critical path
- Design doc §7.5 — σ3 lock
- Design doc §7.8 — σ3 scope expansion + status mapping table
- ADR-014 — the consumer of σ3's outputs
- `memory/gotcha_sf_mcp_username_not_alias.md` — the upstream constraint Pattern 1 routes around
- `memory/gotcha_soql_substring_absence_assertions_fragile.md` — why audit invariant #2 is count-based, not absence-based
- `memory/session_bc_8723.md` — full session log of the BC-8723 ship that established the patterns being backported here
