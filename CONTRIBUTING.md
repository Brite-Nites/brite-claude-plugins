# Contributing

Internal guide for the Brite Nites team working on this plugin bundle.

## Plugin Philosophy

This is a **Process + Org plugin**. When adding new components:

- **Process skills** (how to work): writing-plans, executing-plans, debugging methodology — YES
- **Org commands** (team workflows): sprint-planning, retrospective, deployment-checklist — YES
- **Domain skills** (tech-stack knowledge): Python patterns, Shopify docs, database guides — NO (create a separate domain plugin instead)

If you're unsure whether something belongs here, ask: "Is this about *how* we work, or *what* we know about a technology?" Process and workflow → this plugin. Technology knowledge → separate domain plugin.

## Quick Reference

### Add a command

1. Create `plugins/workflows/commands/my-command.md`
2. Add YAML frontmatter with `description`
3. Write instructions in markdown — use `$ARGUMENTS` for user input

### Add a skill

1. Create `plugins/workflows/skills/my-skill/SKILL.md`
2. Add frontmatter matching the [standard](#skillmd-frontmatter-standard) below
3. Ensure `name` matches the directory name exactly
4. Write skill instructions in markdown

### Add an agent

1. Create `plugins/workflows/agents/my-agent.md`
2. Add frontmatter: `name`, `description`, `model`, `tools`
3. Write system prompt with role and principles
4. Reference from a skill via `agent: my-agent` in the skill's frontmatter

### Add a hook

1. Edit `plugins/workflows/hooks/hooks.json`
2. Add to the appropriate event (`PreToolUse`, `PostToolUse`, `SessionStart`)
3. Choose type: `prompt` (LLM-evaluated) or `command` (shell script)
4. Set a `matcher` regex for which tools trigger the hook
5. Run `python3 -m json.tool hooks/hooks.json` to validate JSON
6. If `type: "prompt"`: `model` must be a concrete ID (e.g. `claude-haiku-4-5`). Tier aliases (`haiku`/`sonnet`/`opus`) are rejected by the hook evaluator — see the gotcha in `CLAUDE.md`.
   - `scripts/validate.sh` enforces this repo-wide.
   - `scripts/validate-single.sh hooks` runs just the hook-config checks for fast single-file feedback.

### Add a tool-using skill

A skill that calls an external service (Linear, Email Bison, Salesforce, etc.) follows a specific three-layer pattern — read [`docs/guides/skill-tool-integration-pattern.md`](docs/guides/skill-tool-integration-pattern.md) before starting. Quick version:

1. **Pick an MCP server.** MCP-first is the default — only add a CLI wrapper when you can name a concrete non-Claude caller.
2. **Register the server** in the plugin's `.mcp.json`. Use `${ENV_VAR}` substitution for credentials — never commit real keys.
3. **Write the integration guide** at `plugins/<plugin>/tools/integrations/<tool>.md` using [`plugins/marketing/tools/integrations/_template.md`](plugins/marketing/tools/integrations/_template.md). Connection details, auth, and full tool inventory go here — zero procedural logic.
4. **Write the skill** with `allowed-tools: mcp__plugin_<plugin>_<server>__*` in the frontmatter. Call tools by semantic name in the body. Zero connection details. See `plugins/workflows/skills/create-issues/SKILL.md` as the working reference.

Every tool-using PR must pass the 6-item checklist at the end of the pattern guide.

## plugin.json Schema (STRICT — read before editing)

**Claude Code validates plugin.json against a strict Zod schema. Any unrecognized field causes a silent hard failure — the entire plugin won't load (no commands, no skills, nothing). There is no error message shown to the user.**

Only these fields are recognized:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | string | yes | |
| `description` | string | yes | |
| `author` | `{ name, email? }` | yes | |
| `version` | string | no | Must bump for cache invalidation |
| `homepage` | string | no | |
| `repository` | string | no | |
| `license` | string | no | |
| `keywords` | string[] | no | |
| `commands` | string | no | Path to commands dir (e.g., `"./commands/"`) |
| `skills` | string | no | Path to skills dir (e.g., `"./skills/"`) |
| `mcpServers` | object | no | **Inline object only**, not a file path |

**NEVER add these to plugin.json** (they are auto-discovered from the plugin root):
- `agents` — the `agents/` directory is scanned automatically
- `hooks` — `hooks/hooks.json` is loaded automatically
- `mcpServers` as a string path (e.g., `"./.mcp.json"`) — `.mcp.json` is loaded automatically. If you must declare MCP servers in plugin.json, use the inline object format.

The `scripts/validate.sh` pre-push hook and CI workflow both enforce this allowlist.

## SKILL.md Frontmatter Standard

```yaml
---
name: skill-name              # Required. Must match the directory name.
description: When to use...   # Required. Unquoted plain YAML string.
user-invocable: true           # Required. Explicit true or false.
allowed-tools: Tool(pattern)   # Optional. Only when skill needs specific tool permissions.
license: MIT                   # Optional. SPDX identifier for third-party content.
metadata:                      # Optional. Only for skills from external sources.
  author: source-org
  version: "1.0.0"
---
```

**Rules:**
- `name` must match the skill's directory name (`skills/react-best-practices/` → `name: react-best-practices`)
- `description` must not be quoted — use plain YAML string (no `>` folded blocks, no `"..."`)
- `user-invocable` must always be explicit — never rely on defaults
- `license` is only needed for third-party content
- `metadata` is only needed for skills ported from external sources

**Agent-linked skills** also use:
- `agent: agent-name` — references an agent in `agents/`
- `context: fork` — intended for isolated execution (currently has upstream bugs, runs inline)

## Hooks

The plugin includes hooks in `plugins/workflows/hooks/hooks.json` (auto-loaded by Claude Code — do NOT add a `hooks` field to `plugin.json`):

- **PreToolUse (Bash)**: Two-layer security — regex command hook (deterministic, blocks `rm -rf`, `--force`, `DROP`, `chmod 777`, piped downloads) runs first, then Haiku prompt hook as fallback
- **PreToolUse (Bash)**: Pre-commit quality — intercepts `git commit` commands, detects project type (`package.json` → JS/TS, `pyproject.toml`/`setup.py` → Python), runs linters on staged files only (ESLint, `tsc --noEmit`, Ruff). Degrades gracefully if no linters installed. Note: inactive from plugins until upstream [#6305](https://github.com/anthropics/claude-code/issues/6305) is fixed.
- **PreToolUse (Write/Edit)**: Two-layer security — regex command hook (deterministic, blocks `sk-proj-`, `AKIA`, `ghp_`, `sk_live/test` patterns) runs first, then Haiku prompt hook as fallback
- **PostToolUse (Write/Edit)**: Auto-linter — runs ESLint (JS/TS) or Ruff (Python) if available
- **SessionStart**: Team context — runs environment health checks (git, node, gh, npx) and shows key commands

A standalone version of the pre-commit hook is available at `scripts/pre-commit.sh` for direct installation as a git hook (`cp scripts/pre-commit.sh .git/hooks/pre-commit`). This works today regardless of the upstream plugin hook bug.

## Salesforce MCP Onboarding

The `marketing` plugin ships `@salesforce/mcp` for skills that read from the prod Salesforce org (`list-building`, `reply-processing`, `lead-routing`, `data-enrichment`, `crm-hygiene`). Unlike most MCPs, `@salesforce/mcp` **reads no runtime env vars** — it delegates 100% to the local SFDX auth store (`~/.sfdx/`). Onboarding is a one-time SFDX CLI provisioning step, not an `.env` file.

**What's committed:** the MCP entry in `plugins/marketing/.mcp.json` uses the `DEFAULT_TARGET_ORG` sentinel — no alias, no URL, no creds.

**One-time per-dev setup:**

1. Install the Salesforce CLI: `brew install --cask sfdx`
2. Retrieve the **Marketing Claude MCP — JWT private key** from the Engineering Bitwarden collection.
3. Run the JWT login (derive `--client-id` and `--instance-url` out-of-band — see [`plugins/marketing/tools/integrations/salesforce.md`](plugins/marketing/tools/integrations/salesforce.md)):

   ```bash
   sf org login jwt \
     --client-id <consumer-key> \
     --jwt-key-file <path-to-key> \
     --username <service-user> \
     --alias <your-alias> \
     --instance-url https://<instance>.my.salesforce.com
   ```

4. Map the sentinel: `sf config set target-org <your-alias>`.
5. `/reload-plugins` in Claude Code.
6. Smoke-test from a skill: the MCP's `run_soql_query` with `SELECT Id FROM User LIMIT 1` should return a row. This is the canonical availability check.

**Not needed:** no env vars, no `.env` file, no GitHub secret. Access is entirely mediated by the local SFDX auth store; the MCP server reads only `NODE_ENV` at runtime (for telemetry tagging).

**Troubleshooting:** if `run_soql_query` fails with a stale-token error, re-run step 3. `get_username` is **not** a reliable liveness check — it reads the local auth store without contacting Salesforce and will return a cached username after the access token expires.

Full onboarding reference, confirmation-gate patterns for destructive tools, and the supported toolset inventory live in [`plugins/marketing/tools/integrations/salesforce.md`](plugins/marketing/tools/integrations/salesforce.md). See [`docs/research/salesforce-mcp-findings.md`](docs/research/salesforce-mcp-findings.md) for the research record behind these decisions.

## Email Bison MCP Onboarding

Email Bison exposes two vendor-hosted HTTP MCP endpoints (`emailbison-b2b`, `emailbison-personal`) used by the outbound-sending skills. Credentials are centralized in Bitwarden; MCP server registration lives at the **user level** today (not plugin-scoped) — see [`plugins/marketing/tools/integrations/email-bison.md`](plugins/marketing/tools/integrations/email-bison.md#known-claude-code-limitation) for why.

**One-time per-dev setup:**

1. Retrieve the **Email Bison MCP — API tokens** item from the Engineering Bitwarden collection. Paste the two `export` lines from its Notes field into your shell profile (`~/.zshrc` or `~/.bashrc`) and start a new shell.
2. Register the two HTTP MCP entries in your user-level `.mcp.json` (repo-root file, gitignored) using the shape in `email-bison.md` § Registration. The entries reference `${EMAILBISON_B2B_TOKEN}` / `${EMAILBISON_PERSONAL_TOKEN}` — no raw tokens in the file.
3. `/reload-plugins` (or restart Claude Code). Smoke-test with `get_active_workspace_info` on each namespace — expect workspace ID `52` (`send.outbase.so`) for b2b and `11` (`personal.outbase.so`) for personal.

**Troubleshooting:** a `401` or an `Authorization` header that logs literally as `Bearer ${…}` (not substituted) means the Claude Code client didn't inherit the env var — re-launch from a shell that has it exported.

**Why not plugin-scoped?** Claude Code bugs [#6204](https://github.com/anthropics/claude-code/issues/6204) / [#9427](https://github.com/anthropics/claude-code/issues/9427) prevent env-var substitution in plugin-scoped HTTP `headers`. We'll migrate when fixed. Full investigation + stdio-wrapper workarounds that also failed are documented in `email-bison.md` § Known Claude Code limitation.

Full onboarding flow, workspace-routing rules, 141-tool inventory, confirmation-gate list, and known gotchas live in [`plugins/marketing/tools/integrations/email-bison.md`](plugins/marketing/tools/integrations/email-bison.md).

## ADR Convention

Architecture Decision Records live in `docs/decisions/NNN-kebab-title.md`. They are imported into CLAUDE.md via individual `@` imports (directory imports are not supported). The `/workflows:architecture-decision` command generates ADRs and auto-appends the import. `/workflows:project-start` generates ADRs for all major tech decisions made during the interview.

## Branch Conventions

Branch from `main`. Use these prefixes:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feat/` | New feature (command, skill, agent) | `feat/deploy-command` |
| `fix/` | Bug fix | `fix/hook-matcher-regex` |
| `docs/` | Documentation only | `docs/architecture-guide` |

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add /deploy command for production deployments
fix: correct hook matcher for Write|Edit tools
docs: add ARCHITECTURE.md with system diagrams
chore: bump version to 2.0.0
refactor: extract shared validation to _shared/
```

Examples from this repo's history:

```
feat: add interactive Linear project setup to create-issues
Complete Milestone 1 foundation: fix plugin.json, add docs, standardize skills
Standardize post-plan skills frontmatter and register agents directory
Update CHANGELOG.md with v1.3.0 entry
```

## Pull Request Process

1. Create a branch with the appropriate prefix
2. Make your changes
3. Push and open a PR against `main`
4. CI runs automatically (see [CI Checks](#ci-checks) below)
5. PR description should include:
   - What changed and why
   - Which components were added/modified (commands, skills, agents, hooks)
   - How to test the changes

## CI Checks

The GitHub Actions workflow (`validate-plugin.yml`) validates on every push/PR to `main`:

| Check | What it validates |
|-------|-------------------|
| JSON validity | `marketplace.json`, `plugin.json`, `hooks.json` parse correctly |
| Required fields | `plugin.json` has `name`, `description`, `author` |
| Directory existence | `commands/`, `skills/`, `agents/` exist |
| Command frontmatter | Every `commands/*.md` has `---` block with `description` |
| Skill frontmatter | Every `skills/*/SKILL.md` has `name`, `description`, `user-invocable` |
| Skill name matching | `name` field matches the directory name |
| Hooks structure | `hooks.json` is valid JSON with proper event/handler structure |

## Testing Changes Locally

### Dev mode (fast iteration)

For a fast edit-validate-test loop, see [`docs/dev-guide.md`](docs/dev-guide.md). Key scripts:

- `scripts/dev-setup.sh` / `scripts/dev-teardown.sh` — symlink plugin for live editing
- `scripts/validate-single.sh <name>` — validate one skill/command/agent (~1s)
- `scripts/test-single-trigger.sh <skill> "phrase"` — test trigger matching for one skill

### Automated validation

Run the full validation script (requires `python3`):

```bash
./scripts/validate.sh
```

This mirrors all CI checks plus additional ones: marketplace field validation, path resolution, `allowed-tools` format, `argument-hint` nesting, agent frontmatter, and cross-reference integrity.

To run validation automatically before every push:

```bash
./scripts/setup-hooks.sh
```

### Manual testing

After `./scripts/validate.sh` passes, see [`docs/testing-guide.md`](docs/testing-guide.md) for the full interactive testing checklist (51 tests across 7 layers). For quick validation, use the **Quick Smoke Subset** section (~10 min).

## Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **Major** (X.0.0): Breaking changes to plugin structure or command interfaces
- **Minor** (0.X.0): New commands, skills, agents, or hooks
- **Patch** (0.0.X): Bug fixes, documentation updates, typo corrections

### During development

Add entries to the `[Unreleased]` section of `CHANGELOG.md` as you go. Follow [Keep a Changelog](https://keepachangelog.com/) format.

### Cutting a release

Run the release script from `main`:

```bash
scripts/release.sh minor "Release Name"    # or: major, patch
```

This bumps version in `VERSION`, `plugin.json`, and `marketplace.json`, moves `[Unreleased]` entries under the new version heading, commits, and creates a git tag. Then push:

```bash
git push && git push --tags
```

Each plugin has its own version in `plugin.json` and `marketplace.json`. `scripts/validate.sh` checks that each plugin's versions match across these two files. The `VERSION` file tracks the workflows plugin version. Per-plugin release support is tracked by BC-1728.

## Skill Routing Updates

When adding a new design-related skill, check the routing table in [ARCHITECTURE.md](ARCHITECTURE.md#design-skills-three-way-split). Design skills must have distinct trigger language to avoid conflicts:

- **Implementation** triggers: "build", "create", "implement", "code"
- **Planning** triggers: "choose", "plan", "explore", "brainstorm"
- **Review** triggers: "review", "audit", "check", "evaluate"

Write the `description` field to clearly signal which category the skill belongs to.

## Using `_shared/` Utilities

Two shared files in `skills/_shared/` are available for any skill to reference:

| File | What it provides |
|------|------------------|
| `validation-pattern.md` | Self-validation & retry loop (check → evaluate → retry 3x → flag for human) |
| `output-formats.md` | Standard severity levels, finding format, summary/progress blocks |

To use them, add to your skill's instructions:

```markdown
### Validation Criteria
Reference `_shared/validation-pattern.md` and apply it.
```

Do not duplicate the shared content into individual skills.
