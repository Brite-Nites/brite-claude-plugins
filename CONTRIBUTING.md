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

## Naming Convention (commands & skills)

Name from the user's **intent**, not the machine's **mechanism**. Derived in [ADR-026](docs/decisions/026-revops-promotion-topology.md) when the revops `deploy-*` command names were found to mis-describe a CI-driven deploy world (the human no longer "deploys" — CI does). Applies to **all plugins**, *apply-forward + opportunistic cleanup*: don't mass-rename established commands; keep deprecation aliases when you do rename.

**Six rules:**

1. **Name from the user's intent, not the machine's mechanism.**
2. **Verb + object** — every name answers *"do what, to what?"* No bare verbs (`try`, `ship`), no bare nouns (`doctor`, `weekly`).
3. **The verb encodes the side-effect class** (see lexicon) — the reader knows before running whether it's safe.
4. **The namespace is the first word; don't repeat it.** `/revops:` already says "SF" — spend the name's words on the specific action, not `sf`.
5. **Plain English over domain jargon/idiom** — no `break-glass`, no `runbook`.
6. **Stakes legible in the name** — `preview` < `submit` < `push-to-production` < `emergency-…`.

**Verb lexicon** (controlled vocabulary — the same verb means the same thing in every plugin), grouped by the three side-effect classes:

| Class | Verbs | Meaning |
|-------|-------|---------|
| **Read-only** (safe) | `check-` · `show-` · `list-` · `report-` | inspects/reports, changes nothing |
| **Throwaway-mutate** | `preview-` | changes only a disposable/personal thing (blast radius ≈ nil) |
| **Real-mutate** | `setup-` · `create-`/`new-` · `submit-` · `push-` · `promote-` · `run-` · `sync-` · `update-` · `delete-` | changes shared/persistent state |

Names that already satisfy this (e.g. marketing's `new-offer`, `plan-campaign`; flow-architecture's `add-domain`) need no change; mechanism-named ones (`deploy-*`) are the cleanup targets. Rationale + the worked revops example live in [ADR-026](docs/decisions/026-revops-promotion-topology.md).

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

- **PreToolUse (Bash)**: Regex command hook (deterministic, blocks `rm -rf`, `git push --force`/`-f`, `DROP TABLE/DATABASE`, `chmod 777`, piped downloads). Haiku-prompt fallback was retired in BC-11889 (workflows v3.31.0).
- **PreToolUse (Bash)**: Pre-commit quality — intercepts `git commit` commands, detects project type (`package.json` → JS/TS, `pyproject.toml`/`setup.py` → Python), runs linters on staged files only (ESLint, `tsc --noEmit`, Ruff). Degrades gracefully if no linters installed.
- **PreToolUse (Write/Edit)**: Regex command hook (deterministic, blocks `sk-`, `sk-proj-`, `AKIA`, `gh[ps]_`, `sk_live/test_`, PEM private keys, Slack `xox[abprs]-`, Google `AIza`).
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

**Easy path:** run `/marketing:setup-email-bison` in Claude Code. It detects current state, walks you through each step with explicit confirmations (Bitwarden retrieval → shell profile → `.mcp.json` edit → reload → verify), and smoke-tests both workspaces at the end. Roughly 3 minutes. See [`plugins/marketing/commands/setup-email-bison.md`](plugins/marketing/commands/setup-email-bison.md) for the full walkthrough.

**Manual path** (fallback or if you want full control):

1. Retrieve the **Email Bison MCP — API tokens** item from the Engineering Bitwarden collection. Paste the two `export` lines from its Notes field into your shell profile (`~/.zshrc` or `~/.bashrc`) and start a new shell.
2. Register the two HTTP MCP entries in your user-level `.mcp.json` (repo-root file, gitignored) using the shape in `email-bison.md` § Registration. The entries reference `${EMAILBISON_B2B_TOKEN}` / `${EMAILBISON_PERSONAL_TOKEN}` — no raw tokens in the file.
3. `/reload-plugins` (or restart Claude Code). Smoke-test with `get_active_workspace_info` on each namespace — expect workspace ID `52` (`send.outbase.so`) for b2b and `11` (`personal.outbase.so`) for personal.

**Troubleshooting:** a `401` or an `Authorization` header that logs literally as `Bearer ${…}` (not substituted) means the Claude Code client didn't inherit the env var — re-launch from a shell that has it exported.

**Why not plugin-scoped?** Claude Code bugs [#6204](https://github.com/anthropics/claude-code/issues/6204) / [#9427](https://github.com/anthropics/claude-code/issues/9427) prevent env-var substitution in plugin-scoped HTTP `headers`. The `${user_config.*}` keychain-backed alternative was tested and also found broken (2026-04-19 validation: token-via-curl = 200, same-token-via-Claude-Code = Failed to connect). We'll migrate to plugin-scoped when fixes land upstream. Full investigation + all workarounds that failed are documented in `email-bison.md` § Known Claude Code limitation.

Full onboarding flow, workspace-routing rules, 141-tool inventory, confirmation-gate list, and known gotchas live in [`plugins/marketing/tools/integrations/email-bison.md`](plugins/marketing/tools/integrations/email-bison.md).

## Plugin secret-config canon

Stdio MCPs and CLI scripts read credentials from OS environment variables — that's the Anthropic-recommended pattern (`@anthropics/claude-code/plugins/plugin-dev/skills/mcp-integration/references/authentication.md`). The friction is *how secrets reach env* without each developer hand-editing `~/.zshrc` and rotating values across machines. The canonical Brite answer is **Bitwarden Secrets Manager + `bws run`**: the vendor's own runner fetches a project's secrets at MCP/CLI spawn time, injects them as env, and runs the wrapped command. Authentication is a machine-account access token (`BWS_ACCESS_TOKEN`), scoped to the projects that account can read, expirable and revocable. No vault master password, no vault session, no `bw unlock`. Rotated values reach the next process spawn — instantly for one-shot CLI invocations via Bash, and at the next Claude Code re-launch for long-lived stdio MCPs (see Tradeoffs below). Decision-record sources (alternatives considered, drivers, reversibility): [ADR-044](docs/decisions/044-secrets-manager-machine-account-broker.md) for the current `bws` mechanism, and [ADR-010](docs/decisions/010-plugin-secret-config-canon.md) for the original canon, which ADR-044 supersedes in part. This section is the operational guide for *how to apply* the canon; the ADRs are *why*.

**Reference implementation:** [`plugins/marketing/.mcp.json`](plugins/marketing/.mcp.json) (stdio MCP entries) plus the `Bash`-tool call sites in [`tam-mapping`](plugins/marketing/skills/tam-mapping/SKILL.md) and [`list-building`](plugins/marketing/skills/list-building/SKILL.md). There is no wrapper script to copy or test — that is the point of the pattern. [ADR-044](docs/decisions/044-secrets-manager-machine-account-broker.md) records why the previous in-repo broker (`bw-run.sh`) was removed rather than hardened.

**Adopt in a new plugin:**

1. **Create a Secrets Manager project** and add one secret per env-var key. **The secret's name becomes the environment variable name** — name it `SPIDER_API_KEY`, not `spider-api-key`.
2. **Split projects where an env-var name is fed from two different values.** One project cannot hold two secrets with the same name, and `bws run --project-id` injects *every* secret in the project. The marketing plugin needs two projects for exactly this reason: `PROSPEO_API_KEY` and `ICYPEAS_API_KEY` each have a tam-map value and a distinct enrichment value.
3. **Grant a machine account `Can read`** on the project and issue an access token. Read, not read-write — nothing at runtime writes secrets.
4. **Wrap stdio MCP entries** in your plugin's `.mcp.json`: `command: "bws", args: ["run", "--project-id", "<uuid>", "--", "exec <original cmd>"]`. Drop any `env: { KEY: "${KEY}" }` block — `bws` fills env at runtime.
5. **Wrap Bash CLI invocations** in your skills the same way. The skill's instruction text is the spec; prepend the `bws run` invocation at each `Bash`-tool call site.

**Quoting is load-bearing.** `bws` joins the command argv with spaces and runs it through `sh -c`, so paths *are* shell-parsed. Any path that could contain a space must carry literal quotes into that string: `bws run --project-id <uuid> -- "exec python '${CLAUDE_PLUGIN_ROOT}/scripts/x.py' --flag"`. The outer double quotes let the shell expand `CLAUDE_PLUGIN_ROOT` while keeping the inner single quotes intact. The removed `bw-run.sh` used `exec "$@"` and never shell-parsed anything, so this is a real behavioural difference — test it against a path with a space before you trust it.

**That shell is `sh`, not `bash`.** On most Linux boxes `/bin/sh` is dash, so anything you pass must be POSIX. The trap is `set -o pipefail`: dash rejects it, and because `set` is a POSIX *special builtin*, a failing `set` exits a non-interactive shell outright — a body opening `set -uo pipefail` dies on line 1 and runs none of itself. Use plain `set -u`. If you genuinely need bash, ask for it explicitly: `-- "exec bash -c '...'"`. Anything that ran under an explicit `bash -c` before this migration needs re-checking, not just re-quoting.

**Tradeoffs (be honest about these in your plugin's setup command):**

- Adds `bws` as a runtime requirement. **It has no Homebrew formula** — install from Bitwarden's script or the [`bitwarden/sdk-sm` releases](https://github.com/bitwarden/sdk-sm/releases). `bitwarden-cli` on Homebrew is `bw`, a different tool. Budget an onboarding step for this and detect it in your plugin's setup command.
- Adds `jq` to the **setup and verification** path, though not to the MCP runtime itself. `bws project list` emits JSON, so resolving a project by name rather than pasting a UUID needs it, as do the probe assertions in `/marketing:setup-tam-map` Phase 3. The `.mcp.json` entries and skill call sites do not — they carry the project UUID literally. Detect `jq` in your plugin's setup command alongside `bws`.
- **Each developer exports `BWS_ACCESS_TOKEN`** in their shell profile. That is a long-lived credential sitting in plaintext on disk — accepted deliberately, because it is scoped to named projects, expirable, and revocable per machine account. Never put it in `.mcp.json`; that file is committed.
- **No vault-lock tax.** Machine-account tokens do not lock or expire mid-session, so there is no `bw unlock` and no `BW_SESSION` for these servers. The previous in-repo broker paid a ~30s recovery cost per lock event (BC-5947 task-3 Pattern A; BC-6905 Q5 measurement); that cost is gone.
- **Rotation propagation:** values are fetched per-MCP-process-spawn, not per-tool-call. MCP server processes are persistent for the Claude Code session; tool calls reuse the running process and its in-memory env. **`/reload-plugins` does NOT re-spawn MCP processes** (measured in BC-6906 T14: it reloads plugin metadata only). To pick up a rotated Secrets Manager value, the user must trigger a real MCP-process re-spawn — typically by re-launching Claude Code (or, if your Claude Code version exposes it, a per-server `claude mcp restart <name>` command). This is still cheaper than the pre-broker world (which required `~/.zshrc` edits *and* a re-launch); it just isn't zero-touch.
- **Scope:** `bws run --project-id` injects **every** secret in that project into the wrapped process — there is no per-key selection. Size projects to the blast radius you want: a server sees all of its project's secrets, so put unrelated credentials in separate projects rather than accepting the widening.

## Team gbrain credentials

The `gbrain-team` MCP server is the one credentialed server this canon does *not*
cover, because it needs an OAuth token rather than a static API key.
`scripts/gbrain-team-broker.sh` exchanges an OAuth client for a short-lived
bearer token at spawn time, then bridges stdio to the HTTP endpoint via
`mcp-remote`. Decision record: [ADR-045](docs/decisions/045-gbrain-broker-env-oauth-client.md).

**Export the client in your shell profile**, next to `BWS_ACCESS_TOKEN`:

1. Open the Bitwarden item `Brite team gbrain — my client`. Its **username** is
   the client id; its **password** is the client secret.
2. Add both to your shell profile:
   ```sh
   export GBRAIN_CLIENT_ID=...
   export GBRAIN_CLIENT_SECRET=...
   ```
3. If you have gbrain **write** access (`/workflows:ship` and
   `/workflows:review` save results back to the brain), also export the separate
   write pair from `Brite team gbrain — write OAuth client`:
   ```sh
   export GBRAIN_WRITE_CLIENT_ID=...
   export GBRAIN_WRITE_CLIENT_SECRET=...
   ```
4. Relaunch Claude Code from a shell that has them. MCP servers read the
   environment at spawn.
5. If your personal client hasn't been issued yet (BC-11758), export the shared
   Engineering client's values instead — open tier only.

**The read and write pairs are separate on purpose.** `--write` reads
`GBRAIN_WRITE_CLIENT_*` and never falls back to the read pair. A missing write
client fails loudly at spawn rather than authenticating as a read identity and
surfacing much later as a `put_page` 403. Do not "simplify" this by collapsing
the two pairs.

**Editing the broker means editing six files.** `gbrain-team-broker.sh` is
duplicated byte-for-byte into `cadence`, `core`, `flow-architecture`,
`marketing`, `revops`, and `workflows`, because each plugin's `.mcp.json` execs
its own `${CLAUDE_PLUGIN_ROOT}` copy. Change `plugins/core/scripts/` first, copy
it to the other five, and bump all six plugin versions in the same commit — the
script ships in the version-keyed plugin cache, so an unbumped plugin keeps
running the old broker. `validate.sh` §2b-gbrain fails on any drift. The
single-source fix (`plugins/_shared/`) is tracked as BC-11757.

**Exception — HTTP MCPs.** This canon applies to **stdio MCPs and CLI scripts only.** For HTTP MCPs with credentialed `Authorization: Bearer ${...}` headers, both `${ENV_VAR}` and `${user_config.*}` substitution into headers are broken in current Claude Code (BC-5551 / upstream issues [#6204](https://github.com/anthropics/claude-code/issues/6204), [#9427](https://github.com/anthropics/claude-code/issues/9427)). Ship user-level registration with guided onboarding (the Email Bison pattern at `/marketing:setup-email-bison`) until upstream lands fixes — see § Email Bison MCP Onboarding above.

## ADR Convention

Architecture Decision Records live in `docs/decisions/NNN-kebab-title.md`. They are imported into CLAUDE.md via individual `@` imports (directory imports are not supported). The `/workflows:architecture-decision` command generates ADRs and auto-appends the import. `/workflows:project-start` generates ADRs for all major tech decisions made during the interview.

## Documentation retention

`docs/` is a **curated** tree — keep it navigable. The durable, queried records are `docs/decisions/` (ADRs), `docs/precedents/`, `docs/guides/`, and the top-level `README.md` / `ARCHITECTURE.md` / `CLAUDE.md`; these are **never** pruned. Raw, point-in-time **session exhaust** does **not** live in `docs/`:

- Write throwaway per-session artifacts (scratch plans, dogfood runs, API dumps) to a gitignored `.local/` (already ignored), or omit them — **git history is the archive** for anything you need later.
- Do **not** accrete per-issue `docs/plans/BC-*.md` plan files or `docs/dogfood/` rounds. (BC-16388 pruned the historical backlog; git retains it.)
- When you must land a point-in-time report (an audit, a research note), give it a stable name and treat it as a historical snapshot that will not be updated.

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
- `scripts/probe-single-trigger.sh <skill> "phrase"` — test trigger matching for one skill

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

> **There is no bundle release step.** The root `VERSION` file and `scripts/release.sh`
> were **retired** (BC-16297 / BC-16819): the single-version bundle model broke once
> plugins diverged (`VERSION` froze at 3.29.0, 2026-03-28), and the fleet already ships
> per-plugin. `CHANGELOG.md` is frozen as a historical record of the bundle era.

Each plugin versions independently. When you change anything under a plugin's
`hooks/`, `skills/`, `commands/`, or `agents/`, bump that plugin's version in **both**
its `plugin.json` and its `.claude-plugin/marketplace.json` entry, in the same commit —
`scripts/validate.sh` §2b enforces that the two stay equal (and that
`homepage`/`repository`/`description` stay consistent). Record notable changes in the PR
description; the marketplace entry's version + git history are the release record.

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
