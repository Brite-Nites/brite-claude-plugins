# 007. RevOps Plugin Design Decisions

**Status:** Accepted
**Date:** 2026-04-19

## Context

The `workflows:ship` command today knows nothing about Brite's Salesforce deploy discipline — dry-run-first, 90%+ Apex coverage, post-deploy Tooling API SOQL verification, Screen Flow manual activation, Scheduled Apex re-scheduling, Named Credential PLACEHOLDER updates, `.forceignore` toggles. That SF discipline lives in `brite-salesforce/CLAUDE.md` but is inaccessible to agents operating in other repos.

BC-5534 (Salesforce MCP adoption research) identified `@salesforce/mcp@0.30.5` as the right tool-layer for Claude-SF interaction, and Jaganpro/sf-skills (MIT, CTA-authored, 36 skills + 7 agents) as the right starting point for the knowledge layer. We need a plugin that combines both.

This ADR locks the architectural decisions made during the 2026-04-19 scoping session that produced `docs/plans/revops-plugin-master-plan.md`. Capturing them here prevents re-litigation (and this ADR itself also documents a session-scope override of one master-plan decision — see §3.6).

## Decision Drivers

- **Gap in workflows for SF ship discipline** — `workflows:ship` doesn't know about Brite SF conventions; agents operating outside `brite-salesforce/` miss them entirely.
- **Jaganpro availability** — CTA-authored, MIT-licensed, 13 of 36 skills directly applicable to Brite (the other 23 cover Data Cloud / Agentforce / Industries / Vlocity / consulting — not in scope).
- **Brite-specific conventions** — ~15 metadata pitfalls, Apex-first principle, Queueable patterns, 7-permset FLS sync, 4 active ECAs, all documented in `brite-salesforce/CLAUDE.md` and `docs/artifacts/`.
- **Augment, not replace** — the existing inner loop (brainstorm → plan → worktree → execute → review → ship) works; SF knowledge should inject during those phases, not bypass them.
- **Cross-repo reach** — a Brite engineer working in `brite-gtm` should see zero SF noise; one working in `brite-salesforce` should see Brite deploy discipline surfaced automatically.

## Decisions

### 3.1 Plugin name: `revops`

"Revenue Operations" — broader than `salesforce` so dbt audience views, Outreach, Gong, or future CRM integrations fit cleanly without renaming. Peer to `marketing` and `workflows`.

### 3.2 Adoption method: `git subtree` with `--squash`

Import Jaganpro via `git subtree add --prefix=plugins/revops https://github.com/Jaganpro/sf-skills main --squash`. Treat as our own code going forward. `git subtree pull` remains available if we ever want upstream updates, but we commit to "this is ours now."

Rationale: subtree is strictly more flexible than wholesale fork. If we never pull upstream, it behaves identically. If upstream ships a bug fix we want, one command pulls it. `--squash` keeps repo history readable — we don't need Jaganpro's commit archaeology in our log.

### 3.3 Workflow integration: augment, don't replace

`workflows:session-start` / `workflows:review` / `workflows:ship` stay unchanged. RevOps adds:
- Auto-activating skills that inject SF knowledge during existing workflow phases (via intent-matching against skill descriptions)
- 3 new `/revops:*` commands for SF-specific orchestration that workflows doesn't cover: `deploy-sandbox`, `deploy-prod`, `post-deploy-runbook`
- Hooks that fire only in SFDX-adjacent contexts (cwd-aware)

### 3.4 MCP scope: `data,metadata,testing --no-telemetry`, GA-only

`plugins/revops/.mcp.json` registers `plugin:revops:salesforce` as `npx @salesforce/mcp@0.30.5 --orgs DEFAULT_TARGET_ORG --toolsets data,metadata,testing --no-telemetry`. No `--allow-non-ga-tools`. This is medium scope — broader than `plugins/marketing/`'s SOQL-read narrow scope, narrower than `brite-salesforce/.mcp.json`'s full dev scope (which adds `orgs,users` + non-GA tools).

Claude Code project-scope precedence means the three MCP instances (marketing narrow, revops medium, brite-salesforce broad) don't conflict when a session sits inside `brite-salesforce` — the most-local config wins.

### 3.5 Skill filter: 13 keep, 22 skip, 7 agents skip

**Keep (13):** sf-apex, sf-flow, sf-lwc, sf-soql, sf-testing, sf-debug, sf-metadata, sf-data, sf-docs, sf-permissions, sf-connected-apps, sf-integration, sf-deploy.

**Defer (1):** sf-diagram-mermaid — no customization issue filed; leaves upstream as-is for now.

**Skip (21 skills + 7 agents):** Data Cloud family (7), Agentforce AI family (5), Industries/Vlocity (7), sf-flex-estimator, sf-diagram-nanobananapro, all 7 consulting agents. None apply to Brite's stack.

### 3.6 Naming convention: keep upstream skill names

**Override of master plan §3.6, locked 2026-04-19.** Phase 3 skill customizations preserve upstream directory names (`sf-deploy`, `sf-apex`, etc.) rather than renaming to `brite-*`.

Rationale:
- Skill activation is description-driven, not name-driven. Claude matches user intent against SKILL.md frontmatter `description`, which gets customized regardless of directory name.
- The `plugins/revops/` namespace already signals Brite ownership — `plugins/revops/skills/sf-deploy/` is visibly "Brite's revops version" without any `brite-` prefix.
- Attribution header inside each customized SKILL.md (`# Brite-customized from Jaganpro/sf-skills@<sha>`) carries provenance where it counts: inside the file, where maintainers look.
- Keeping names upstream-matched preserves `git subtree pull --squash` as a low-friction future option. Every rename becomes a merge conflict during `subtree pull`.

### 3.7 Renames deferred to Phase 3 per-skill issues

With §3.6 resolved to "keep upstream names by default," each Phase 3 skill customization issue ships as a content-customization (SKILL.md content + attribution header + references/ updates) without directory rename. If a specific skill develops a Brite-specific reason to rename, that rename lives inside its per-skill issue with its own justification — not inherited from a global convention.

## Rejected Alternatives

### Pure fork (vs subtree)
Cloning Jaganpro into a new Brite-owned repo and losing the `git subtree pull` path entirely. Rejected because subtree is strictly more flexible — it behaves identically to a fork if we never pull upstream, and gives us a one-command bug-fix sync option if we ever want it. Zero-cost optionality.

### User-level Jaganpro install (vs plugin-level import)
Installing Jaganpro at `~/.claude/plugins/` alongside Brite plugins. Rejected because we can't layer Brite conventions on top — user-level installs are read-only from Brite's perspective, and Brite's ~15 metadata gotchas + Apex-first principle + Queueable patterns would have nowhere to live.

### `salesforce`-named plugin (vs `revops`)
Naming the plugin `salesforce` or `sfdx`. Rejected because it forecloses dbt audience views, Outreach/Gong integration, or future CRM expansions without a rename. `revops` scopes to the business function (revenue ops), not a single tool.

### Extending the `workflows` plugin (vs new plugin)
Adding SF skills to `plugins/workflows/skills/`. Rejected because SF knowledge is domain, not process. `workflows` should stay platform-agnostic (applies equally to any repo type). Domain plugins (marketing, revops, future) handle stack-specific intelligence.

## Consequences

### Positive
- Upstream sync path stays mechanical — `git subtree pull --squash` works against unmodified upstream names.
- Fork-behavior by default — zero ongoing maintenance cost if we never pull upstream.
- Plugin namespace (`revops`) is sufficient to signal Brite ownership without renaming each skill.
- `workflows:ship` becomes SF-aware in `brite-salesforce` context without touching the workflows plugin.

### Negative
- Drift from Jaganpro accumulates over time. If we ever want to pull upstream improvements after months of Brite customization, the per-skill merge cost will grow. Mitigation: periodic sync cadence or write our own patches upstream.
- Keeping upstream names means documentation inside each SKILL.md carries the Brite-vs-upstream distinction. Mitigation: the attribution header pattern is small and scripted (one header block per customized skill).

### Neutral
- Per-plugin versioning: `revops` starts at `0.1.0`, iterates independently of `workflows` and `marketing`. Matches the existing monorepo marketplace model (ADR-003).

## Reversibility

Each decision is individually reversible:

- **§3.1 Plugin name**: rename via `git mv plugins/revops plugins/<new>`. Marketplace.json + CLAUDE.md update. ~10 min.
- **§3.2 Adoption method**: if subtree proves wrong, convert to fork by extracting `plugins/revops/` to its own repo and updating `marketplace.json` source type. No consumer-facing change.
- **§3.6 Naming convention**: if we later decide `brite-*` renames add real value, each Phase 3 issue can re-enable the rename as a per-skill decision. The ADR override is a default, not a prohibition.

## Related

- `docs/plans/revops-plugin-master-plan.md` §3 — original decision record; §3.6 overridden by this ADR
- `docs/research/salesforce-mcp-findings.md` — BC-5534, underlying MCP research
- BC-5789 — scaffold `plugins/revops/` (blocked-by this ADR per master plan §4)
- Jaganpro/sf-skills: https://github.com/Jaganpro/sf-skills (upstream, MIT)
