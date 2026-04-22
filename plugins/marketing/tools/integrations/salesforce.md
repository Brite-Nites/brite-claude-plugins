# Salesforce Integration

> Reference document. Connection details, auth, and tool inventory only — procedural logic (when to call, in what order, for what outcome) lives in consuming skills. See `docs/guides/skill-tool-integration-pattern.md`.

## Purpose

Salesforce is Brite's **CRM system of record** — Leads, Contacts, Accounts, Opportunities, Campaigns, Territories, reply sentiment, lifecycle stage, disqualification reasons. Every marketing skill that writes or reads authoritative prospect state crosses Salesforce at some point.

The `marketing` plugin ships the official [`@salesforce/mcp`](https://github.com/salesforcecli/mcp) server. It's currently in Developer Preview (`0.x` semver, multi-release-per-day cadence) — see [findings §Q7](../../../../docs/research/salesforce-mcp-findings.md#q7-upgrade-cadence) for the upgrade policy.

Provisioned as a standalone External Client App (ECA) — classic ConnectedApp creation is blocked org-wide since Spring '26. This is Brite's first pure ECA; future integrations should follow this as the new exemplar.

Decisions backing this integration: [`docs/research/salesforce-mcp-findings.md`](../../../../docs/research/salesforce-mcp-findings.md) (BC-5534, amended by BC-5579) + [ADR 2a/2c](../../../../docs/designs/outbound-agent-architecture-adrs.md).

## Consumed by

- `situation-mining` (BC-5824) — existing-account deep dive: `run_soql_query` on Account, Activity history, Opportunity history, `Account_Notes__c`, `Lifecycle_Stage_History__c` to enrich per-prospect worldview inference with internal signals.
- `account-research` (BC-5827) — existing-SF-account enrichment conditional via `run_soql_query` on Account, Activity history, Opportunity history, `Account_Notes__c`, `Lifecycle_Stage_History__c` to augment public-source fact sheets with internal signals.
- `list-building` (BC-2717)
- `reply-processing` (BC-2720)
- `lead-routing` (BC-2725)
- `data-enrichment` (BC-2727)
- `crm-hygiene` (BC-2728)

## Auth

**Credential type.** JWT Bearer flow against a dedicated External Client App (ECA) named **"Marketing Claude MCP"** in the prod Salesforce org. Scopes: `Api` + `RefreshToken`. See [findings §Q3](../../../../docs/research/salesforce-mcp-findings.md#q3-auth-strategy) for why JWT over web/device/client-credentials. `RefreshToken` scope is required by the SFDX CLI auth layer (`sf org login jwt` fails without it); `refreshTokenPolicy: ZERO` prevents long-lived tokens.

**Where the server reads from.** `@salesforce/mcp` has **no auth mechanism of its own**. It delegates 100% to `AuthInfo.create({ username })` in `@salesforce/core`, which loads whatever auth record is persisted in the local `~/.sfdx/` store. The MCP server does not log in — it only reads pre-provisioned auth ([findings §A.1](../../../../docs/research/salesforce-mcp-findings.md#a1-authentication-options)).

**Env vars read by the MCP at runtime.** One: `NODE_ENV` (telemetry tagging only). That's it — no `SALESFORCE_*` / `SFDX_*` / `SF_*` env vars are consumed at the MCP layer ([findings §A.5](../../../../docs/research/salesforce-mcp-findings.md#a5-env-vars-read-by-the-mcp)).

**Target org resolution.** The plugin `.mcp.json` passes the `DEFAULT_TARGET_ORG` sentinel (the canonical portable convention from the upstream README). Each dev's local `sf config set target-org <alias>` maps the sentinel to their chosen alias — nothing about the org URL or alias is committed.

**Credential storage.** The JWT cert private key lives in the **Engineering Bitwarden collection**, item name **"Marketing Claude MCP — JWT private key"**. Per-user ACLs + audit trail; revocable without touching the Salesforce Connected App. The private key is never committed, never bundled with the plugin, never written to `.mcp.json`.

### One-time per-dev onboarding

> Instance URL, consumer key, and service-user email appear as placeholders (`<...>`) throughout this section — their concrete values live in the Bitwarden item, not in the committed repo. This matches BC-5534's blast-radius stance (instance identifiers stay out of source so a repo leak never exposes the prod SF tenant). Ask in `#eng-marketing` if you need help locating the Bitwarden item.

1. Install the Salesforce CLI: `brew install --cask sfdx` (macOS) or follow [upstream install docs](https://developer.salesforce.com/tools/salesforcecli).
2. Retrieve the **"Marketing Claude MCP — JWT private key"** item from the Engineering Bitwarden collection. Save the private key anywhere local on your machine (e.g. `~/.sfdx/marketing-claude-mcp.key` to co-locate with SFDX's own config, or somewhere under your home directory you'll remember). **`chmod 600` the file** — this is the one non-optional step.
3. The Bitwarden item's **Notes field** carries everything else you need: the consumer key, the service-user email, and the prod instance URL. Keeping these alongside the cert makes onboarding a single-stop operation — no Slack-grepping or cross-repo cross-referencing. (Fallback: `brite-salesforce/README.md` documents the same JWT login pattern against the prod alias, and `sf org display --verbose` surfaces the consumer key + instance URL after the first login lands.)
4. Run the JWT login (one time), substituting the consumer key / service-user / instance URL from the Bitwarden Notes field and the key path from step 2:

   ```bash
   sf org login jwt \
     --client-id <consumer-key> \
     --jwt-key-file <path-from-step-2> \
     --username <service-user> \
     --alias <your-chosen-alias> \
     --instance-url <instance-url>
   ```

5. Map the sentinel: `sf config set target-org <your-chosen-alias>`.
6. `/reload-plugins` in Claude Code.
7. Smoke-test from any skill that has `mcp__plugin_marketing_salesforce__run_soql_query` allowed. Run `SELECT Id FROM User LIMIT 1` — the canonical availability check. If it returns a row, you're connected. If it fails with a token error, re-run step 4.

## Service User Permissions

**Audit date:** 2026-04-22 (BC-5924). **Status: over-provisioned — tightening tracked in [BC-5925](https://linear.app/brite-nites/issue/BC-5925/).**

`@salesforce/mcp` has no server-side read-only mode, no row limits, and no destructive-tool gates ([findings §Q8](../../../../docs/research/salesforce-mcp-findings.md#q8-mcp-confirmation-gates-inventory)). Blast radius is controlled entirely by the service user's profile + permission set assignments. This section documents the current baseline; the minimum-required matrix below is the target state that Part B (BC-5925) will enforce.

### Identity

| Field | Value |
|---|---|
| Username / Email | See Bitwarden item *"Marketing Claude MCP — JWT private key"* Notes field |
| Profile | `System Administrator` |
| Active | Yes |

### Permission set assignments (current)

| Permset | Grants | Needed? |
|---|---|---|
| (profile-owned permset, auto-generated) | Full admin parity with the profile — cannot be detached | N/A — fix by changing profile |
| `OutboundSync_Integration` | Legacy sync integration access | No — remove |
| `StandardEinsteinActivityCapturePsl` | Einstein Activity Capture | No — unrelated to SOQL skills |
| `Automation_Validation_Bypass` | Bypasses validation rules on DML | **No — actively dangerous on a headless service user** |
| `Sales_Operations` | Full CRUD + View All on 8 of the 11 marketing-relevant objects | No — too broad |
| `AirCall_PermissionSet` | Phone-system integration access | No — unrelated |

### Object-level effective access

Because the profile is `System Administrator`, effective access is **full CRUD + View All + Modify All** on every object below. `ObjectPermissions` rows only surface permsets with explicit grants; absence of rows does not imply absence of access when the base profile is SysAdmin.

| Object | Effective access today | Required by planned skills |
|---|---|---|
| `Account` | Full CRUD + VA + MA | Read |
| `Contact` | Full CRUD + VA + MA | Read |
| `Lead` | Full CRUD + VA + MA | Read |
| `Campaign` | Full CRUD + VA + MA | Read |
| `Territory__c` | Full CRUD + VA + MA | Read |
| `Location` | Full CRUD + VA + MA | Read |
| `Task` + `Event` (Activity virtual) | Full CRUD + VA + MA | Read |
| `Lifecycle_Stage_History__c` | Full CRUD + VA + MA | Read |
| `Opportunity` | Full CRUD + VA + MA | Read |
| `AccountContactRelation` | Full CRUD + VA + MA | Read |
| `In_App_Checklist_Settings__c` | Full CRUD + VA + MA | Read |

### Destructive / admin capabilities

| Capability | Granted? | Needed by SOQL skills? |
|---|---|---|
| Modify All Data | Yes (profile) | No |
| View All Data | Yes (profile) | No |
| Api Enabled | Yes (profile) | **Yes** |
| Author Apex | Yes (profile) | No |
| Customize Application | Yes (profile) | No |
| Manage Users | Yes (profile) | No |
| Validation rule bypass | Yes (`Automation_Validation_Bypass` permset) | No |

### Minimum required per planned consumer skill

All 5 planned skills are read-only SOQL patterns. Required permissions are **identical** across the set: `Api Enabled` + `Read` on the listed objects.

| Skill | Issue | SOQL objects | Canonical query shape |
|---|---|---|---|
| `list-building` | [BC-2717](https://linear.app/brite-nites/issue/BC-2717/) | `Lead` (+ `duplicateRules`) | `SELECT Id, Email, Status FROM Lead WHERE Email IN (:emails)` — see [§Lead suppression read](#lead-suppression-read-1-mcp-call) |
| `reply-processing` | [BC-2720](https://linear.app/brite-nites/issue/BC-2720/) | `Lead`, `Contact` | Reply-sentiment + lifecycle-stage field reads |
| `lead-routing` | [BC-2725](https://linear.app/brite-nites/issue/BC-2725/) | `Lead`, `Territory__c` | `Lead.Territory__c` + `Territory__c` assignment reads |
| `data-enrichment` | [BC-2727](https://linear.app/brite-nites/issue/BC-2727/) | `Account`, `Contact`, `Lead`, `Location` | HubSpot-migration external-key + Location custom-field reads |
| `crm-hygiene` | [BC-2728](https://linear.app/brite-nites/issue/BC-2728/) | `Lead`, `Contact`, `Account` | Duplicate-rule result reads for dedup |

None require Create / Edit / Delete / Modify-All / Author-Apex / validation bypass.

### Part B — tightening target (BC-5925)

Close the gap between current (`System Administrator` + 6 permsets) and required (`Api Enabled` + Read on 11 objects):

1. **Change profile from `System Administrator` → a least-privilege profile** (Standard User, or a new custom "Integration User" profile) with `Api Enabled` + nothing else.
2. **Unassign 4 permsets:** `OutboundSync_Integration`, `StandardEinsteinActivityCapturePsl`, `Automation_Validation_Bypass`, `AirCall_PermissionSet`.
3. **Replace `Sales_Operations` with a narrow permset** that grants Read-only on the 11 marketing-relevant objects. Align with [ADR-004 permission-set strategy](https://github.com/Brite-Nites/brite-salesforce/blob/main/docs/decisions/004-permission-set-strategy.md) in `brite-salesforce`.
4. **Post-tightening verification** (Part B Verify phase T6 + T7): `PermissionsModifyAllData = false` on every assigned permset; service user still executes `SELECT Id FROM User LIMIT 1` via the MCP without auth error.

See [BC-5925](https://linear.app/brite-nites/issue/BC-5925/) for execution.

### Audit methodology (re-runnable)

Queries run from `brite-salesforce/` via `sf data query --target-org marketing-claude-prod`. Re-run these before Part B opens, and after Part B merges, to confirm the baseline shift:

1. `SELECT Id, Username, Email, Profile.Name, IsActive FROM User WHERE Email = '<service-user-email>'`
2. `SELECT PermissionSet.Name, PermissionSet.IsOwnedByProfile FROM PermissionSetAssignment WHERE AssigneeId = '<service-user-id>'`
3. `SELECT Name, PermissionsModifyAllData, PermissionsViewAllData, PermissionsApiEnabled, PermissionsAuthorApex FROM PermissionSet WHERE Id IN (<permset-ids>)`
4. `SELECT Parent.Name, SobjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete FROM ObjectPermissions WHERE Parent.Id IN (<permset-ids>) AND SobjectType IN ('Account','Contact','Lead','Campaign','Territory__c','Location','Task','Event','Lifecycle_Stage_History__c','Opportunity','AccountContactRelation','In_App_Checklist_Settings__c')`

## Registration

```json
{
  "mcpServers": {
    "salesforce": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@salesforce/mcp@0.30.5",
        "--orgs", "DEFAULT_TARGET_ORG",
        "--toolsets", "data"
      ]
    }
  }
}
```

**File location.** `plugins/marketing/.mcp.json` (plugin-scoped — distributes with the plugin). No creds, no env-var substitution, no alias.

**Version pin is exact.** `0.x` upstream + multi-release-per-day cadence means every minor bump is potentially breaking; do not use `@latest` or a caret range. Upgrade procedure: see [findings §Q7](../../../../docs/research/salesforce-mcp-findings.md#q7-upgrade-cadence). **Watch both** the aggregator [GitHub Releases](https://github.com/salesforcecli/mcp/releases) **and** per-provider CHANGELOGs at `packages/mcp-provider-*/CHANGELOG.md` — tool renames surface in provider changelogs, not the aggregator.

**Toolsets: `data` explicit, `core` always on.** `--toolsets data` exposes `run_soql_query`. `core` (always on) gives `get_username` and `resume_tool_operation`. All other toolsets (`orgs`, `metadata`, `testing`, `users`, `mobile*`, `aura-experts`, `lwc-experts`, `devops`, `code-analysis`, `scale-products`, `enrichment`, `experts-validation`) are off — none map to marketing/outbound surface per [findings §Q5](../../../../docs/research/salesforce-mcp-findings.md#q5-toolset-scoping-per-skill-minimum).

**`--allow-non-ga-tools` is NOT set.** GA-only posture for the plugin. Enabling any non-GA tool requires a new ADR, not an ad-hoc flag flip — see [findings §Q2](../../../../docs/research/salesforce-mcp-findings.md#q2-non-ga-gating).

## Tool inventory

Total upstream: **~80 tools across 15 selectable toolsets** at `0.30.5` (pinned commit `02e99fabe59a5dc189c3c7a7acb6430204e2c024`). With the plugin's `core + data` scoping, **3 tools** are exposed:

| Tool | Toolset | What it does |
|---|---|---|
| `run_soql_query` | data | Execute a read-only SOQL query against the target org |
| `get_username` | core | Return the username associated with the active auth record — **local-only read**, does NOT contact Salesforce |
| `resume_tool_operation` | core | Resume a long-running async tool operation |

**Naming in skill frontmatter.** Use the full plugin-namespaced form:

- `mcp__plugin_marketing_salesforce__run_soql_query`
- `mcp__plugin_marketing_salesforce__get_username`
- `mcp__plugin_marketing_salesforce__resume_tool_operation`

To browse tools outside the current scope (e.g. while designing a future skill), run `@salesforce/mcp` locally with `--toolsets all --allow-non-ga-tools` as an exploratory one-off — do NOT commit that expanded scope to the plugin `.mcp.json`.

**Full upstream inventory, per-toolset GA flags, and release-state enum:** [findings §A.3](../../../../docs/research/salesforce-mcp-findings.md#a3-tool-inventory-complete).

## Common workflows

Canonical recipes that combine Salesforce tools. Skills should follow these sequences verbatim unless they have a reason to deviate documented in their own `## Operational Runbook`.

### Availability check (1 MCP call)

Use this before any skill's first real Salesforce call, per ADR 2c degradation policy.

| # | Tool | SOQL | What it verifies |
|---|------|------|---|
| 1 | `run_soql_query` | `SELECT Id FROM User LIMIT 1` | Full round-trip to Salesforce: auth store is valid, access token is live (or was just refreshed), org is reachable. Returns 0 or 1 rows. |

**Why not `get_username`.** `get_username` reads the local SFDX auth store without contacting Salesforce — it returns a username even when the cached access token has expired. The next real call then fails with a stale-token error that's harder to distinguish from "org unreachable." Always use `run_soql_query` as the liveness probe.

### Lead suppression read (1 MCP call)

Canonical pattern for `list-building` and `crm-hygiene` skills that need to exclude existing Salesforce records from a net-new outbound list.

| # | Tool | SOQL | What it returns |
|---|------|------|---|
| 1 | `run_soql_query` | `SELECT Id, Email, Status FROM Lead WHERE Email IN (:emails) LIMIT 2000` | Existing Lead rows matching the input emails. Skill compares against the candidate list to suppress duplicates before attaching to an Email Bison campaign. |

SOQL-injection note: bind variables (`:emails`) are evaluated by the `run_soql_query` tool's internal binding, not string-interpolated. Skills should construct the email array as a tool parameter, not by formatting a literal string.

## MCP confirmation gates

**The MCP implements ZERO server-side confirmation gates.** This is a material difference from Email Bison, whose MCP enforces two-call confirmation on destructive tools like `resume_campaign` and `import_leads_to_campaign`. [findings §Q8](../../../../docs/research/salesforce-mcp-findings.md#q8-mcp-confirmation-gates-inventory) documents the full evidence.

What the MCP does instead for destructive tools like `delete_org` and `deploy_metadata`:

- Annotates them with MCP-protocol `destructiveHint: true` — which the client MAY use to prompt the user but is **not enforced server-side**.
- Prose in the tool description like `"AGENT INSTRUCTIONS: ALWAYS confirm with the user before deleting"` — no code path enforces this.

### Skill-layer confirmation pattern (mandatory for destructive tools)

Under the current plugin scoping (`core + data`), none of the 3 exposed tools are destructive. But any future skill that enables `metadata`, `orgs`, or `users` toolsets and calls a tool annotated `destructiveHint: true` **must** implement this pattern at the skill layer:

1. **Summarize the intended change.** Object, record count, field names to be affected.
2. **AskUserQuestion** with 3 options: `proceed`, `cancel`, `dry-run`.
3. **On `proceed`:** call the tool.
4. **On `cancel`:** stop.
5. **On `dry-run`:** call a query-only equivalent first (e.g. `run_soql_query` to preview the record set) and re-ask.

Never auto-execute. Never degrade the confirmation to a prose "please confirm" — use `AskUserQuestion` so the approval is captured explicitly.

## Known gotchas

- **`get_username` is NOT a liveness check.** It reads the local auth store without contacting Salesforce. Always use `run_soql_query` + trivial SOQL for availability probes. This is the #1 trap for skill authors.
- **JWT-from-ECA is broken for scratch-org creation.** Upstream bugs [forcedotcom/cli#3025](https://github.com/forcedotcom/cli/issues/3025) and [#3482](https://github.com/forcedotcom/cli/issues/3482). The marketing plugin doesn't create scratch orgs (GA-only, no `orgs` toolset), so this caveat doesn't bite here — but document it for future skill authors who might wander into scratch-org territory.
- **Provider sub-packages release independently.** Tool-name changes and toolset additions often land in `packages/mcp-provider-dx-core/CHANGELOG.md` or `packages/mcp-provider-devops/CHANGELOG.md` — not the aggregator `@salesforce/mcp` CHANGELOG. When bumping the version pin, check **both**.
- **`destructiveHint: true` is an annotation, not a gate.** See the skill-layer confirmation pattern above.
- **No `.env.example` pattern.** Unlike Email Bison where the token is an env var, Salesforce has no env-var configuration. If you see a Salesforce-related `SALESFORCE_*` / `SFDX_*` / `SF_*` env var in a skill draft, it's almost certainly a leftover from an unrelated pattern — remove it.
- **Pinned version may go stale quickly.** Upstream is in Developer Preview with multi-release-per-day cadence. Every version bump should go through a PR with explicit review of the release notes + provider CHANGELOGs.
- **`DEFAULT_TARGET_ORG` must be set per-dev.** A dev who forgets `sf config set target-org <alias>` after logging in will see cryptic "no org found" errors from the MCP. The integration guide's onboarding step 6 is not optional.

## Related skills

**Primary consumers** *(all blocked by this integration landing)*:

- `list-building` (BC-2717) — SOQL reads against `Lead` + `duplicateRules` for suppression before attaching to Email Bison campaigns
- `reply-processing` (BC-2720) — SOQL reads of CF-owned reply sentiment + lifecycle stage fields on `Lead` / `Contact`
- `lead-routing` (BC-2725) — SOQL reads of `Lead.Territory__c` + `Territory__c` object for assignment logic; may add `assign_permission_set` if routing grants temp permsets (that would flip on the `users` toolset — separate decision)
- `data-enrichment` (BC-2727) — SOQL reads of HubSpot migration external keys + Location custom fields to reconcile enrichment state
- `crm-hygiene` (BC-2728) — SOQL reads of duplicate-rule results for dedup workflows

**Adjacent integration:** [Email Bison](email-bison.md) — the sending layer that consumes Salesforce lead data and emits reply events back via OutboundSync. The two MCPs are complementary: Salesforce is the authoritative store, Email Bison is the sending runtime.

**Upstream pipeline:** Brite enrichment engine in `brite-data-platform` (custom Python CLI, no MCP yet — BC-5536/5537/5538 track the wrap).

**Rejected alternatives:** reusing the `Outbound Sales Ops` Connected App (couples blast radius); SFDX refresh-token URL (CI-pattern, not runtime); OAuth client-credentials (unnecessary divergence from existing JWT pattern); device flow (interactive — wrong for headless use). Full rationale: [findings §Q3](../../../../docs/research/salesforce-mcp-findings.md#q3-auth-strategy).

## Last verified

`2026-04-22` — Service user permission baseline audited in BC-5924. Profile = `System Administrator` + 6 permsets (including `Automation_Validation_Bypass`); over-provisioned against the `Api Enabled` + Read-on-11-objects minimum required by planned skills. Tightening tracked in [BC-5925](https://linear.app/brite-nites/issue/BC-5925/) (Part B, blockedBy BC-5924). See §Service User Permissions above for the full matrix and re-runnable audit queries. Re-run the §Service User Permissions queries before BC-5925 opens, after BC-5925 merges, and quarterly thereafter.

`2026-04-16` — End-to-end verified by BC-5579. JWT login as service user succeeded; `run_soql_query` with `SELECT Id FROM User LIMIT 1` returned a row. ECA provisioned as standalone (not classic CA — Spring '26 blocked CA creation). `RefreshToken` scope re-added (required by SFDX CLI auth layer; original BC-5534 guidance to drop it was incorrect). Upstream inventory + per-toolset GA flags + confirmation-gate absence verified at pinned commit `02e99fabe59a5dc189c3c7a7acb6430204e2c024` during BC-5534 research.

Re-verify `discover_tools`-equivalent (`--toolsets all` local run) whenever the version pin bumps.
