# BC-5536 — External References URL Brief

Working notes from reading the 14 External Reference URLs in BC-5536. Used as citation source for `brite-enrichment-mcp-findings.md`. All 14 URLs verified live and fetched 2026-05-14.

Quote conventions: verbatim quotes are in double-quotes. **Bold** in a quote = normative ("MUST", "SHOULD", etc.) preserved from the source.

## RQ1 — Language/framework (Python FastMCP vs Node)

- [URL 4 — github.com/modelcontextprotocol/python-sdk] Official Python SDK states: "The FastMCP server is your core interface to the MCP protocol." A low-level `Server` class exists for advanced scenarios.
- [URL 4] Decorator-based ergonomics in Python: `@mcp.tool()`, `@mcp.resource("uri")`, `@mcp.prompt()` — "clean and Pythonic, requiring minimal boilerplate."
- [URL 5 — gofastmcp.com/getting-started/welcome] "FastMCP 1.0 was incorporated into the official MCP Python SDK in 2024." Standalone project remains actively maintained, "downloaded millions of times daily."
- [URL 5] FastMCP claims: "some version of FastMCP powers 70% of MCP servers across all languages" and positions itself as "the standard framework for building MCP applications."
- [URL 6 — github.com/modelcontextprotocol/typescript-sdk] TypeScript SDK uses a **builder pattern** (not decorators): `new McpServer(...)` + `registerTool()` with Zod schemas. No decorator equivalent.
- [URL 6] TypeScript SDK v2 is **"pre-alpha, development branch."** "v1.x remains the recommended version for production use." V2 stable expected Q1 2026; current v1.29.0 (March 30, 2026).
- [URL 7 — github.com/modelcontextprotocol/servers] Official servers repo language mix: **TypeScript 69.3%, Python 19.2%, JavaScript 10.3%**. Seven reference servers (Everything, Fetch, Filesystem, Git, Memory, Sequential Thinking, Time).

## RQ2 — Transport (stdio vs HTTP)

- [URL 2 — modelcontextprotocol.io/specification/2025-03-26/basic/transports] Verbatim: **"Clients SHOULD support stdio whenever possible."**
- [URL 2] Verbatim: "JSON-RPC messages **MUST** be UTF-8 encoded." Stdio messages "**MUST NOT** contain embedded newlines." Server "**MUST NOT** write anything to its `stdout` that is not a valid MCP message."
- [URL 2] Streamable HTTP security: "Servers **MUST** validate the `Origin` header on all incoming connections to prevent DNS rebinding attacks." "When running locally, servers **SHOULD** bind only to localhost (127.0.0.1) rather than all network interfaces (0.0.0.0)." "Servers **SHOULD** implement proper authentication for all connections."
- [URL 2] Session IDs: "The session ID **SHOULD** be globally unique and cryptographically secure (e.g., a securely generated UUID, a JWT, or a cryptographic hash)." "The session ID **MUST** only contain visible ASCII characters (ranging from 0x21 to 0x7E)."
- [URL 2] Streamable HTTP supersedes HTTP+SSE from protocol version 2024-11-05.
- [URL 4] FastMCP production HTTP guidance: "Use `stateless_http=True` and `json_response=True` for optimal scalability."
- [URL 9] MotherDuck: `--stateless-http` flag exists for HTTP mode; HTTP defaults to port 8000 / localhost.
- [URL 10] Snowflake Labs MCP supports **stdio (default), sse (legacy), streamable-http (containers)**, default HTTP port 9000.
- [URL 12 — code.claude.com/docs/en/mcp.md] Claude Code MCP supports `--transport http`, `--transport sse` (deprecated, "Use HTTP servers instead, where available"), `--transport stdio`. In JSON the `type` field "accepts `streamable-http` as an alias for `http`."

## RQ4 — Deploy target

- [URL 11 — docs.snowflake.com/.../cortex-agents-mcp] Snowflake Cortex Agents MCP is **vendor-hosted**: "The Snowflake-managed MCP server lets AI agents securely retrieve data from Snowflake accounts without needing to deploy separate infrastructure." Status: "Feature - Generally Available."
- [URL 11] Cortex Agents endpoint: `https://<account_URL>/api/v2/databases/{database}/schemas/{schema}/mcp-servers/{name}` — HTTP/REST, OAuth 2.0 recommended.
- [URL 12] Claude Code stdio spawns server as subprocess and sets `CLAUDE_PROJECT_DIR` in the child env. "This variable is set in the server's environment, not in Claude Code's own environment, so referencing it via `${VAR}` expansion in a project- or user-scoped `.mcp.json` `command` or `args` requires a default such as `${CLAUDE_PROJECT_DIR:-.}`. Plugin-provided MCP configurations substitute `${CLAUDE_PROJECT_DIR}` directly and don't need the default."
- [URL 12] Reconnection: "If an HTTP or SSE server disconnects mid-session, Claude Code automatically reconnects with exponential backoff: up to five attempts, starting at a one-second delay and doubling each time… **Stdio servers are local processes and are not reconnected automatically.**"
- [URL 12] Initial-connect retry (v2.1.121+): "Claude Code retries the initial connection up to three times on transient errors such as a 5xx response, a connection refused, or a timeout." "Authentication and not-found errors are not retried because they require a configuration change to resolve."
- [URL 14 — code.claude.com/docs/en/plugins-reference.md] `${CLAUDE_PLUGIN_ROOT}` semantics: "the absolute path to your plugin's installation directory… This path changes when the plugin updates. The previous version's directory remains on disk for about seven days after an update before cleanup, but treat it as ephemeral and do not write state here."
- [URL 14] Update behavior: "When a plugin updates mid-session, hook commands, monitors, MCP servers, and LSP servers keep using the previous version's path. Run `/reload-plugins` to switch hooks, MCP servers, and LSP servers to the new path; monitors require a session restart."
- [URL 13/14] Persistent state: use `${CLAUDE_PLUGIN_DATA}` (survives updates) — distinct from `${CLAUDE_PLUGIN_ROOT}` (ephemeral, version-bound).
- [URL 14] All plugin path vars supported in MCP configs: `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`, `${CLAUDE_PROJECT_DIR}`, `${user_config.*}`, plus any `${ENV_VAR}`.

## RQ5 — Provider credentials

- [URL 3 — modelcontextprotocol.io/docs/tutorials/security/authorization] Verbatim: **"For MCP servers using the STDIO transport, you can use environment-based credentials or credentials provided by third-party libraries embedded directly in the MCP server instead. Because a STDIO-built MCP server runs locally, it has access to a range of flexible options when it comes to acquiring user credentials that may or may not rely on in-browser authentication and authorization flows."**
- [URL 3] Verbatim: "OAuth flows, in turn, are designed for HTTP-based transports where the MCP server is remotely-hosted and the client uses OAuth to establish that a user is authorized to access said remote server."
- [URL 3] Authorization is "**optional**" but strongly recommended when accessing user data, requiring audit trails, or in enterprise environments.
- [URL 3] Security best practices: "Never embed client credentials directly in your code." "Always validate tokens." "Use short-lived access tokens." "Don't log credentials." "Don't reuse your MCP server's client secret for end-user flows."
- [URL 12] Claude Code substitutes `${VAR}` and `${VAR:-default}` in `command`, `args`, `env`, `url`, `headers`. "If a required environment variable is not set and has no default value, Claude Code will fail to parse the config."
- [URL 12] HTTP OAuth: tokens "stored securely and refreshed automatically." 401/403 triggers OAuth flow via `/mcp`. `headersHelper` shell command runs "fresh on each connection (at session start and on reconnect). There is no caching."
- [URL 12] Implied refresh-on-reconnect for env-based creds: since stdio servers aren't auto-reconnected, env updates require a fresh spawn (Claude Code restart or `/reload-plugins`).

## RQ6 — Data flow (JSON inline vs upstream write)

- [URL 8 — servers-archived/sqlite] SQLite reference server splits SQL by operation: **`read_query`** (SELECT, returns array of objects), **`write_query`** (INSERT/UPDATE/DELETE, returns `{ affected_rows: number }`), **`create_table`** (CREATE TABLE), plus `list_tables`, `describe_table`, `append_insight`.
- [URL 8] "The server implements **asymmetric permissions**: read operations operate without gates, while modification operations execute immediately upon invocation. There's no explicit confirmation requirement documented for destructive operations."
- [URL 9 — github.com/motherduckdb/mcp-server-motherduck] MotherDuck uses a single **`execute_query`** tool + `list_databases`, `list_tables`, `list_columns`, `switch_database_connection`. Results capped at "1024 rows or 50,000 characters by default."
- [URL 9] MotherDuck read-only is the **default**: "Activated by **omitting** the `--read-write` flag." Read-only requires a "read-scaling token rather than standard authentication tokens."
- [URL 10 — github.com/Snowflake-Labs/mcp] Snowflake Labs MCP: SQL is a **single unified tool** with `sql_statement_permissions` config controlling execution by statement type (Alter/Create/Delete/etc.) — "Those marked as False will be stopped before execution." Tools: Cortex Search, Cortex Analyst, Cortex Agent, object management, SQL, semantic view queries.
- [URL 11] Snowflake-managed (vendor-hosted) MCP exposes: Cortex Search queries, Cortex Analyst (semantic views only, not models), SQL execution ("read-write or read-only modes available"), Cortex Agents, custom tools via UDFs and stored procedures.

## RQ7 — Availability check

- [URL 8] SQLite read-only tools (no gates): `list_tables` (no params), `describe_table` (requires `table_name`). Schema inspection is the standard health/availability surface.
- [URL 9] MotherDuck mirrors the pattern: `list_databases`, `list_tables` (optional `database`/`schema`), `list_columns` (requires `table`). All read-only by default mode.
- [URL 10] Snowflake Labs MCP's RBAC-based check: the server "honors the RBAC permissions assigned to the specified role" — availability is implicit in connection success + role grants.

## RQ8 — Confirmation gates

- [URL 1 — modelcontextprotocol.io/specification/2025-11-25] MCP spec only states: "Hosts **must** obtain explicit user consent before invoking any tool" — consent is the **host's** responsibility, not the server's. "MCP itself cannot enforce these security principles at the protocol level."
- [URL 1] "Implementors **SHOULD**: Build robust consent and authorization flows into their applications."
- [URL 8] SQLite reference: no two-call/confirmation pattern — "delegating responsibility to client-level validation."
- [URL 9] MotherDuck: "**None documented**. The README contains no mention of confirmation prompts or approval workflows before executing write operations. Security relies entirely on the `--read-write` flag and connection permissions."
- [URL 10] Snowflake Labs MCP: "No explicit confirmation gates are documented. The MCP client determines execution prompts 'based on the MCP client settings.' Permission validation happens pre-execution through configuration rules."
- [URL 12] Project-scoped servers ("For security reasons, Claude Code prompts for approval before using project-scoped servers from `.mcp.json` files") — host-level gate, not server-level.
- Pattern across all reference impls: **read-only-mode-flag as alternative to runtime confirmation gates** (MotherDuck `--read-write`, Snowflake `sql_statement_permissions`).

## RQ10 — Engine-contract conformance

- [URL 1] MCP spec lists "Error reporting" as an additional utility but the index page does not detail typed error codes. The spec is JSON-RPC 2.0-based (errors use standard JSON-RPC error objects with `code`, `message`, `data`).
- [URL 1] Tool annotations are "untrusted, unless obtained from a trusted server" — servers signal tool behavior via metadata but clients can't trust it blindly.
- [URL 3] HTTP-layer error signaling for auth: 401 with `WWW-Authenticate` header pointing to PRM document for OAuth flow. "On 401, include `WWW-Authenticate` with `Bearer`, `realm`, and `resource_metadata` so clients can discover how to authenticate."
- [URL 3] HTTP 403 + `insufficient_scope`: Claude Code re-authenticates with pinned scopes on this signal.
- [URL 12] Claude Code distinguishes transient vs permanent failures explicitly: "Authentication and not-found errors are not retried because they require a configuration change to resolve" — servers should return distinguishable HTTP/JSON-RPC error codes for retry semantics to work.
- **No `confidence_score` precedent surfaced.** Snowflake Labs MCP, MotherDuck, SQLite all return raw results without per-result confidence annotations. Cortex Agents docs page didn't surface confidence scoring either. This is novel territory for Brite's engine contract.

## Cross-cutting facts not bucketed

- [URL 12] Claude Code MCP tool-output limit: warning at 10K tokens, default cap 25K, configurable via `MAX_MCP_OUTPUT_TOKENS` env. Tools can self-annotate with `_meta["anthropic/maxResultSizeChars"]` up to 500K chars — relevant for enrichment tools returning large entity sets.
- [URL 12] Tool Search (`ENABLE_TOOL_SEARCH`): MCP tools are **deferred by default** in Claude Code — only loaded on-demand. Server `instructions` field becomes load-bearing. "Keep them concise to avoid truncation" (2KB cap). Servers can set `"anthropic/alwaysLoad": true` on specific tools.
- [URL 12] `list_changed` notification supported: servers can refresh tool/prompt/resource lists mid-session without reconnect.
- [URL 12] Elicitation: servers can request mid-task structured input via Form or URL mode — relevant for interactive credential bootstrap or confirmation gates.
- [URL 13 — code.claude.com/docs/en/plugins.md] Plugins can ship `bin/` (executables added to Bash PATH while plugin enabled), `settings.json` (limited to `agent` and `subagentStatusLine` keys), `monitors/` (background watchers).
- [URL 14] Plugin-shipped agents do NOT support `mcpServers`, `hooks`, or `permissionMode` "for security reasons" — constrains how an enrichment-agent plugin can dispatch to its own MCP.
- [URL 14] `mcpServers` in plugin.json schema: `"string|array|object — MCP config paths or inline config"` — flexibility for splitting servers across files.

## URL fetch status

All 14 URLs fetched OK (no auth failures, no 404s). The Cortex Agents page (URL 11) shows "Generally Available" but the specific Nov 4 2025 GA date was not surfaced in the fetched excerpt — confirmed by BC-5536 issue text (added 2026-05-12).
