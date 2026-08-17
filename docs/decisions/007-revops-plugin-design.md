# 007. RevOps Plugin Design Decisions

**Status:** Accepted (2026-04-19); **amended 2026-06-02** — §3.3 + §3.4 reconciled to as-built (7 commands, 2 MCP servers); **amended 2026-07-07** — §3.5 clarified: `skills-registry.json` is a superset with runtime-install packs, not a strict on-disk manifest (BC-16683); original locked decisions unchanged.
**Date:** 2026-04-19 / amended 2026-06-02 / amended 2026-07-07

## Context

The `workflows:ship` command today knows nothing about Brite's Salesforce deploy discipline — dry-run-first, 90%+ Apex coverage, post-deploy Tooling API SOQL verification, Screen Flow manual activation, Scheduled Apex re-scheduling, Named Credential PLACEHOLDER updates, `.forceignore` toggles. That SF discipline lives in `brite-salesforce/CLAUDE.md` but is inaccessible to agents operating in other repos.

BC-5534 (Salesforce MCP adoption research) identified `@salesforce/mcp@0.30.5` as the right tool-layer for Claude-SF interaction, and Jaganpro/sf-skills (MIT, CTA-authored, 36 skills + 7 agents) as the right starting point for the knowledge layer. We need a plugin that combines both.

This ADR locks the architectural decisions made during the 2026-04-19 scoping session that produced `docs/plans/revops-plugin-master-plan.md`. Capturing them here prevents re-litigation (and this ADR itself also documents a session-scope override of one master-plan decision — see §3.6).

## Decision Drivers

- **Gap in workflows for SF ship discipline** — `workflows:ship` doesn't know about Brite SF conventions; agents operating outside `brite-salesforce/` miss them entirely.
- **Jaganpro availability** — CTA-authored, MIT-licensed. Of 36 upstream skills: 13 directly applicable and Brite-customized, 1 shipped unmodified (sf-diagram-mermaid), 22 out of scope (Data Cloud, Agentforce, Industries, Vlocity, flex-estimator, nanobananapro-diagramming). All 7 upstream consulting agents are also out of scope.
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

> **Update 2026-06-02 (as-built):** the command surface has grown from 3 to **7**. Original three: `deploy-sandbox`, `deploy-prod`, `post-deploy-runbook`. Added since: `setup-sandbox` (guided sandbox auth) and `doctor` (zero-mutation SF environment health check) — the onboarding → health lifecycle; plus `create-sf-campaign` and `update-sf-campaign-status` — the GTM campaign-sync seam, owned by `marketing` and governed by [ADR-015](015-gtm-sigma3-sf-campaign-sync.md), hosted here as commands. Per `CONTEXT.md`, campaign-sync is **not** part of revops's core charter (SF knowledge + deploy/ops discipline) — it is a seam revops hosts on marketing's behalf.
>
> **Update 2026-08-17 (superseded by [ADR-026](026-revops-promotion-topology.md), built in BC-19521):** the deploy command names above are historical. `deploy-sandbox` → `preview-changes`, `deploy-prod` → `push-to-production`, `setup-sandbox` → `setup-dev-workspace`, `doctor` → `check-environment-health`, `post-deploy-runbook` → `run-manual-post-deploy-steps`, plus two new commands (`submit-changes-to-integration`, `emergency-deploy-to-production`). Each old name survives as a deprecation stub. This note records the rename; ADR-026 records why.

### 3.4 MCP scope: `data,metadata,testing --no-telemetry`, GA-only

`plugins/revops/.mcp.json` registers `plugin:revops:salesforce` as `npx @salesforce/mcp@0.30.5 --orgs DEFAULT_TARGET_ORG --toolsets data,metadata,testing --no-telemetry`. No `--allow-non-ga-tools`. This is medium scope — broader than `plugins/marketing/`'s SOQL-read narrow scope, narrower than `brite-salesforce/.mcp.json`'s full dev scope (which adds `orgs,users` + non-GA tools).

Claude Code project-scope precedence means the three MCP instances (marketing narrow, revops medium, brite-salesforce broad) don't conflict when a session sits inside `brite-salesforce` — the most-local config wins.

> **Update 2026-06-02 (as-built):** `plugins/revops/.mcp.json` now registers a **second** server alongside `salesforce` — `plugin:revops:gbrain-team` (the Brite handbook "brain", via `${CLAUDE_PLUGIN_ROOT}/scripts/gbrain-team-broker.sh`). Two servers remains within the ADR-009 §3 soft cap (~5–6). The `salesforce` server is otherwise unchanged (`DEFAULT_TARGET_ORG`, `data,metadata,testing`, GA-only). The canonical owner of the gbrain-team registration is the `brite-core` plugin; revops and 4 other plugins (workflows, marketing, cadence, flow-architecture) currently self-register the same broker for standalone resilience. Whether to consolidate on `brite-core` vs keep self-registration is an open cross-plugin question — not settled by this ADR.

### 3.5 Skill filter: 13 customized, 1 deferred, 22 skip, 7 agents skip

**Keep (13):** sf-apex, sf-flow, sf-lwc, sf-soql, sf-testing, sf-debug, sf-metadata, sf-data, sf-docs, sf-permissions, sf-connected-apps, sf-integration, sf-deploy.

**Defer (1):** sf-diagram-mermaid — installed unmodified, no Brite customization issue filed yet. The plugin ships 14 skill directories total (13 customized + this one).

**Skip (22 skills + 7 agents):** Data Cloud family (7), Agentforce AI family (5), Industries (7), Vlocity (1), sf-flex-estimator, sf-diagram-nanobananapro, all 7 consulting agents. None apply to Brite's stack.

**Amendment 2026-07-07 (BC-16683) — `skills-registry.json` is a superset, not a strict manifest.** The "Skip (22)" bullet above conflates two distinct classes. `plugins/revops/shared/hooks/skills-registry.json` deliberately retains all 36 upstream entries; the 22 with no on-disk `SKILL.md` split as:

- **Runtime-installable (7):** the Data Cloud family (`sf-datacloud`, `-connect`, `-prepare`, `-harmonize`, `-segment`, `-act`, `-retrieve`). These are *not* skipped in the "never ported" sense — they are installed on demand via `tools/install.py --with-datacloud-runtime` (community `sf data360` CLI), and their full trigger metadata + `background_operations` rules are load-bearing for the active `tests/test_datacloud_registry_contracts.py`. They stay in the registry so the packs remain discoverable and installable.
- **Not-ported (15):** Agentforce AI family (5, incl. `sf-ai-agentscript`), Industries (7), Vlocity (1), `sf-flex-estimator`, `sf-diagram-nanobananapro`. Genuinely out of scope per the original §3.5 skip; retained only as registry entries. The deeper "delete these families entirely" question is deferred to the revops owner (out of BC-16683).

Each absent entry now carries an explicit `absent_reason` marker (`"runtime-installable"` | `"not-ported"`). The previously-quarantined `test_registry_does_not_reference_missing_sf_skill_directories` is re-scoped to fail only on *unmarked* absent `sf-*` entries — genuine silent drift (a renamed/deleted on-disk skill whose registry entry lingers, or a bogus marker value used to mute the check) — and un-quarantined. The registry is therefore a **superset with runtime-install packs**, not a strict on-disk manifest.

### 3.6 Naming convention: keep upstream skill names

**Override of master plan §3.6, locked 2026-04-19.** Phase 3 skill customizations preserve upstream directory names (`sf-deploy`, `sf-apex`, etc.) rather than renaming to `brite-*`.

Rationale:
- Skill activation is description-driven, not name-driven. Claude matches user intent against SKILL.md frontmatter `description`, which gets customized regardless of directory name.
- The `plugins/revops/` namespace already signals Brite ownership — `plugins/revops/skills/sf-deploy/` is visibly "Brite's revops version" without any `brite-` prefix.
- Attribution header inside each customized SKILL.md (`# Brite-customized from Jaganpro/sf-skills@<sha>`) carries provenance where it counts: inside the file, where maintainers look.
- Keeping names upstream-matched preserves `git subtree pull --squash` as a low-friction future option. Every rename becomes a merge conflict during `subtree pull`.

### 3.7 Renames deferred to Phase 3 per-skill issues

With §3.6 resolved to "keep upstream names by default," each Phase 3 skill customization issue ships as a content-customization (SKILL.md content + attribution header + references/ updates) without directory rename. If a specific skill develops a Brite-specific reason to rename, that rename lives inside its per-skill issue with its own justification — not inherited from a global convention.

### 3.8 Upstream agents: don't port; preserve as prior art

**Locked 2026-04-27 via BC-5820 evaluation.** §3.5 above marks all 7 upstream consulting agents as skip. BC-5789's per-item audit-at-filter-time pattern (see [BC-5789 precedent](../precedents/BC-5789.md)) surfaced 3 candidates whose skill dependencies are entirely or mostly KEEP — `fde-release-engineer` (2 of 3 skills KEEP; `sf-ai-agentscript` is in the skipped Agentforce family), `ps-solution-architect` (5 of 5 KEEP), `ps-technical-architect` (8 of 8 KEEP). All 3: don't port.

Per-candidate rationale:

- **fde-release-engineer** — duplicated by `/revops:deploy-sandbox`, `/revops:deploy-prod`, `/revops:post-deploy-runbook` (shipped via BC-5790 / BC-5791 / BC-5792). Slash commands orchestrate the deploy and gate on user confirmation; an agent persona over the same skills adds no execution value those commands don't already provide.
- **ps-solution-architect** — 4 KEEP + 1 Defer skill per §3.5 (`sf-metadata`, `sf-flow`, `sf-permissions`, `sf-testing`, plus the deferred `sf-diagram-mermaid` shipped unmodified) — all 5 auto-activate via description-matching during `workflows:executing-plans`; `workflows:architecture-reviewer` covers the design-review angle.
- **ps-technical-architect** — 8 KEEP skills (`sf-apex`, `sf-integration`, `sf-connected-apps`, `sf-data`, `sf-soql`, `sf-debug`, `sf-deploy`, `sf-lwc`) all auto-activate; same coverage as `ps-solution-architect`.

**Cross-cutting reason.** Brite plugins' *review-family* agents use a narrow read-only specialist shape: minimal frontmatter (`name + description + model + tools`) with read-only tooling (`Glob, Grep, Read, Bash`), single-purpose `description`, no `skills` / `memory` / `maxTurns`. (Brite also ships task-specific orchestrator/drafter/auditor agents like `issue-creator`, `post-plan-orchestrator`, `narrative-writer`, `project-audit` — those have wider tool surfaces but are not review-family agents.) Upstream Jaganpro consulting agents are *implementation actors* with `permissionMode: acceptEdits`, `tools: Read, Edit, Write, Bash, Grep, Glob` (plus `WebFetch, WebSearch` on the two `ps-*` agents), `disallowedTools`, declared `skills:` lists, `memory: project|user`, `maxTurns: 25`, and persona-driven workflows. Porting any of the 3 would establish a new agent shape in Brite plugins — an architectural commitment larger than BC-5820's scope. The decision to introduce implementation-actor agents (or not) belongs in a future ADR.

**Recoverability.** All 3 agent files remain accessible via `git show ff1ab74:agents/<file>` (pinned subtree commit, recoverable per BC-5789's audit log) if a future ADR changes this position.

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
- **§3.8 Upstream agents**: if a future ADR adopts the implementation-actor agent shape, the 3 candidate files are recoverable via `git show ff1ab74:agents/<file>` (see §3.8 Recoverability). ~5 min per agent.

## Related

- `docs/plans/revops-plugin-master-plan.md` §3 — original decision record; §3.6 overridden by this ADR
- `docs/research/salesforce-mcp-findings.md` — BC-5534, underlying MCP research
- BC-5789 — scaffold `plugins/revops/` (blocked-by this ADR per master plan §4)
- Jaganpro/sf-skills: https://github.com/Jaganpro/sf-skills (upstream, MIT)
