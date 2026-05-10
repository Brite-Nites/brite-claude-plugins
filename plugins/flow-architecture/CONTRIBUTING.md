# Contributing to flow-architecture

This plugin is part of the [britenites-claude-plugins](https://github.com/Brite-Nites/britenites-claude-plugins) monorepo. Repo-wide contribution guidelines live in [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md). This file covers conventions specific to `flow-architecture`.

## Source of truth

The canonical design record is the multi-session interview at `docs/design-rationale/project_fda_plugin_interview.md` (2,306 lines, 54 Q-locks, 16 amendments). Before changing plugin behavior, **find the relevant Q-lock and read it**. The architecture overview (`fda-plugin-architecture-overview.md`) is a reading aid — the interview is authoritative.

For session bootstrap, paste the bridging prompt at `docs/design-rationale/00-resume-bridge.md` as the first user message in a fresh Claude Code session. That file is a **living artifact** — update it as state drifts (e.g., when a phase closes, a new editorial fix lands, or a cross-repo PR's status changes). The other 4 files in `docs/design-rationale/` are frozen Phase-3 output and should not be edited after merge.

## Linear scope

All FDA plugin work tracks under milestone **Flow-Driven Architecture Plugin v1.0** in the Brite Plugin Marketplace project. Issues carry the `flow-architecture` label plus a categorical (`skill` / `agent` / `command` / `infrastructure` / `documentation`) and a size (`size-S` / `size-M` / `size-L`). Parent issues have no size.

## Cross-cutting discipline

- **Parking-lot-#39 + extension** — re-verify cribbed sources at every consumer lock, not just at inheritance. Heavily-cited foundation locks accumulate errors at downstream drafting; the consumer must re-grep.
- **Validation-first cycle** — validate orchestrator suggestions against memory + actual files before applying. Push back on weak claims with line citations.
- **Schema-discipline amendment pattern** — when locks evolve, write an amendment-with-audit-trail in both the originating Q-lock and any consuming Q-locks; never silently mutate prior locks.

## Plugin-specific conventions

- **`plugin.json` strict schema** — only the documented allowlist of fields. Adding `agents`, `hooks`, or string-path `mcpServers` causes silent hard failure. See `../../CLAUDE.md` § Gotchas.
- **`_shared/` is nested inside `skills/`**, never top-level (Q30.2 lock, memory L281).
- **Bash 3.2 compatibility** — macOS ships bash 3.2 by default. Avoid associative arrays, `mapfile`, `${var,,}`, and other bash-4-only features. Guard empty `"${arr[@]}"` under `set -u` (per repo CLAUDE.md gotcha surfaced in BC-6905).
- **MCPs** — FDA's `.mcp.json` is empty (`{"mcpServers": {}}`). It reuses the workflows plugin's Linear MCP per BC-5810 / BC-5811. Duplicate registration breaks tool routing.
- **No plugin CLAUDE.md yet** — the plugin's own CLAUDE.md is Standalone #15 per Q55 and lands in a separate commit later in Phase 4 (4f), not as part of the scaffold.

## Working an issue

Most milestone issue bodies open with a `> Memory:` blockquote citing exact Q-lock line refs. Before touching any code:

1. Run `mcp__plugin_workflows_linear-server__get_issue` on the issue ID.
2. Open the cited Q-lock(s) in `docs/design-rationale/project_fda_plugin_interview.md`.
3. If the issue cites the architecture overview or other docs, read those too.
4. Cross-check via `get_issue` against any cross-referenced issues (`<issue id="...">BC-NNNN</issue>` tags in the body).

## Acceptance criteria are non-negotiable

Each issue body has an `## Acceptance criteria` section with concrete check commands. Run them. If they fail, do not declare the issue done.

## Plugin version + marketplace

Bump `plugins/flow-architecture/.claude-plugin/plugin.json` `version` AND the matching entry in `.claude-plugin/marketplace.json` (repo root) **in the same commit**. Clients' plugin cache is keyed on plugin version; deferring the bump leaves every client serving stale content. Costly precedent: BC-6000.
