# Outbound Agent Architecture — ADRs

**Issue:** BC-5041 (Phase 2 of outbound agent architecture)
**Status:** Draft — human review at PR
**Date:** 2026-04-12
**Blocked by:** BC-5040 (Phase 1 validation — Done, PR #115)
**Blocks:** BC-5042 (Phase 3 — design doc, template, findings)
**Pre-resolved:** ADR 2c ratifies PR #116's pattern and adds a degradation policy (no fallback to curl when MCP is unreachable)

---

## ADR 2a. MCP Server Adoption Strategy

### Decision

Adopt **Email Bison** and **Salesforce** MCP servers into the marketing plugin. Defer Apollo and Resend. Skip Smartlead. Use `${ENV_VAR}` substitution in committed `.mcp.json` for credential storage.

### Context

The marketing plugin needs to connect outbound skills to external services — but which services get MCP slots (budget: ~5–6 per plugin), and how do credentials flow?

BC-5040 (Phase 1, PR #115) validated 8 MCP servers. Key findings:

- **Email Bison:** Official vendor-hosted MCP (Beta) at `mcp.emailbison.com/mcp` with 141 tools across 16 categories. Full CRUD including blocklist management (8 tools), campaign lifecycle (21 tools), lead import (15 tools). Both Brite workspaces verified: `emailbison-b2b` (send.outbase.so) and `emailbison-personal` (personal.outbase.so). Integration guide already shipped at `plugins/marketing/tools/integrations/email-bison.md` (PR #116).
- **Salesforce:** Official `@salesforce/mcp` with 120+ tools across 14 toolsets. 348 stars, last commit 2026-04-03. SFDX CLI auth. Many tools non-GA (require `--allow-non-ga-tools`). Salesforce is Brite's CRM SoR (migration from HubSpot complete per BC-5040 §1b).
- **Apollo:** Official `apolloio/apollo-mcp-plugin` with only 4 tools. 8 stars, early stage. Brite's enrichment pipeline uses Apollo's REST API directly via `brite-data-platform` — the MCP adds marginal value.
- **Smartlead:** Community `LeadMagic/smartlead-mcp-server` with ~112 tools. Brite has never used Smartlead — it's listed in the handbook only as a market alternative. Last commit 2025-07-02 (9+ months stale).
- **Resend:** Official `resend/resend-mcp` with 10+ tool categories. 492 stars. No outbound skill currently needs transactional email.

### Alternatives considered

**Alternative 1: Adopt all 5 available servers immediately.**
- Pros: Maximum coverage from day one. Skills can reference any tool without waiting.
- Cons: Blows the ~5–6 per-plugin budget immediately. Apollo (4 tools) and Resend (no current consumer) waste slots. Smartlead is stale and unused. More auth flows to configure per developer.
- Rejected because: MCP slots are a budget, not a buffet. Unused servers consume startup latency and context for zero return.

**Alternative 2: Adopt only Email Bison, defer everything else.**
- Pros: Minimum surface area. Only commit to the one server we've already validated end-to-end.
- Cons: Salesforce is the CRM SoR — every skill that reads lifecycle state or writes contact updates needs it. Deferring Salesforce blocks BC-2720 (reply-processing), BC-2725 (lead-routing), and BC-2722 (outbound-playbook).
- Rejected because: Salesforce is too central to defer. Two skills (reply-processing, lead-routing) can't be built without CRM access.

**Alternative 3 (recommended): Adopt Email Bison + Salesforce, defer Apollo + Resend, skip Smartlead.**
- Pros: Two high-value servers that together cover the sending layer + CRM layer — the two layers every outbound skill touches. 2 of ~6 slots used, leaving room for 3–4 future additions. Apollo and Resend can be adopted later when a skill actually needs them.
- Cons: Skills that need Apollo enrichment data must use the cross-repo pattern (ADR 2d) to reach `brite-data-platform` instead of calling Apollo MCP directly. Adds indirection.
- Accepted because: Covers the critical path (send + CRM) without wasting budget on tools with no current consumer.

### Outcome (if adopted)

- `plugins/marketing/.mcp.json` gains 2 server entries (Email Bison b2b + personal = 2 logical servers on 1 vendor, Salesforce = 1 server). Total: 3 entries against a ~6 budget.
- Each entry uses `${ENV_VAR}` substitution for credentials (see credential pattern below).
- Integration guides required: `email-bison.md` (already merged), `salesforce.md` (new — write alongside the first skill that consumes it, not speculatively).
- Apollo stays in `brite-data-platform` via REST. No MCP registration here.
- Smartlead never enters the picture.
- Resend adopts later if a marketing-ops or notification skill lands.

### Credential pattern

```json
{
  "mcpServers": {
    "emailbison-b2b": {
      "type": "http",
      "url": "https://mcp.emailbison.com/mcp",
      "headers": {
        "Authorization": "Bearer ${EMAILBISON_B2B_TOKEN}",
        "Instance-URL": "https://send.outbase.so"
      }
    },
    "emailbison-personal": {
      "type": "http",
      "url": "https://mcp.emailbison.com/mcp",
      "headers": {
        "Authorization": "Bearer ${EMAILBISON_PERSONAL_TOKEN}",
        "Instance-URL": "https://personal.outbase.so"
      }
    },
    "salesforce": {
      "command": "npx",
      "args": ["-y", "@salesforce/mcp@latest"],
      "env": {
        "SALESFORCE_INSTANCE_URL": "${SALESFORCE_INSTANCE_URL}"
      }
    }
  }
}
```

**Developer setup:** Each developer sets env vars in their shell profile. The plugin README documents required vars per server. This is the simplest pattern that works today. If Claude Code ships native secret management, we upgrade — the `${VAR}` form is forward-compatible.

**Graceful degradation:** Skills include a "check availability" step that calls a lightweight read-only tool before mutating anything. Canonical per-server tools: `get_active_workspace_info` for Email Bison; `run_soql_query` with a trivial SOQL (`SELECT Id FROM User LIMIT 1`) for Salesforce (per [BC-5534 findings §Q1](../research/salesforce-mcp-findings.md#q1-availability-check-tool) — `get_username` is rejected because it reads the local SFDX auth store without contacting Salesforce and returns a stale username after the access token expires). If the check fails, the skill reports the failure and stops — no fallback to `Bash(curl)`.

### Recommendation

Adopt Email Bison (official, 141 tools, both workspaces) and Salesforce (official, ~80 tools across 15 toolsets, CRM SoR) into `plugins/marketing/.mcp.json`. Email Bison uses `${ENV_VAR}` credential substitution; Salesforce uses the `DEFAULT_TARGET_ORG` sentinel + local SFDX auth store (no env vars — see [BC-5534 findings §Q4](../research/salesforce-mcp-findings.md#q4-credential-storage)). Defer Apollo and Resend until a skill needs them. Skip Smartlead entirely — Brite has never used it and the MCP is stale.

### Review notes

- Is `${ENV_VAR}` substitution in committed `.mcp.json` sufficient, or should we evaluate Claude Code's project-scoped `.env` support before committing to this pattern?
- Should we register Salesforce now (in this PR) or defer until the first skill that consumes it (e.g. BC-2720 reply-processing)?
- Is the Apollo deferral correct given the enrichment pipeline lives in `brite-data-platform`, not this plugin repo?
- The Salesforce MCP has many non-GA tools. Should we pin to GA-only toolsets, or accept the risk of depending on non-GA tools for SOQL queries and CRUD?
- Email Bison is still in Beta. Should we add a version-pinning strategy or accept that tool names may change?

---

## ADR 2b. Custom MCP Server Strategy

### Decision

Do not build custom MCP servers for OutboundSync or Master Inbox. Use existing Cloud Functions as the integration layer for OutboundSync, and the official Email Bison MCP for Master Inbox. Defer the enrichment engine MCP wrapper to `brite-data-platform` ownership.

### Context

BC-5040 §8 confirmed two gaps: OutboundSync and Master Inbox have no MCP servers. The question is whether to build custom ones, build CLI wrappers, use existing infrastructure, or wait for vendors.

Key validated facts:
- **OutboundSync** is a webhook-based sync layer — it receives events from Email Bison and writes to Salesforce. There is no user-facing API to wrap. The `outbound-sales-ops` Cloud Functions (`label-sync`, `reply-notification`, `message-router`) mediate all writes.
- **Master Inbox** is an Email Bison feature — the official Email Bison MCP's 13 inbox/reply tools (`list_replies`, `search_replies`, `send_reply`, `get_reply`, `get_replies_analytics`, etc.) cover the read/write surface a skill would need.
- **Brite enrichment engine** has a real CLI (`python -m enrichment.cli`, 9 commands, 14 providers) with non-Claude callers (CI, cron). But it lives in `brite-data-platform`, not this plugin repo.

### Alternatives considered

**Alternative 1: Build custom MCP servers for OutboundSync and Master Inbox.**
- Pros: Skills get a clean, dedicated tool surface for each tool. Full control over the API shape.
- Cons: OutboundSync has no API to wrap — it's a webhook receiver, not a queryable service. Building a custom MCP means also building a new API layer in front of the CFs, which is significant new infrastructure. Master Inbox's MCP surface is already covered by Email Bison's official server. Maintenance burden of 2 custom MCP servers with auth, versioning, and testing.
- Rejected because: OutboundSync is architecturally a mediator, not a service — wrapping it in an MCP is fighting the architecture. Master Inbox's MCP is already built by the vendor.

**Alternative 2: Build CLI wrappers for both.**
- Pros: Lighter than a full MCP. Skills call Bash(cli) as a fallback.
- Cons: CLI wrappers bypass the `allowed-tools` pattern — skills would need `Bash(cli:*)` permissions, violating anti-pattern #3 from the pattern guide. No non-Claude callers exist for either tool in this repo (the enrichment CLI has them, but OutboundSync and Master Inbox don't).
- Rejected because: MCP-first is the default (ADR 2a). CLI wrappers only when you can name a non-Claude caller. Neither OutboundSync nor Master Inbox has one.

**Alternative 3: Wait for vendors to build MCP servers.**
- Pros: Zero maintenance on our side. Vendor MCPs are more likely to stay current.
- Cons: No vendor MCP is on any public roadmap for OutboundSync or Master Inbox. OutboundSync is a Brite-built integration, not a vendor product — no one else will build an MCP for it. Master Inbox is already covered by Email Bison MCP.
- Rejected because: Waiting for an OutboundSync MCP from a vendor that doesn't exist is indefinite deferral. And the Master Inbox MCP already exists inside Email Bison.

**Alternative 4 (recommended): Use existing CFs for OutboundSync, Email Bison MCP for Master Inbox, defer enrichment.**
- Pros: Zero new infrastructure. OutboundSync's CFs already mediate all writes — a skill that needs to "sync a reply to Salesforce" lets the webhook pipeline handle it. A skill that needs to "read replies" or "manage blocklist" calls Email Bison MCP directly. The enrichment engine stays in `brite-data-platform` and is accessed via GitHub MCP (ADR 2d).
- Cons: Skills can't trigger an OutboundSync "re-sync" on demand — they must wait for the webhook pipeline. If a skill needs to force a sync, there's no tool to call.
- Accepted because: Matches the existing architecture ("Cloud Functions are the only writers" — outbound-sales-ops architecture rule 2) and adds zero new infrastructure. The "no on-demand re-sync" gap is real but minor — the `replay-pending` cron handles retries every 5 minutes.

### Outcome (if adopted)

- **No custom MCP servers built.** Zero new infrastructure in this milestone.
- **OutboundSync interactions** — skills that need CRM sync trust the webhook pipeline. Skills that need to *read* CRM state use the Salesforce MCP directly (ADR 2a). Skills that need to *write* to the Email Bison blocklist use the Email Bison MCP directly. The CFs handle the ambient sync between them. Known limitation: skills can't trigger an on-demand re-sync — they must wait for the webhook pipeline (seconds in the happy path) or the 5-minute `replay-pending` cron if something fails. This is addressable by adding an on-demand trigger endpoint to `outbound-sales-ops` if a skill needs it — not blocked by this decision.
- **Master Inbox interactions** — skills use Email Bison MCP's reply tools. The `list_replies`, `search_replies`, `send_reply`, `get_replies_analytics` tools cover the read/write surface. If a skill needs MI-specific features that the Email Bison MCP can't reach, that's a signal to re-evaluate — but no such case exists today.
- **Enrichment engine** — stays in `brite-data-platform`. Skills in this plugin access enrichment data via GitHub MCP (ADR 2d). If the enrichment CLI needs an MCP wrapper, that's a `brite-data-platform` issue, not a marketing-plugin issue.
- **Integration guide for OutboundSync** — write `tools/integrations/outboundsync.md` alongside the first skill that touches the sync layer (likely BC-2720 reply-processing). Not in this PR — grounded in a real use case, not speculative. Documents the CF-mediated architecture so skill authors understand how the sync layer works without an MCP.

### Recommendation

Don't build what the existing architecture already provides. OutboundSync's Cloud Functions are the integration layer — skills call Email Bison and Salesforce MCPs directly for their respective concerns, and the CFs handle the ambient sync. Master Inbox is Email Bison's domain — its reply tools are in the official MCP. Reserve custom MCP investment for tools that have a genuine API gap, not tools whose functionality is already reachable through existing servers.

### Review notes

- Does the "CFs are the integration layer" framing hold for future features like auto-triage or auto-reply, which might need to trigger CF logic on demand rather than waiting for webhooks?
- Is "Master Inbox = Email Bison MCP" accurate enough, or does MI have UI-only features (label management, list routing configuration) that the MCP can't reach and that a skill might need?
- If a skill needs to force a re-sync (e.g. after a manual blocklist update), is the 5-minute `replay-pending` cron acceptable, or do we need an on-demand trigger?
- Should we create a `tools/integrations/outboundsync.md` integration guide even though there's no MCP — just to document the CF-mediated architecture for skill authors? *(Resolved during review: yes — write alongside the first consuming skill, not speculatively.)*

---

## ADR 2c. Skill-to-MCP Orchestration Pattern

### Decision

Ratify the three-layer pattern defined in [`docs/guides/skill-tool-integration-pattern.md`](../guides/skill-tool-integration-pattern.md) (PR #116, merged 2026-04-11) as the standard for all tool-using skills. Add one clarification: skills must include a tool-availability check before mutating, and must not fall back to `Bash(curl)` when an MCP server is unreachable.

### Context

This question — "how do SKILL.md files declare and invoke MCP tool dependencies?" — was the original §6 Q3 in the outbound research WIP. It was resolved before BC-5041 began: PR #116 established the full pattern, template, first real instance (Email Bison), and a 6-item PR checklist. The pattern is already merged to `main`, validated by architecture-reviewer self-consistency audit, and referenced from CLAUDE.md, ARCHITECTURE.md, and CONTRIBUTING.md.

This ADR exists to formally ratify that work as an architecture decision and to close the one remaining gap the pattern guide didn't address: graceful degradation when an MCP server is unreachable.

### Alternatives considered

**Alternative 1: Accept the pattern guide as-is with no additions.**
- Pros: Pattern is already complete and validated. Adding more rules risks over-specification.
- Cons: No guidance on what happens when a server is down. A skill author might reasonably reach for `Bash(curl)` as a fallback — which violates the anti-pattern list but isn't explicitly addressed in the "what to do instead" sense.
- Rejected because: The gap is narrow but real. One paragraph closes it.

**Alternative 2 (recommended): Ratify the guide + add a degradation clause.**
- Pros: Formally blesses the guide as an ADR. Adds the one missing piece (degradation) without changing anything in the existing guide.
- Cons: Slight risk of the ADR and the guide drifting — two documents saying similar things.
- Accepted because: The ADR cites the guide by path; it doesn't duplicate it. The degradation clause is ADR-level guidance (a decision), not guide-level guidance (a pattern).

**Alternative 3: Extend the pattern guide itself with the degradation clause.**
- Pros: Single source of truth.
- Cons: The guide is a pattern document (how to do things); degradation is a policy decision (what to do when things fail). Mixing them blurs the guide's scope.
- Rejected because: Policies belong in ADRs; patterns belong in guides.

### Outcome (if adopted)

- The pattern guide at `docs/guides/skill-tool-integration-pattern.md` is the canonical reference for all tool-using skills. No changes to it.
- **Degradation policy:** when a skill's `allowed-tools` MCP server is unreachable, the skill:
  1. Calls a lightweight read-only tool as an availability check. Canonical per-server tools:
     - **Email Bison:** `get_active_workspace_info`.
     - **Salesforce** (`@salesforce/mcp`): `run_soql_query` with `SELECT Id FROM User LIMIT 1` — exercises the full round-trip including refresh-token exchange (resolved in [BC-5534 findings §Q1](../research/salesforce-mcp-findings.md#q1-availability-check-tool)). `get_username` is rejected because it reads the local SFDX auth store without contacting the org and will return a stale username when the cached token has expired.
  2. If the check fails, reports the failure to the user with the server name and suggests checking credentials / connectivity.
  3. Does **not** fall back to `Bash(curl)`, direct API calls, or any other bypass. The skill stops. This preserves anti-pattern #3 ("bypassing `allowed-tools` with Bash(curl)") from the pattern guide and keeps the three-layer boundary clean.
  4. If a specific MCP proves unreliable enough in practice to warrant a temporary escape hatch, that's a per-server decision documented in the server's integration guide — not a blanket policy change. The default remains "no bypass."
- Skills may continue with partial functionality if only one of multiple servers is down (e.g. a skill that uses both Email Bison and Salesforce can still show Email Bison data if only Salesforce is unreachable — it just can't do the Salesforce parts).

### Recommendation

Ratify the existing pattern guide as the architecture decision for skill-to-MCP orchestration. Add a one-paragraph degradation policy: check availability with a read-only tool before mutating; stop on failure; never bypass `allowed-tools`. The pattern is already working in 4 post-plan skills and 1 marketing integration guide — this ADR formalizes what's already proven.

### Review notes

- Is the "no fallback to curl" stance too rigid? Are there tools where the MCP is unreliable enough to warrant a curl escape hatch during a transitional period?
- Should the degradation policy be added to the pattern guide itself (as a new section) rather than living only in this ADR? If so, the guide grows by ~10 lines.
- Should the 6-item PR checklist be extended to include the availability-check pattern as item 7?

---

## ADR 2d. Cross-Repo Agent Pattern

### Decision

Use domain MCP servers for runtime data, GitHub MCP (`@modelcontextprotocol/server-github`) for cross-repo file reads, and Context7 for semantic search. No local clone dependency. Never build a custom MCP just to bridge two repos.

### Context

Brite's outbound pipeline spans 4 repos:
- `britenites-claude-plugins` (this repo — skills and orchestration)
- `outbound-sales-ops` (Cloud Functions — reply processing)
- `brite-data-platform` (Snowflake + dbt + enrichment engine)
- `brite-salesforce` (Salesforce SFDX source)

Skills in this repo need data from all three others. The question is: what's the access pattern for each cross-repo path?

Key constraints from BC-5040 validation:
- `outbound-sales-ops` has no MCP server, but Email Bison MCP covers the runtime data (replies, campaigns) and Salesforce MCP covers the CRM data.
- `brite-data-platform` has a CLI (`python -m enrichment.cli`, 9 commands) but no MCP. Skills need enrichment schema knowledge (dbt models, recipe definitions) more than they need to *run* enrichment (running recipes is a future need — deferred until a skill requires it, likely via the enrichment CLI or a future MCP wrapper in `brite-data-platform`).
- `brite-salesforce` is SFDX source — skills access Salesforce runtime data via the Salesforce MCP, not by reading Apex source files.
- **No local clone dependency.** Skills must not assume sibling repos are cloned locally. Cross-repo file access uses the GitHub API (via MCP or `gh` CLI), not local filesystem reads.

### Alternatives considered

**Alternative 1: Clone everything locally.**
- Pros: Fast reads (`git show origin/main:<path>`). Simple mental model. How most Claude Code users handle multi-repo today.
- Cons: Requires every developer to clone 3+ repos and keep them fetched. Fragile — a stale clone silently serves old data. Fails in CI/CD environments. Not portable across team members without a setup script.
- Rejected because: Local clone dependencies are unnecessary infrastructure friction. The GitHub API provides the same read access without the setup burden.

**Alternative 2: Build custom MCP servers for each repo.**
- Pros: Uniform pattern — every cross-repo interaction is a structured tool call.
- Cons: Requires building 2–3 custom MCP servers for repos that don't have them. Significant maintenance burden. ADR 2b already rejected building custom MCPs.
- Rejected because: Building bridges before we know the traffic.

**Alternative 3: Repo-specific CLI wrappers called via Bash.**
- Pros: Each repo exposes a CLI; skills call `Bash(python -m enrichment.cli ...)`.
- Cons: Violates the "no Bash escape hatch" principle from the pattern guide. Different auth per CLI. Error handling is string-parsing.
- Rejected because: CLI-via-Bash is the anti-pattern the skill↔tool integration pattern was designed to avoid.

**Alternative 4 (recommended): GitHub MCP server for file access, domain MCPs for runtime data, Context7 for semantic search.**
- Pros: Three complementary tools, each doing what it's best at. GitHub MCP (`@modelcontextprotocol/server-github`) reads files from any private repo via GitHub API — structured tool calls, no local clones, PAT auth. Domain MCPs (Email Bison, Salesforce) provide runtime data. Context7 provides semantic search when a skill needs to "find docs about X" rather than "read this specific file." No local dependencies beyond `gh` CLI (already required by the plugin environment).
- Cons: GitHub MCP costs an MCP server slot. Three access patterns to explain. Context7 returns snippets, not full files.
- Accepted because: Eliminates the local clone dependency entirely. Each access method serves a distinct need (file reads, runtime data, semantic search). The GitHub MCP server already exists and is maintained by the MCP org — no custom code needed.

### Access layer overview

| Need | Tool | Auth | Local dependency |
|---|---|---|---|
| **Read a specific file** from another repo | GitHub MCP server (`@modelcontextprotocol/server-github`) | GitHub PAT (scoped to Brite-Nites org) | None |
| **Query runtime data** (campaigns, CRM records, replies) | Domain MCPs (Email Bison, Salesforce) | Per-server credentials (ADR 2a) | None |
| **Semantic search** across another repo's docs | Context7 MCP (`query-docs`) | Context7 Pro (already adopted, ADR-001) | None |

> **Legacy note:** Existing skills (`handbook-drift-check`, `promote-precedent`) use `gh api` via Bash for cross-repo file reads. These continue working but new skills should prefer the GitHub MCP server (tier 1 above).

**GitHub MCP adoption:** Adopt as the recommended approach for new skills. Register in `plugins/marketing/.mcp.json` alongside the first skill that needs cross-repo file access. Existing skills that use `gh api` via Bash (`handbook-drift-check`, `promote-precedent`) continue working — migration to GitHub MCP is optional for them.

**Context7 for sibling repos:** Add `brite-data-platform`, `outbound-sales-ops`, and `brite-salesforce` to the Context7 dashboard (one-time setup). Skills can then query architecture docs via `resolve-library-id` → `query-docs` — same pattern as handbook access (ADR-001).

### Per-scenario matrix

| From (this plugin) → To | Access pattern | What it provides | Limitation |
|---|---|---|---|
| → **Salesforce runtime data** | Salesforce MCP (`@salesforce/mcp`) | SOQL queries, CRUD on Contacts/Leads/Opportunities, lifecycle state | Non-GA tools may change. SFDX CLI auth required per developer. |
| → **Email Bison runtime data** | Email Bison MCP (`emailbison-b2b` / `emailbison-personal`) | Campaigns, leads, replies, blocklist, warmup, analytics | Beta server — tool names may change. |
| → **Enrichment schemas** (`brite-data-platform`) | GitHub MCP: `read_file(repo, path)` | dbt model definitions (`dim_people.sql`, `dim_companies.sql`), recipe YAML files, CLI help text, CLAUDE.md | Can't *run* enrichment recipes or query Snowflake. Running recipes is a deferred need — will likely require the enrichment CLI or a future MCP wrapper. |
| → **Reply pipeline architecture** (`outbound-sales-ops`) | GitHub MCP for docs; Email Bison MCP for runtime data | Architecture docs (label→action mappings, BDR workflow, CF flow diagrams), plus live reply/campaign data via Email Bison MCP | Can't invoke CFs on demand. CF state (dead-letter queue, dedup cache) is in Supabase — not accessible without a separate integration. |
| → **Salesforce metadata** (`brite-salesforce`) | GitHub MCP for SFDX source; Salesforce MCP for runtime | Object definitions, field models, lifecycle GlobalValueSets, validation rules | SFDX source may drift from production SF org. Salesforce MCP reads production state. Prefer MCP for runtime truth, GitHub MCP for schema understanding. |

### Default rule

Three tiers, in priority order:
1. **Domain MCP** — if the target data has a registered MCP server (Email Bison, Salesforce), use it. This gives structured, authenticated, runtime access.
2. **GitHub MCP** — if the skill needs a specific file from another repo, use the GitHub MCP server's `read_file` tool. This gives exact file contents via GitHub API, no local clone required.
3. **Context7** — if the skill needs to search across another repo's documentation (not a specific file), use `query-docs`. Returns relevant snippets with source pointers.

**Never build a custom MCP just to bridge two repos.** When a repo stabilizes its own MCP server (e.g. if `brite-data-platform` wraps its enrichment CLI), adopt it as a domain MCP at tier 1.

### Outcome (if adopted)

- **No local clone dependency.** Skills do not assume sibling repos are cloned. All cross-repo access goes through GitHub API (via MCP or `gh` CLI) or Context7.
- Skills document their cross-repo data sources in a "## Data Sources" section specifying which access tier they use for each source.
- GitHub MCP server registered in `plugins/marketing/.mcp.json` alongside the first skill that needs cross-repo file access. Uses a PAT scoped to Brite-Nites org, stored as `${GITHUB_PAT}` in the `.mcp.json` credential pattern (ADR 2a). This brings the marketing plugin's MCP server count to 4 of ~6 (3 from ADR 2a + GitHub MCP), leaving 2 slots for future servers (e.g. Apollo, Resend).
- Context7 dashboard updated to index `brite-data-platform`, `outbound-sales-ops`, and `brite-salesforce` (one-time setup, same mechanism as the handbook — ADR-001).
- Existing skills using `gh api` via Bash continue working. New skills should prefer the GitHub MCP server.

### Recommendation

Eliminate local clone dependencies. Use domain MCPs for runtime data, GitHub MCP for file reads, Context7 for semantic search. Three tiers, each serving a distinct need, all operating through structured tool calls or existing MCP servers — no local filesystem assumptions. Register the GitHub MCP server alongside the first consuming skill, same pattern as Salesforce and Email Bison.

### Review notes

- *(Resolved during review)* Read-only file access is sufficient for enrichment schemas. Running enrichment recipes is a future need — deferred until a skill requires it.
- *(Resolved during review)* Local clones are removed as a dependency. GitHub MCP + Context7 replace `git show origin/main`.
- Should the GitHub MCP server be registered in the marketing plugin or the workflows plugin? Marketing skills are the primary consumers, but workflow skills (`handbook-drift-check`, `promote-precedent`) also do cross-repo reads.
- The GitHub MCP server requires a PAT. Should this be a personal PAT (per-developer) or a machine PAT (shared, stored as org secret)?

---

## ADR 2e. Audience View Architecture

### Decision

Reusable audience segments are dbt models in `brite-data-platform`. Campaign-specific prospect lists are loaded into Email Bison via MCP. Skills orchestrate the handoff between the two. Audience view models are created alongside the first skill that needs targeting data, not speculatively.

### Context

The outbound pipeline's "list building → sequencer" handoff is currently manual — enriched prospects in Snowflake golden records (`dim_people`, `dim_companies`) are loaded into Email Bison campaigns by hand. BC-5040 §1 Layer 1 confirmed that audience views ("filtered golden records for campaign targeting") are planned but not yet built — no `audience_view` models exist in dbt.

The question is where campaign targeting logic lives: dbt (governed, version-controlled), Email Bison list management (runtime, sequencer-native), skill-generated SQL (ad-hoc, flexible), or a hybrid.

### Alternatives considered

**Alternative 1: All targeting in dbt models.**
- Pros: Fully governed. Version-controlled. Testable with dbt tests. Reusable across campaigns. Leverages existing Snowflake + dbt investment. Single source of truth for "who are our prospects."
- Cons: dbt is batch-oriented — models run on a schedule (dbt Cloud), not on-demand. Ad-hoc filtering for a specific campaign requires editing a dbt model and waiting for a run. Slow iteration for campaign-specific tweaks. Skill authors need dbt knowledge.
- Rejected as sole approach because: The "slow iteration for ad-hoc filtering" gap is real. Campaign targeting often needs one-off exclusions ("everyone except people we emailed last week") that don't justify a permanent dbt model.

**Alternative 2: All targeting in Email Bison list management.**
- Pros: Campaign-native. Leads are already in Email Bison once imported. Filtering by campaign status, send history, and reply state happens inside the sequencer where the data lives.
- Cons: Email Bison only knows about leads that have already been imported — it can't filter the full golden record universe in Snowflake. No access to enrichment quality scores, territory data, or custom segmentation logic. Puts targeting logic inside the sequencer, which is a layer violation (the sequencer owns *how* to send, not *who* to send to).
- Rejected as sole approach because: Email Bison sees a subset of the prospect universe. Targeting starts upstream in Snowflake.

**Alternative 3: Skill-generated SQL against Snowflake.**
- Pros: Maximum flexibility. The skill generates or references a SQL query that filters golden records for a specific campaign. No dbt model changes needed. Fast iteration.
- Cons: Ungoverned — SQL lives in the skill body or in a temporary query, not version-controlled. No reusability across campaigns. Risk of inconsistent filtering logic. Direct Snowflake access from a skill requires a Snowflake MCP or CLI — neither exists in this plugin.
- Rejected as sole approach because: Governance gap is too wide. Ad-hoc SQL for campaign targeting is how data quality problems start.

**Alternative 4 (recommended): Hybrid — dbt for segments, Email Bison for campaign lists, skills orchestrate.**
- Pros: Each layer does what it's best at. dbt produces governed, reusable segments (the *who*). Email Bison owns runtime campaign state (the *how*). Skills orchestrate the handoff (the *when* and *why*). Ad-hoc filtering is a dbt model variant, not freeform SQL.
- Cons: Requires coordination across two repos (`brite-data-platform` for dbt, this plugin for skills). The audience view models don't exist yet — someone has to build them.
- Accepted because: Aligns with the existing architecture. Golden records are already in Snowflake. dbt already transforms them. Adding `audience_view_*` models is the natural next step. Email Bison MCP's `create_lead` / `bulk_create` (500/call) handles the import leg.

### Scope boundaries

| Concern | Owned by | Layer |
|---|---|---|
| **Who to target** (segment definition, filtering criteria, quality thresholds) | dbt models in `brite-data-platform` (`audience_view_*`) | List Building (Layer 1) |
| **How to import** (chunking, dedup, lead format) | Skill orchestration + Email Bison MCP (`create_lead`, `bulk_create`) | Handoff |
| **How to send** (timing, inbox rotation, warmup, sequence steps) | Email Bison campaign config | Sending (Layer 2) |
| **What to exclude** (blocklist, prior campaign recipients, opted-out) | Email Bison blocklist MCP tools + dbt exclusion models | Shared — dbt for historical exclusions, Email Bison for real-time blocklist |

### Audience view model convention

When the first outbound skill needs targeting data, it creates audience view models in `brite-data-platform` following this convention:

```sql
-- models/marts/audience_views/audience_view_smb_property_managers.sql
-- Reusable audience segment: SMB property managers with quality score >= 7

SELECT
    p.person_id,
    p.email,
    p.first_name,
    p.last_name,
    c.company_name,
    p.data_quality_score
FROM {{ ref('dim_people') }} p
JOIN {{ ref('dim_companies') }} c ON p.company_id = c.company_id
WHERE c.company_size_bucket = 'SMB'
  AND p.title ILIKE '%property manag%'
  AND p.data_quality_score >= 7
  AND p.email IS NOT NULL
  AND p.person_id NOT IN (
      SELECT person_id FROM {{ ref('exclusion_recently_emailed') }}
      WHERE last_emailed_at > DATEADD(day, -30, CURRENT_DATE)
  )
```

Naming: `audience_view_<segment_name>`. Lives in `models/marts/audience_views/`. Exclusion models (`exclusion_*`) are separate reusable dbt models.

### Outcome (if adopted)

- **No audience views built in this PR.** The convention is defined; the first implementation is a separate issue in the `brite-data-platform` backlog, blocked by the first consuming skill's contract definition (see ownership model below).
- The skill workflow for "build a campaign list" becomes: (1) skill reads the audience view definition from `brite-data-platform` via GitHub MCP (ADR 2d), (2) skill either references an existing audience view or helps the user define a new one, (3) skill calls Email Bison MCP to import the leads (`bulk_create` in chunks of 500), (4) skill calls Email Bison MCP to attach senders and configure the campaign.
- Exclusion logic is split: dbt models handle historical exclusions (recently emailed, opted out, low quality score); Email Bison blocklist handles real-time exclusions (suppressed prospects from reply processing).

### Ownership model (interface contract pattern)

Audience views follow the **interface contract pattern** recommended by the dbt community for cross-team data consumption:

1. **The consuming skill defines the contract** — its Linear issue specifies what columns, filters, and freshness SLA the audience view must provide. This is the "what I need" spec.
2. **The data platform fulfills the contract** — a separate issue in `brite-data-platform`'s backlog implements the `audience_view_*` dbt model. The data platform team (or the same person, on a small team) owns naming, testing, and performance.
3. **The skill issue is blocked by the dbt issue.** The skill can't be marked done until the view exists. The same person can do both, but separate issues preserve clean lineage — one dbt project, one `dbt test`, one lineage graph.

This keeps all SQL in the dbt project (no SQL scattered across the plugin repo) and maintains the dbt project as the single source of truth for data transformations.

### Ad-hoc targeting

**dbt-first, with a pragmatic escape hatch for one-off test campaigns.** Reusable segments and anything going to production must go through dbt. But for a quick test campaign (e.g. "50 property managers in Dallas to test a new sequence"), ad-hoc filtering through the skill is acceptable — the skill conversation itself serves as the audit trail. If the same ad-hoc filter is used twice, that's the signal to promote it to a dbt model.

The exact mechanism for ad-hoc Snowflake access from a skill (direct query, MCP wrapper, export) is deferred to when the first skill actually needs it.

### Recommendation

dbt for the *who*, Email Bison for the *how*, skills for the *when*. Audience views are dbt models owned by `brite-data-platform`, defined by interface contracts from consuming skills. Separate issues, separate repos, blocking relationship. Ad-hoc filtering is acceptable for one-off tests; reusable segments always go through dbt.

### Review notes

- *(Resolved during review)* Audience views are separate issues in `brite-data-platform` backlog, with the consuming skill blocked by them. Interface contract pattern.
- *(Resolved during review)* Ad-hoc SQL is acceptable for one-off test campaigns. Reusable segments must go through dbt. Promote to dbt model on second use.
- Is the `audience_view_*` naming convention clear enough, or should we write a more detailed spec in `brite-data-platform`'s CLAUDE.md?
- Does the 500-lead `bulk_create` limit in Email Bison constrain campaign sizes, or is chunking sufficient for Brite's volumes?

---

## ADR 2f. Skill Design Pattern for Outbound

### Decision

Outbound skills follow a 9-section template that extends the upstream marketing-skill structure with three Brite-specific layers: Brite Implementation, MCP Tool Reference, and Operational Runbook. This ADR defines the **spec**; BC-5042 produces the **template file**.

### Context

The marketing plugin already has a porting convention for upstream skills (`docs/guides/marketing-skill-porting.md`) and a tool integration pattern for MCP-calling skills (`docs/guides/skill-tool-integration-pattern.md`). Multiple net-new marketing skills — including 5 Outbound Lead Gen skills (BC-2717–2721), the Demand Gen `outbound-playbook` skill (BC-2722), and Marketing Ops skills like `lead-routing` (BC-2725) — need to teach methodology *and* orchestrate real tools against real repos. Neither existing guide covers this combination.

ADRs 2a–2e produced decisions that shape the template:
- **2a:** Email Bison + Salesforce MCPs adopted. Email Bison uses `${ENV_VAR}` credentials; Salesforce uses `DEFAULT_TARGET_ORG` sentinel + SFDX auth store (no env vars). Graceful degradation via availability check.
- **2b:** No custom MCPs. CFs are the OutboundSync integration layer. Email Bison MCP covers Master Inbox.
- **2c:** Pattern guide ratified. Skills call tools by semantic name. 6-item PR checklist.
- **2d:** Domain MCPs for runtime data, GitHub MCP for cross-repo file reads, Context7 for semantic search. No local clone dependency.
- **2e:** dbt for audience segments, Email Bison for campaign lists. Skills orchestrate the handoff.

### Alternatives considered

**Alternative 1: Use upstream marketing-skill structure as-is.**
- Pros: Consistency with the 33 upstream ports. One template for all marketing skills.
- Cons: Upstream skills are methodology-only — they teach frameworks and best practices but never call external tools. Tool-calling marketing skills need to orchestrate Email Bison, Salesforce, and cross-repo data. The upstream structure has no sections for MCP tool references, Brite-specific repo architecture, or step-by-step runbooks.
- Rejected because: The upstream structure is necessary but insufficient. The outbound skills need 3 additional sections.

**Alternative 2: Create a completely separate template for outbound skills.**
- Pros: Full freedom to design the template from scratch. No constraints from upstream conventions.
- Cons: Two incompatible skill templates in the same plugin. Skill authors have to learn which template applies. Review agents can't apply a single structure check. Future skills that mix methodology and tool orchestration (e.g. a "revops" skill) wouldn't know which template to use.
- Rejected because: The overhead of two templates outweighs the flexibility. Better to extend one.

**Alternative 3 (recommended): Extend upstream structure with 3 Brite-specific sections.**
- Pros: All marketing skills share a common base (frontmatter, Before Starting, Methodology, Health Scoring, Anti-Slop, Behavioral Tests). Outbound skills add 3 sections in the middle (Brite Implementation, MCP Tool Reference, Operational Runbook). Upstream ports can ignore the 3 extra sections; outbound skills fill all 9. One template, one checklist, one review agent rule.
- Cons: The 3 extra sections are only relevant for skills that call tools — upstream methodology-only skills leave them empty or omit them. Slightly more template to read.
- Accepted because: Extending is cheaper than forking. The 3 extra sections are clearly marked as "tool-calling skills only" and can be omitted from methodology-only ports.

### Template spec (9 sections)

#### 1. Frontmatter

```yaml
---
name: {skill-name}
description: {trigger phrases — what activates this skill. Keep from upstream if porting.}
user-invocable: true
allowed-tools: mcp__plugin_marketing_emailbison-b2b__*, mcp__plugin_marketing_emailbison-personal__*, mcp__plugin_marketing_salesforce__*, Read, Write, Glob, Grep
metadata:
  version: {version}
  upstream: {coreyhaines31/marketingskills — if ported, omit if net-new}
  category: {Outbound Lead Gen | Demand Generation | Marketing Ops}
---
```

- `allowed-tools` uses the wildcard form per the pattern guide. Only include servers the skill actually calls.
- `category` must be one of the three Brite-native categories defined in the 2026-04-01 planning session.

#### 2. Before Starting

Check `docs/marketing-context.md`. Warn if missing. This is unchanged from the upstream convention — every marketing skill reads brand context before asking questions.

#### 3. Methodology

Best practices, frameworks, benchmarks — portable knowledge not tied to Brite's stack. This is what makes the skill valuable beyond Brite. For upstream ports, this is the ported content. For net-new skills, this is original methodology.

Examples: cold email sequence design principles (campaign-orchestration), deliverability scoring frameworks (deliverability-audit), reply classification taxonomies (reply-processing).

#### 4. Brite Implementation *(tool-calling skills only)*

Which repos, which tools, which architectural rules apply for Brite specifically. This section translates the generic methodology into Brite's concrete stack. Cross-links to other skills for boundary clarity.

Content draws from:
- Research WIP §1 (pipeline layers) for repo/tool mapping
- ADR 2d (cross-repo pattern) for access methods
- ADR 2e (audience views) for targeting conventions
- Architectural rules from `outbound-sales-ops` (no tool-to-tool writes, single-label enforcement, upgrade-only lifecycle transitions)

#### 5. MCP Tool Reference *(tool-calling skills only)*

"When you need to X, call `tool_name`" — semantic tool calls, no connection details. Grouped by **workflow**, not by server. This is the section where ADR 2c's pattern becomes concrete per-skill.

Example structure:
```markdown
### Import leads into a campaign
1. Call `create_campaign` with campaign name and settings
2. Call `bulk_create` with lead data (max 500 per call, chunk larger lists)
3. Call `attach_senders` to assign sending inboxes

### Check campaign health
1. Call `get_campaign_stats` for open/reply/bounce rates
2. Call `get_leads_analytics` for per-lead delivery status
```

Each workflow step names the tool by semantic name only. Connection details live in the integration guide (`plugins/marketing/tools/integrations/email-bison.md`). This section links to the integration guide for deeper reference.

#### 6. Operational Runbook *(tool-calling skills only)*

4–8 step-by-step common tasks, more detailed than the MCP Tool Reference. Each task is a complete workflow with preconditions, steps, expected output, and error handling.

Distinct from MCP Tool Reference: the tool reference says *which tool to call*. The runbook says *the full procedure including context reads, user confirmations, and cross-skill handoffs*.

Example: "Launch a new outbound campaign" runbook would span audience view selection (ADR 2e), lead import (MCP Tool Reference), sender attachment, warmup check, schedule configuration, and launch confirmation.

#### 7. Health Scoring Rubric

10-point rubric per upstream convention. Tailored to the skill's specific output.

```markdown
| Score | Criteria |
|------:|----------|
| 10 | {skill-specific excellence criteria} |
| 7-9 | {good output with minor gaps} |
| 4-6 | {functional but missing key elements} |
| 1-3 | {poor output — generic, off-brand, or incorrect} |
```

#### 8. Anti-Slop Guardrails

Skill-specific guardrails plus the standard base:
- Do not generate generic marketing jargon
- Do not fabricate statistics, case studies, or testimonials
- Do not produce output that ignores the product-marketing-context
- {skill-specific guardrails}

#### 9. Behavioral Tests

Tier 1 (free assertions — no tool calls needed) + Tier 2 (tool-assisted — requires file read or MCP call). Minimum 6 scenarios. Evals file at `evals/evals.json`.

### Which sections are required when

| Section | Upstream port (methodology-only) | Net-new outbound skill (tool-calling) |
|---|---|---|
| 1. Frontmatter | Required | Required (with `allowed-tools`) |
| 2. Before Starting | Required | Required |
| 3. Methodology | Required | Required |
| 4. Brite Implementation | Omit | Required |
| 5. MCP Tool Reference | Omit | Required |
| 6. Operational Runbook | Omit | Required |
| 7. Health Scoring Rubric | Required | Required |
| 8. Anti-Slop Guardrails | Required | Required |
| 9. Behavioral Tests | Required | Required |

### Outcome (if adopted)

- **BC-5042** creates the template file at `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` implementing this spec. (Named "outbound" because outbound skills drove the design; applies to all tool-calling marketing skills.)
- **All tool-calling marketing skills** conform to this template — this includes the 5 Outbound Lead Gen skills (BC-2717–2721), the Demand Gen `outbound-playbook` (BC-2722), and Marketing Ops skills like `lead-routing` (BC-2725) that also call MCP tools. The template applies to any marketing skill that declares `allowed-tools` in its frontmatter, regardless of category.
- Upstream methodology-only ports continue using the existing `docs/guides/marketing-skill-porting.md` flow — sections 4–6 are simply omitted.
- The review agents can check for structural conformance: if `allowed-tools` is present in frontmatter, sections 4–6 must exist.

### Recommendation

Extend, don't fork. The 9-section template adds three Brite-specific layers (Implementation, Tool Reference, Runbook) between the portable methodology and the quality guardrails. Upstream ports ignore sections 4–6. Outbound skills fill all 9. One template covers both cases, and the "which sections are required" table makes it clear when each section applies.

### Review notes

- Is the Operational Runbook section too prescriptive? Step-by-step flows can drift as the pipeline evolves. Should runbooks live in a `references/` subdirectory instead of inline?
- Should MCP Tool Reference group tools by workflow (recommended) or by server? Grouping by server is easier to maintain but less useful to a skill author who thinks in tasks, not tools.
- Should every outbound skill have a Brite Implementation section, or only the ones that touch Brite-specific repos? (e.g. `deliverability-audit` is mostly generic methodology with a small Brite section — is a 2-line Brite Implementation section worth the structural overhead?)
- The template spec says `category` must be one of three values. Should we enforce this in the validator (`scripts/validate.sh`) or trust skill authors to get it right?
