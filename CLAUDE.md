# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Superpowers methodology + compound engineering + Linear integration.** A Process + Org plugin bundle for the Brite organization — structured workflow (brainstorm → plan → worktree → execute → review → compound → audit) with Linear woven into every step. No build process; changes are pure markdown/JSON.

## Linear Project

Project: **Brite Skill Packs** (team: Brite Company, prefix: `BC-`, not `BRI-`).
Sibling projects (same team, same prefix, same initiative — created 2026-05-27 4-layer re-org): **Brite Orchestration Layer** (Layer A), **Brite Knowledge Layer** (Layer D), **Brite Runtime & Harness** (Layer B). See `docs/history/prd-m5-m8-archive.md`.

## Quick Start

```bash
./scripts/validate.sh                              # Validate all plugins (CI-equivalent)
./scripts/check-guardrails.sh --claude-md CLAUDE.md # Enforce CLAUDE.md size + anti-slop
./scripts/dev-setup.sh                             # Symlink plugin for live editing
./scripts/release.sh <major|minor|patch> [name]    # Cut a release
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full script reference, `plugin.json` schema, frontmatter rules, and CI checks.

## Key References

- **Memory:** `memory/MEMORY.md` — session-spanning knowledge (project status, recent decisions, session history). Always loaded at session start; check it before asking about prior work.
- **Skill ↔ tool integration pattern:** [`docs/guides/skill-tool-integration-pattern.md`](docs/guides/skill-tool-integration-pattern.md) — how skills reference MCP servers. Apply the 6-item PR checklist before merging any skill that calls an external service.
- **Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md) — plugin resolution, runtime flow, hook execution, full skill routing catalog.
- **Marketing skill porting:** [`docs/guides/marketing-skill-porting.md`](docs/guides/marketing-skill-porting.md) — upstream `coreyhaines31/marketingskills` → `plugins/marketing/` conventions.

## Architecture Decisions

On-demand references — read when working on these subsystems, not auto-loaded every session:

- [ADR-001: Cross-repo import solution](docs/decisions/001-cross-repo-import-solution.md) — **Withdrawn** — see file for current status
- [ADR-002: Trait evolution mechanism](docs/decisions/002-trait-evolution-mechanism.md) — Trait add/remove commands + auto-detect
- [ADR-003: Plugin distribution architecture](docs/decisions/003-plugin-distribution-architecture.md)
- [ADR-007: RevOps plugin design decisions](docs/decisions/007-revops-plugin-design.md) — naming, subtree, augment-not-replace, skill filter, MCP scope
- [ADR-008: tam-mapping enrichment pluggability](docs/decisions/008-tam-mapping-enrichment-pluggability.md) — provider selection via userConfig, shared input/output schema, swap path
- [ADR-009: SF capability adoption framework](docs/decisions/009-sf-capability-adoption.md) — 6-check framework (runtime model, license, plugin slot, toolset breadth, GA gate, domain fit) with worked examples
- [ADR-010: Plugin secret-config canon](docs/decisions/010-plugin-secret-config-canon.md) — Bitwarden + `bw-run.sh` broker for stdio MCPs and CLI scripts; HTTP MCPs covered by BC-5551 exception
- [ADR-021: `raise-a-ticket` intake](docs/decisions/021-raise-a-ticket-intake.md) — Linear-native, cross-product product-feedback intake (Bug/Idea → `type:bug`/`type:task` + `needs-triage`) that reuses `docs/agents/issue-tracker.md` for routing and hands off to `/triage`; deprecates `bug-report` — *front-door consequence amended by ADR-022*
- [ADR-022: Unified intake front door](docs/decisions/022-unified-intake-front-door.md) — `raise-a-ticket` becomes the single front door with a Step-1 product-vs-agent-tooling fork (tooling dispatches to `report-issue`, kept as a direct alias); content-aware switch replaces the location-only redirect; cap-proof numbered-list disambiguation + multi-team modal default (BC-12400). Supersedes ADR-021's "keep separate" consequence only
- [ADR-023: GTM commercial-model vocabulary](docs/decisions/023-gtm-commercial-model-vocabulary.md) — campaign-level economic-axis vocabulary (`install-fee`/`rev-share`/`ticketed`/`sponsor`/`co-invest`/`hybrid`), distinct from offer-posture (ADR-017); resolves the `ticket`/`rev share` spelling drift; SF Campaign picklist declared as the future mapping target but not built (BC-12392)
- [ADR-024: Defer launch-campaign Phase 2 → `verify_emails` swap](docs/decisions/024-launch-campaign-verify-emails-swap-deferred.md) — defers the `launch-campaign` Phase 2 `verify_emails` swap to the bulk-verify door (BC-8173); the REST batch door (BC-5296) is the swap's real home. *(Index entry added when landing ADR-028 — #439 merged the ADR without one.)*
- [ADR-025: sfdx-hardis selective adopt-as-tool](docs/decisions/025-sfdx-hardis-adoption.md) — per-capability ADR-009 6-check on sfdx-hardis; adopt deploy/CI/SFDMU/quality, phase-2 monitoring, skip GUI, F1 stays a revops build (BC-12346, keystone of BC-12345)
- [ADR-026: revops promotion-topology command model & vocabulary](docs/decisions/026-revops-promotion-topology.md) — mirror of bn-salesforce ADR-016 (CI-driven deploy topology); dual-path, commands-as-orchestrators, intent-based command vocabulary, config-gated guidance (BC-12345)
- [ADR-027: artifact-class dimension for the SF capability-adoption framework](docs/decisions/027-sf-capability-adoption-artifact-class.md) — extends ADR-009 with a Step-0 artifact class (MCP server · CLI plugin · skill library) that selects each check's per-class reading, so non-MCP CLI tools/skill libraries score natively (no reinterpretation); GUI = Check-1 fail, class ⊥ capability granularity, sfdx-hardis re-run as the worked example (BC-12345 item #4)
- [ADR-028: Skill/command engineering discipline](docs/decisions/028-skill-engineering-discipline.md) — behavioral evals (artifact-level via a side-effect-free **emit mode** that runs an extracted deterministic builder; **native python/bash harness in `validate.sh`**, promptfoo reserved for a future advisory LLM smoke) become a phased ratchet: Phase 1 forward-only tiered gate (blocking: `disable-model-invocation` on side-effecting cmds + a changed cmd ships emit-mode + ≥1 eval; rest advisory), Phase 2 retroactive backfill. Deprecates decorative `evals/evals.json`. Repo-wide. Canonical checklist: [`docs/guides/skill-command-design-standards.md`](docs/guides/skill-command-design-standards.md).
- [ADR-029: Canonical FDA flow-doc key](docs/decisions/029-fda-canonical-flow-doc-key.md) — `flow_id`/`DOMAIN-NN` (+ `parent_issue`) is the single canonical FDA flow-doc identity key; the plugin tooling stays single-convention (no `sub_flow_id ?? flow_id` bridge), and the two kebab deviation repos converge instead (BC-13152); the unshipped central-templates draft is shelved for auto-seed
- [ADR-033: FDA journey-doc frontmatter canon](docs/decisions/033-fda-journey-frontmatter-canon.md) — 9-key journey frontmatter schema (`linear_milestone: {name, id:UUID}` nested per the real docs — the template's `milestone: BC-XXXX` was structurally impossible, consciously inverting ADR-029's template-wins outcome for that field; kebab `domain` + `display_name`; `linear_project_id` dropped; personas/flow_ids aggregated from story-doc frontmatter), stamped by `build_journey_frontmatter.py` + locked by the journey vslice (BC-13028 #4 journey half)
- [ADR-034: Full-surface structural gate + per-rule structural-debt list](docs/decisions/034-structural-ratchet-full-surface-gate.md) — ADR-028 Phase-2 ratchet wiring (BC-12700 bullet #2): `eval_gate.py --structural` (a second step in the REQUIRED eval-gate CI job) blocks any gate-tier structural-lint finding across commands AND skills unless covered by a `(file, rule)`-keyed row in `docs/structural-lint-debt.md` (R2 rows carry a line-count baseline; stale rows fail). Promoting a rule = flipping its severity constant; flip order R3→R5→R6→R2→R4. *(030–033 claimed by open PRs #398/#432/#475 at land time — 033 lost to #475 in-flight, the cross-pr-adr-guard's first live catch.)*

## Company Context

initiative: Shared Infrastructure to Move Quick
goal: Universal agent platform — structured discovery routes any project type to domain plugins, with handbook as company brain and autonomous execution
team: Brite Company / lead: Amanuel Belay
related-projects: Brite Enterprise Data Platform, Brite Handbook
handbook-library: /brite-nites/handbook
handbook-topics: architecture, coding-standards, tools, team-structure, onboarding

## Plugin Philosophy

- **Process**: Superpowers' full workflow with TDD, subagent-per-task execution, and compound knowledge accumulation
- **Org**: Linear integration at every step, security hooks, team conventions
- **Not domain**: Skills that teach framework-specific patterns (React, Python, CI/CD) belong in domain plugins. Process skills (brainstorming, planning, execution) stay here.

## Repository Structure

Multi-plugin monorepo. Each plugin under `plugins/<domain>/` follows the same structure.

```
.claude-plugin/marketplace.json    # Plugin registry (lists all plugins)
plugins/
  workflows/                       # Process + org plugin (primary)
    .claude-plugin/plugin.json     # Plugin metadata
    commands/*.md                  # Slash commands
    skills/*/SKILL.md              # Auto-invoked skills (+ _shared/ utilities)
    agents/*.md                    # Review and utility agents
    hooks/hooks.json               # SessionStart hooks (auto-loaded)
    .mcp.json                      # MCP server configurations
  marketing/                       # Marketing domain plugin
    skills/*/SKILL.md              # Domain skills (context-skill pattern)
    tools/integrations/*.md        # Tool integration guides (see pattern)
    references/                    # Shared reference content read by skills (MIT upstream port, see UPSTREAM.md)
    data/canonicals/               # GTM canonicals (slug+display+personas+offers per ADR-016; lint at plugins/marketing/scripts/lint_canonicals.py)
    scripts/                       # Plugin-owned scripts (bw-run.sh secret broker, tam-map/, lint_canonicals.py)
    hooks/hooks.json
    .mcp.json
  revops/                          # SF dev + CRM data (subtree from Jaganpro/sf-skills, MIT — see UPSTREAM.md)
    skills/                        # 14 retained SF skills (filtered from upstream 36)
    .mcp.json                      # plugin:revops:salesforce
  cadence/                         # Weekly planning cadence (commands/weekly.md — 5 phases, 3 gates, resume breadcrumb; agents/narrative-writer.md drives Phase 4)
```

## Skill Routing

Skills activate via their `description` field — Claude matches user intent against descriptions. Full catalog (Inner Loop, Backend & Quality, Design, Post-Plan, Utility) in [ARCHITECTURE.md#skill-routing](ARCHITECTURE.md).

## Review Agents

Override the default review agent selection by adding a `## Review Agents` section to your project CLAUDE.md with `include:` / `exclude:` lists (Tier 1 agents — code, security, performance — cannot be excluded). Full spec, depth modes, confidence scoring, and model tiering in `docs/workflow-guide.md`.

## Agent skills

### Issue tracker

Issues live in **Linear** (Brite Company team, `BC-` prefix, *Brite Skill Packs* project) via the workflows-plugin Linear MCP — not GitHub Issues, despite the GitHub remote. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles with default label strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context; ADRs live in `docs/decisions/` (not `docs/adr/`). See `docs/agents/domain.md`.

## Gotchas

- **`plugin.json` strict schema.** Any unrecognized field causes silent hard failure with no error. Allowlist: `name`, `description`, `author`, `version`, `homepage`, `repository`, `license`, `keywords`, `commands`, `skills`, `mcpServers` (inline object only), `userConfig` (inline object declaring user-prompted settings; use with `sensitive: true` for secrets stored in OS keychain — but note that `${user_config.*}` substitution into HTTP MCP headers is currently broken in Claude Code (BC-5551), see `email-bison.md` § Known Claude Code limitation; for stdio MCPs the recommended pattern is OS env-vars populated by `bw-run.sh` rather than `userConfig` substitution, see [CONTRIBUTING.md § Plugin secret-config canon](CONTRIBUTING.md#plugin-secret-config-canon) — full Rejected Alternatives and rotation semantics in [ADR-010](docs/decisions/010-plugin-secret-config-canon.md)). **Never** add `agents`, `hooks`, or `mcpServers` as string path — they're auto-discovered by convention.
- **`userConfig` field paired with an ADR-defined "unset → auto-detect" resolution: omit `default`.** When an ADR specifies that an unset `${user_config.<field>}` triggers a probe-fallback chain (e.g., ADR-008 for `enrichment_provider` probes `brite_mcp` → `brite_cli` → `blitz_waterfall`), the userConfig MUST NOT specify a `default` — the field would never be "unset" at substitution time, silently making the auto-detect path unreachable. Cross-cite the ADR's resolution-order section in the userConfig description. Origin: BC-5832 review-fix.
- **`.claude-plugin/marketplace.json` registers a plugin; it does not install it.** A plugin can be in the marketplace registry, on disk under `plugins/<name>/`, and pass `scripts/validate.sh` while never appearing in `claude plugin list` — that's "registered but uninstalled." Symptom: commands, skills, AND agents are all absent from dispatchable lists (not just one of the three). Source of truth: `claude plugin list` output and `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` presence. Fix: `claude plugin install <name>@<marketplace>` (or `/plugin install` slash-command equivalent) once per scope (user or project). Defense-in-depth: `scripts/validate.sh` cross-checks every plugin in `.claude-plugin/marketplace.json` against `claude plugin list` and emits `WARN` for any registered-but-uninstalled plugin. Costly precedent: BC-9023 — BC-6998 iter 1 burned a full session diagnosing a "plugin-loader bug" that was actually an uninstalled plugin; the 6-plugin / 28-agent counts `/reload-plugins` kept printing were the totals WITHOUT flow-architecture, which iter 1's operator read as evidence the plugin was loading-but-broken.
- **MCP server soft cap ~5–6 per plugin (advisory).** Per-plugin, not global — user-level registrations (e.g., Email Bison) do not count. The cap protects startup latency and context budget, both measurable. A plugin at or near the cap must demonstrate `< 2s` startup-latency delta and `< 500 tokens` context-budget delta against a clean-session baseline before merge. See [`docs/research/tam-map-port-policy.md`](docs/research/tam-map-port-policy.md) § 1 for methodology.
- **Anchor `/.mcp.json` in `.gitignore`**, never unanchored `.mcp.json`. The unanchored form would match at any depth and silently ignore `plugins/*/.mcp.json` files, breaking plugin distribution.
- **Skill frontmatter for MCP tools:** `allowed-tools: mcp__plugin_<plugin>_<server>__*` for multi-tool servers, `mcp__plugin_<plugin>_<server>__<tool_name>` for single-tool servers. The `plugin_<plugin>_` namespace is auto-generated from the OWNING plugin's `.mcp.json` (where the server is registered) — don't hand-edit. **Cross-plugin invocation IS supported**: a skill in plugin A can declare `mcp__plugin_B_<server>__*` and it resolves at runtime, because the namespace is globally addressable. Confirmed sibling pattern: `plugins/cadence/skills/linear-housekeeping/SKILL.md` declares `mcp__plugin_workflows_linear-server__*` from a non-workflows plugin and works. `allowed-tools` is NOT cross-validated: listing a server that isn't registered ANYWHERE (typo, deleted server) fails silently at runtime (the first availability probe hits a missing server and halts). Cross-check every `mcp__plugin_<plugin>_<server>__*` entry against `plugins/<owning-plugin>/.mcp.json` before merging. See the pattern guide for the full rule set.
- **Hook `type: "prompt"` requires a concrete model ID.** Tier aliases (`haiku`, `sonnet`, `opus`) are rejected by the hook evaluator with `Hook evaluator API error: There's an issue with the selected model (...)`. Use `claude-haiku-4-5` (or the dated `claude-haiku-4-5-20251001`). Agent frontmatter is a separate resolver that still accepts tier names. **Enforced by `scripts/_lib/lint_hooks.py`** (runs in `validate.sh` + via `validate-single.sh hooks`).
- **PreToolUse/PostToolUse plugin hooks now fire** — upstream bug [#6305](https://github.com/anthropics/claude-code/issues/6305) previously suppressed them. Recent Claude Code versions run them normally. Hook errors fail open (the tool call proceeds) but surface as red banners in the UI.
- **Bump plugin version in the SAME commit as any edit under `plugins/<plugin>/{hooks,skills,commands,agents}/**`.** Clients' plugin cache is keyed by plugin version; deferring the bump leaves every client serving the old content. Bump BOTH `plugins/<plugin>/.claude-plugin/plugin.json` and the matching `.claude-plugin/marketplace.json` entry. Costly precedent: BC-6000 — a hook fix sat uncollected in cache for 4+ `/workflows:ship` sessions before anyone diagnosed the cause.
- **`context: fork` has upstream bugs** ([#16803](https://github.com/anthropics/claude-code/issues/16803), [#17283](https://github.com/anthropics/claude-code/issues/17283)) — skills declaring it run inline in the parent context for now.
- **`SessionStart` `command`-hook stdout is model-context-only in Claude Code v2.1.x** (observed in v2.1.123; upstream pins window) — stdout reaches the model via `<system-reminder>` (skills activate normally) but no longer renders as a visible terminal block. Tracked upstream as [#24425](https://github.com/anthropics/claude-code/issues/24425). For user-visible session context, use statusline (`statusLine` setting) or a slash command. Diagnosed in BC-6434.
- **Bash scripts using `set -u` MUST guard `"${arr[@]}"` of arrays that may be empty.** macOS ships bash 3.2 by default; bash 3.2 + `set -u` errors with `arr[@]: unbound variable` for empty-array expansion. Wrap with `if [ "${#arr[@]}" -gt 0 ]; then for x in "${arr[@]}"; do ...; done; fi`. Surfaced in BC-6905 — the spike's verbatim wrapper code wouldn't have run on macOS without this guard.
- **`validate.sh` Step-sequence lint treats `## Step N.M` as duplicate Step N.** The regex `^#{2,4} Step [0-9]+([^0-9a-zA-Z]|$)` extracts the leading integer; `.` matches `[^0-9a-zA-Z]`, so `## Step 1.5 — ...` registers as Step 1 + creates `gap Step 1 to Step 2` AND `duplicate Step 1` errors. Use the sub-step letter-suffix form `## Step 1b — ...` instead — `1b` fails the regex (next char after `1` is alphanumeric), excluded from sequence counting, no false-positive. Per the validator's own comment: "Sub-steps like 'Step 2b' are excluded." Surfaced in BC-8724 iter-1 fixes 2026-05-19 when a new parse-time-validation sub-step landed as `## Step 1.5` and blocked validate.sh.
- **APFS case-insensitive `.gitignore` matches silently swallow new files.** macOS APFS is case-insensitive by default; git's gitignore matching follows the filesystem's case-sensitivity. A top-level `AUDIT.md` rule (or any case-overlapping pattern) silently matches `audit.md`, `Audit.md`, etc. — symptom: file written + visible via `ls`, but absent from `git status` and `git ls-files` (not even `??`). Always run `git check-ignore -v <path>` after writing a new file whose name case-insensitively overlaps an existing gitignore pattern; add an explicit `!path/to/file.md` negation when needed. Surfaced in BC-6969 ([precedent task-4](docs/precedents/BC-6969.md#BC-6969-task-4)) — `audit.md` was silently swallowed by `.gitignore`'s `AUDIT.md` rule.
- **`git push --force` / `-f` is regex-blocked; `--force-with-lease` and `--force-if-includes` are allowed on all branches.** workflows v3.31.0+ (BC-11889) replaced the Haiku LLM classifier with regex-only gating — the regex matches `--force`/`-f` but not the safer check-then-push variants, so they pass everywhere (including `main`). The BC-11117 branch-aware carve-out was retired with its classifier. Defense-in-depth for the regex is in `scripts/test-hooks.sh` (wired into `validate.sh` §2d).
- **Any command interpolating a non-literal `--target-org` (`<placeholder>`/`$var`, not a literal alias) into an `sf` shell-out MUST carry a standalone `<!-- guard:target-org -->` marker before its earliest sink** + the byte-identical `^[a-zA-Z0-9._@-]+$` guard (`$(...)`/backtick survives `"<value>"` double-quoting). Enforced repo-wide by `scripts/_lib/lint_target_org_guard.py` (validate.sh); copy-paste-only snippets use `<!-- guard:target-org:exempt <reason> -->`. Per-command failure idiom varies (σ3 soft-fail JSON vs marketing hard-fail `ERROR:`) — keep it; only placement + regex are uniform. See [ADR-015 §Amendment 2026-06-07](docs/decisions/015-gtm-sigma3-sf-campaign-sync.md). Origin: BC-12637 (after the BC-10511→12594→12623 whack-a-mole).
- **Claim an ADR number before authoring `docs/decisions/NNN-slug.md`.** Numbers are read off `main`; two branches reading a stale `main` grab the same `NNN` with different slugs, git never flags it (filenames differ), and the 2nd merge silently creates a duplicate (happened 4× in one week — same silent-failure family as the registered-but-uninstalled + version-bump gotchas above). Before adding an ADR: (1) read the next free number off **`origin/main`** (not stale local main); (2) check `gh pr list` + open Linear issues for any in-flight PR/issue already using it; (3) put the claimed `NNN` in your PR/issue title. The CI backstop is `scripts/_lib/lint_adr_numbers.py` (`validate.sh §15a-bc-12617`) — it fails loudly on duplicate normalized numbers (`021` == `21`) but catches at merge/post-merge time, so claiming first avoids the renumber cascade. The guard detects DUPLICATES only: gaps (004–006 absent, 001 Withdrawn) are legitimate. Cross-PR-*pre-merge* detection (catch at PR-open time) now exists as an **advisory** CI job (`.github/workflows/validate-plugin.yml` → `cross-pr-adr-guard` → `scripts/ci/cross-pr-adr-guard.sh`, a thin `gh` adapter over the deterministic core `scripts/_lib/lint_cross_pr_adr_numbers.py`, self-tested at `validate.sh §15a-bc-12698`): on a `pull_request` it names any other OPEN PR already claiming your added `NNN` so you renumber before the cascade. It's advisory and racy by design (each PR's run only sees what's open then; both colliding PRs may red on their own runs) and checks OTHER open PRs ONLY — vs-main is already covered by §15a-bc-12617's merge-ref tree scan — so the claim-first step + the within-repo backstop stay the real guards; the cross-PR job is the earlier-surface, valuable mainly when the convention is skipped. Both guards share ONE filename→number rule (`scripts/_lib/adr_numbers.py`), locked by a parity test so they can't drift. Formalized org-wide (per-repo ADRs + handbook CDRs) as **CDR-025** (handbook `decisions/CDR-025-claim-first-decision-record-numbering.md`). Origin: BC-12617 (within-repo) + BC-12698 (cross-PR) + BC-12699 (CDR-025).
