# Brite Enrichment MCP — Wrapper Design Findings

**Linear issue:** [BC-5536](https://linear.app/brite-nites/issue/BC-5536/research-brite-enrichment-mcp-wrapper-design)
**Status:** Draft — research in progress (Corinne, 2026-05-14)
**Decision-gating:** [BC-5537](https://linear.app/brite-nites/issue/BC-5537) scaffold + [BC-5538](https://linear.app/brite-nites/issue/BC-5538) production + cross-repo milestone `M49: Brite Enrichment MCP Enablement` in Brite Enterprise Data Platform.

## Context

This document decides the architecture for a net-new MCP server wrapping Brite's custom enrichment CLI (`services/enrichment/cli.py` in `Brite-Nites/brite-data-platform`, 9 subcommands, 14 callable provider adapters). The MCP becomes the integration surface five marketing skills/commands already expect — replacing the current state where each consumer either shells to Bash + a Python script (the `blitz_waterfall` path in list-building / tam-mapping) or falls through gracefully because no MCP exists yet (situation-mining, icp-scoring, launch-campaign).

Clay was deprecated 2026-04-14. The Brite enrichment engine is the replacement. ADR-008 (`docs/decisions/008-tam-mapping-enrichment-pluggability.md`) already froze the input/output contract and the typed-error names this MCP must honor. ADR 2d prohibits skills from assuming local clones, so an MCP server (not a shared library) is the right integration surface.

This research produces decisions only. Code lands in BC-5537/5538 and the M49 follow-ups.

## How to read this file

Each Research Question has its own section with: (1) the question framed in plain language, (2) the options considered, (3) the chosen answer with citations to source files (path + line range) or external URLs from the External References appendix. The **Decision Memo** at the bottom collects all 10 decisions into a single page for BC-5537/5538 executors. The **Scaffold Tool List** names the 2–3 concrete tools the MVP ships. The **v2 Deferrals** section names what was deliberately punted.

External URL citations resolve through the companion **`brite-enrichment-mcp-findings-url-brief.md`** in this directory, which contains verbatim quotes from the 14 External References in BC-5536. Inline citations of the form `[URL N]` map to that brief's URL list.

---

## RQ1 — Language and framework

**Question.** Should the MCP server be written in **Python (FastMCP)** or **Node (TypeScript SDK)**? What are the maintenance / team-fluency / import-vs-subprocess tradeoffs?

**Options considered.**

| | Python FastMCP | Node TS SDK |
|---|---|---|
| **Engine integration** | `from enrichment.flows.batch_waterfall import run_batch_enrichment` — direct import, shared memory, shared Pydantic models, shared error types | Must `subprocess.spawn("python", ...)` to the CLI or stand up a Python sidecar (e.g., FastAPI) for the MCP to call over HTTP |
| **In-house precedent** | `brite-data-platform/tools/fivetran-mcp/server.py` (290 lines, PEP 723 header, `@mcp.tool()` decorators, `mcp.run(transport="stdio")`) | `plugins/marketing/scripts/tam-map/aiark-mcp.js` (144 lines) + `discolike-mcp.js` (120 lines) — both use `setRequestHandler` builder pattern with hand-rolled JSON Schema |
| **SDK ergonomics** | "The FastMCP server is your core interface to the MCP protocol" [URL 4 — modelcontextprotocol/python-sdk]. Decorator-driven (`@mcp.tool()`, `@mcp.resource()`, `@mcp.prompt()`). Type hints become tool schemas automatically. FastMCP "powers 70% of MCP servers across all languages" [URL 5 — gofastmcp.com] | Builder pattern with `new McpServer(...)` + `registerTool()` + Zod schemas [URL 6 — typescript-sdk]. v2 is "pre-alpha, development branch"; v1.x recommended for production |
| **Team fluency** | `services/enrichment/` is 100% Python; engineers already maintain it. Pydantic models are already the lingua franca for the contract surfaces this MCP must honor. | The two existing Node MCPs are vendored from `Revgrowth1/tam-map@9f5c72e74b` (upstream maintainer), not Brite-authored. No Brite engineer actively maintains Node MCP code today. |
| **Engine-contract conformance (RQ10)** | Whatever ADR-008 contract adapter exists, it can be a Python module imported by both the MCP AND `services/enrichment/cli.py` directly — single source of truth, parity-testable with shared pytest. | The adapter would have to live in Python (the engine side) regardless; Node MCP would translate the engine's JSON output a second time. Two translation layers, two parity surfaces. |
| **Reference servers** | Official `modelcontextprotocol/servers` repo is **TypeScript 69.3% / Python 19.2%** [URL 7] — Node has more public examples to crib from | Same as left. |
| **Maintenance horizon** | Same Poetry environment as the engine; `poetry add mcp` and we're done. CI already runs `poetry run pytest` on Python 3.13. | Requires a separate `package.json`, separate CI, separate test runner. Increases the bus-factor surface area. |

**Choice.** **Python FastMCP.**

Three reasons, ordered by weight:

1. **Direct import beats subprocess for a process-bound engine.** Every enrichment call needs to (a) read env vars, (b) load YAML recipes, (c) connect to Snowflake, (d) hit one-or-more provider APIs, (e) write back to Snowflake. In a Python MCP these are function calls inside the same process; in a Node MCP every call is a subprocess.spawn (~50–200ms cold start to start the Python interpreter, parse the CLI argparse, load Poetry deps) or an HTTP hop to a sidecar Brite would have to operate. Direct import also lets the MCP surface typed errors as typed errors (RQ10) instead of as parsed stderr.
2. **Fivetran MCP is the established in-house pattern for this exact shape.** `tools/fivetran-mcp/server.py` is the only Brite-authored MCP today; the aiark/discolike MCPs are vendored from upstream and Brite does not edit them in place. Choosing Python FastMCP matches the precedent for Brite-authored MCPs and concentrates Node know-how on the vendored-only surface.
3. **The contract adapter is Python regardless.** ADR-008 names `EnrichmentQuotaExceededError`/`EnrichmentAuthError`/`EnrichmentNetworkError` as the typed-error contract. These types have to be defined in Python because that's where the providers throw (per RQ10). A Python MCP imports them as-is. A Node MCP has to re-define string-keyed error codes and translate them at the JSON-RPC boundary — adding a translation layer without removing the Python one underneath it.

**Constraint.** Use `mcp>=1.0` (the official Python SDK, which incorporates FastMCP 1.0 as of 2024 per [URL 5]). Do not adopt the standalone FastMCP 2.x project as a dependency unless we hit a specific feature gap in the SDK — adding a second framework increases drift risk. Match the Fivetran MCP's PEP 723 inline-script header for dependency declaration so the MCP can be invoked via `uv run --script` with no separate venv setup, mirroring the established pattern.

**Citations.**
- `tools/fivetran-mcp/server.py:1-7` (PEP 723 header), `:26` (`FastMCP("fivetran")`), `:32-41` (`_get_credentials`), `:290` (`mcp.run(transport="stdio")`) — in-house Python FastMCP precedent (290 lines total).
- `plugins/marketing/scripts/tam-map/aiark-mcp.js:43-48` (SDK import), `:82-111` (tool registration), `:143-144` (stdio transport) — Node precedent for comparison.
- [URL 4 — github.com/modelcontextprotocol/python-sdk] — official Python SDK; FastMCP is the high-level API.
- [URL 5 — gofastmcp.com/getting-started/welcome] — "FastMCP 1.0 was incorporated into the official MCP Python SDK in 2024."
- [URL 6 — github.com/modelcontextprotocol/typescript-sdk] — TypeScript SDK; v2 pre-alpha, v1.x current.
- [URL 7 — github.com/modelcontextprotocol/servers] — language mix of official reference servers.

## RQ2 — Transport

**Question.** Should the MCP use **stdio** (per-session subprocess) or **HTTP** (vendor-style remote service, like Email Bison)? Implications for credentials, auth, scaling, install requirements?

**Options considered.**

| | stdio | HTTP (Streamable HTTP) |
|---|---|---|
| **Spec guidance** | Verbatim: **"Clients SHOULD support stdio whenever possible."** [URL 2 — modelcontextprotocol/specification/transports] | Streamable HTTP supersedes HTTP+SSE from protocol version 2024-11-05 [URL 2]. SSE is deprecated; Claude Code docs say "Use HTTP servers instead, where available" [URL 12]. |
| **Credentials** | Verbatim from MCP auth tutorial: **"For MCP servers using the STDIO transport, you can use environment-based credentials… Because a STDIO-built MCP server runs locally, it has access to a range of flexible options when it comes to acquiring user credentials that may or may not rely on in-browser authentication and authorization flows."** [URL 3] | "OAuth flows… are designed for HTTP-based transports where the MCP server is remotely-hosted." [URL 3] HTTP needs OAuth + token-refresh + 401/403 handling, or `${ENV_VAR}` header substitution at spawn time (Email Bison pattern). |
| **Security surface** | None — single-process tree owned by the developer | Spec mandates: "Servers **MUST** validate the `Origin` header on all incoming connections to prevent DNS rebinding attacks"; "When running locally, servers **SHOULD** bind only to localhost (127.0.0.1)"; "Servers **SHOULD** implement proper authentication for all connections." [URL 2] |
| **Reconnection** | Claude Code does NOT auto-reconnect stdio servers — "Stdio servers are local processes and are not reconnected automatically." [URL 12] | Auto-reconnect with exponential backoff: "up to five attempts, starting at a one-second delay and doubling each time." [URL 12] |
| **Multi-developer scaling** | Each developer runs their own process. 14 provider keys live in their own env (or Bitwarden vault). No shared rate-limit accounting. | Single backend serves all developers. Shared rate-limit accounting, shared cost tracking, observable in one place. Brite has to operate the service. |
| **Cold-start cost** | ~50–200ms (Python interpreter + Poetry deps + Snowflake connection). Acceptable inside a single session because the process persists. | Persistent service — zero cold-start per call. |
| **Install requirements** | Developer needs `uv` (already installed on Brite dev machines per `docs/python-pipeline-services.md`). PEP 723 header handles deps. | Developer needs nothing; just the URL + token. Brite needs an operated HTTP service (deploy target = RQ4). |
| **In-house precedent** | Fivetran MCP (`mcp.run(transport="stdio")` at `server.py:290`), aiark/discolike (`StdioServerTransport()`), bw-run.sh credential broker — all stdio | Email Bison (vendor-hosted, `Authorization: Bearer ${EMAILBISON_*_TOKEN}` header substitution per `plugins/marketing/.mcp.json`), Linear MCP, Context7 — all HTTP, all third-party |
| **Brite-authored precedent** | Yes — Fivetran | No — every HTTP MCP currently in use is a third-party vendor service |

**Choice.** **stdio.**

Four reasons, ordered by weight:

1. **The credentials decision (RQ5) is dramatically simpler on stdio.** Brite has 14 provider API keys today, each already stored as a Bitwarden vault item (matching the `bw-run.sh` broker pattern used by aiark / discolike / spider MCPs). Stdio lets these be exported into the child process at spawn time with one line per provider. HTTP would force a decision: either (a) Brite operates a per-developer secret-management service (expensive overhead), (b) Brite federates each developer's Bitwarden vault into the HTTP service (defeats the purpose of vault per-user separation), or (c) Brite operates a service-account model where the MCP holds Brite-owned credentials, which loses per-developer cost attribution. The MCP spec authors call this out as the design intent of the stdio/HTTP split [URL 3].
2. **No HTTP service to operate.** Choosing HTTP forces RQ4 to pick a deploy target (vendor-hosted is irrelevant here — the engine IS the vendor; per-developer local; central Brite service). Two of those are still local processes (just with HTTP framing on top, which is strictly worse than stdio per the spec). The third — central Brite service — adds an entire operational surface (uptime, scaling, observability, secret rotation, deploy pipelines) for a problem that stdio solves with zero infrastructure.
3. **The auto-reconnect "advantage" of HTTP doesn't apply here.** HTTP auto-reconnect [URL 12: "up to five attempts, starting at a one-second delay and doubling each time"] is valuable when the server is a remote service that can transiently disconnect for reasons unrelated to the client. A stdio MCP only disconnects if the local subprocess crashes — at which point auto-reconnect would just spin up another crashing process. The right repair is `/reload-plugins` (or session restart), which stdio supports cleanly today.
4. **Spec normative guidance is unambiguous.** "Clients SHOULD support stdio whenever possible" is the strongest normative phrasing in the transport spec for our class of use case (local engine, single developer per process, env-var credentials).

**Constraint.** Register the MCP in `plugins/marketing/.mcp.json` with `"type": "stdio"`. Wrap the command in `bw-run.sh` to inject the 14 provider API keys + Snowflake auth env vars from Bitwarden — matching the existing aiark / discolike / spider registration pattern. Use `${CLAUDE_PLUGIN_ROOT}` for the script path (substitutes at spawn time per [URL 14], no default needed in plugin scope per [URL 12]).

**Non-decision.** This research does not preclude a future HTTP migration. If a later need arises (shared rate-limit accounting, cross-developer observability, Snowflake Cortex Agents MCP-style vendor hosting of the engine itself), the FastMCP SDK supports transport swap with no business-logic changes — `mcp.run(transport="stdio")` becomes `mcp.run(transport="http", port=…)`. Migration cost would be the new operational surface, not the MCP code. Flagged for v2 deferrals.

**Citations.**
- [URL 2 — modelcontextprotocol.io/specification/2025-03-26/basic/transports] — "Clients SHOULD support stdio whenever possible"; Streamable HTTP security mandates.
- [URL 3 — modelcontextprotocol.io/docs/tutorials/security/authorization] — env-based creds for stdio, OAuth for HTTP.
- [URL 12 — code.claude.com/docs/en/mcp.md] — transport options in Claude Code, reconnection behavior.
- [URL 14 — code.claude.com/docs/en/plugins-reference.md] — `${CLAUDE_PLUGIN_ROOT}` substitution semantics.
- `tools/fivetran-mcp/server.py:290` (`mcp.run(transport="stdio")`) — in-house stdio precedent.
- `plugins/marketing/scripts/bw-run.sh` — Bitwarden credential broker pattern.
- `plugins/marketing/.mcp.json:27-45` — aiark stdio + bw-run.sh registration shape.

## RQ3 — Tool surface prioritization

**Question.** Map each of the 9 CLI subcommands to: (a) consuming skill(s), (b) mutation vs read, (c) confirmation-gate candidacy. Pick 2–3 for the scaffold MVP that unblocks [BC-2717](https://linear.app/brite-nites/issue/BC-2717) (list-building).

**Critical reframe upfront.** MCP tools are **not** required to be 1:1 wrappers of CLI subcommands. The MCP is free to compose engine primitives into surfaces shaped to the consumer contract (ADR-008's `EnrichmentInput → EnrichmentOutput`). Three tool types are available:

- **Type A — 1:1 CLI wrappers.** Direct exposure of a single CLI subcommand. Cheapest to build, but the CLI commands print rather than return structured data (verified at `services/enrichment/cli.py`; `find_phone.find_phone()` returns `None` and prints to stdout per `scripts/find_phone.py:69-113`), so wrapping verbatim is not useful.
- **Type B — Composite tools.** Orchestrate multiple engine primitives behind one tool name. Example: `enrich_contacts(domain, title_seed)` internally runs `discover-people` (Apollo People Search) then `run-recipe work_email_waterfall` (IcyPeas → Prospeo → LeadMagic) then `run-recipe phone_discovery` (LeadMagic → Prospeo → Datagma), returning the ADR-008 output shape.
- **Type C — Novel tools.** Surfaces that don't exist in the CLI at all. Example: `query_entity(domain)` reads `dim_companies` + `ENRICHMENT_ENTITIES` directly from Snowflake; `check_enrichment_health` synthesizes a status object from `cost_ops` + recipe registry + Snowflake reachability.

The MVP picks one of each type, weighted by day-1 consumer satisfaction (from RQ9 audit).

**9 CLI command mapping.**

| # | CLI subcommand | Line range | Consuming skill(s) | Mutation? | Gate candidacy | MVP? |
|---|---|---|---|---|---|---|
| 1 | `run-recipe` | `cli.py:54-105` | list-building, tam-mapping, launch-campaign (future BounceBan swap) | **Mutation** (Snowflake writes + provider credit) | **Yes** — bulk-over-N; per-row billable | v2 (exposed as part of `enrich_contacts` composite for MVP; raw exposure in BC-5538) |
| 2 | `ingest-people` | `cli.py:168-217` | list-building (CSV imports), data-enrichment (BC-2727) | **Mutation** (Snowflake writes; no provider credit) | Yes — bulk writes | v2 (rarely needed via MCP today; manual CLI works) |
| 3 | `ingest-companies` | `cli.py:274-338` | list-building | **Mutation** (Snowflake writes) | Yes — bulk writes | v2 |
| 4 | `ingest-company-csv` | `cli.py:461-514` | list-building, data-enrichment | **Mutation** (Snowflake writes) | Yes — bulk writes | v2 |
| 5 | `discover-people` | `cli.py:340-395` | list-building, tam-mapping | **Mutation** (Snowflake writes + Apollo credit) | **Yes** — bulk-over-N; per-row billable | v2 (exposed via `enrich_contacts` composite for MVP) |
| 6 | `check-spend` | `cli.py:397-404` | all (cost-aware skills) | Read | No | v2 (synthesized into `check_enrichment_health` for MVP) |
| 7 | `list-recipes` | `cli.py:406-424` | all (recipe introspection) | Read | No | v2 (synthesized into `check_enrichment_health` for MVP) |
| 8 | `validate-recipes` | `cli.py:426-459` | data-enrichment debugging | Read | No | v2 (developer-only) |
| 9 | `consolidate-clay` | `cli.py:516-544` | (Clay is deprecated 2026-04-14) | Read (filesystem only) | No | **Drop** — Clay deprecated; will not be wrapped |

**Three MCP tools the MVP ships.**

1. **`check_enrichment_health` (Type C — novel).** Synthesizes a single read-only status object from three engine primitives: (a) `cost_ops.check_enrichment_budget()` for budget status / daily spend / block flag (`operations/cost_ops.py:64-102`), (b) `recipes/parser.py` for "N recipes loaded" + recipe-name list (subsumes `list-recipes`), (c) a Snowflake `SELECT 1` round-trip via `shared/snowflake_client.execute_query()`. Returns `{ok: bool, budget: {…}, recipes: [name…], snowflake_reachable: bool, providers_configured: [name…]}`. No provider call, $0 cost. **Satisfies the availability-check requirement of ADR 2c** (see RQ7).

2. **`enrich_contacts` (Type B — composite).** ADR-008 contract: `EnrichmentInput → EnrichmentOutput[]`. Input: `domain` (required), `company_name` (required), optional `linkedin_url` / `title_seed` / `geo`. Output: list of `{email, first_name?, last_name?, mobile?, phone?, title?, linkedin_url?, confidence_score, source, provider_raw?}` per ADR-008 lines 92-112. Internal flow: if no `title_seed`, return early with a helpful error (Apollo People Search needs titles); otherwise (1) `discover-people` to find candidate decision makers at the company, (2) `run-recipe work_email_waterfall` per discovered person, (3) `run-recipe phone_discovery` per person with an email. **Confirmation-gate candidate** — see RQ8.

3. **`query_entity` (Type C — novel).** Read-only `dim_companies` / `ENRICHMENT_ENTITIES` lookup by domain or `entity_id`. Returns the canonical company + linked person rows from the golden record. $0 provider cost. **Satisfies** (a) list-building's "is this lead already in our DB?" pre-flight, (b) situation-mining's firmographic-fallback (when populated), (c) the icp-scoring activation-day need without forcing icp-scoring's `allowed-tools` registration today. Backed by RQ10 follow-up issue in M49 — `query_entity_by_domain` helper does not exist in `shared/snowflake_client.py` today (verified via grep).

**Why not a 4th tool.** Verification mandates "exactly 2–3 tools" in the Scaffold Tool List. The candidates for a hypothetical 4th — `check_spend` (collapsible into `check_enrichment_health`), `lookup_person` (M49 follow-up depends on `find_phone` structured-return refactor; not engine-ready), `list_recipes` (debug surface, not a consumer need) — all either fold into the three above or block on M49 work that BC-5538 should pick up.

**Why three, not two.** The minimum viable set is `enrich_contacts` + `check_enrichment_health` (RQ7 mandates availability check). But adding `query_entity` is high-leverage because (a) it's the cheapest tool to build (a single read query against Snowflake), (b) it unblocks three consumers — situation-mining (firmographic fallback per RQ9), icp-scoring's future activation, launch-campaign's future BounceBan swap — for ~10% more work, and (c) it forces the M49 `query_entity_by_domain` helper to land in `shared/snowflake_client.py` so BC-5538 doesn't have to introduce both the helper AND the tool in one PR.

**Confirmation-gate decisions deferred to RQ8.** Three of these tools are read-only (`check_enrichment_health`, `query_entity`) and need no gates. `enrich_contacts` is mutation + billable; RQ8 picks the threshold.

**Citations.**
- `services/enrichment/cli.py:54-544` — 9 subcommands inventoried (line ranges in table above).
- `services/enrichment/scripts/find_phone.py:69-113` — `find_phone()` returns `None`, prints; confirms CLI is print-oriented for interactive use, not return-structured for programmatic callers.
- `services/enrichment/operations/cost_ops.py:64-102` — `check_enrichment_budget()`.
- `services/shared/snowflake_client.py` — `execute_query` / `execute_dml` exist; no `query_entity_by_domain` helper (per RQ10 follow-up).
- ADR-008 § Input/Output schemas at `docs/decisions/008-tam-mapping-enrichment-pluggability.md:76-112` — the contract `enrich_contacts` must match exactly.
- RQ9 consumer audit (below) — day-1 satisfaction analysis.
- [URL 8 — servers-archived/sqlite] — Type A/B/C tool framing inspired by SQLite reference's split of `read_query` vs `write_query` vs schema-introspection tools.

## RQ4 — Deploy target

**Question.** Where does the MCP source code live, and how does it get on each developer's machine? The issue framed three options: (a) vendor-hosted HTTP, (b) per-developer local process via `uvx` / `npx`, (c) central Brite service the MCP routes to.

**Reframe after RQ1 + RQ2.** RQ2 picked stdio (per-developer local subprocess), which rules out (c) central Brite service — that would require re-opening RQ2 to pick HTTP. RQ1 picked Python with direct engine import (`from enrichment.flows.batch_waterfall import …`), which means the MCP source code must be physically co-located with `services/enrichment/` somehow. Option (a) is unavailable for the same reason — no vendor hosts Brite's engine.

The remaining question is binary: **which repo does the MCP source file live in, and how does the plugin's `.mcp.json` reach it?**

**Options considered.**

| | A. MCP lives in `brite-data-platform` | B. MCP lives in `brite-claude-plugins` |
|---|---|---|
| **Co-location** | Next to the engine it wraps. `tools/enrichment-mcp/server.py` mirrors the Fivetran MCP precedent at `tools/fivetran-mcp/server.py` | Next to the skills it serves. `plugins/marketing/scripts/enrichment-mcp/server.py` mirrors the aiark/discolike precedent |
| **Engine access** | Direct Python import — same repo, same Poetry venv, shared models | Cannot import — different repo. Must subprocess the CLI (defeats RQ1) or stand up an HTTP shim (defeats RQ2) |
| **Contract-adapter location (RQ10)** | Whatever contract-translation code is needed lives next to the engine that produces the data. Parity tests run in the engine's CI. Single source of truth. | Translation code drifts from the engine in a separate repo. Two CI pipelines must agree on the contract shape. |
| **How `.mcp.json` reaches it** | `uvx --from git+https://github.com/Brite-Nites/brite-data-platform@<sha>#subdirectory=tools/enrichment-mcp brite-enrichment-mcp` — uv resolves PEP 723 deps, caches per-session. No local clone required. | `node ${CLAUDE_PLUGIN_ROOT}/scripts/enrichment-mcp/server.js` — but the engine is Python, so this means subprocess + JSON-over-stdout. |
| **In-house precedent** | Fivetran MCP (`tools/fivetran-mcp/server.py`, 290 lines, `mcp.run(transport="stdio")` at `:290`, PEP 723 header at `:1-7`) — proves the pattern works | aiark/discolike — but they wrap external HTTP APIs, not a co-located Python engine |
| **ADR 2d compliance** | The *MCP server* is a per-developer install, not a per-skill-invocation file read. ADR 2d targets skills, not MCPs. Plus, `uvx --from git` doesn't require a local clone — it pulls from GitHub like any other dep. | Trivially compliant — but irrelevant if RQ1 is honored. |
| **Update behavior** | Pinned to a git SHA in `.mcp.json` → reproducible across developers; intentional `gh repo sync` to update. Branch refs work for fast iteration during BC-5537. | Plugin updates carry the MCP code, but the engine code lives elsewhere — version mismatches become possible (plugin says contract v3, engine still on v2). |
| **First-time-setup friction** | Developer needs `uv` (already installed per `docs/python-pipeline-services.md` and `docs/tooling.md`). Snowflake creds (already a Brite dev prereq). Provider keys from Bitwarden (via `bw-run.sh`). Zero net-new install. | Same as left — bw-run.sh, env vars — but only if we accept subprocess overhead per call. |

**Choice.** **Option A — MCP source lives in `brite-data-platform/tools/enrichment-mcp/server.py`, invoked from `brite-claude-plugins/plugins/marketing/.mcp.json` via `uvx --from git+https://github.com/Brite-Nites/brite-data-platform@<pinned-sha> brite-enrichment-mcp`.**

Three reasons:

1. **Direct import is the entire reason RQ1 picked Python.** Putting the MCP in a different repo than the engine forces subprocess or HTTP, both of which RQ1 already rejected. Once you accept the direct-import constraint, the MCP must live in `brite-data-platform`.
2. **The contract adapter lives next to the engine (RQ10 preview).** Whatever shape-translation code is needed to honor ADR-008's `EnrichmentInput → EnrichmentOutput` contract — typed errors, confidence-score mapping, ordered output ranking — has to be where the providers throw and the Pydantic models live. That's `services/enrichment/`. The MCP either imports that adapter directly (Option A) or duplicates it across a repo boundary (Option B).
3. **Fivetran MCP already proved the pattern works.** A Brite-authored Python FastMCP server with stdio transport, env-var credentials, and PEP 723 deps is sitting in `brite-data-platform/tools/fivetran-mcp/server.py` today. Imitating it costs zero design risk.

**Constraints.**

- **Pin to a git SHA, not a branch.** `.mcp.json` invokes `uvx --from git+https://github.com/Brite-Nites/brite-data-platform@<sha>#subdirectory=tools/enrichment-mcp brite-enrichment-mcp`. Pinning prevents silent contract drift between developer machines. The plugin must be re-released to bump the SHA — explicit, auditable.
- **Publish a `pyproject.toml` entry point inside `tools/enrichment-mcp/`.** Define `[project.scripts]` so `uvx` can resolve `brite-enrichment-mcp` to the FastMCP `main()`. Without this, `uvx` can't find an executable.
- **The MCP is its own uv project.** It declares `mcp>=1.0` as a dep and `enrichment` (the engine package) as a path dep within the same repo. This isolates the MCP's deps from the broader `services/` Poetry env — keeps the dep graph clean and makes `uvx` resolution fast.
- **Developer experience.** Zero net-new install. `uv` is already a Brite dev prereq per `docs/tooling.md`. Snowflake auth and provider env vars are already handled by `bw-run.sh`. The plugin install adds one `.mcp.json` entry; nothing else changes on the developer's machine.

**Tradeoff to flag.** Pinning to a git SHA means engine updates don't auto-propagate to developer machines. A `services/enrichment/` PR that fixes a typed-error bug doesn't take effect until the plugin's `.mcp.json` SHA is bumped and developers re-pull the plugin. This is intentional — deterministic, auditable, no silent contract drift — but it does add a manual step ("when shipping an engine fix that the MCP depends on, also bump the plugin SHA"). Document this in the BC-5538 integration guide alongside the cross-repo blockedBy graph.

**Non-decision.** Whether to also publish `brite-enrichment-mcp` as a versioned PyPI package (vs git-only) is deferred to v2. Git pinning works for our internal-only use case today; PyPI adds release ceremony without solving a current problem.

**Citations.**
- `tools/fivetran-mcp/server.py:1-7` (PEP 723), `:26` (FastMCP instantiation), `:32-41` (env-var credential pattern), `:290` (stdio transport) — in-house precedent for Option A.
- [URL 12 — code.claude.com/docs/en/mcp.md] — Claude Code MCP install patterns, env-var substitution semantics, plugin-scope `${CLAUDE_PLUGIN_ROOT}` behavior.
- [URL 14 — code.claude.com/docs/en/plugins-reference.md] — `mcpServers` schema, plugin update behavior ("hook commands, monitors, MCP servers, and LSP servers keep using the previous version's path until `/reload-plugins`").
- ADR 2d at `docs/designs/outbound-agent-architecture-adrs.md` — "Skills must not assume sibling repos are cloned locally" — clarified as skill-scoped, not MCP-scoped.
- `services/enrichment/cli.py` — the engine surface the MCP imports against.
- `docs/python-pipeline-services.md`, `docs/tooling.md` — `uv` is already a Brite dev prereq.

## RQ5 — Provider credential handling

**Question.** 14 providers means 14 keys (plus Snowflake auth). Three options were framed in the issue: (a) all in `.mcp.json` env vars, (b) MCP reads a Brite secrets service or 1Password / Bitwarden script, (c) per-provider toolset gating so only enabled providers need keys.

**Inventory of secrets the MCP needs.** From `memory/project_brite_enrichment_mcp.md` and `CLAUDE.md`'s `services/.env` references:

- ~13 single-key provider secrets (IcyPeas, Prospeo, LeadMagic, BounceBan, EmailGuard, Serper, Apollo, Findymail, Datagma, PDL, Snov.io, Openmart, plus CUFinder deferred) — one env var each, typically named `<PROVIDER>_API_KEY`
- 1 paired-credential provider (Twilio: account SID + auth token) — 2 env vars
- Snowflake auth bundle (account / user / role / private-key path) — 4 env vars, plus a private-key file on disk

Call it ~15 env vars for the provider tier plus the Snowflake bundle. The literal list of env-var names matches what already exists in `services/.env` (gitignored) and what `services/enrichment/config.py` reads via Pydantic Settings.

**Options considered.**

| | A. Plain env vars in `.mcp.json` | B. Bitwarden broker via `bw-run.sh` | C. Per-provider toolset gating |
|---|---|---|---|
| **Pattern** | `"env": {"<NAME>": "${<NAME>}"}` per secret | `command: ${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh`, with `KEY=<vault-item>` args before `--` | Orthogonal to A/B. MCP starts even with missing keys; tools needing absent providers return `EnrichmentAuthError` |
| **Where the secret lives** | Developer's shell profile (~15 export lines per dev) | Bitwarden vault (Engineering collection) — single source of truth | n/a — augments either A or B |
| **Rotation cost** | Every developer edits `.zshrc` and restarts shell | Rotate in vault; `/reload-plugins` or Claude Code restart picks up new value at next stdio spawn | n/a |
| **Audit trail** | None | Bitwarden access logs | n/a |
| **Crash-log leak risk** | Higher — env present in `printenv` and any crash dump for life of process; `.zshrc` greppable | `bw-run.sh` `exec`-replaces itself with the child and unsets `BW_SESSION` first, so the vault session token is gone; provider env vars are still in the running process (same as A while running) but no broader vault access | n/a |
| **In-house precedent** | Fivetran MCP reads `os.getenv()` directly — but Fivetran is 2 secrets, not 15 | Three production MCPs (aiark, discolike, spider) use this pattern today; documented in `marketing:setup-tam-map` | None yet |
| **First-time setup** | New dev populates ~15 env vars from Bitwarden manually | Plugin install JustWorks™ once `bw login` (already a Brite onboarding step) is done | n/a |
| **Snowflake auth fits** | Yes | Yes — Snowflake env vars can be exported by the broker; the private-key file stays on disk | n/a |
| **Spec guidance** | "For MCP servers using the STDIO transport, you can use environment-based credentials" [URL 3] | Same — `bw-run.sh` produces env-based credentials at exec time | n/a |

**Choice.** **B + C combined: Bitwarden broker via `bw-run.sh` as the credential source, plus per-provider toolset gating so missing keys degrade gracefully.**

Three reasons:

1. **Bitwarden broker is already the in-house pattern.** Three production MCPs in `plugins/marketing/.mcp.json` use `bw-run.sh` today; the broker script is documented in `marketing:setup-tam-map`; new Brite devs already run `bw login` as part of onboarding. Choosing plain env vars would invent a new credential-distribution mechanism that only this MCP uses. 15 secrets is far too many to expect each developer to maintain manually in `.zshrc` — that is where credential rot starts.

2. **Per-provider toolset gating is cheap insurance.** The MCP shouldn't refuse to start because one provider key is missing — that's a brittle DX failure for a 14-provider engine. Most marketing-side use cases hit a 3-provider waterfall (email: IcyPeas → Prospeo → LeadMagic) and don't need all 14. Gating means: at MCP startup, log which providers are configured; when a tool is called that needs an unconfigured provider, return a typed `EnrichmentAuthError` per ADR-008 with the provider name in `cause`. Skills can either retry with a different provider or fall through gracefully (the same pattern situation-mining already implements for the MCP-availability check itself per RQ9).

3. **Defense-in-depth on the vault session.** `bw-run.sh` unsets `BW_SESSION` before `exec "$@"` (verified at `plugins/marketing/scripts/bw-run.sh:139-140`). This prevents the spawned MCP — or any transitive subprocess it spawns — from re-fetching arbitrary vault items beyond what the broker was explicitly told to export. Plain env vars don't carry this guarantee because there's no `bw login` session at all.

**Constraint.** The MCP's `.mcp.json` entry follows the existing broker pattern documented at `plugins/marketing/.mcp.json` and the `bw-run.sh` usage comment at `plugins/marketing/scripts/bw-run.sh:10`:

```json
{
  "type": "stdio",
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh",
  "args": [
    "<ENV_VAR_NAME>=<vault-item-name>",
    "<ENV_VAR_NAME>=<vault-item-name>",
    "... (one row per provider, ~15 rows total)",
    "--",
    "uvx", "--from",
    "git+https://github.com/Brite-Nites/brite-data-platform@<sha>#subdirectory=tools/enrichment-mcp",
    "brite-enrichment-mcp"
  ]
}
```

The literal `KEY=vault-item` rows are scoped to BC-5537 — the executor reads the canonical naming convention from the already-committed `plugins/marketing/.mcp.json` (Spider/aiark/discolike entries) and the Engineering collection in Bitwarden, then mirrors that convention here. Snowflake env vars are sourced from the developer's existing shell profile (`SNOWFLAKE_*`), not Bitwarden — `bw-run.sh` preserves the surrounding shell env per its design. The `.env` mechanism in `services/.env` continues to work for local engine work outside Claude Code.

**Per-provider gating implementation note.** At MCP startup, `ProviderFactory` (already exists at `services/enrichment/providers/factory.py`) enumerates registered providers; the MCP iterates the factory's `enabled_providers()` (new method, small M49 follow-up) and logs the configured-provider list as part of `check_enrichment_health` output (RQ7). When a tool is called that hits an unconfigured provider via a recipe step, the existing waterfall handles fall-through naturally; the MCP just needs to map "all providers in the waterfall returned auth errors" to a typed `EnrichmentAuthError` per ADR-008.

**Tradeoff to flag.** A developer without Bitwarden access (e.g., a new hire mid-onboarding) cannot use the MCP at all — fail-closed. This is the right posture for production credentials but does mean the MCP availability check (RQ7) needs to distinguish "Bitwarden auth failed" from "engine itself is broken." Document in BC-5538 integration guide.

**Citations.**
- [URL 3 — modelcontextprotocol.io/docs/tutorials/security/authorization] — verbatim "For MCP servers using the STDIO transport, you can use environment-based credentials… Because a STDIO-built MCP server runs locally, it has access to a range of flexible options when it comes to acquiring user credentials."
- [URL 12 — code.claude.com/docs/en/mcp.md] — `${VAR}` substitution semantics in `.mcp.json` `command`, `args`, `env`.
- `plugins/marketing/scripts/bw-run.sh:139-140` — `unset BW_SESSION; exec "$@"` defense-in-depth.
- `plugins/marketing/scripts/bw-run.sh:10` — broker usage comment (the canonical `KEY=item -- cmd args` invocation shape).
- `plugins/marketing/.mcp.json` (aiark / discolike / spider entries) — canonical Brite broker-registration shape; source of truth for vault-item naming convention.
- `tools/fivetran-mcp/server.py:32-41` — `_get_credentials()` plain env-var read; precedent for the in-process credential acquisition pattern (still applies inside the MCP after the broker exports the env).
- `services/enrichment/providers/factory.py` — ProviderFactory registry; surface point for per-provider gating.
- ADR-008 § typed errors at `docs/decisions/008-tam-mapping-enrichment-pluggability.md:114-122` — `EnrichmentAuthError` is the contract for "provider not configured" failures.
- `memory/project_brite_enrichment_mcp.md` — confirms `bw-run.sh` is the "established Brite pattern (alternative to .mcp.json env vars)."

## RQ6 — Data flow

**Question.** Does the MCP return JSON inline to the calling skill, or does it write results somewhere (Snowflake via dbt-governed schema, S3, local file)? Per ADR 2e, dbt owns audience views — name the skill ↔ audience-view interface.

**Reframe.** The engine already writes to Snowflake — that's its job, not a decision the MCP makes. The single-writer gold pattern (`RAW.PIPELINE_ENRICHMENT` staging via Python; `dim_people` / `dim_companies` via dbt) is documented in `docs/golden-record-architecture.md` and is not in scope for re-litigation here. The MCP-specific question is: **what does the MCP return to the skill that called it?**

Three things can happen on any tool call:

1. **Engine-side writes happen as a side effect** (existing behavior — `enrich_contacts` logs attempts, writes results, upserts entities into staging) — unchanged from CLI behavior; not an MCP decision.
2. **The MCP returns something to the skill.** Options for that return:
3. **A skill that needs a multi-row result set reads it via an audience view.** This is the ADR 2e interface.

**Options for the return shape.**

| | A. JSON inline (synchronous return) | B. Write to a known location, return a pointer | C. Hybrid — small results inline, large results to S3/Snowflake with a fetch URL |
|---|---|---|---|
| **Spec / reference precedent** | SQLite MCP `read_query` returns array of objects inline [URL 8]; MotherDuck `execute_query` returns inline up to "1024 rows or 50,000 characters" [URL 9]; Snowflake Labs MCP returns SQL results inline [URL 10] | No MCP reference impl I've seen does this; "write somewhere, return URL" is an HTTP / REST pattern, not idiomatic MCP | None in reference impls |
| **Claude Code output budget** | Warning at 10K tokens, default cap 25K, configurable via `MAX_MCP_OUTPUT_TOKENS`, max 500K chars with `_meta["anthropic/maxResultSizeChars"]` [URL 12] | Bypasses the budget but adds a fetch step + storage operation surface | Budget on the tail; pointer protocol on the head |
| **DX / skill ergonomics** | Skill writes `result = mcp__plugin_marketing_enrichment__enrich_contacts(...)` and reads `result["contacts"]` directly. One round-trip, no parsing. | Skill writes `pointer = enrich_contacts(...)`, then `data = read_file(pointer["path"])` or similar. Two round-trips, more code paths. | Skill must branch on response shape — complex skill code |
| **Latency** | Same as engine call | Engine call + (S3 PUT or local fwrite) + skill-side read | Mixed |
| **Failure modes** | If response is too big for budget, MCP must truncate or fail. Caller can't recover. | Storage write can fail independently of engine work. Skill must handle both failure types. | Skill must handle three failure types |

**Choice for `check_enrichment_health` and `query_entity`.** **Option A — JSON inline.** Both tools return small, bounded payloads (health: a few hundred bytes; entity: one company row + ≤N linked-person rows). They fit comfortably under the 25K-token default cap [URL 12].

**Choice for `enrich_contacts`.** **Option A with a hard batch-size cap and `_meta["anthropic/maxResultSizeChars"]: 100000` annotation.** The tool accepts a single `(domain, company_name)` per call — there is no `domains: List[str]` parameter. A skill that wants to enrich N companies calls the tool N times (one per company), letting the agent shape the loop with normal flow control rather than the MCP needing to stream a partial response.

Three reasons for one-call-per-company:

1. **Engine semantics.** Each `enrich_contacts` invocation does `discover-people` (returns ≤5 candidates per the default `people_discovery` recipe) then runs the email + phone waterfalls per candidate. Worst case per call: ~5 candidates × (1 email + 1 phone + metadata) ≈ ~2KB of JSON. Comfortably inline-sized.
2. **Confirmation-gate granularity (RQ8).** Per-company calls let the skill apply the two-call confirmation gate at the natural unit ("you're about to spend ~$0.20 on cellings@hilton.com") instead of inventing a batch threshold inside the MCP.
3. **Failure isolation.** One bad domain (`EnrichmentNetworkError`) doesn't poison an entire batch. The skill handles per-call failures with normal try/except.

A hypothetical `bulk_enrich_contacts` for power-user batch workflows is deferred to v2 (deserves its own RQ when needed; not on the day-1 critical path per RQ9).

**The skill ↔ audience-view interface (ADR 2e).** Per `docs/designs/outbound-agent-architecture-adrs.md` ADR 2e: "Audience views follow the interface contract pattern — the consuming skill defines the contract (Linear issue), the data platform fulfills it (separate `brite-data-platform` issue), and the skill issue is blocked by the dbt issue." Naming convention: `audience_view_<segment_name>` in `models/marts/audience_views/`.

For the MVP, the interface looks like:

1. **Skill needs an audience.** A skill author opens a Linear issue in `brite-claude-plugins` describing the audience contract (which rows, which columns, which filters).
2. **Data platform delivers.** A blocking Linear issue in `Brite Enterprise Data Platform` builds `audience_view_<segment>` as a dbt model. The skill issue's `blockedBy` includes the dbt issue.
3. **Skill consumes via a Snowflake read.** Today, the only way for a skill to read an audience view is the MCP itself — by either (a) calling `query_entity` with specific identifiers known up front, or (b) shelling out to `snow sql` via Bash (rejected by ADR 2c).

**Day-1 gap.** No `query_audience_view(view_name, limit, filters)` tool exists in the MVP. This is a known limitation. The MVP unblocks list-building + tam-mapping (which enrich individual companies, one at a time) and situation-mining (which looks up specific entities). It does not yet unblock the broader "give me the next 100 outbound leads from `audience_view_park_city_facilities_directors`" flow that BC-2727 (data-enrichment skill) will eventually need.

**Deferral, not denial.** `query_audience_view` is the natural BC-5538 addition once an audience view actually ships in `brite-data-platform`. Today there are zero `audience_view_*` dbt models, so adding the tool would be premature. File this as a v2 deferral. Flagging here means BC-5538's scope refinement (Task 6a) is informed by it.

**Constraints on the MCP's return-shape contracts.**

- **All return values are JSON-serializable.** No Python objects, no pickled blobs, no datetime objects (ISO 8601 strings instead).
- **Pydantic models on the inside become `.model_dump_json()` on the wire.** The engine's `EnrichmentResult` and `EnrichmentEntityRecord` Pydantic types are the in-memory representation; the MCP serializes them to JSON before returning. ADR-008 output shape uses snake_case fields throughout (`confidence_score`, `provider_raw`).
- **Errors come back as typed exceptions (RQ10), not as `{ok: false, message: …}` payloads.** The MCP raises `EnrichmentAuthError`, `EnrichmentQuotaExceededError`, `EnrichmentNetworkError`, and FastMCP serializes them into the JSON-RPC error frame per [URL 1] (standard error objects with `code`, `message`, `data`).
- **No engine-side writes happen at MCP startup or in `check_enrichment_health`.** Health checks must be safe to call N times per session without side effects.

**Tradeoff to flag.** If a skill wants to bulk-enrich (>20 companies in one operator request), today's per-call shape forces the agent to issue 20+ tool calls. This may hit Claude Code's per-session tool-call ceiling or feel slow. Mitigation: skills that hit this pattern open a BC-5538 follow-up for `bulk_enrich_contacts`. Don't pre-build for hypothetical scale.

**Citations.**
- [URL 1 — modelcontextprotocol.io/specification/2025-11-25] — JSON-RPC 2.0 error frame; tool responses serialized inline.
- [URL 8 — servers-archived/sqlite] — inline result return precedent for read tools.
- [URL 9 — github.com/motherduckdb/mcp-server-motherduck] — "1024 rows or 50,000 characters by default" inline cap precedent.
- [URL 10 — github.com/Snowflake-Labs/mcp] — Snowflake SQL-tool inline returns.
- [URL 12 — code.claude.com/docs/en/mcp.md] — `MAX_MCP_OUTPUT_TOKENS`, default 25K cap, `_meta["anthropic/maxResultSizeChars"]` up to 500K.
- `docs/designs/outbound-agent-architecture-adrs.md` ADR 2e — audience-view interface contract.
- `docs/golden-record-architecture.md` — single-writer gold pattern (engine writes staging, dbt produces marts).
- `services/enrichment/recipes/people_discovery.yml` — default ≤5-candidate ceiling per discover-people invocation.

## RQ7 — Availability check

**Question.** Which read-only CLI command becomes the MCP availability-check tool per ADR 2c?

**What ADR 2c actually requires.** From `docs/designs/outbound-agent-architecture-adrs.md`: "Skills must include a tool-availability check before mutating, and must not fall back to `Bash(curl)` when an MCP server is unreachable." Canonical existing checks per server:

- **Email Bison:** `get_active_workspace_info` — single HTTP call to vendor
- **Salesforce:** `run_soql_query` with `SELECT Id FROM User LIMIT 1` — single SOQL round-trip, deliberately not `get_username` because that reads stale local auth

The pattern is: **one tool call, one cheap round-trip to the real backend, deterministic boolean-ish output, no provider credit spent.** The point is to prove the MCP is alive AND can talk to its primary upstream, not to comprehensively audit every dependency.

**The enrichment MCP's primary upstream is Snowflake, not the 14 providers.** Three observations:

1. Every meaningful operation (`enrich_contacts`, `query_entity`, budget gating, attempt logging) hits Snowflake. If Snowflake is unreachable, the MCP is functionally dead regardless of provider state.
2. Provider liveness is per-provider and varies independently — a healthy MCP can have BounceBan failing while EmailGuard works fine. A single boolean "providers up?" check would be misleading. Per-provider deep-check exists as a v2 surface (see below).
3. Per RQ5, provider keys are gated at MCP startup. By the time `check_enrichment_health` runs, the "which providers have keys configured" question has a static answer.

**Choice.** The availability-check tool is **`check_enrichment_health`** (already named in RQ3 as the first MVP tool). It is a **novel Type C tool**, not a 1:1 wrap of any single CLI subcommand. It synthesizes from three engine surfaces:

| Source | What it contributes | Engine path |
|---|---|---|
| `services/shared/snowflake_client.execute_query("SELECT 1")` | `snowflake_reachable: bool`. Single cheap round-trip; mirrors the Salesforce ADR 2c precedent. | New 1-line call inside the MCP — no engine change |
| `services/enrichment/recipes/parser.list_recipes()` (currently powers the CLI's `list-recipes` at `cli.py:406-424`) | `recipes: list[str]` (recipe names, capped at 50 to stay inside the JSON-RPC budget) | Direct reuse — existing function |
| `services/enrichment/operations/cost_ops.check_enrichment_budget()` at `cost_ops.py:64-102` | `budget: { used_pct, remaining_usd, block_new_enrichments }` | Direct reuse — existing function |
| `services/enrichment/providers/factory.ProviderFactory.enabled_providers()` (new method, ~5 lines, M49 follow-up) | `providers_configured: list[str]` — env-var presence check only, no provider API call | Small engine add (M49) |

**Return shape (final).**

```jsonc
{
  "ok": true,                                  // true iff Snowflake reachable AND ≥1 recipe loaded AND ≥1 provider configured
  "snowflake_reachable": true,                 // SELECT 1 succeeded within 2s timeout
  "recipes": ["work_email_waterfall", "phone_discovery", "people_discovery", ...],
  "recipe_count": 13,
  "providers_configured": ["icypeas", "prospeo", "leadmagic", ...],
  "budget": {
    "daily_spend_usd": 4.21,
    "daily_budget_usd": 50.00,
    "remaining_usd": 45.79,
    "used_pct": 8.4,
    "block_new_enrichments": false
  },
  "mcp_version": "<git-sha>",                  // from .mcp.json pin (RQ4)
  "engine_version": "<git-sha>"                // from services/__about__.py or similar
}
```

**No provider API calls in the default check.** The MCP must NOT call out to any of the 14 provider APIs as part of `check_enrichment_health`. Three reasons:

1. **Spec / precedent compliance.** ADR 2c's canonical checks are single round-trips. Calling 14 provider APIs turns one check into 14 — too slow, too expensive, defeats the purpose.
2. **Cost.** Most provider auth-check endpoints don't charge, but some count as "credits used" (Prospeo and LeadMagic specifically — verified during recent recipe testing). Health checks must be safe to call repeatedly without budget impact.
3. **Failure-mode noise.** If 1 of 14 providers is having an incident, `check_enrichment_health` shouldn't return `ok: false` and block the skill — the skill's actual operation might not need that provider. Per-provider failures surface naturally at tool-call time as `EnrichmentAuthError` / `EnrichmentNetworkError` per ADR-008.

**Per-provider deep-check is a v2 deferral.** A future `check_provider_health(provider: str)` could ping a specific provider's auth endpoint on demand. Useful for debugging "why is the email waterfall failing on this domain?" but not needed for ADR 2c compliance. Flagged for v2.

**How skills use the check.** Per ADR 2c, skills call `check_enrichment_health` once per session before any mutation. Pattern:

1. Skill calls `check_enrichment_health` (no args).
2. If `ok: false` or call raises, skill falls back gracefully (situation-mining's "skip block if MCP unavailable" pattern per RQ9; list-building's `blitz_waterfall` Bash fallthrough per `plugins/marketing/skills/list-building/SKILL.md:140`).
3. If `ok: true` AND `budget.block_new_enrichments: true`, skill warns the user about budget exhaustion and pauses for confirmation before mutating tools.
4. If `ok: true` and budget is fine, skill proceeds to `enrich_contacts` / `query_entity`.

**Constraints.**

- **Idempotent and side-effect-free.** N calls in a row produce identical Snowflake state. No writes, no enrichment attempts logged.
- **Timeout discipline.** Snowflake `SELECT 1` ≤ 2 seconds. If the round-trip exceeds the timeout, return `snowflake_reachable: false` and `ok: false` rather than blocking the skill for 30+ seconds.
- **Always returns.** Never raises `EnrichmentNetworkError` for the Snowflake step — instead reports `snowflake_reachable: false`. The whole point of an availability check is to give the caller a clean signal; throwing an exception inside the availability check is an anti-pattern.

**Citations.**
- `docs/designs/outbound-agent-architecture-adrs.md` ADR 2c — "skills must include a tool-availability check before mutating"; canonical Email Bison + Salesforce check examples.
- `services/shared/snowflake_client.py` — `execute_query` exists; needed for `SELECT 1` round-trip.
- `services/enrichment/recipes/parser.py` — `list_recipes` powers `cli.py:406-424` (existing `list-recipes` subcommand).
- `services/enrichment/operations/cost_ops.py:64-102` — `check_enrichment_budget()` existing function.
- `services/enrichment/providers/factory.py` — ProviderFactory registry; needs ~5-line `enabled_providers()` addition (M49 follow-up).
- `plugins/marketing/skills/list-building/SKILL.md:140` — `brite_mcp` fall-through pattern; skill uses availability check to decide whether to swap to `blitz_waterfall`.
- ADR-008 § typed errors at `docs/decisions/008-tam-mapping-enrichment-pluggability.md:114-122` — per-provider failures surface at tool-call time as `EnrichmentAuthError` / `EnrichmentNetworkError`, not in the health check.

## RQ8 — Confirmation gates

**Question.** Which mutations need MCP-level two-call gates per the Email Bison pattern? Candidates named in the issue: bulk enrichment over N, expensive per-row billable calls.

**The Email Bison precedent — what's actually being gated.** From `plugins/marketing/tools/integrations/email-bison.md` §"MCP confirmation gates" (verified verbatim in prep), the 8 gated tools are:

| Tool | Why it's gated |
|---|---|
| `resume_campaign` | "STARTS SENDING REAL EMAILS" — irreversible side effect on recipients |
| `archive_campaign` | Campaign cannot be resumed after archive — destructive |
| `import_leads_to_campaign` | Attaches leads to a campaign that may already be sending — irreversible at the recipient level |
| `unsubscribe_lead` | Unsubscribes lead globally — workspace-wide irreversible action |
| `blacklist_lead` | Adds lead to workspace blacklist — irreversible |
| `enable_warmup` | Starts warmup sends from the account — real send behavior change |
| `remove_email_from_blocklist` | Un-blocks an email explicitly suppressed — defeats prior intent |
| `remove_domain_from_blocklist` | Un-blocks an entire domain — defeats prior intent |

**The pattern in all 8 cases is the same: irreversible workspace-level side effects that an agent could trigger by accident.** The gate is not "spending money" — it's "doing something that can't be undone or that affects real recipients." The Bison vendor enforces these gates server-side; relaying the prompt verbatim is the skill's job, with the principle "Do NOT issue both calls in the same turn without a real user response between them" (`plugins/marketing/skills/email-bison/SKILL.md:135-145`).

**Comparison to the enrichment MCP's MVP surface.**

| MVP tool | Mutation? | Side effects | Irreversible? | Worst-case cost per call |
|---|---|---|---|---|
| `check_enrichment_health` | No | None | n/a | $0 (no provider calls per RQ7) |
| `query_entity` | No | None (read-only Snowflake) | n/a | $0 |
| `enrich_contacts` | Yes — provider credit spend + writes to `RAW.PIPELINE_ENRICHMENT` staging | Provider credit spent (cannot be un-spent); staging row(s) inserted (reversible via dbt rebuild or direct UPDATE) | Provider credit is irreversible but **bounded** — see worst-case analysis below | ~$0.20–$1.00 per single-company invocation |

**Worst-case-cost analysis for `enrich_contacts`.** Per the work_email_waterfall + phone_discovery recipes:

- `discover-people` (Apollo People Search): ~$0.10 for up to 5 candidates per company (free for org members, but billable if quota exceeded)
- Per candidate: email waterfall (IcyPeas $0.01 → Prospeo $0.02 → LeadMagic $0.03, stops at first success) + phone waterfall (LeadMagic $0.03 → Prospeo $0.02 → Datagma $0.05, stops at first success)
- Worst case (5 candidates, every waterfall falls through to the last provider): 5 × ($0.03 + $0.05) + $0.10 ≈ $0.50
- Typical: ~$0.20

This is more than zero, but it is **bounded per call** (no batch multiplier in the MVP shape per RQ6), and it is not workspace-irreversible in the Bison sense. The credit is gone, but no real-world side effect (no email sent, no recipient affected, no record blacklisted).

**Choice for MVP.** **Zero MCP-level confirmation gates in the scaffold.**

Three reasons, ordered by weight:

1. **The MVP tool shape doesn't generate the Bison-class risk.** `enrich_contacts` is one-company-per-call (RQ6). There is no multiplier inside the MCP. An agent doing 50 leads must make 50 visible tool calls — each one shows up in the operator's session log, and Claude Code's existing tool-call confirmation surface (`Bash` and project-scoped MCP servers prompt for approval per [URL 12]) provides one layer of operator visibility already. The "agent runs amok and spends $200 in one call" scenario doesn't exist for the MVP.
2. **Engine-level budget gate is a stronger floor.** `cost_ops.check_enrichment_budget()` already returns `block_new_enrichments: bool` when the daily budget threshold is hit. The MCP must wire this in: at the top of `enrich_contacts`, call `check_enrichment_budget()`; if `block_new_enrichments: true`, raise `EnrichmentQuotaExceededError` per ADR-008 before any provider call. This is fail-fast at the daily cumulative cost level — exactly where unbounded spend would actually matter. It's stricter than a per-call gate because it can stop the 100th call after 99 prior successes; a per-call gate cannot.
3. **Per-call gates at $0.20–$1 are friction, not safety.** A skill doing routine work (list-building enriching 10 leads sequentially) would hit 10 gates in a row. Operators learn to confirm-without-reading at that frequency — the "real user response between calls" principle from Bison degenerates into rubber-stamping. Worse, since the engine already wrote the attempt record before the gate fires (the engine doesn't know about MCP-layer gating), partial spends could leak through if a gate is added without redesigning the call flow.

**Constraint.** `enrich_contacts` must call `check_enrichment_budget()` as its first action before any provider call. If `block_new_enrichments: true`, raise `EnrichmentQuotaExceededError` with the current `daily_spend_usd` and `daily_budget_usd` in the error payload. ADR-008 already names this exception (§ typed errors at `docs/decisions/008-tam-mapping-enrichment-pluggability.md:114-122`). Skills surface this to the operator as "daily enrichment budget exhausted ($50/$50 spent) — increase budget or retry tomorrow."

**v2 deferrals (gates we may want later, not now).**

| Future scenario | Why a gate would make sense | Why not yet |
|---|---|---|
| `bulk_enrich_contacts(domains: list[str])` | True batch multiplier — 100 leads × $0.50 = $50, hits daily budget in one call. Gate at N > 10 or estimated cost > $5. | Tool doesn't exist; per RQ6 it's a v2 deferral that requires both an MCP tool AND a new engine API. Build the gate alongside the tool. |
| `clear_enrichment_data(domain: str)` | If we ever expose entity-purge as an MCP tool, that's destructive and Bison-class. | No such tool exists or is planned. |
| `run_recipe(recipe: str, source: str, limit: int)` raw exposure | The CLI's batch-pull surface — runs against a Snowflake source table, can enrich thousands of entities in one call. Definitely needs a gate. | Deferred to BC-5538 v2 per RQ3. When/if exposed, gate at `limit > 25` or estimated cost > $10. |

**Implementation note for BC-5538 when bulk lands.** The Bison two-call shape (first call without `confirmation`, MCP returns prompt, second call with `confirmation: true`) requires `estimate_recipe_cost(recipe, n)` to exist — otherwise the first-call prompt can't quote a cost. `estimate_recipe_cost` is the M49 follow-up from RQ10. The dependency graph is: BC-5538's `bulk_enrich_contacts` blocked by M49 issue for `estimate_recipe_cost`, blocked by BC-5538's actual implementation. Document in BC-5537/5538 refinement (Task 6a).

**Tradeoff to flag.** Skipping MCP-level gates in MVP means a careless agent could fire 20 `enrich_contacts` calls in 30 seconds before the daily budget gate catches the runaway. Worst-case loss: ~$10–$20 before the engine slams the door. This is consciously accepted because (a) the operator sees every call in the session log, (b) the engine-level daily budget exists and is enforced, and (c) the alternative (per-call gating) would degrade operator confidence in gates the rest of the platform also relies on (Bison's 8 actually-irreversible gates).

**Citations.**
- `plugins/marketing/tools/integrations/email-bison.md` §"MCP confirmation gates" — 8 gated tools, all workspace-irreversible.
- `plugins/marketing/skills/email-bison/SKILL.md:135-145` — verbatim two-call principle.
- [URL 1 — modelcontextprotocol.io/specification/2025-11-25] — "Hosts must obtain explicit user consent before invoking any tool" — consent is the host's responsibility; MCPs are not required to gate at the protocol level.
- [URL 12 — code.claude.com/docs/en/mcp.md] — Claude Code prompts for approval before using project-scoped servers from `.mcp.json` files — host-level layer that already exists.
- `services/enrichment/operations/cost_ops.py:64-102` — `check_enrichment_budget()` returns `block_new_enrichments`.
- `services/enrichment/recipes/work_email_waterfall.yml`, `services/enrichment/recipes/phone_discovery.yml` — per-step cost data informing worst-case-cost analysis.
- ADR-008 § typed errors at `docs/decisions/008-tam-mapping-enrichment-pluggability.md:114-122` — `EnrichmentQuotaExceededError` is the contract.
- RQ6 above — single-company-per-call shape rules out the batch-multiplier risk.

## RQ9 — Pre-wired consumer audit

**Question.** Which skills/commands already declare `mcp__plugin_marketing_enrichment__*` in `allowed-tools` or fall-through paths today? Does the 3-tool scaffold MVP (`check_enrichment_health`, `enrich_contacts`, `query_entity`) satisfy all of them on day 1, not just list-building?

**5 pre-wired consumers — what each expects today.**

| # | Consumer | File:line | How the MCP is referenced today | Active or inert? |
|---|---|---|---|---|
| 1 | `situation-mining` | `plugins/marketing/skills/situation-mining/SKILL.md:5` frontmatter; `:210-215` body | Frontmatter declares `mcp__plugin_marketing_enrichment__*` in `allowed-tools` (already today). Body Workflow 3 (lines 210-215) uses MCP as tertiary firmographic fallback with "skip block if MCP unavailable" graceful-degrade language. | **Inert** — skill produces complete artifacts without enrichment today; MCP availability triggers an opt-in deeper block |
| 2 | `list-building` | `plugins/marketing/skills/list-building/SKILL.md:140` | NOT in frontmatter `allowed-tools` today (frontmatter lists Bash + Salesforce + Spider + EmailBison only). Line 140 contact-discovery-enrichment row provides a `brite_mcp` provider option with "pending GA via BC-5538 + BC-6170" fallback to `blitz_waterfall` Bash path. | **Inert** — default path is Bash to `enrich_waterfall.py`; MCP path is the planned post-GA swap |
| 3 | `tam-mapping` | `plugins/marketing/skills/tam-mapping/SKILL.md:301` | NOT in frontmatter `allowed-tools` today. Phase 5 pluggable-provider table (line 301) lists `brite_mcp` as a provider option with "Pending BC-5537/5538 GA. Currently NOT in `allowed-tools`; falls through to `blitz_waterfall`." | **Inert** — same shape as list-building; MCP path is the planned post-GA swap |
| 4 | `icp-scoring` | `plugins/marketing/skills/icp-scoring/SKILL.md:118` (graceful-degrade block at `:139-145`) | **Explicit exclusion.** "`mcp__plugin_marketing_enrichment__*` is NOT registered in `plugins/marketing/.mcp.json` today (BC-5537/5538 not yet shipped). The skill therefore does NOT list it in `allowed-tools`." With an activation procedure documented at `:141-143` for when MCP ships. | **Intentionally inert** — degrades to conservative scoring (40/C) on missing firmographic data |
| 5 | `launch-campaign` | `plugins/marketing/commands/launch-campaign.md:290` | NOT in frontmatter `allowed-tools` today. Phase 2 step 1 uses static role-prefix + free-mail-domain lists. Swap-intent comment at line 290: "Predicate output names (`is_role`, `is_free`) match the BounceBan response shape so the future brite-enrichment-MCP swap (BC-5538) is an internals-only change." | **Active with static logic** — works today; the MCP swap replaces the static predicate with a call to the validation tool |

**Critical observation.** Only **one** of the 5 consumers (situation-mining) declares `mcp__plugin_marketing_enrichment__*` in `allowed-tools` today. The other 4 deliberately do NOT — because per `CLAUDE.md` gotcha in icp-scoring's SKILL.md, "listing an unregistered server causes silent runtime failure." This means **the moment BC-5537 ships the MCP and BC-6170 / BC-8173 / BC-8174 activate their respective consumers, the consumers will add the wildcard to their frontmatter as part of activation** — not on scaffold-MVP day 1.

**Day-1 satisfaction analysis — does the 3-tool MVP unblock the consumers that will actually pull on day 1?**

| Consumer | Activation issue | Day-1 tools needed | Day-1 satisfied by MVP? |
|---|---|---|---|
| `situation-mining` | None — already declares MCP wildcard | `check_enrichment_health` (graceful-degrade probe) + `query_entity` (firmographic fallback for `who` dimension) | **Yes — fully** with the 3-tool MVP |
| `list-building` | BC-6170 | `check_enrichment_health` (availability probe before swap) + `enrich_contacts` (ADR-008 shape replaces `blitz_waterfall` Bash) | **Yes — fully** with the 3-tool MVP |
| `tam-mapping` | BC-6170 | Same as list-building — `check_enrichment_health` + `enrich_contacts` | **Yes — fully** with the 3-tool MVP |
| `icp-scoring` | BC-8174 | `query_entity` for industry / employees / geography lookup once skill activates | **Yes — fully** with the 3-tool MVP (tool exists, consumer activates whenever) |
| `launch-campaign` | BC-8173 | Future BounceBan swap; needs a per-email validation tool returning `is_role` / `is_free` — **NOT in MVP scope per RQ3** | **No — activation-day work**, waits on BC-5538's BounceBan-shaped tool |

**Verdict.** The 3-tool MVP `{check_enrichment_health, enrich_contacts, query_entity}` satisfies **4 of 5 pre-wired consumers** on day 1 (or whenever each activates). The fifth — `launch-campaign` — explicitly waits on BC-5538 per the swap-intent comment at `commands/launch-campaign.md:290`; this is by design, not a gap.

**Important nuance on `query_entity` shape.** RQ3 picked `query_entity` partly as insurance for situation-mining + icp-scoring. The shape it has to return for **both** consumers to be satisfied:

- **Identity fields** (entity_id, domain, company_name, address) — table-stakes
- **Firmographic fields** (`business_category` exists today on `dim_companies`; needs `business_vertical` per BC-4536; needs `employee_count` / `industry` per icp-scoring's `must_have` rules) — partial today
- **ICP / persona signals** (`icp_fit`, `persona_fit`, `business_vertical`) — **do not surface in `dim_companies` mart today** (verified: present in `EnrichmentEntityRecord` at `schemas.py:212-213`, missing from `models/marts/dim_companies.sql` per RQ10 follow-up)

So `query_entity` MVP returns **what's available in `dim_companies` today**. The M49 follow-up to surface `icp_fit` / `persona_fit` / `business_vertical` is the unblock for icp-scoring's full activation (BC-8174) — not the unblock for MVP shipping.

**Constraint on each consumer's activation.** When a consumer is ready to activate (BC-6170, BC-8173, BC-8174), it must:

1. Add `mcp__plugin_marketing_enrichment__*` to its frontmatter `allowed-tools` (or specific tool names, per the icp-scoring activation procedure documented at `SKILL.md:141-143`)
2. Add `check_enrichment_health` as a pre-flight before any mutating tool call (ADR 2c compliance)
3. Define the fallback path for `ok: false` or unreachable MCP — list-building falls through to `blitz_waterfall`; situation-mining skips the firmographic block; icp-scoring scores conservatively at 40/C

These are activation-issue scope (BC-6170 / BC-8173 / BC-8174), not BC-5537 / 5538 scope.

**Citations.**
- `plugins/marketing/skills/situation-mining/SKILL.md:5` (frontmatter), `:210-215` (Workflow 3 tertiary fallback row).
- `plugins/marketing/skills/list-building/SKILL.md:140` (contact-discovery row with `brite_mcp` provider option).
- `plugins/marketing/skills/tam-mapping/SKILL.md:301` (Phase 5 pluggable-provider table).
- `plugins/marketing/skills/icp-scoring/SKILL.md:118`, `:139-145` (graceful-degrade block + activation procedure).
- `plugins/marketing/commands/launch-campaign.md:290-309` (static predicate + swap-intent comment).
- ADR-008 input/output schemas at `docs/decisions/008-tam-mapping-enrichment-pluggability.md:74-112` — the shape `enrich_contacts` must match exactly.
- ADR 2c at `docs/designs/outbound-agent-architecture-adrs.md` — availability-check requirement.
- `services/enrichment/models/schemas.py:212-213` (`icp_fit` + `persona_fit` exist on entity record).
- `models/marts/dim_companies.sql` (verified `icp_fit` / `persona_fit` / `business_vertical` do not surface in mart today — RQ10 follow-up).

## RQ10 — Engine-contract conformance (the lynchpin)

**Three sub-questions:**
(a) Where does the ADR-008 contract adapter live — inside `services/enrichment/` (M49 gets ~5 issues) or as a translation layer inside the MCP server only (M49 stays mostly empty)?
(b) Typed exception hierarchy — full constructor signatures + raise sites for `EnrichmentQuotaExceededError`, `EnrichmentAuthError`, `EnrichmentNetworkError`?
(c) Does the wire-shape `confidence_score` stay numeric float (matching `EnrichmentResult.confidence` at `services/enrichment/models/schemas.py:152-157`) or map to categorical?

**Engine state today — three gaps verified during prep.**

| Surface | What it does today | What ADR-008 requires |
|---|---|---|
| `flows/batch_waterfall.py:96-102` `run_batch_enrichment()` | Returns `{total, success_count, no_data_count, skipped_count, failed_count}` counter dict only — no per-entity payloads | A push-based API returning `list[EnrichmentOutput]` per company |
| `services/enrichment/` exception classes | **Zero typed exceptions defined** (verified: `grep -rn "class.*Error" services/enrichment/ services/shared/` returns 0 matches). Errors flow as generic `Exception` or `ValueError`. | `EnrichmentQuotaExceededError`, `EnrichmentAuthError`, `EnrichmentNetworkError` typed hierarchy |
| `models/schemas.py:152-157` `EnrichmentResult.confidence` | `float \| None` with range 0.0-1.0 — already matches the ADR-008 wire type | `confidence_score: number; required; 0.0 to 1.0 float` |

The engine is two-thirds of the way to ADR-008 conformance on the data shape and zero of the way on errors. **The contract adapter has to exist somewhere; this RQ decides where.**

---

### (a) Contract adapter location

**Options considered.**

| | A. Adapter lives engine-side (`services/enrichment/`) | B. Adapter lives MCP-side only (translation at the JSON boundary) |
|---|---|---|
| **What changes in the engine** | New `services/enrichment/errors.py` module; `flows/batch_waterfall.py` adds `enrich_one(input: EnrichmentInput) -> list[EnrichmentOutput]` push-based API; provider adapters raise typed errors; `cost_ops.estimate_recipe_cost()` exists; etc. ~5 M49 issues. | Nothing. Engine stays as-is. |
| **What lives in the MCP** | Thin orchestration: `enrich_contacts` calls `discover-people` then `run-recipe` then formats the return. Imports `EnrichmentOutput`, `EnrichmentInput`, `EnrichmentError` types directly from `enrichment.contracts`. | Parses the counter-dict + reads result rows back from Snowflake; reconstructs `EnrichmentOutput` shape; pattern-matches error strings to typed exceptions. |
| **Single source of truth** | Yes — same types used by future REST API (BC-5264 / 5296 / 5332), future CLI restructure, the MCP, and any future agent-style consumer | No — every consumer that wants the ADR-008 shape duplicates the translation layer |
| **Cross-consumer drift risk** | None — types are imported, not recreated | High — MCP and REST translation layers will diverge as the engine evolves |
| **Parity-testability** | Yes — same engine pytest suite covers the contract; one test set, deterministic | No — each consumer's translation layer has its own parity test set |
| **MVP delivery speed** | Slower — engine team must ship the M49 issues before MCP can ship | Faster — MCP ships first, engine catches up later |
| **Bus factor / maintenance** | Lower — types live next to the providers that throw and the Snowflake records that produce data | Higher — translation layer in MCP duplicates engine-internal knowledge that's outside the MCP's primary concern |
| **Compatibility with RQ4 choice** | Required by RQ4 — RQ4 placed the MCP physically inside `brite-data-platform/tools/enrichment-mcp/` to enable direct imports. If the adapter lives MCP-side, RQ4's import-not-subprocess advantage degrades. | Inconsistent with RQ4 — would have wanted MCP in plugins repo with subprocess to CLI |

**Choice. Engine-side (Option A). The contract adapter lives in `services/enrichment/`.**

Three reasons:

1. **RQ4's deploy decision implies engine-side.** RQ4 placed the MCP physically next to the engine specifically to enable `from enrichment.contracts import EnrichmentOutput, EnrichmentInput`. Imported types only have value if they're defined where they make sense — next to the providers that throw and the Pydantic models that already exist. Putting the adapter MCP-side undoes RQ4's "direct import" reasoning.
2. **M49 work isn't MCP-specific — it's "engine infrastructure for any agent-style consumer."** The same surfaces benefit BC-5264 / 5296 / 5332 (FastAPI REST surface for Brite Base or third-party consumers per `memory/project_brite_enrichment_mcp.md`). Framing the M49 issues as "ADR-008 conformance for the engine" makes them self-justifying, not "MCP-only work the engine team is paying for."
3. **Cross-consumer drift is the dominant long-term risk.** Two translation layers (one in MCP, one in REST) WILL diverge as the engine evolves — adding a new provider, changing a confidence-mapping rule, renaming a field. The engine-side adapter is the single point of change. ADR-008 chose to freeze the contract; we honor that by giving the contract one home.

**What this means for M49.** The following data-platform follow-up issues are filed in `M49: Brite Enrichment MCP Enablement` per Task 6b. Each cites the specific RQ that drives it and adds `blockedBy` from BC-5537 or BC-5538 (whichever consumes the engine surface).

| # | Title | Drives RQ | Blocked by |
|---|---|---|---|
| 1 | **`services/enrichment/contracts.py` + `errors.py`** — define `EnrichmentInput`, `EnrichmentOutput`, base `EnrichmentError` + 3 subclasses. Refactor provider adapters to raise typed errors. Add `enrich_one()` push-based API to `flows/batch_waterfall.py` returning `list[EnrichmentOutput]`. | RQ10(a) + RQ10(b) | BC-5537 (MVP needs the imported types) |
| 2 | **`cost_ops.estimate_recipe_cost(recipe, n) -> float`** — given a recipe YAML and a target entity count, return estimated cost in USD from per-step provider costs. | RQ8 (gates on `bulk_enrich_contacts` v2 need cost estimation); also useful for `check_enrichment_health` "remaining_capacity" display | BC-5538 (only needed for the v2 bulk gate; MVP can ship without it) |
| 3 | **`shared/snowflake_client.query_entity_by_domain(domain)`** — read-only helper returning canonical company + linked persons from `dim_companies` / `dim_people`. | RQ3 (`query_entity` MVP tool) | BC-5537 (MVP needs this helper) |
| 4 | **Surface `icp_fit`, `persona_fit`, `business_vertical` columns on `dim_companies`** (and persona on `dim_people`) — they exist in `EnrichmentEntityRecord` (`schemas.py:212-213`) but are dropped at the mart layer. Pure additive dbt change, no migration. | RQ9 (icp-scoring activation per BC-8174 needs these columns) | BC-8174 (activation issue; not BC-5537 — MVP `query_entity` works without these) |
| 5 | **`providers/factory.enabled_providers() -> list[str]`** — 5-line method enumerating registered providers with env vars present. | RQ5 (per-provider toolset gating) + RQ7 (`check_enrichment_health` returns the list) | BC-5537 (MVP `check_enrichment_health` needs this) |
| 6 (deferred) | **`scripts/find_phone.find_phone()` structured-return refactor** — currently returns `None` and prints; refactor to `find_phone(...) -> EnrichmentOutput \| None`. | RQ3 v2 (`lookup_person` MCP tool, not in MVP) | BC-5538 — deferred until `lookup_person` is in scope |

**Justification for not collapsing M49 to zero.** The MCP-side translation alternative is technically possible but creates two engine-shape representations that must stay in sync — that's a maintenance liability we're not willing to accept for a "ship faster today" benefit when the engine team's roadmap already includes a REST API that will need the same types.

---

### (b) Typed exception hierarchy

ADR-008 names three typed exceptions but doesn't fix the constructor signatures. Per Brite's existing exception conventions (`tools/fivetran-mcp/server.py:37` uses bare `RuntimeError` with f-string message), there's no in-house precedent to extend. Below is the proposed signature shape; the M49 issue 1 above implements it.

```python
# services/enrichment/errors.py (new file, M49 issue 1)

class EnrichmentError(Exception):
    """Base class for all enrichment-engine errors.

    All typed errors carry:
      - provider: the provider that failed (None if not provider-attributable)
      - cause: the underlying httpx / connector exception (None if synthetic)
    """
    def __init__(
        self,
        message: str,
        *,
        provider: str | None = None,
        cause: Exception | None = None,
    ) -> None:
        super().__init__(message)
        self.provider = provider
        self.cause = cause


class EnrichmentQuotaExceededError(EnrichmentError):
    """API quota exceeded for a provider, OR the Brite daily-budget gate fired.

    Skill response: retry with a different provider; if Brite daily-budget,
    surface to operator with current spend / budget figures and pause.
    """
    def __init__(
        self,
        provider: str,
        *,
        daily_spend_usd: float | None = None,
        daily_budget_usd: float | None = None,
        cause: Exception | None = None,
    ) -> None:
        super().__init__(
            f"Quota exceeded for {provider}",
            provider=provider,
            cause=cause,
        )
        self.daily_spend_usd = daily_spend_usd
        self.daily_budget_usd = daily_budget_usd


class EnrichmentAuthError(EnrichmentError):
    """Provider authentication failure: missing key, invalid key, revoked key.

    Skill response: direct operator to the onboarding doc for the named provider;
    do not retry the same provider in the same session.
    """
    def __init__(
        self,
        provider: str,
        *,
        reason: str = "auth failed",
        cause: Exception | None = None,
    ) -> None:
        super().__init__(
            f"Auth failed for {provider}: {reason}",
            provider=provider,
            cause=cause,
        )
        self.reason = reason


class EnrichmentNetworkError(EnrichmentError):
    """Network timeout / connection error after retries with exponential backoff.

    Skill response: surface as transient; retry the operation at the skill level
    (different provider via waterfall, or wait + retry).
    """
    def __init__(
        self,
        provider: str,
        *,
        attempts: int = 3,
        cause: Exception | None = None,
    ) -> None:
        super().__init__(
            f"Network error from {provider} after {attempts} attempts",
            provider=provider,
            cause=cause,
        )
        self.attempts = attempts
```

**Raise sites (M49 issue 1 implementation scope).**

| Site | Existing behavior | New behavior |
|---|---|---|
| `providers/base.py` HTTP error handling | Each provider catches `httpx.HTTPStatusError` and re-raises generic `Exception` | Map status codes: `401` → `EnrichmentAuthError(provider, reason="401 unauthorized", cause=exc)`; `403` + quota body → `EnrichmentQuotaExceededError`; `429` → `EnrichmentQuotaExceededError`; `5xx` after 3 retries → `EnrichmentNetworkError(provider, attempts=3, cause=exc)` |
| `providers/base.py` connection/timeout | Generic `httpx.NetworkError` propagates | Caught and wrapped: `EnrichmentNetworkError(provider, attempts=3, cause=exc)` after exponential-backoff retry sequence |
| `providers/factory.get_provider()` | Returns provider with missing env-var key → first API call fails generically | Check env vars at factory time; if missing, raise `EnrichmentAuthError(provider, reason="not configured")` immediately |
| `operations/cost_ops.py` budget gate | `check_enrichment_budget()` returns `{block_new_enrichments: bool}`; caller checks the flag and raises `ValueError` if true | Caller (the MCP's `enrich_contacts` tool wrapper) raises `EnrichmentQuotaExceededError(provider="brite-daily-budget", daily_spend_usd=..., daily_budget_usd=...)` |
| `flows/batch_waterfall.py` | Catches generic `Exception`, logs, counts in `failed_count` | Catches `EnrichmentError` subclasses, attaches them per-entity in the new `list[EnrichmentOutput]` return; never swallows |

**Wire-format note.** FastMCP serializes Python exceptions into the JSON-RPC error frame per [URL 1]. The standard JSON-RPC error object has `code`, `message`, `data`. The MCP server should set `data` to `{"provider": ..., "reason": ..., "daily_spend_usd": ..., ...}` so skills can parse without grepping the `message` string. JSON-RPC error codes follow the spec's reserved ranges; use `-32000` (server error) range with sub-codes per exception type, documented in BC-5538 integration guide.

---

### (c) `confidence_score` wire shape

**Choice. Numeric float in `[0.0, 1.0]`, non-null.** Matches the engine's existing `EnrichmentResult.confidence` type at `schemas.py:152-157` AND the ADR-008 output schema at `docs/decisions/008-tam-mapping-enrichment-pluggability.md:96-106`. No categorical wire representation.

**Categorical-to-numeric mapping is the adapter's job.** ADR-008 already specifies: "Providers that emit categorical confidence must map to numeric (e.g., provider 'high' → 0.9, 'medium' → 0.6, 'low' → 0.3)." This mapping happens **inside each provider adapter** (`providers/icypeas.py` etc.), not at the MCP boundary. The MCP imports `EnrichmentOutput` and ships it as-is.

**Null-confidence handling.** Some providers don't expose explicit confidence (e.g., Findymail returns a hit without a confidence score). Three sub-options were considered:

| | A. Drop the record (strict ADR-008) | B. Default to 0.5 (neutral) | C. Per-provider default (proxy for provider reliability) |
|---|---|---|---|
| Pro | Conservative; aligns with ADR-008's "log warning, drop record, continue" schema-violation rule | Simple; preserves the record | Best signal — Apollo's hit ≠ Snov's hit, encodes that in the score |
| Con | Throws away usable contact data — violates "never drop contact info" from memory:`feedback_never_drop_contact_info` | Misleading; a Findymail hit isn't actually "50% confident" | Requires documented per-provider tier values; mild ADR-008 extension |

**Choice. Option C — per-provider default tier**, with the per-provider value documented inline in each provider's recipe YAML metadata. Defaults proposed (M49 issue 1 finalizes):

| Provider | Confidence default when API returns none |
|---|---|
| Apollo | 0.85 (people search hit) |
| IcyPeas | 0.80 (when explicit confidence is absent) |
| Prospeo | 0.80 |
| LeadMagic | 0.75 |
| Findymail | 0.75 |
| Datagma | 0.70 |
| PDL | 0.85 |
| Snov.io | 0.65 |
| Openmart | 0.70 |
| BounceBan | 0.90 (verification result; high inherent confidence) |
| EmailGuard | 0.85 (verification result) |

The "never drop contact info" memory makes Option A wrong; Option B is silently misleading; Option C is honest and tunable. M49 issue 1 documents the table and the rationale for each tier value.

**Categorical wire format remains unsupported.** A future v2 could expose `confidence_categorical: "high" | "medium" | "low"` alongside `confidence_score` for skills that prefer the discrete form. Not in MVP scope. Flag for v2 deferrals.

---

**Citations.**
- `services/enrichment/flows/batch_waterfall.py:96-102` — current counter-dict return (verified via prep agent).
- `services/enrichment/models/schemas.py:23-50` (`EnrichmentResult`), `:152-157` (`confidence: float | None`), `:212-213` (`icp_fit`, `persona_fit`).
- `services/enrichment/operations/cost_ops.py:18-144` — three existing functions; no `estimate_recipe_cost`.
- `services/shared/snowflake_client.py` — `get_snowflake_connection`, `execute_query`, `execute_dml`; no `query_entity_by_domain`.
- Exception-class grep verified zero matches in `services/enrichment/` + `services/shared/`.
- `models/marts/dim_companies.sql`, `dim_people.sql` — verified `icp_fit` / `persona_fit` / `business_vertical` do not surface in mart.
- ADR-008 § Input/Output/Errors at `docs/decisions/008-tam-mapping-enrichment-pluggability.md:74-122`.
- `memory/project_brite_enrichment_mcp.md` — confirms M49 anticipated families match this RQ's findings.
- `memory/feedback_never_drop_contact_info.md` — rule against dropping records; drives the null-confidence decision.
- [URL 1 — modelcontextprotocol.io/specification/2025-11-25] — JSON-RPC error frame for typed-exception wire format.

---

## Decision Memo

One row per Research Question. Concrete values — no TBD, no "depends." For full reasoning, citations, and tradeoff analysis, see the RQ section above.

| RQ | Decision |
|---|---|
| **RQ1 — Language** | **Python FastMCP** via the official `mcp>=1.0` SDK. PEP 723 inline-script header matching the Fivetran MCP precedent at `tools/fivetran-mcp/server.py:1-7`. |
| **RQ2 — Transport** | **stdio.** Plugin `.mcp.json` entry uses `"type": "stdio"`. Future HTTP migration stays open via FastMCP's `mcp.run(transport=…)` swap but is not in scope. |
| **RQ3 — MVP tool surface** | **Three tools:** `check_enrichment_health` (novel; availability + budget + recipes + providers), `enrich_contacts` (composite over `discover-people` + email/phone waterfalls; ADR-008 contract), `query_entity` (novel; Snowflake read by domain). |
| **RQ4 — Deploy target** | **Source lives in `brite-data-platform/tools/enrichment-mcp/`**, invoked from `plugins/marketing/.mcp.json` via `uvx --from git+https://github.com/Brite-Nites/brite-data-platform@<sha>#subdirectory=tools/enrichment-mcp brite-enrichment-mcp`. Pin to a git SHA, not a branch. |
| **RQ5 — Credentials** | **Bitwarden broker via `bw-run.sh` + per-provider toolset gating.** MCP starts even with missing keys; tools needing absent providers raise typed `EnrichmentAuthError`. Vault item naming follows the established `plugins/marketing/.mcp.json` convention. |
| **RQ6 — Data flow** | **JSON inline.** `enrich_contacts` is **one company per call** (no `domains: list[str]`). Engine-side writes to `RAW.PIPELINE_ENRICHMENT` happen as a side effect per the single-writer gold pattern. ADR 2e skill ↔ audience-view interface defined; no MCP-side audience-view tool in MVP (zero `audience_view_*` dbt models exist). |
| **RQ7 — Availability check** | **`check_enrichment_health`** is the ADR 2c canonical check. Synthesizes Snowflake `SELECT 1` round-trip + recipe count + budget status + configured-provider list. **No provider API calls in the check.** Idempotent, side-effect-free, always returns (never raises). |
| **RQ8 — Confirmation gates** | **Zero MCP-level gates in MVP.** Engine-level fail-fast: at the top of `enrich_contacts`, call `check_enrichment_budget()`; if `block_new_enrichments: true`, raise `EnrichmentQuotaExceededError`. Future gates flagged for v2 only when bulk/raw-recipe tools are added. |
| **RQ9 — Consumer satisfaction** | **4 of 5 pre-wired consumers satisfied day 1:** situation-mining (graceful-degrade probe + firmographic via `query_entity`), list-building (drops in for `blitz_waterfall`), tam-mapping (same), icp-scoring (whenever it activates via BC-8174). **launch-campaign waits on BC-5538** by design — explicit per `commands/launch-campaign.md:290` swap-intent comment. |
| **RQ10 — Engine contract** | **(a)** Contract adapter lives **engine-side** in `services/enrichment/contracts.py` + `errors.py`. M49 gets 5 issues (see Task 6b below). **(b)** Typed errors: `EnrichmentError` base + `EnrichmentQuotaExceededError(provider, daily_spend_usd?, daily_budget_usd?, cause?)`, `EnrichmentAuthError(provider, reason, cause?)`, `EnrichmentNetworkError(provider, attempts=3, cause?)`. **(c)** `confidence_score` is numeric float `[0.0, 1.0]`, non-null; null-confidence providers use a documented per-provider tier default at the adapter layer. |

## Scaffold Tool List (MVP)

Three rows, every column populated. This table is the deliverable BC-5537 uses verbatim to scope its tasks.

| MCP tool name | Engine surfaces it composes | Parameters (Pydantic-typed) | Availability-check status | Confirmation-gate status |
|---|---|---|---|---|
| `check_enrichment_health` | Direct: `snowflake_client.execute_query("SELECT 1")`, `recipes/parser.list_recipes()`, `cost_ops.check_enrichment_budget()`, `providers/factory.enabled_providers()` (new, M49 #5) | None | **This IS the availability-check tool** per ADR 2c. Skills call this first. | None — read-only, idempotent, side-effect-free |
| `enrich_contacts` | Composes: `discover-people` (Apollo People Search) → per-candidate `run-recipe work_email_waterfall` (IcyPeas → Prospeo → LeadMagic) → per-candidate `run-recipe phone_discovery` (LeadMagic → Prospeo → Datagma). Returns `list[EnrichmentOutput]`. | `domain: str` (required), `company_name: str` (required), `linkedin_url: str \| None`, `title_seed: str \| None`, `geo: str \| None` (ISO 3166-1 alpha-2). Matches ADR-008 `EnrichmentInput` exactly. | Caller must invoke `check_enrichment_health` first (skill-side responsibility) | **No two-call gate in MVP.** Engine fail-fast: first action raises `EnrichmentQuotaExceededError` if daily budget exhausted |
| `query_entity` | Direct: `shared/snowflake_client.query_entity_by_domain(domain)` (new helper, M49 #3) reading `dim_companies` + linked `dim_people` rows | One of `domain: str` or `entity_id: str` required (mutually exclusive). Optional `include_persons: bool = True` toggles linked-person rows. | Caller must invoke `check_enrichment_health` first (skill-side responsibility) | None — read-only, $0 provider cost |

**Return shapes (Pydantic, ADR-008-aligned).**

```python
# check_enrichment_health return
{
  "ok": bool,
  "snowflake_reachable": bool,
  "recipes": list[str],
  "recipe_count": int,
  "providers_configured": list[str],
  "budget": {
    "daily_spend_usd": float, "daily_budget_usd": float,
    "remaining_usd": float, "used_pct": float,
    "block_new_enrichments": bool
  },
  "mcp_version": str,        # git SHA from .mcp.json pin
  "engine_version": str      # git SHA from engine repo
}

# enrich_contacts return — list of EnrichmentOutput per ADR-008
[
  {
    "email": str,            # lowercase, trimmed, required
    "first_name": str | None,  # carried from discovery when returned (BC-12078)
    "last_name": str | None,   # carried from discovery when returned (BC-12078)
    "mobile": str | None,    # E.164 preferred
    "phone": str | None,     # office/landline; E.164 preferred
    "title": str | None,     # actual title returned (may differ from title_seed)
    "linkedin_url": str | None,
    "confidence_score": float,  # required, 0.0–1.0, non-null (per-provider default if API didn't return)
    "source": str,           # e.g., "brite-enrichment:icypeas"
    "provider_raw": dict | None  # debug only
  },
  ...
]

# query_entity return
{
  "entity_id": str,
  "domain": str | None,
  "company_name": str | None,
  "address": dict | None,            # {street, city, state, zip, country}
  "business_category": str | None,   # from dim_companies
  "general_email": str | None,
  "phone": str | None,
  "data_quality_score": int,         # 0-100
  "persons": [                       # only if include_persons=true
    {
      "entity_id": str,
      "first_name": str | None,
      "last_name": str | None,
      "title": str | None,
      "work_email": str | None,
      "work_email_deliverable": bool | None,
      "phone": str | None,
      "linkedin_url": str | None,
      "data_quality_score": int
    }, ...
  ]
}
```

**Why `query_entity` does not return `icp_fit` / `persona_fit` / `business_vertical` in MVP.** Those columns exist in `EnrichmentEntityRecord` (`schemas.py:212-213`) but not in `dim_companies` mart today. Surfacing them is M49 #4, blocked by BC-8174 (icp-scoring activation), not BC-5537 (MVP). When M49 #4 lands, `query_entity` adds the three fields without a contract break — they appear when populated, omit when not.

## v2 Deferrals

Items deliberately deferred from MVP. Each gets one sentence of reasoning. **Order is by "consumer who would request" → "what they'd ask for"** so a future consumer can find their answer.

1. **`bulk_enrich_contacts(domains: list[…])`** — true batch multiplier; requires both a new engine push-based API AND a two-call confirmation gate AND `estimate_recipe_cost`. **Don't build unless a real consumer files a Linear issue requesting it.** Documented stance per RQ8 implementation note.
2. **`run_recipe(recipe, source, limit)` raw exposure** — too low-level for marketing skills; cost-multiplier risk would need a gate. The CLI surface remains available for power-user operator flows.
3. **`ingest_people` / `ingest_companies` / `ingest_company_csv`** — batch CSV imports are operator-mediated terminal work today; rarely needed via MCP. Wrap if a skill actually needs to push data into the engine.
4. **`discover_people` raw exposure** — covered by `enrich_contacts` composite for the day-1 use case. Wrap separately if a skill wants candidate names without enriching email/phone.
5. **`check_spend` / `list_recipes` / `validate_recipes` standalone tools** — folded into `check_enrichment_health`. Standalone exposure adds tool-count noise without unblocking any consumer.
6. **`consolidate_clay`** — Clay deprecated 2026-04-14; will not be wrapped.
7. **`lookup_person(name, domain)`** — needs `find_phone` structured-return refactor (M49 #6, deferred). Wait for a real consumer (situation-mining's per-prospect lookup may eventually want this).
8. **`query_audience_view(view_name, limit, filters)`** — zero `audience_view_*` dbt models exist today per RQ6. Build alongside the first audience view that lands, per ADR 2e contract pattern.
9. **`check_provider_health(provider)`** — per-provider deep-check would call the provider's auth/ping endpoint. Useful for debugging but ADR 2c doesn't require it. Build if MVP usage surfaces a recurring debug need.
10. **`confidence_categorical: "high" | "medium" | "low"`** field alongside `confidence_score` — purely a presentation convenience for skills preferring discrete buckets. ADR-008 specifies numeric; categorical is optional sugar.
11. **HTTP transport migration** — flagged per RQ2 non-decision. FastMCP supports `mcp.run(transport="http", …)` swap with no business-logic change. Migration cost would be the operational surface (deploy target, OAuth, shared rate-limit accounting), not the MCP code. Trigger conditions: shared rate-limit accounting becomes valuable, OR multi-developer cost attribution becomes a budget concern.
12. **Confidence-default tier values** beyond the M49 #1 starter table — first-pass per-provider defaults proposed in RQ10(c). Tune based on observed deliverability of real campaigns after MVP ships.

## Sources

### External References (the 14 BC-5536 URLs)

All 14 URLs were read 2026-05-14 — verbatim quotes and structured excerpts live in the companion file `brite-enrichment-mcp-findings-url-brief.md` in this directory. Citations in the RQ sections above use the form `[URL N — short.host.tld]` and resolve through that brief.

### In-repo source files cited

- `services/enrichment/cli.py` (9 subcommands, line ranges in RQ3 table)
- `services/enrichment/flows/batch_waterfall.py:96-102` (counter-dict return)
- `services/enrichment/models/schemas.py:23-50, 152-157, 212-213` (`EnrichmentResult`, `confidence`, `icp_fit` / `persona_fit`)
- `services/enrichment/operations/cost_ops.py:18-144` (three existing cost functions)
- `services/enrichment/operations/enrichment_ops.py` (public functions list)
- `services/enrichment/providers/factory.py` (ProviderFactory registry)
- `services/enrichment/recipes/work_email_waterfall.yml`, `services/enrichment/recipes/phone_discovery.yml` (worst-case cost analysis)
- `services/enrichment/scripts/find_phone.py:69-113` (prints + returns None)
- `services/shared/snowflake_client.py` (`get_snowflake_connection`, `execute_query`, `execute_dml`)
- `models/marts/dim_companies.sql`, `dim_people.sql` (columns NOT surfaced today)
- `tools/fivetran-mcp/server.py:1-7, 26, 32-41, 290` (PEP 723 + bootstrap + creds + stdio)
- `plugins/marketing/scripts/bw-run.sh:10, 139-140` (broker usage, BW_SESSION unset)
- `plugins/marketing/.mcp.json` (broker registration shape)
- `plugins/marketing/tools/integrations/email-bison.md` §"MCP confirmation gates" (8 gated tools)
- `plugins/marketing/skills/email-bison/SKILL.md:135-145` (two-call principle verbatim)
- `plugins/marketing/skills/situation-mining/SKILL.md:5, 210-215`
- `plugins/marketing/skills/list-building/SKILL.md:140`
- `plugins/marketing/skills/tam-mapping/SKILL.md:301`
- `plugins/marketing/skills/icp-scoring/SKILL.md:118, 139-145`
- `plugins/marketing/commands/launch-campaign.md:290-309`
- `docs/designs/outbound-agent-architecture-adrs.md` ADR 2a / 2c / 2d / 2e
- `docs/decisions/008-tam-mapping-enrichment-pluggability.md:74-122` (frozen contract)
- `docs/research/outbound-pipeline-findings.md` §"Brite enrichment engine"
- `docs/golden-record-architecture.md` (single-writer gold pattern)

### Memory references

- `memory/project_brite_enrichment_mcp.md` (cluster definition, M49 anticipated families)
- `memory/feedback_never_drop_contact_info.md` (drove RQ10(c) null-confidence decision)
