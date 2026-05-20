# BC-10657 — `/revops:setup-sandbox` guided sandbox-auth command

**Issue:** [BC-10657](https://linear.app/brite-nites/issue/BC-10657) (High) · blocks BC-10660 (`/revops:doctor`), BC-10661 (brite-salesforce docs)
**Branch:** `holden/bc-10657-revops-setup-sandbox` (worktree)
**Workstream:** RevOps onboarding (get Drake + Kells shipping SF end-to-end). See memory `project-revops-onboarding`.

## Goal

Add a guided, gated `/revops:setup-sandbox` command that walks a semi-technical dev from
"no `brite-sandbox` auth" to "connected + trivial SOQL returns a row," modeled on
`plugins/marketing/commands/setup-email-bison.md` (detect-then-guide, one `AskUserQuestion`
per gate, idempotent early-exit) and `plugins/revops/commands/deploy-sandbox.md` (Rules
style, `sf` not `sfdx`, parse `--json` via `status === 0`, never assume default org).

## Constraints / gotchas to honor

- **plugin-install-discipline**: registered in marketplace.json ≠ installed. Phase 2 must check `claude plugin list`, not just that the plugin is on disk.
- **sf-mcp-username-not-alias**: the MCP `run_soql_query` needs a literal username, so the connectivity probe uses the `sf` CLI with `--target-org brite-sandbox` (CLI accepts the alias), NOT the MCP-by-alias path.
- **plugin-cache keyed by version**: bump `plugins/revops/.claude-plugin/plugin.json` AND the revops entry in `.claude-plugin/marketplace.json` in the same commit. Current `0.2.9` → `0.3.0` (minor, new feature).
- **no emojis** in generated content (banners/scripts/docs) per user feedback — even where a template includes them. Use ASCII status markers (`OK` / `MISSING` / `[x]`).
- **validate.sh** command check: first line `---`, non-empty `description`. (It does NOT run the Python contract tests.)
- **worktree Write paths** must include the `.claude/worktrees/<name>/` prefix once the worktree exists.

## Tasks

### Task 1 — Write `plugins/revops/commands/setup-sandbox.md`

Single new file. Structure:

- **Frontmatter**
  - `description:` trigger-rich, unquoted — must fire on "set up salesforce", "sandbox access", "revops onboarding", "first time salesforce".
  - `allowed-tools: Bash, Read, AskUserQuestion` (exactly these three).
- **Intro** (mirror deploy-sandbox tone): one question per gate; halt-and-help on any non-proceed answer; no auto-retry; `sf` not `sfdx`; parse `--json` via `status === 0`; never assume the default org; cross-cite `brite-salesforce/CLAUDE.md` §Development Flow and `plugins/revops/.mcp.json` (`--orgs DEFAULT_TARGET_ORG`).
- **7 gated phases** (each ends with one `AskUserQuestion`; non-proceed → halt):
  1. **Detect** — `sf --version` (expect v2.x), `node --version`, `gh auth status`; `sf org list --json` scan for a `brite-sandbox` alias + whether default target-org already resolves to it. If already authed AND default target-org is `brite-sandbox` → print `OK: brite-sandbox already set up` and **exit** (idempotent early-exit, zero mutations).
  2. **Plugin-install check** — `claude plugin list` shows `revops` *installed* (not merely registered). If missing, guide `claude plugin install revops@<marketplace>`.
  3. **Authenticate** — instruct `sf org login web --alias brite-sandbox` (browser; may run via `!` prefix). Gate on the org showing `Connected` in `sf org list`.
  4. **Default target-org** — `sf config set target-org brite-sandbox`; explain the MCP/skills resolve `DEFAULT_TARGET_ORG` to this.
  5. **Connectivity probe** — `sf org display --target-org brite-sandbox` + `sf data query --target-org brite-sandbox --query "SELECT Id FROM Organization LIMIT 1" --json` (CLI, not MCP-by-alias). Confirm a row returns.
  6. **Permission self-probe** — get the authed username from `sf org display --target-org brite-sandbox --json`, then `sf data query` a `PermissionSetAssignment` SOQL; report whether a dev-grade group (`Admin_Group` / `Near_Admin_Group`) is present; if absent, state which group to request and from whom (Brite SF admin).
  7. **First-login + completion** — link `brite-salesforce/docs/runbooks/new-user-first-login.md`; point to `/revops:doctor` (re-checks) and `/revops:deploy-sandbox` (first deploy).
- **Rules** section (mirror deploy-sandbox): never skip a gate; one question at a time; `sf` not `sfdx`; parse `--json`, not stdout strings; no auto-retry; never assume the default org; no mutations in the idempotent early-exit path.

**Verify:** file starts with `---`; `description` non-empty; `allowed-tools` = `Bash, Read, AskUserQuestion`.

### Task 2 — Bump versions (same commit as Task 1)

- `plugins/revops/.claude-plugin/plugin.json`: `"version": "0.2.9"` → `"0.3.0"`.
- `.claude-plugin/marketplace.json`: revops entry `"version": "0.2.9"` → `"0.3.0"`.

**Verify:** both equal `0.3.0`; both `> 0.2.8`.

### Task 3 — Write `plugins/revops/tests/test_setup_sandbox_contracts.py`

Mirror `test_create_sf_campaign_contracts.py` (pytest-style bare-assert functions, stdlib only, no mocks/subprocess/org). Assertions:

- `test_command_file_exists`
- `test_frontmatter_has_description_and_allowed_tools`
- `test_allowed_tools_is_exactly_bash_read_askuserquestion` — set equality on the three tools (no MCP tools — the command is CLI-only by design).
- `test_all_seven_phases_present` — phase headings 1–7 present.
- `test_idempotent_early_exit_documented` — Phase 1 early-exit + "zero mutation" intent greppable.
- `test_key_commands_present_verbatim` — `sf org login web --alias brite-sandbox`, `sf config set target-org brite-sandbox`, `claude plugin list`, the `SELECT Id FROM Organization LIMIT 1` probe, `PermissionSetAssignment`, `sf org list`.
- `test_askuserquestion_at_each_gate` — `AskUserQuestion` count ≥ number of gates.
- `test_plugin_json_version_bumped` (≠ `0.2.9`, and `> 0.2.8`).
- `test_marketplace_json_version_mirrors_plugin_json`.

**Verify (no pytest installed locally):** run bare functions via
`python3 -c "import test_setup_sandbox_contracts as t; [getattr(t,n)() for n in dir(t) if n.startswith('test_')]; print('all pass')"`
from `plugins/revops/tests/`.

### Task 4 — Validate + green baseline

- `./scripts/validate.sh` → exits 0 (fix any findings).
- New contract test passes (Task 3 runner).

## Acceptance criteria mapping

| AC | Task |
|----|------|
| command file + valid frontmatter | T1 |
| AskUserQuestion at every gate, one per gate | T1, T3 |
| 7 phases (detect/install/login/config/probe/perm/handoff) | T1, T3 |
| re-run early-exits, zero mutations | T1, T3 |
| plugin.json + marketplace.json bumped same commit | T2, T3 |
| `./scripts/validate.sh` exits 0 | T4 |
| verified live (walk recorded as comment) | post-merge with Drake — out of scope for this PR's code; recorded as Linear comment |

## Out of scope (sibling issues)

- `/revops:doctor` re-runnable health check → BC-10660 (blockedBy this).
- brite-salesforce auth/first-login docs → BC-10661 (blockedBy this).
- Kells email de-scramble → BC-10658.
- The live walk with a not-yet-authed dev is a runtime/people step; the code lands here, the recorded walk is a follow-up comment on BC-10657.
