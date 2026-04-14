# Salesforce MCP adoption — research findings

**Issue:** [BC-5534](https://linear.app/brite-nites/issue/BC-5534/research-salesforce-mcp-adoption-availability-check-non-ga-gating-auth)
**Purpose:** Resolve the ADR 2c TBD + decide concrete adoption details so [BC-5535](https://linear.app/brite-nites/issue/BC-5535) can execute without re-litigating.
**Status:** In progress — Appendix A (upstream inventory) complete; Q/A blocks and Decision Memo pending.

---

## Q1. Availability-check tool

**Decision: `run_soql_query` with a trivial read — `SELECT Id FROM User LIMIT 1`.**

**Rationale:**
- **Exercises the full round-trip.** This is the critical best-practice call: the check must verify "can we actually talk to Salesforce right now," not "is there an auth token cached locally." `get_username` only reads the SFDX auth store and returns a username even when the cached token is expired — the next real call then fails with a stale-token error that's harder to distinguish from server unreachability.
- **Triggers refresh-token exchange on expiry.** If the access token has expired but a refresh token is still valid, the SOQL call triggers the refresh transparently. `get_username` does not.
- **Minimal cost.** ~100–200ms round trip. Returns 0 or 1 rows — cheap on the Salesforce API quota (`SELECT Id FROM User LIMIT 1` is near-free relative to any real data query the skills will run).
- **Toolset-compatible.** The `data` toolset is enabled for the plugin anyway (Q5), so no extra toolset is needed just for the check.
- **SOQL injection non-concern.** The check string is a fixed literal — no user input is interpolated.

**Rejected alternatives:**
- `get_username` (`core` toolset): fails the correctness test — local-only resolution, doesn't detect stale tokens or unreachable org. Reviewed and flipped during the Gate #3 best-practices audit.
- `list_all_orgs` (`orgs` toolset): `orgs` isn't default-enabled; would require enabling a toolset solely for the check.

**Citation:** [`packages/mcp-provider-dx-core/src/tools/run_soql_query.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp-provider-dx-core/src/tools/run_soql_query.ts); ADR 2c degradation policy (availability-check-before-mutating requirement).

## Q2. Non-GA gating

**Decision: GA-only posture. Do NOT set `--allow-non-ga-tools` for the marketing plugin.**

**Mapping to the 5 downstream skills** (based on Appendix A.3 inventory cross-referenced with Appendix B.2 object/field needs):

| Skill | Needs from @salesforce/mcp | Any non-GA tools required? |
|---|---|---|
| BC-2717 list-building | `run_soql_query` (SOQL for suppression dedup + audience cross-ref), `get_username` | No |
| BC-2720 reply-processing | `run_soql_query` (read CF-owned reply fields) | No |
| BC-2725 lead-routing | `run_soql_query` (read Lead/Territory__c), possibly `assign_permission_set` (if routing logic grants temp permsets) | No |
| BC-2727 data-enrichment | `run_soql_query` (read HubSpot ID external keys + Location custom fields) | No |
| BC-2728 crm-hygiene | `run_soql_query` (query duplicate candidates) | No |

None of the non-GA tools (scratch org lifecycle, LWC/SLDS experts, DevOps Center, Apex perf antipatterns, metadata enrichment) map to marketing/outbound skill surface. Keeping GA-only narrows the attack surface and avoids dependency on pre-release tool names that may rename between 0.x releases.

**Exception path:** if a future skill needs a non-GA tool, update ADR 2c (or add ADR 2h) and flip the flag at the plugin level — don't enable it ad-hoc per-skill.

**Citation:** Appendix A.3 (per-tool GA flags); `--allow-non-ga-tools` logic in [`packages/mcp/src/index.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp/src/index.ts).

## Q3. Auth strategy

**Decision: JWT Bearer flow via a net-new dedicated Connected App ("Marketing Claude MCP").**

**Rationale:**
- The `@salesforce/mcp` server has no auth of its own — it reads whatever the SFDX auth store holds (Appendix A.1). So the real decision is "which CLI login command do we run to provision the auth store."
- Brite's production runtime integration pattern is JWT-via-dedicated-Connected-App (Outbound Sales Ops). The marketing MCP is runtime, not CI, so it matches that pattern — not the CI refresh-token pattern.
- A **dedicated** Connected App (not reusing Outbound Sales Ops) gives:
  - Rotatable blast radius — revoke the marketing app without breaking CF reply-sync.
  - **Scope minimization: `Api` only** (drop `RefreshToken`). JWT Bearer flow doesn't rely on refresh tokens the way web OAuth does — the CLI pre-step exchanges the JWT assertion for an access token each session, so `RefreshToken` scope is unnecessary surface. Least-privilege says omit it.
  - Auditable — distinct `ConnectedAppHistory` / login history so BC-5535's adoption doc can cite specific events.
- Known caveat: JWT-from-ECA is broken for scratch-org creation per upstream SFDX bugs ([forcedotcom/cli#3025](https://github.com/forcedotcom/cli/issues/3025), [#3482](https://github.com/forcedotcom/cli/issues/3482)). The marketing MCP doesn't create scratch orgs (GA-only, no `orgs` toolset), so this caveat doesn't apply here — but document it so future skills don't hit it.

**Rejected alternatives:**
- **Reusing Outbound Sales Ops Connected App** — couples blast radius; revoking one means revoking both. Rejected.
- **SFDX refresh-token URL** — matches CI, not runtime. No clean per-service-user story; awkward for shared-credential scenarios. Rejected.
- **OAuth client-credentials** — requires CC enabled on the Connected App; JWT is standard for Brite already. Unnecessarily different from the Outbound Sales Ops pattern.
- **Device flow** — interactive; wrong for a plugin meant to run headless.

**Provisioning (what a new dev does once):**
1. Admin creates `Marketing Claude MCP` Connected App + ECA wrapper in prod org (mirror `extlClntAppOauthSettings/Outbound_Sales_Ops_oauth.ecaOauth-meta.xml` with a new name + new cert).
2. Dev retrieves JWT cert private key from 1Password / handbook credential store (source TBD by BC-5535 — see Q4).
3. Dev runs: `sf org login jwt --client-id <consumer-key> --jwt-key-file <key-path> --username <service-user> --alias brite-prod --instance-url https://<instance>.my.salesforce.com` — derives instance URL via `sf org display` out-of-band.
4. MCP server at `.mcp.json` references the `brite-prod` alias.

**Citations:** [`packages/mcp/src/utils/auth.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp/src/utils/auth.ts); Appendix B.1 (existing Outbound Sales Ops pattern); [`packages/mcp/src/index.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp/src/index.ts) `--orgs` flag.

## Q4. Credential storage

**Decision: plugin-scoped `.mcp.json` uses `DEFAULT_TARGET_ORG` (not a hardcoded alias); NO credentials live in `.mcp.json` at all.**

**Why `DEFAULT_TARGET_ORG` over hardcoded `brite-prod` alias:**
- Matches the Salesforce MCP README's own example pattern (`--orgs DEFAULT_TARGET_ORG`). This is the canonical portable convention.
- Works regardless of what alias each dev uses locally. If a teammate aliases their auth as `britemarketing` or `prod` instead of `brite-prod`, the hardcoded form breaks; `DEFAULT_TARGET_ORG` resolves via `sf config get target-org` so onboarding is per-dev configurable.
- Revised from the first draft (which hardcoded `brite-prod`) during the Gate #3 best-practices audit — hardcoded alias was fragile for distributed plugin use.

**What lives where:**

| Artifact | Location | Contains |
|---|---|---|
| `plugins/marketing/.mcp.json` | Committed | MCP invocation: `npx -y @salesforce/mcp@<pinned> --orgs DEFAULT_TARGET_ORG --toolsets data` — no creds, no alias |
| SFDX auth store (`~/.sfdx/`) | Per-dev workstation | Refresh/access tokens provisioned by the one-time `sf org login jwt` step in Q3 |
| SFDX config (`sf config set target-org <alias>`) | Per-dev workstation | Maps `DEFAULT_TARGET_ORG` to whatever alias the dev used. Set once during onboarding. |
| JWT cert private key | Credential store (1Password / handbook vault — **BC-5535 decides**) | The single sensitive artifact. Distributed to devs out-of-band; not in any repo. |
| Consumer key / client ID | Connected App Setup UI in prod org | Retrieved via `sf org display --verbose` after JWT login — informational, not secret |

**Why no env-var substitution in `.mcp.json`:** the MCP server itself reads no runtime env vars (Appendix A.5 — only `NODE_ENV` for telemetry tagging). Auth is handled by the SFDX CLI pre-step which reads its own args (`--jwt-key-file`, `--client-id`). `DEFAULT_TARGET_ORG` is a sentinel recognized by the MCP, not a secret.

**`.mcp.json` shape:**

```jsonc
{
  "mcpServers": {
    "salesforce": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@salesforce/mcp@0.30.5", "--orgs", "DEFAULT_TARGET_ORG", "--toolsets", "data"]
    }
  }
}
```

**Net-new dev onboarding contract (documented in `plugins/marketing/tools/integrations/salesforce.md` — write in BC-5535):**
1. Install `sf` CLI.
2. Pull JWT cert key from `<credential-store>` (BC-5535 picks the location).
3. Run `sf org login jwt --client-id <from-setup-UI> --jwt-key-file <path> --username <service-user> --alias brite-prod --instance-url <derived-from-sf-org-display>` (alias name is dev-chosen).
4. Run `sf config set target-org <alias>` — so `DEFAULT_TARGET_ORG` resolves.
5. `/reload-plugins` in Claude Code.

**Citation:** Appendix A.5 (env vars MCP reads); README example `--orgs DEFAULT_TARGET_ORG` usage in [`packages/mcp/README.md`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/README.md); Appendix B.1 (no `.env.example` in `brite-salesforce` — this pattern mirrors).

## Q5. Toolset scoping (per-skill minimum)

**Decision: default toolsets = `core` (always on) + `data` (explicit). Per-skill allow-listing done via the `allowed-tools` frontmatter on each SKILL.md, not via toolset tweaks.**

**Plugin-level config:**

```json
"args": ["-y", "@salesforce/mcp@0.30.5", "--orgs", "DEFAULT_TARGET_ORG", "--toolsets", "data"]
```

**Per-skill `allowed-tools` frontmatter (written in BC-5535 per skill):**

| Skill | `allowed-tools` from `@salesforce/mcp` |
|---|---|
| BC-2717 list-building | `mcp__plugin_marketing_salesforce__run_soql_query`, `mcp__plugin_marketing_salesforce__get_username` |
| BC-2720 reply-processing | `mcp__plugin_marketing_salesforce__run_soql_query`, `mcp__plugin_marketing_salesforce__get_username` |
| BC-2725 lead-routing | `mcp__plugin_marketing_salesforce__run_soql_query`, `mcp__plugin_marketing_salesforce__get_username`; consider adding `assign_permission_set` if routing temporarily grants permsets (enable `users` toolset if so — open question for BC-2725, not BC-5534) |
| BC-2727 data-enrichment | `mcp__plugin_marketing_salesforce__run_soql_query`, `mcp__plugin_marketing_salesforce__get_username` |
| BC-2728 crm-hygiene | `mcp__plugin_marketing_salesforce__run_soql_query`, `mcp__plugin_marketing_salesforce__get_username` |

**Why `data` + not more:**
- All 5 skills share a common need: SOQL reads against Lead/Contact/Account/Opportunity. `data` provides `run_soql_query`.
- `core` provides `get_username` (availability check — Q1 decision) and `resume_tool_operation` (for long-running ops if ever needed).
- `users` adds `assign_permission_set` — deferred to BC-2725's design; not default.
- `metadata`, `testing`, `mobile*`, `aura-experts`, `lwc-experts`, `devops`, `code-analysis`, `scale-products`, `enrichment`, `experts-validation` are all irrelevant to marketing/outbound skill surface (Appendix A.2).
- `orgs` is NOT needed — `get_username` in `core` handles availability checks.

**Citations:** Appendix A.2 (toolset catalog); Appendix B.2 (per-skill object/field surface — all SOQL reads); [skill↔tool integration pattern guide](../guides/skill-tool-integration-pattern.md).

## Q6. Production org scope

**Decision: `DEFAULT_TARGET_ORG` sentinel in plugin config; each dev's SFDX config maps the sentinel to their local prod alias.**

**What's committed:**
- Plugin `.mcp.json`: `"--orgs", "DEFAULT_TARGET_ORG"`.
- Skill-level docs: reference "the prod Salesforce org" semantically — no alias, no URL.
- This findings doc: neither alias nor URL committed (no `*.my.salesforce.com` string).

**What's per-dev local config:**
- Alias name (dev picks — commonly `brite-prod` matching the `brite-salesforce` repo convention, but any alias works).
- `sf config set target-org <alias>` maps `DEFAULT_TARGET_ORG` → chosen alias.

**What's derived out-of-band per dev:**
- Instance URL via `sf org display --target-org <alias> --verbose` (run once per dev).
- Consumer key via same command after JWT login.

**Sandboxes out of scope** (per ADR 2a). If a future skill needs sandbox access (e.g., for safe-destructive-op preview), that's a separate ADR — the current plugin config points at the dev's `target-org` which should be a prod org for all production skills. If a dev sets `target-org` to a sandbox, they get sandbox data — that's an individual workstation decision, not a plugin-level config.

**Service user:** referenced by alias/role in committed docs; concrete username lives in handbook credential section. BC-5535 should add a Credentials section to `plugins/marketing/tools/integrations/salesforce.md` that names the credential store but not the username directly.

**Citation:** README `DEFAULT_TARGET_ORG` convention at [`packages/mcp/README.md`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/README.md); Appendix B.1 (brite-salesforce repo alias pattern); ADR 2a (`docs/designs/outbound-agent-architecture-adrs.md`).

## Q7. Upgrade cadence

**Decision: pin exact version in `plugins/marketing/.mcp.json` (e.g. `@salesforce/mcp@0.30.5`). Track upstream via GitHub Releases RSS/webhook, NOT npm CHANGELOG.**

**Observed cadence (from Appendix A.6):**
- Multi-release-per-day during active development (six 0.30.x patches in five days, 2026-03-30 → 2026-04-03).
- Still in Developer Preview / `0.x` — every minor bump (0.29 → 0.30) should be treated as potentially breaking.
- Provider sub-packages release independently (`mcp-provider-dx-core@0.9.6`, `mcp-provider-devops@0.3.4`) — tool-name changes often surface in **provider CHANGELOGs**, not the aggregator CHANGELOG. Monitoring just the top-level `@salesforce/mcp` release feed misses provider-level renames.

**What changes between versions (from CHANGELOG scan):**
- Tool renames (e.g. `create-custom-rule` → likely to get standardized hyphen/underscore convention in a future release).
- Non-GA list shifts (tools graduating GA, new non-GA tools appearing).
- Toolset additions (e.g. `experts-validation` was added in a minor — a 14→15 toolset jump post our stale-memory snapshot).
- Auth library bumps (transitively changes which `@salesforce/core` features work).

**How a bump surfaces:**
- Explicit `.mcp.json` version pin → lockfile diff on `npm install` → visible in PR review.
- `npm outdated @salesforce/mcp` in CI (future enhancement) or a dedicated handbook section.

**Upgrade procedure (BC-5535 should document):**
1. Bump version in `plugins/marketing/.mcp.json`.
2. Check GitHub release notes at https://github.com/salesforcecli/mcp/releases.
3. Check provider CHANGELOGs for tool-name diffs: `packages/mcp-provider-dx-core/CHANGELOG.md`, `packages/mcp-provider-devops/CHANGELOG.md`, etc.
4. Re-run `/reload-plugins` and smoke-test with `get_username`.
5. Run the 5 downstream skills' acceptance criteria if any toolset they use saw changes.

**Don't do:** `@latest` or omit version — release cadence is too fast and too breaking.

**Citations:** Appendix A.6 (release history); [GitHub releases](https://github.com/salesforcecli/mcp/releases).

## Q8. MCP confirmation gates inventory

**Decision: the MCP has NO confirmation gates. All confirmation gating for destructive Salesforce calls lives at the skill/agent layer in Brite's plugin.**

**Finding (Appendix A.7):**
- `@salesforce/mcp` implements **zero** confirmation-gate tools.
- Destructive tools (`delete_org`, `deploy_metadata`) rely on:
  - MCP-protocol `destructiveHint: true` annotation — which the **client** may use to prompt the user but is not enforced server-side.
  - Prose `"AGENT INSTRUCTIONS: ALWAYS confirm..."` in the tool description — no code path enforces this.
- No `elicitInput`, no two-call pattern, no server-side human-in-the-loop.

**Implication for Brite's 5 skills:**
- None of the 5 marketing skills call destructive tools under GA-only scoping. `run_soql_query` is a read. `get_username` is a read. `assign_permission_set` is mutating but not destructive.
- **BUT** any future skill that calls `deploy_metadata` or `delete_org` must implement its own AskUserQuestion gate at the skill level. Document this as a pattern in `plugins/marketing/tools/integrations/salesforce.md`.

**Material difference from Email Bison:** Email Bison's MCP enforces server-side gates (`resume_campaign`, `import_leads_to_campaign` require explicit approval via `confirm` param). Salesforce does not. Our skill-authoring pattern must handle both paradigms.

**Recommended skill-layer gate pattern (for BC-5535 to codify in the integration guide):**

```
Before calling any @salesforce/mcp tool annotated destructiveHint: true:
  1. Summarize the intended change (object, record count, fields).
  2. AskUserQuestion with 3 options: proceed / cancel / dry-run.
  3. On proceed: call the tool. On cancel: stop. On dry-run: use a query-only equivalent first.
```

**Citations:** Appendix A.7 (no confirmation gates); BC-5042 addendum on Email Bison confirmation gates (`plugins/marketing/tools/integrations/email-bison.md` § "MCP Confirmation Gates").

---

## Decision Memo

The prescriptive payload [BC-5535](https://linear.app/brite-nites/issue/BC-5535) executes against. Concrete values, no hedge words.

1. **Availability-check tool:** `run_soql_query` with `SELECT Id FROM User LIMIT 1`. Exercises the full round-trip including refresh-token exchange.
2. **Auth strategy:** JWT Bearer flow via a **net-new dedicated Connected App "Marketing Claude MCP"** in the prod org. Scope: `Api` only (drop `RefreshToken`). Mirrors the Outbound Sales Ops ECA pattern structurally; isolates blast radius.
3. **Default toolsets:** `--toolsets data` at the plugin level. `core` is always on. All other toolsets remain off by default.
4. **Plugin `.mcp.json` shape:** `"args": ["-y", "@salesforce/mcp@0.30.5", "--orgs", "DEFAULT_TARGET_ORG", "--toolsets", "data"]`. No env-var substitution required (MCP reads no runtime env vars).
5. **Non-GA posture:** GA-only. Do NOT set `--allow-non-ga-tools`. Enabling any non-GA tool requires a new ADR, not an ad-hoc flag flip.
6. **Version pin:** exact version pin (starting with `0.30.5`). Monitor both GitHub Releases AND provider CHANGELOGs (`packages/mcp-provider-*/CHANGELOG.md`) because tool renames surface in provider changelogs, not the aggregator.
7. **Confirmation-gate policy:** the MCP has no server-side gates. All confirmation gating for destructive Salesforce calls lives at the skill/agent layer. Pattern: summarize change → AskUserQuestion (proceed / cancel / dry-run) → execute. Document in `plugins/marketing/tools/integrations/salesforce.md` (BC-5535).

## Provisioning checklist (for BC-5535)

Salesforce admin (one-time):
- [ ] Create Connected App "Marketing Claude MCP" with JWT Bearer flow, `Api` scope only, self-signed X.509 cert (10-yr CN=`Marketing Claude MCP`, O=`Brite Nites`).
- [ ] Deploy matching `ExternalClientApplication` wrapper in source (mirror `Outbound_Sales_Ops_oauth.ecaOauth-meta.xml` in `brite-salesforce`).
- [ ] Set `isAdminApproved=true`, `refreshTokenPolicy=ZERO`, `ipRelaxation=ENFORCE`.
- [ ] Retrieve consumer key from Setup UI, store JWT cert private key in credential vault.

Per-dev (one-time during onboarding):
- [ ] Install `sf` CLI.
- [ ] Pull JWT cert private key from credential vault.
- [ ] Run `sf org login jwt --client-id <consumer-key> --jwt-key-file <path> --username <service-user> --alias <chosen-alias> --instance-url <derived-via-sf-org-display>`.
- [ ] Run `sf config set target-org <chosen-alias>`.
- [ ] `/reload-plugins` in Claude Code.
- [ ] Smoke-test: the availability-check SOQL resolves.

## ADR 2c amendment draft (NOT committed — BC-5535 commits it)

**Original text** (`docs/designs/outbound-agent-architecture-adrs.md:196–200`):
> **Degradation policy:** when a skill's `allowed-tools` MCP server is unreachable, the skill:
> 1. Calls a lightweight read-only tool (e.g. `get_active_workspace_info` for Email Bison, or a metadata read tool for Salesforce — verify the exact tool name when writing the Salesforce integration guide) as an availability check.

**Proposed replacement:**
> **Degradation policy:** when a skill's `allowed-tools` MCP server is unreachable, the skill:
> 1. Calls a lightweight read-only tool as an availability check. Canonical per-server tools:
>    - Email Bison: `get_active_workspace_info`
>    - Salesforce (`@salesforce/mcp`): `run_soql_query` with `SELECT Id FROM User LIMIT 1` — exercises the full round-trip including refresh-token exchange. `get_username` is rejected because it reads the local SFDX auth store without contacting the org and will return a stale username when the cached token has expired.

**Rationale for the replacement:**
- Resolves the TBD with a concrete, tested choice.
- Adds the reasoning for rejecting `get_username` so future skill authors don't re-litigate.
- Keeps the guidance tool-named + cited per server so the pattern scales to future MCP adoptions.

**Unresolved in the ADR (out of BC-5534 scope):**
- Whether the 6-item PR checklist should grow to 7 items with "availability-check pattern declared" added. Recommend deferring to a separate amendment alongside the first skill that uses the Salesforce MCP (BC-2717).
- Whether the degradation policy should migrate from ADR to the pattern guide. No change recommended here.

---

## Appendix A — `@salesforce/mcp` upstream inventory

### Header

| Field | Value |
|---|---|
| npm package | `@salesforce/mcp` |
| Latest version | **0.30.5** |
| Published | 2026-04-03T14:58:41Z |
| License | Apache-2.0 |
| Homepage | https://github.com/salesforcecli/mcp |
| Git repo | `salesforcecli/mcp` |
| Stars | 354 (2026-04-14) |
| Default branch | `main` |
| Pinned commit SHA | **`02e99fabe59a5dc189c3c7a7acb6430204e2c024`** (release commit for 0.30.5) |
| Monorepo layout | Server + CLI live in `packages/mcp/`; 14 tool-provider packages live alongside in `packages/mcp-provider-*` |

Sources: [npm registry](https://registry.npmjs.org/@salesforce/mcp/0.30.5), [GitHub repo](https://github.com/salesforcecli/mcp), [`packages/mcp/package.json`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp/package.json) at pinned SHA.

### A.1 Authentication options

**Critical finding:** the MCP server implements **no auth mechanism of its own**. It delegates 100% to `AuthInfo.create({ username })` from `@salesforce/core`, which loads whatever auth record is already persisted in `~/.sfdx/`. Every auth mode supported by `sf` / `sfdx` CLI is transitively supported — but the MCP server only *reads* those stored authorizations; it never performs a login.

Source: [`packages/mcp/src/utils/auth.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp/src/utils/auth.ts) uses `AuthInfo.create({ username: foundOrg.username })` + `Connection.create({ authInfo })`. README "Orgs" section: *"You must explicitly authorize the orgs on your computer before the MCP server can access them. Use the `org login web` Salesforce CLI command or the VS Code SFDX: Authorize an Org command from the command palette."*

| Auth mode | How it lands in `~/.sfdx` | Fits | Env vars MCP reads at runtime |
|---|---|---|---|
| **SFDX CLI web-login / refresh-token** | `sf org login web` (OAuth device flow, refresh token stored locally) | Dev workstation | None — MCP reads stored username via `--orgs` flag |
| **JWT bearer flow (Connected App)** | `sf org login jwt --username <u> --jwt-key-file <pk> --client-id <consumer-key>` | CI, headless, server | None at MCP runtime |
| **Access-token flow** | `sf org login access-token` or `SFDX_ACCESS_TOKEN` during CLI login | Short-lived automation | None at runtime |
| **SFDX auth URL** | `sf org login sfdx-url --sfdx-url-file <file>` or `SFDX_AUTH_URL` during CLI step | CI secret-pipe | None at runtime |
| **Client-credentials (OAuth 2.0 CC)** | `sf org login client-credentials` | Server-to-server (Connected App with CC enabled) | None at runtime |
| **Device flow** | `sf org login device` | Remote / headless | None at runtime |

**Caveat for Brite distribution:** because the MCP server has no auth of its own, headless/CI/containerized usage requires the SFDX auth store to be *provisioned before* the MCP server starts — typically by baking a JWT key + running `sf org login jwt` as a pre-step. The MCP server itself reads no auth env vars.

### A.2 Toolsets

Source of truth: [`packages/mcp-provider-api/src/enums.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp-provider-api/src/enums.ts). The `Toolset` enum + `TOOLSETS` array drive the `--toolsets` option list in [`packages/mcp/src/index.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp/src/index.ts). README documents **15 selectable toolsets** (enum has 16; `OTHER` is a catch-all not surfaced via `--toolsets`).

| Toolset | Purpose | Default | GA count | Non-GA count |
|---|---|---|---|---|
| `core` | Always-on helpers: resolve username, resume long ops | **Always enabled** | 2 | 0 |
| `data` | SOQL queries | Opt-in | 1 | 0 |
| `orgs` | Scratch org / sandbox lifecycle + list | Opt-in | 1 | 4 |
| `metadata` | DX project deploy / retrieve | Opt-in | 2 | 0 |
| `testing` | Apex + Agent tests | Opt-in | 2 | 0 |
| `users` | Permission-set assignment | Opt-in | 1 | 0 |
| `mobile` | Full mobile LWC / offline toolkit | Opt-in | 12 | 0 |
| `mobile-core` | Subset of `mobile` (barcode, biometrics, location, offline) | Opt-in | 5 | 0 |
| `aura-experts` | Aura component migration expertise | Opt-in | 4 | 0 |
| `lwc-experts` | LWC authoring, LDS GraphQL, SLDS, migration | Opt-in | ~34 | ~7 |
| `devops` | DevOps Center work items, PRs, deployments | Opt-in | 2 | 8 |
| `code-analysis` | Salesforce Code Analyzer (PMD + rules) | Opt-in | 4 | 2 |
| `scale-products` | Apex performance antipattern scan | Opt-in | 1 | 0 |
| `enrichment` | Enrich local DX project metadata from org | Opt-in | 0 | 1 |
| `experts-validation` | LWC validator runbook + scoring | Opt-in | 2 | 0 |

`--toolsets all` enables every toolset. `--dynamic-tools` / `-d` activates dynamic-toolset mode, mutually exclusive with `--toolsets`/`--tools`.

### A.3 Tool inventory (complete)

All tool names + GA flags verified from the README tool-listing tables at the pinned SHA. Total: **~80 tools**.

**core** (always on): `get_username` (GA), `resume_tool_operation` (GA).

**data**: `run_soql_query` (GA).

**orgs**: `list_all_orgs` (GA), `create_scratch_org` (NON-GA), `create_org_snapshot` (NON-GA), `delete_org` (NON-GA, `destructiveHint: true`), `open_org` (NON-GA).

**metadata**: `deploy_metadata` (GA, `destructiveHint: true`), `retrieve_metadata` (GA).

**testing**: `run_apex_test` (GA), `run_agent_test` (GA).

**users**: `assign_permission_set` (GA).

**mobile / mobile-core**: `create_mobile_lwc_app_review`, `create_mobile_lwc_ar_space_capture`, `create_mobile_lwc_barcode_scanner`*, `create_mobile_lwc_biometrics`*, `create_mobile_lwc_calendar`, `create_mobile_lwc_contacts`, `create_mobile_lwc_document_scanner`, `create_mobile_lwc_geofencing`, `create_mobile_lwc_location`*, `create_mobile_lwc_nfc`, `create_mobile_lwc_payments`, `get_mobile_lwc_offline_analysis`*, `get_mobile_lwc_offline_guidance`* (all GA). `*` = also in `mobile-core`.

**aura-experts**: `create_aura_blueprint_draft`, `enhance_aura_blueprint_draft`, `orchestrate_aura_migration`, `transition_prd_to_lwc` (all GA).

**lwc-experts** (largest): `create_lwc_component_from_prd`, `create_lwc_jest_tests`, `review_lwc_jest_tests`, `create_lightning_type`, `explore_slds_blueprints` (NON-GA), `guide_design_general`, `guide_component_accessibility`, `guide_lwc_best_practices`, `guide_lwc_development`, `guide_lwc_rtl_support`, `guide_lws_security`, `guide_slds_blueprints` (NON-GA), `guide_utam_generation` (NON-GA), `lwc-doc-error`, `reference_lwc_compilation_error`, `guide_slds_styling` (NON-GA), `explore_slds_styling` (NON-GA), `guide_lbc_usage`, `explore_lbc_components`, `create_lds_graphql_mutation_query`, `create_lds_graphql_read_query`, `explore_lds_uiapi`, `fetch_lds_graphql_schema`, `guide_lds_data_consistency`, `guide_lds_development`, `guide_lds_graphql`, `guide_lds_referential_integrity`, `orchestrate_lds_data_requirements`, `test_lds_graphql_query`, `guide_figma_to_lwc_conversion`, `guide_lo_migration`, `run_lwc_accessibility_jest_tests`, `verify_aura_migration_completeness`, `orchestrate_lwc_component_creation`, `orchestrate_lwc_component_optimization`, `orchestrate_lwc_component_testing`, `orchestrate_lwc_slds2_uplift` (NON-GA).

**devops**: `detect_devops_center_merge_conflict` (GA), `resolve_devops_center_merge_conflict` (GA), `check_devops_center_commit_status` (NON-GA), `checkout_devops_center_work_item` (NON-GA), `commit_devops_center_work_item` (NON-GA), `create_devops_center_pull_request` (NON-GA), `list_devops_center_projects` (NON-GA), `list_devops_center_work_items` (NON-GA), `promote_devops_center_work_item` (NON-GA), `resolve_devops_center_deployment_failure` (NON-GA).

**code-analysis**: `run_code_analyzer`, `list_code_analyzer_rules`, `describe_code_analyzer_rule`, `query_code_analyzer_results` (all GA); `create-custom-rule` (NON-GA), `generate_xpath_prompt` (NON-GA).

**scale-products**: `scan_apex_class_for_antipatterns` (GA).

**enrichment**: `enrich_metadata` (NON-GA).

**experts-validation**: `validate_and_optimize` (GA), `score_issues` (GA).

Full inventory source: [README.md](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/README.md). Per-tool implementations under `packages/mcp-provider-*/src/tools/*.ts` at pinned SHA.

---

## Appendix B — `Brite-Nites/brite-salesforce` scan

Pinned to `Brite-Nites/brite-salesforce@<HEAD-SHA-2026-04-14>`. See repo for live SHA.

### B.1 Prod org config

- **Production org URL — not written in source.** No `*.my.salesforce.com` string in `README.md`, `CLAUDE.md`, `.mcp.json`, or CI. Repo identifies prod by CLI alias `brite-prod` only (`.mcp.json` + `README.md` login instructions). Derive instance URL via `sf org display --target-org brite-prod`.
- **Service user:** referenced by alias in repo docs; concrete email lives in handbook/credential store (not in source).
- **Connected App for outbound pipeline:** `Outbound Sales Ops` — parent ConnectedApp + ExternalClientApplication wrapper. JWT bearer flow. Scopes: `Api`, `RefreshToken`. `isAdminApproved=true`, `refreshTokenPolicy=ZERO`, `ipRelaxation=ENFORCE`. Writes CF-owned fields on Lead/Contact (reply sentiment, lifecycle stage, last-replied date).
- **Consumer key / client ID — not in source** (Salesforce never writes it to metadata). Retrieve via `sf org display --verbose` or Setup UI.
- **Self-signed X.509 cert in source** (public half only — standard ConnectedApp pattern). Private key lives outside the repo. No `.env.example`.
- **Sibling ECAs:** `CI_Deploy` (inactive — CI uses `SFDX_AUTH_URL` refresh-token under built-in `PlatformCLI` app); `OutboundSync` (separate sync path).
- **JWT-scratch-org caveat:** `docs/ci-architecture.md` documents that JWT-from-ECA is broken for scratch-org creation (upstream SFDX CLI bugs). CI uses SFDX auth URL instead. MCP adoption should mention this to avoid the same trap.
- **`brite-salesforce` has its own repo-scoped `.mcp.json`** (uses `"--orgs", "brite-prod"`), unrelated to our plugin's `plugins/marketing/.mcp.json`. Our plugin should match the alias convention for consistency.

### B.2 Per-skill SF object/field surface

All paths relative to `force-app/main/default/` in `brite-salesforce`.

| Skill | Primary objects | Key custom fields | Cited repo paths |
|---|---|---|---|
| **BC-2717 list-building** | `Lead`, `Contact`, `Account`, `Campaign`, `CampaignMember`, `Territory__c` | UTM_*, Territory__c, Lifecycle_Stage__c on Lead/Account; Outbase_Campaign_ID__c, External_Campaign_URL__c, Vertical__c on Campaign. Record types on Lead/Account: Acquisition_Target / Commercial / Lighting_Professional / Residential. **No `Brite__*` audience objects** — suppression/audience lists live in `brite-data-platform`. Dedup via `matchingRules/Lead.*` + `duplicateRules/Lead.*`. | `objects/Lead/fields/UTM_*`, `objects/Campaign/fields/Outbase_Campaign_ID__c`, `matchingRules/Lead.*`, `duplicateRules/Lead.*` |
| **BC-2720 reply-processing** | `Lead`, `Contact`, `Lifecycle_Stage_History__c` (custom audit), `Task`, `EmailMessage` | Last_Replied_Date__c, Reply_Sentiment__c, Lifecycle_Stage__c, Lifecycle_MQL_Date__c, Lifecycle_SQL_Date__c, Lifecycle_Disqualified_Date__c, Disqualification_Reason__c on Lead + Contact. **Fields CF-owned** via `Outbound Sales Ops` ECA. Gotcha: HubSpot emails migrated as `Task`, not `EmailMessage`. | `objects/Lead/fields/Reply_Sentiment__c`, `objects/Lifecycle_Stage_History__c/**`, `connectedApps/Outbound_Sales_Ops.connectedApp-meta.xml` |
| **BC-2725 lead-routing** | `Lead`, `Territory__c` (custom, NOT native TM), `User` | Lead.Territory__c, Lead_Status__c (custom), Lifecycle_Stage__c, Estimated_Project_Value__c, Disqualification_Reason__c. Territory__c.Territory_Manager__c, Parent_Territory__c, Is_Active__c, Boundary_Tool_ID__c. Apex: `LeadTriggerHandler.cls` + `LeadAfterInsertService.cls`. **`assignmentRules/` absent from source.** **`Lead_Source` picklist customization absent** — LinkedIn-as-source is open debt. ADR `007-territory-custom-object.md` explains custom Territory over native TM. | `objects/Territory__c/**`, `classes/LeadTriggerHandler.cls`, `globalValueSets/Lead_Status.globalValueSet-meta.xml`, `docs/decisions/007-territory-custom-object.md` |
| **BC-2727 data-enrichment** | `Lead`, `Contact`, `Account`, `Location`, `Activity` | HubSpot_*_ID__c migration external keys on Lead/Contact/Account/Opportunity/Activity. Location.CompanyCam_URL__c, NearMap_URL__c, Prior_Season_Notes__c, Service_Address__c. **No `Enrichment_Status__c` / `Last_Enriched__c` in repo.** Enrichment persistence lives in `brite-data-platform`. | `objects/Lead/fields/HubSpot_Lead_ID__c`, `objects/Location/fields/*`, `classes/FreeEmailDomains.cls` |
| **BC-2728 crm-hygiene** | `Lead`, `Contact`, `Account`, `Opportunity` | **7 duplicate rules**: Lead (3), Contact (2), Account (2). **3 matching rules** (Lead/Contact/Account). Remediation: `AccountRemediationJob.cls`, `DisqualifiedRecycleScheduler.cls` (annual cron). `customPermissions/Bypass_Validation_Rules` is the documented bypass pattern. | `duplicateRules/*`, `matchingRules/*`, `classes/AccountRemediationJob.cls`, `classes/DisqualifiedRecycleScheduler.cls` |

### B.3 Flags / open items surfaced by the scan

1. **Entity canon three-way discrepancy.** Handbook memory: Nites / Labs / Supply (3). `README.md` in brite-salesforce: Nites / Commercial / Platform (3 with different names). `CLAUDE.md`: adds Acquisitions as 4th business line. Repo metadata: 5 Opportunity record types including `Acquisition` + `Partner_Fulfillment`. Findings doc should frame Acquisitions as a deal type *within* a canonical entity; `README.md` entity names need a correctness pass outside BC-5534's scope.
2. **CI ECAs are "compliance-posture-only"**. `CI_Deploy` ECA is committed but inactive. Only `Outbound_Sales_Ops` is a real runtime integration (right model to emulate for marketing MCP).
3. **Lead assignment rules not source-tracked** — BC-2725 open item.
4. **`LinkedIn` not in `Lead_Source` picklist** — memory-flagged, still open.
5. **No enrichment-status schema in SF** — BC-2727 may propose new schema or reuse `Lifecycle_Stage_History__c` pattern.
6. **No audience/suppression custom objects** — confirms list-building dedup relies on native duplicate/matching rules + out-of-SF audience views.
7. **No `.env.example`** — new-dev auth is prose-driven. MCP adoption doc should name env vars explicitly.

### A.4 Non-GA gating

- Flag: **`--allow-non-ga-tools`** (boolean) in [`packages/mcp/src/index.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp/src/index.ts).
- Passed as 5th positional arg to `registerToolsets(...)`; tools whose `releaseState === ReleaseState.NON_GA` ([`enums.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp-provider-api/src/enums.ts)) are skipped at registration time when the flag is `false` (default).
- Also propagated to `services.startupFlags['allow-non-ga-tools']` so individual tools can reference it at call time.
- No startup banner for non-GA exposure — silent unless the flag is set. README example: `--toolsets all --orgs DEFAULT_TARGET_ORG --allow-non-ga-tools`.
- `ReleaseState` enum has only `GA` / `NON_GA` today (enum comment: *"subject to change; we may instead introduce BETA, DEV_PREVIEW"*).

### A.5 Env vars read by the MCP

Direct, verbatim `process.env.*` references in `packages/mcp/src/`:

| Env var | Source | Meaning |
|---|---|---|
| `NODE_ENV` | `packages/mcp/src/telemetry.ts` — `nodeEnv: process.env.NODE_ENV` | Telemetry dimension only |

**That's it at the MCP-server layer.** Downstream, `@salesforce/core` respects the usual SFDX env vars (`SF_TARGET_ORG`, `SFDX_ACCESS_TOKEN`, `SF_USE_PROGRESS_BAR`, `SF_DISABLE_TELEMETRY`, etc.) but those are **not** declared or gated by the MCP server itself.

`DEVELOPING.md` mentions one debug var: **`MCP_SERVER_REQUEST_TIMEOUT=120000`** extends the `@modelcontextprotocol/inspector` client's request timeout during local debugging — inspector-side, not consumed by the MCP server.

Telemetry controlled by a build-time constant `APP_INSIGHTS_KEY` in `telemetry.ts` (empty in public source, populated only by the official release pipeline). Runtime toggle is the **`--no-telemetry`** CLI flag, not an env var.

### A.6 Release cadence

From [GitHub releases](https://api.github.com/repos/salesforcecli/mcp/releases) + `packages/mcp/CHANGELOG.md`:

| Version | Published (UTC) |
|---|---|
| 0.30.5 | 2026-04-03 |
| 0.30.4 | 2026-04-02 |
| 0.30.3 | 2026-04-01 |
| 0.30.2 | 2026-04-01 |
| 0.30.1 | 2026-03-31 |
| 0.30.0 | 2026-03-30 |
| 0.29.5 | 2026-03-26 |
| 0.29.4 | 2026-03-25 |

**Observations:**
- Multi-release-per-day is common (six 0.30.x patches in five days). Release-train style.
- Still **0.x semver** — project is in Developer Preview per the [official launch blog](https://developer.salesforce.com/blogs/2025/06/level-up-your-developer-tools-with-salesforce-dx-mcp) (2025-05-30). Treat every minor bump (0.29 → 0.30) as potentially breaking.
- Provider sub-packages release independently under their own tags (`mcp-provider-dx-core@0.9.6`, `mcp-provider-devops@0.3.4`, etc.). The aggregator `@salesforce/mcp` version bumps whenever a dependency range updates. Tool-name changes typically surface in **provider changelogs**, not the top-level changelog — downstream we should watch GitHub releases, not just the aggregator CHANGELOG.

### A.7 Confirmation-gate tools

**Definitively: the MCP server implements NO confirmation gates.**

Evidence:
- README has zero mentions of the words *confirm, confirmation, approval, destructive, elicit, safety, ask the user*.
- [`delete_org.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp-provider-dx-core/src/tools/delete_org.ts) tool description contains prose *"AGENT INSTRUCTIONS: ALWAYS confirm with the user before deleting an org"* — but the `exec()` method proceeds directly to deletion. No `elicitInput`, no two-call pattern, no server-side gate.
- [`deploy_metadata.ts`](https://raw.githubusercontent.com/salesforcecli/mcp/02e99fabe59a5dc189c3c7a7acb6430204e2c024/packages/mcp-provider-dx-core/src/tools/deploy_metadata.ts) is annotated with `destructiveHint: true` — an MCP-protocol *annotation* that the client MAY use to prompt the user, **but is not enforced server-side**.
- No elicitation / human-in-the-loop scaffolding anywhere in `packages/mcp/src/`. The only "handoff"-shaped pattern is `resume_tool_operation` for long-running async ops.

**Implication for Brite:** if Brite wants confirmation gates for destructive Salesforce calls (e.g. `delete_org`, `deploy_metadata`), they must live at the Claude-Code skill/agent layer, not at the MCP layer. This is materially different from Email Bison's MCP, which enforces a dedicated `resume_campaign` / `import_leads_to_campaign` two-call pattern server-side. Document this as a known gap when writing the Salesforce skill.

### A.8 Verification against 3-day-old memory claims

From `memory/reference_outbound_mcp_servers.md`:

- ✅ **"SFDX CLI auth"** — holds up. The MCP server only reads from the SFDX auth store; there is no alternative auth path.
- ❌ **"120+ tools"** — **stale/overstated.** Current inventory totals ~80 tools. 120+ appears to have been an over-estimate from an earlier scan.
- ❌ **"14 toolsets"** — **off by one.** Current build exposes **15 selectable toolsets** (enum has 16 including `OTHER`, a catch-all not listed under `--toolsets`).
- ❌ **"348 stars"** — **stale.** Current count **354 stars** (2026-04-14). Freshness, not correctness.

**Net:** memory is directionally right (first-party Salesforce MCP, SFDX-auth-based) but specific numbers should update to **~80 tools / 15 toolsets / 354 stars / v0.30.5**. New fact worth recording: **no MCP-level confirmation gates** — destructive ops rely on `destructiveHint` annotations + prose instructions only.

Sources cross-referenced above. All repo files cited at pinned commit `02e99fabe59a5dc189c3c7a7acb6430204e2c024`.
