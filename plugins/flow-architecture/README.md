# flow-architecture

Flow-Driven Architecture (FDA) plugin for Claude Code. Scaffolds UI-bearing Brite product builds into the FDA shape: Linear domain milestones + 5-discipline child issues + repo flow docs.

Implements [CDR-023](https://github.com/Brite-Nites/handbook/blob/main/decisions/CDR-023-flow-driven-architecture.md) (Brite handbook).

## Status

**Version 0.1.0 — alpha scaffold.** Slash commands and skills not yet wired up. Flips to `1.0.0` on the first successful Brand Hub retrofit (Q8 v1.0 acceptance gate, [BC-6998](https://linear.app/brite-nites/issue/BC-6998)).

See [ROADMAP.md](./ROADMAP.md) for the 6-phase plan and [ARCHITECTURE.md](./ARCHITECTURE.md) for the 4-tier domain model.

## v1.0 surface (planned)

- **4 orchestrators** — `/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow`
- **6 inner-loop utilities** — `/flow:audit`, `/flow:office-hours`, `/flow:retro`, `/flow:session-start`, `/flow:review`, `/flow:ship`
- **5 plan-X commands** — `/flow:plan-{story,eng,design,qa,docs}`
- **Deferred to v1.1** — `/flow:design-consult`, `/flow:journey-refresh`

## Install

The plugin is distributed through the `britenites-claude-plugins` marketplace.

```
/plugin marketplace add Brite-Nites/britenites-claude-plugins
/plugin install flow-architecture
```

## Dependencies

- **`workflows` plugin** (required) — provides the Linear MCP server (`mcp__plugin_workflows_linear-server__*`). Per [BC-5810](https://linear.app/brite-nites/issue/BC-5810) § 4 and [BC-5811](https://linear.app/brite-nites/issue/BC-5811) § 4.2, duplicate registration breaks tool routing, so FDA's own `.mcp.json` is empty and reuses the workflows registration.
- **External CLIs** — `bash 3.x+`, `python3 3.6+`, `git 2.x+`. `gh` is soft (optional auth check).
- **OS** — macOS or Linux with POSIX filesystem (atomic rename). No Windows in v1.

## For contributors

See [CONTRIBUTING.md](./CONTRIBUTING.md) for working in this plugin. The canonical design record is `docs/design-rationale/fda-plugin-interview.md` (2,306 lines, 54 Q-locks). For session bootstrap, paste `docs/design-rationale/00-resume-bridge.md` as the first user message in a fresh Claude Code session.
