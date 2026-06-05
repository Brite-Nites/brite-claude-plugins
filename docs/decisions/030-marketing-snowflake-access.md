# 030. Snowflake Access for Marketing Plugin

**Status:** Proposed
**Date:** 2026-05-28
**Linear:** [BC-11926](https://linear.app/brite-nites/issue/BC-11926)
**Blocks:** [BC-11929](https://linear.app/brite-nites/issue/BC-11929) (Source 4 impl), [BC-11928](https://linear.app/brite-nites/issue/BC-11928) (Source 4 design), [BC-11927](https://linear.app/brite-nites/issue/BC-11927) (audience-view catalog)
**Related ADRs:** [ADR-008](008-tam-mapping-enrichment-pluggability.md), [ADR-009](009-sf-capability-adoption.md), [ADR-010](010-plugin-secret-config-canon.md)
**Research:** [`docs/research/tam-map-port-policy.md`](../research/tam-map-port-policy.md) § 1 (MCP-cap measurement methodology)

## Context

The `list-building` skill (`plugins/marketing/skills/list-building/SKILL.md`) accepts three input sources today: tam-mapping output, dbt audience CSV, and manual CSV. The dbt audience CSV path requires the operator to **manually export** a CSV from Snowflake out-of-band before invoking the skill. The skill body documents this gap verbatim:

> Skill reads CSV via `Read`. Skill reads the dbt model definition via `Bash` → `gh api ...` for column-shape reference + audit logging only — does NOT execute the model (no Snowflake MCP exists; the dbt models materialize in Snowflake out-of-band).

The 2026-05-28 scoping session ([BC-11924](https://linear.app/brite-nites/issue/BC-11924), [BC-11926](https://linear.app/brite-nites/issue/BC-11926)) committed to closing this gap by adding a Source 4 to `list-building` that reads Snowflake audience views directly — the canonical first view being `audience_commercial_outreach` ([BC-2314](https://linear.app/brite-nites/issue/BC-2314), Corinne's golden-record-fed commercial outreach output). Before the implementation issue ([BC-11929](https://linear.app/brite-nites/issue/BC-11929)) can land, the access mechanism needs to be chosen.

Three mechanisms are plausible. This ADR picks one and documents why the other two are rejected — without re-litigating the choice the next time a Snowflake-consuming skill ships.

## Decision Drivers

- **MCP-cap discipline** ([`tam-map-port-policy.md`](../research/tam-map-port-policy.md) § 1). The marketing plugin runs 5 plugin-level MCPs today (`salesforce`, `spider`, `aiark`, `discolike`, `gbrain-team`). Adding a 6th puts the plugin at the top of the ~5–6 advisory range. Latency + context-budget impact must be measured before a 6th MCP merges. The cost of measurement (a baseline + re-baseline) is non-trivial.
- **Credential discipline** ([ADR-010](010-plugin-secret-config-canon.md)). Snowflake credentials must flow through the Bitwarden + `bw-run.sh` broker pattern, not env-var sprawl or `userConfig` substitution (broken for HTTP MCPs).
- **Pattern reuse** ([ADR-008](008-tam-mapping-enrichment-pluggability.md)). ADR-008 already canonicalizes the `brite_cli` shell-out pattern for enrichment provider routing. A Snowflake-access mechanism that mirrors that pattern compounds rather than diverges.
- **Cross-repo coordination cost.** `brite-data-platform` is owned by Corinne (GTM Intelligence project). Any mechanism that requires changes in that repo adds coordination overhead and slows the marketing plugin's iteration cadence.
- **GA posture** ([ADR-009](009-sf-capability-adoption.md) check 5). Whatever path we pick must be production-ready today, not contingent on a beta or pilot.

## Decision

The marketing plugin will access Snowflake audience views via a **`snow` CLI wrapper script** at `plugins/marketing/scripts/snowflake/query_audience.py`, invoked from skill code via `Bash` and credentialed through `bw-run.sh`. **Option B is selected; Options A and C are rejected** as analyzed below.

### Wrapper contract

The wrapper accepts a view name (validated against the audience-view catalog from [BC-11927](https://linear.app/brite-nites/issue/BC-11927)), optional WHERE predicate, optional LIMIT, and emits JSON-lines on stdout — one record per row of the view. Schema mirrors the audience view's column shape per [BC-11927](https://linear.app/brite-nites/issue/BC-11927). Errors return non-zero exit + structured stderr JSON (mirrors the σ3 soft-fail pattern from [ADR-015](015-gtm-sigma3-sf-campaign-sync.md) so callers can act on the error without parsing prose).

### Invocation pattern

Skill code invokes via:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh \
  SNOWFLAKE_USER=marketing-plugin-snowflake-user \
  SNOWFLAKE_PASSWORD=marketing-plugin-snowflake-password \
  SNOWFLAKE_ACCOUNT=marketing-plugin-snowflake-account \
  -- \
  python ${CLAUDE_PLUGIN_ROOT}/scripts/snowflake/query_audience.py \
    --view audience_commercial_outreach \
    --limit 5000
```

Exact Bitwarden field names will be ratified in the BC-11929 implementation. The `bw-run.sh` shape is the load-bearing contract; field names are an implementation detail.

### Credential canon ([ADR-010](010-plugin-secret-config-canon.md))

Snowflake credentials live in Bitwarden under fields prefixed `marketing-plugin-snowflake-*`. `bw-run.sh` exports them as OS env-vars for the wrapper's duration only — no plaintext on disk, no `.mcp.json` interpolation, no `userConfig` substitution.

### Audience-view allowlist

The wrapper validates view names against a static allowlist generated from [BC-11927](https://linear.app/brite-nites/issue/BC-11927) (`plugins/marketing/references/audience-views.md`). Operators cannot pass arbitrary SQL or arbitrary view names — only views that have been ratified into the catalog by Corinne (GTM Intelligence owns view design). This is the SQL-injection guardrail for an operator-passed argument that flows into a database call.

## Consequences

**Positive.**

- **No new MCP.** Marketing plugin stays at 5 plugin-level MCPs. The MCP-cap measurement gauntlet from [`tam-map-port-policy.md`](../research/tam-map-port-policy.md) § 1 doesn't have to run.
- **Pattern reuse.** Mirrors the `brite_cli` enrichment shell-out from [ADR-008](008-tam-mapping-enrichment-pluggability.md). Skill authors who've internalized that pattern transfer the mental model directly.
- **Credential discipline.** [ADR-010](010-plugin-secret-config-canon.md)'s `bw-run.sh` broker handles credential injection. No env-var sprawl, no `userConfig` interpolation surprises.
- **No cross-repo change.** `brite-data-platform` is not modified. Iteration cadence on the marketing plugin is decoupled from GTM Intelligence's roadmap.
- **Allowlist-bounded surface area.** Operators cannot pass arbitrary SQL; the catalog ([BC-11927](https://linear.app/brite-nites/issue/BC-11927)) gates which views are reachable. Skills cite `--view <name>`, not `--sql <query>`.

**Negative.**

- **Bash-shelled command boundary.** Skill code reads JSON-lines from a subprocess instead of typed tool returns. Error handling is `exit code + stderr JSON` instead of structured tool errors. Mitigated by σ3-style stderr-JSON contract; not eliminated.
- **`snow` CLI as a developer dependency.** The wrapper assumes `snow` is installed on the operator's machine. Already true for the data-platform team (BC-1838 / BC-2308 / BC-2314 all reference it), but introduces a setup step for first-time marketing-plugin users who haven't onboarded to Snowflake.
- **No tool-schema surface for the LLM.** A Snowflake MCP would advertise per-view tool schemas to the LLM, giving discoverability. The CLI wrapper hides those views behind a single `--view <name>` argument — the LLM relies on `audience-views.md` for catalog awareness.

**Future work.**

- If the audience-view catalog grows beyond ~10 views OR if a Snowflake MCP server lands in the GA `@snowflake/mcp` package (currently community-only via `snowflake-labs/mcp-server-snowflake`), this ADR may be revisited under the [ADR-009](009-sf-capability-adoption.md) six-check framework. A measured threshold: **once a session routinely makes >2 Snowflake calls** (e.g., when `prospect-temporal-gate` consumes the same query layer), the per-invocation cold-start cost of the CLI wrapper (`bw-run.sh` unlock + `snow` bootstrap, ~1.5–5s amortized over zero calls today) inverts the MCP-vs-CLI tradeoff and an MCP becomes the right answer.
- A future `prospect-temporal-gate` enhancement could reuse the wrapper for direct golden-record state lookups (e.g., "does this domain appear in `dim_companies`?"), avoiding the EB-workspace round-trip.
- If [BC-11929](https://linear.app/brite-nites/issue/BC-11929) eval tests surface cost-gate or pagination pain that the CLI shell-out makes hard to manage, the wrapper can be promoted to an MCP in a follow-up without breaking the skill's `--snowflake-audience` contract.
- **Add CI lint** for `audience-views.md` ↔ `brite-data-platform/main` drift detection (planned `/marketing:audit-views` command, gated on [BC-11856](https://linear.app/brite-nites/issue/BC-11856) drift-detection patterns). Eliminates the manual coordination overhead between the marketing plugin and GTM Intelligence projects.
- **Extract catalog to typed data file** (`audience-views.yaml`/`.json`) so the wrapper + skill don't parse markdown at runtime. Tracked in [BC-11929](https://linear.app/brite-nites/issue/BC-11929) follow-up.

**Logging discipline.** The wrapper at `plugins/marketing/scripts/snowflake/query_audience.py` MUST NOT log `os.environ` or any subset of it on error paths. Stderr output is restricted to a structured JSON envelope containing only `view`, `where`, `limit`, `query_hash`, `error_code`, and `error_detail`. Snowflake credentials never appear in any log stream. (Defensive-logging idioms that dump environments on uncaught exceptions are explicitly prohibited.)

## Alternatives Considered

### Option A — Snowflake MCP server (REJECTED)

A community `snowflake-labs/mcp-server-snowflake` package exists; a bespoke MCP wrapper around `snow` is also feasible.

**Pros.** First-class tool integration; matches the existing `salesforce` MCP pattern; uniform tool surface for skills; per-view tool schemas give the LLM discoverability.

**Cons (decisive).** Adding the 6th plugin-level MCP triggers the [`tam-map-port-policy.md`](../research/tam-map-port-policy.md) § 1 measurement gauntlet: cold-session baseline + re-baseline + `< 2s` startup-latency delta + `< 500 tokens` context-budget delta. The measurement itself is non-trivial (a half-day's work), and historically the marketing plugin's MCPs are toolset-heavy — the 6th may not pass. Until [BC-11929](https://linear.app/brite-nites/issue/BC-11929) has a single audience-view consumer, the MCP's tool surface is a single tool (`run_query`) that wraps a single view, which is exactly the kind of MCP the [ADR-009](009-sf-capability-adoption.md) check 4 (Toolset Breadth) is designed to reject.

The community `snowflake-labs/mcp-server-snowflake` is **not GA** as of 2026-05-28 — it's a community-maintained package. [ADR-009](009-sf-capability-adoption.md) check 5 (GA Gate) rejects non-GA tooling. A bespoke MCP avoids the GA gate but multiplies the implementation cost.

Revisit if: a GA Snowflake MCP ships, OR the audience-view catalog grows past ~10 views so per-view discoverability becomes load-bearing.

### Option C — HTTP gateway via `brite-data-platform` service (REJECTED)

`brite-data-platform` could expose an HTTP endpoint that returns audience-view rows in JSON. The marketing plugin would call this endpoint via `Bash` + `curl` or via a future HTTP MCP.

**Pros.** Decouples credentials (the service holds them, the plugin never sees Snowflake auth); centralizes audience-view access control + rate limiting; service-layer integration matches the [ADR-009](009-sf-capability-adoption.md) check 6 pattern for data-platform consumption.

**Cons (decisive).** No service exists today. Standing one up — with auth, deployment, monitoring, on-call — is a multi-issue effort that blocks [BC-11929](https://linear.app/brite-nites/issue/BC-11929) and pulls Corinne into the marketing plugin's critical path. The credential decoupling benefit is real but not yet load-bearing: `bw-run.sh` already gives us a clean credential boundary.

Revisit if: (a) golden-record consumption surfaces beyond the marketing plugin (e.g., revops, recruiting) and a shared service becomes the cheapest integration, OR (b) a security/compliance review surfaces a reason to remove Snowflake credentials from operator machines entirely.
