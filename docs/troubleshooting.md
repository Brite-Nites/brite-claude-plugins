# Troubleshooting

Common issues and solutions when developing or using the Brite Claude Plugins.

## Skills Not Triggering

**Symptom:** You describe a task that should activate a skill, but it doesn't.

**Check these:**

1. **Plugin not loaded** — Start a new Claude Code session and type `/workflows:`. If no commands appear, the plugin isn't installed. See [Getting Started](getting-started.md).

2. **Description mismatch** — Skills are matched by their `description` field. If your prompt doesn't align with the skill's description, Claude won't select it. Check the skill's `SKILL.md` frontmatter for the exact trigger language.

3. **Name mismatch** — If the `name` field in frontmatter doesn't match the directory name, the skill may fail to load. The CI will catch this, but if you're testing locally, verify:
   ```
   skills/my-skill/SKILL.md  →  name: my-skill  ✓
   skills/my-skill/SKILL.md  →  name: mySkill    ✗
   ```

4. **Conflicting skills** — If two skills have overlapping descriptions, Claude may pick the wrong one. Check the [skill routing table](../ARCHITECTURE.md#skill-routing) for intended trigger boundaries.

5. **`user-invocable: false`** — Skills marked as not user-invocable (like `refine-plan`, `create-issues`, `setup-claude-md`) won't appear in the slash menu and can only be triggered by other skills or agents.

## Hooks Not Firing

**Symptom:** Security checks don't run, linter doesn't trigger, or SessionStart message doesn't appear.

**Check these:**

1. **Session restart needed** — Hooks are loaded at session start. If you edited `hooks.json`, start a new session.

2. **Matcher mismatch** — Hook matchers are regex patterns. The current matchers are:
   - `Bash` — matches the Bash tool
   - `Write|Edit` — matches Write or Edit tools
   - `startup` — matches session start

   If a tool name doesn't match the regex, the hook won't fire.

3. **Timeout** — Security regex hooks have a 5-second timeout, the pre-commit quality hook has 60 seconds, and the PostToolUse linter has 30 seconds. If a check takes longer, it silently times out (typically because a linter is processing a very large file).

4. **Linter not installed** — The PostToolUse linter hook checks for `npx` (ESLint) and `ruff` (Python). If neither is installed, the hook exits silently (by design — `|| true`). Install the relevant linter:
   ```bash
   npm install -g eslint        # For JS/TS files
   pip install ruff              # For Python files
   ```

5. **No prompt-type hooks in workflows plugin** — Since BC-11889 (workflows v3.31.0), all `workflows` PreToolUse hooks are `type: "command"` (regex-based, deterministic, no LLM call). The `revops` plugin retains its own Haiku-backed guardrails; if you see `Hook evaluator API error: ... model (haiku/sonnet/opus) ...`, the offending hook is in revops, not workflows.

## MCP Server Issues

### sequential-thinking

**Symptom:** Skills that use sequential-thinking fail or can't connect.

- **npx not found**: Ensure Node.js 18+ is installed and `npx` is on your PATH
- **Package download fails**: The server is installed on-the-fly via `npx -y`. Check your network connection and npm registry access
- **Timeout**: The server starts a subprocess via stdio. If it takes too long to initialize, it may time out

### linear-server

**Symptom:** Linear MCP tools fail or return auth errors.

- **Not authenticated**: The Linear MCP server at `https://mcp.linear.app/mcp` requires OAuth. You'll be prompted to authorize on first use. If authorization expired, re-authorize in Claude Code settings.
- **Wrong URL**: The server URL is `https://mcp.linear.app/mcp` (not `.dev`). This was corrected in v1.0.0.
- **Network issues**: The server uses HTTP transport. Ensure you can reach `mcp.linear.app` from your network.

## Plugin Not Loading

**Symptom:** `/workflows:` shows nothing in the slash menu.

**Check these:**

1. **Malformed JSON** — Validate all JSON files:
   ```bash
   python3 -m json.tool .claude-plugin/marketplace.json > /dev/null
   python3 -m json.tool plugins/workflows/.claude-plugin/plugin.json > /dev/null
   ```

2. **Missing required fields** — `plugin.json` must have `name`, `description`, `version`, and `author`.

3. **Source path** — The plugin `source` in `marketplace.json` must be the full relative path (e.g., `./plugins/workflows`). Do not use a separate `pluginRoot` field.

4. **Installation method** — If installed via `settings.json`, the `source` path must be absolute. Relative paths may not resolve correctly.

## Step 0 Prerequisite Failures

**Symptom:** `/session-start`, `/review`, or `/ship` stop at Step 0 with a prerequisite error.

Each command now verifies its critical dependencies before running:
- **session-start**: Checks Linear MCP + sequential-thinking MCP connectivity
- **review**: Checks agent dispatch (Task tool) with a trivial ping
- **ship**: Checks `gh auth status` and GitHub repo connectivity

**Fix:** Run `/workflows:smoke-test` for a full diagnostic. It will identify exactly which dependency is failing and suggest remediation.

## Stale Plugin Cache After Update

**Symptom:** You updated the plugin and ran `claude plugins update`, but old behavior persists (e.g., old hooks still fire).

**Cause:** Claude Code caches plugins by version. If the version number didn't change, `plugins update` refreshes the marketplace registry but serves the old cached files.

**Fix:**
1. Delete the old cache directory:
   ```bash
   rm -rf ~/.claude/plugins/cache/brite-claude-plugins/workflows/<old-version>
   ```
2. Run `claude plugins update workflows@brite-claude-plugins`
3. Start a new session

**Prevention:** Always bump the version in both `plugin.json` and `marketplace.json` when making changes that need to reach installed users.

## `context: fork` Not Working

**Symptom:** Skills that declare `context: fork` run in the parent context instead of an isolated agent.

**This is a known issue.** The `context: fork` feature has upstream bugs in Claude Code:
- [#16803](https://github.com/anthropics/claude-code/issues/16803)
- [#17283](https://github.com/anthropics/claude-code/issues/17283)

**Workaround:** Skills currently run inline. The `context: fork` declarations are kept in frontmatter so they'll work automatically when the bugs are fixed. No action needed from contributors.

**Impact:** Agent isolation doesn't work as designed. The `refine-plan`, `create-issues`, and `setup-claude-md` skills run in the parent session context rather than forked agents. This means they share the parent's context window.

## CI Validation Failures

### Missing frontmatter

```
FAIL: commands/my-command.md missing YAML frontmatter
```

Every command file must start with `---` on line 1, followed by YAML frontmatter, closed with `---`.

### Missing fields

```
FAIL: my-skill/SKILL.md missing 'user-invocable' field
```

Skills require three frontmatter fields: `name`, `description`, `user-invocable`. All must be present and explicit.

### Name mismatch

```
FAIL: my-skill/SKILL.md name 'wrong-name' does not match directory 'my-skill'
```

The `name` field must exactly match the directory name. Rename either the field or the directory.

### JSON parse errors

```
Checking hooks.json is valid JSON... ERROR
```

Run locally to see the specific error:
```bash
python3 -m json.tool plugins/workflows/hooks/hooks.json
```

Common causes: trailing commas, missing quotes, unescaped characters in prompt strings.

## ui-ux-pro-max Issues

**Symptom:** The design planning skill fails or returns incomplete results.

- **Skill not activating**: Use planning-oriented language: "choose a palette", "design system for", "plan the visual direction". Implementation language ("build", "create") routes to `frontend-design` instead.
- **Large skill file**: `ui-ux-pro-max` is one of the largest skills. If context is tight, Claude may truncate or skip parts of the skill's instructions.
