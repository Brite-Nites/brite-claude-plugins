---
description: Guided, gated setup that gets a developer authenticated to the brite-sandbox Salesforce org and ready to use the revops plugin end-to-end. Detects current state, then walks one step at a time through sf CLI / plugin-install checks, browser login, default target-org, a connectivity SOQL probe, and a permission self-check. Use on first-time Salesforce onboarding, when you need sandbox access, when "sf org display" fails, or when revops commands error because no org is authenticated. Triggers on "set up salesforce", "sandbox access", "revops onboarding", "first time salesforce", "setup sandbox".
allowed-tools: Bash, Read, AskUserQuestion
---

# /revops:setup-sandbox

Get a developer from "no Salesforce auth" to "connected to `brite-sandbox`, default target-org set, and a trivial SOQL returns a row" — the laptop-side prerequisites every other revops command (`/revops:deploy-sandbox`, `/revops:deploy-prod`, `/revops:post-deploy-runbook`) silently assumes.

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered gate so the user explicitly acknowledges the state before any mutating step. **One question at a time — never batch gate questions.** If the user answers anything other than the proceed option, halt and help with their blocker before re-asking; do not re-run earlier phases silently.

Conventions (from `brite-salesforce/CLAUDE.md` §Development Flow and `plugins/revops/.mcp.json`):

- Sandbox alias is `brite-sandbox`. Always pass `--target-org brite-sandbox` explicitly — never rely on an ambient default.
- Use `sf`, never legacy `sfdx`.
- Parse `--json` output via top-level `status === 0`, not human-readable stdout strings.
- The revops MCP runs `@salesforce/mcp --orgs DEFAULT_TARGET_ORG`, so it follows whatever the default target-org resolves to — that is why Phase 4 sets it.
- This command performs the connectivity probe with the `sf` CLI, **not** the MCP `run_soql_query`: the MCP requires a literal username per call (it rejects an alias), whereas the `sf` CLI accepts `--target-org brite-sandbox` directly.

Out of scope: SF org-side user/permission provisioning (admin work), Kells' email de-scramble (BC-10658), the re-runnable health check (use `/revops:doctor`, BC-10660), and the first deploy (use `/revops:deploy-sandbox`).

---

## Phase 1 — Detect current state

Narrate: `Phase 1/7: Detecting current state...`

Run:

```bash
# Probe install state with `command -v` (NOT `cmd | head`: a pipeline's exit
# status is the last command's, so `cmd | head || echo MISSING` never reports
# MISSING when `cmd` is absent).
if command -v sf   >/dev/null 2>&1; then echo "sf:   $(sf --version 2>/dev/null | head -1)"; else echo "sf:   MISSING"; fi
if command -v node >/dev/null 2>&1; then echo "node: $(node --version 2>/dev/null)"; else echo "node: MISSING"; fi
if command -v gh   >/dev/null 2>&1; then
  gh auth status >/dev/null 2>&1 && echo "gh:   OK (authenticated)" || echo "gh:   PRESENT (not authenticated)"
else
  echo "gh:   MISSING"
fi
echo "--- sf org list ---"
sf org list --json 2>/dev/null || echo "SF_ORG_LIST_FAILED"
echo "--- default target-org ---"
sf config get target-org --json 2>/dev/null || echo "NO_DEFAULT"
```

Interpret:

- **`sf` MISSING** → halt. Tell the user: *"The Salesforce CLI (`sf`) is not installed. Install it (`npm install -g @salesforce/cli`, needs Node 18+), open a fresh terminal, then re-run `/revops:setup-sandbox`."* Do not continue.
- **`node` MISSING** → halt with the equivalent Node install guidance.
- **`gh` MISSING** or **`gh: PRESENT (not authenticated)`** → note it as a warning (the revops flow needs an authenticated `gh` later for shipping, but it does not block sandbox auth). If present-but-unauthenticated, suggest `gh auth login`. Continue.
- **Already set up** — `sf org list` shows a `brite-sandbox` alias whose `connectedStatus` is `Connected` AND `sf config get target-org` resolves to `brite-sandbox` → print:

  > OK: brite-sandbox is already authenticated and set as your default target-org. Nothing to do.
  > Next: `/revops:doctor` (re-check health) or `/revops:deploy-sandbox` (first deploy).

  Then **exit immediately**. This early-exit path performs **zero mutations** — no `sf org login`, no `sf config set`.
- **Not yet set up** (no `brite-sandbox` entry, or it is not Connected, or the default target-org is something else) → summarize what is present vs. missing, then proceed.

Ask via `AskUserQuestion`:

- Question: `sf and node detected. Continue setting up brite-sandbox access?`
- Options:
  - `Yes, continue` — proceed to Phase 2.
  - `No, stop` — halt cleanly. Print: *"Stopped at detection. Nothing was changed. Re-run `/revops:setup-sandbox` when ready."* Exit.

Narrate: `Phase 1/7: Detecting current state... done`

---

## Phase 2 — Plugin-install check

Narrate: `Phase 2/7: Plugin-install check...`

A plugin can be registered in `marketplace.json` and on disk yet never installed — in which case its commands, skills, and agents are all absent. Source of truth is `claude plugin list`, not the marketplace registry.

Run:

```bash
claude plugin list 2>/dev/null | grep -E "revops" || echo "REVOPS_NOT_INSTALLED"
```

Interpret:

- A line containing `revops@<marketplace>` → the plugin is installed. Continue.
- `REVOPS_NOT_INSTALLED` → tell the user: *"The revops plugin is registered but not installed in this scope. Install it with `claude plugin install revops@brite-claude-plugins` (or the `/plugin install` equivalent), then re-run `/revops:setup-sandbox`."*

Ask via `AskUserQuestion`:

- Question: `Is the revops plugin installed (shows in 'claude plugin list')?`
- Options:
  - `Yes, installed` — proceed to Phase 3.
  - `No / not sure` — halt and walk the install command above, then re-ask this gate. Do not proceed until confirmed.

Narrate: `Phase 2/7: Plugin-install check... done`

---

## Phase 3 — Authenticate to brite-sandbox

Narrate: `Phase 3/7: Authenticating to brite-sandbox...`

Tell the user:

> Log in to the sandbox in your browser. Because Brite's sandbox uses a custom My Domain, you must pass `--instance-url` — without it `sf` sends the OAuth flow to the generic `https://test.salesforce.com` page, you end up authenticated in the browser but `sf` never captures the token.
>
> **Step 1 — find your sandbox My Domain URL:**
> Navigate to the sandbox in your browser. The URL bar will show something like:
> `https://<instance>--<sandbox>.sandbox.lightning.force.com/lightning/page/home`
> Drop `lightning.` from the host and change the path to get the API URL:
> `https://<instance>--<sandbox>.sandbox.my.salesforce.com`
>
> **Step 2 — run the login command** (substituting your URL):
> ```bash
> sf org login web --alias brite-sandbox --instance-url https://<instance>--<sandbox>.sandbox.my.salesforce.com
> ```
>
> A browser tab opens at the sandbox login page. Use your **sandbox** credentials (sandbox usernames carry a suffix such as `.bndev` after your normal username). After the browser shows "successfully authorized," return here.

After the user says they have logged in, verify:

```bash
sf org list --json 2>/dev/null | python3 -c "
import json, sys
try:
    result = json.load(sys.stdin).get('result', {})
except Exception:
    print('PARSE_FAILED'); sys.exit(0)
orgs = result.get('nonScratchOrgs', []) + result.get('sandboxes', [])
match = [o for o in orgs if o.get('alias') == 'brite-sandbox']
print('CONNECTED' if any(o.get('connectedStatus') == 'Connected' for o in match) else 'NOT_CONNECTED')
" 2>/dev/null || echo "PYTHON_MISSING"
```

This is a single, local `sf org list` read (no network callout — the deeper probe is Phase 5). Interpret the printed token:

- `CONNECTED` → continue.
- `NOT_CONNECTED` → the login did not complete. Surface `sf org list` verbatim, do not auto-retry, and re-ask the gate below after the user retries the login.
- `PARSE_FAILED` / `PYTHON_MISSING` → fall back to reading `sf org list` (plain, not `--json`) yourself and confirm a `brite-sandbox` row shows `Connected`; do not auto-retry.

Ask via `AskUserQuestion`:

- Question: `Does 'sf org list' show brite-sandbox as Connected?`
- Options:
  - `Yes, Connected` — proceed to Phase 4.
  - `No, login failed` — halt and help: confirm they used sandbox (not production) credentials and the correct sandbox-suffixed username, then re-run the login and re-ask. Do not proceed.

Narrate: `Phase 3/7: Authenticating to brite-sandbox... done`

---

## Phase 4 — Set default target-org

Narrate: `Phase 4/7: Setting default target-org...`

Explain: the revops MCP and skills resolve `DEFAULT_TARGET_ORG` (see `plugins/revops/.mcp.json`) to whatever your default target-org is. Setting it to `brite-sandbox` makes the MCP point at the sandbox without per-call org flags.

Run:

```bash
sf config set target-org brite-sandbox --global --json
```

The `--global` flag is required when the working directory is not an SFDX project (e.g. `~/.claude/plugins/...`). Without it, `sf` throws `InvalidProjectWorkspaceError`. `--global` writes to `~/.sf/config.json` and applies across all directories.

Parse the JSON via `status === 0` (the `set` response already echoes the resolved value — no separate `sf config get` round-trip needed):

- `status: 0` → report the value from `result.successes[0].value` (should be `brite-sandbox`). Continue.
- Any other `status` → surface the error verbatim and halt; do not auto-retry.

Ask via `AskUserQuestion`:

- Question: `Default target-org now set to brite-sandbox?`
- Options:
  - `Yes` — proceed to Phase 5.
  - `No / errored` — halt, surface the error, help, and re-ask. Do not proceed.

Narrate: `Phase 4/7: Setting default target-org... done`

---

## Phase 5 — Connectivity probe

Narrate: `Phase 5/7: Connectivity probe...`

Prove the auth actually works against the org — using the `sf` CLI (not the MCP-by-alias path).

Run:

```bash
sf org display --target-org brite-sandbox --json
sf data query --target-org brite-sandbox --query "SELECT Id FROM Organization LIMIT 1" --json
```

Parse each via `status === 0`:

- Both `status: 0` and the query returns one record → print the resolved username and instance URL from `sf org display`, and confirm the SOQL returned a row. **Note the username** — Phase 6 reuses it (no need to re-run `sf org display`). Continue.
- Any other `status` → surface the error verbatim and halt. Common causes: session expired (re-run Phase 3), or the org has no API access for this user (escalate to a Brite SF admin). Do not auto-retry.

Ask via `AskUserQuestion`:

- Question: `Did the connectivity probe return a row from brite-sandbox?`
- Options:
  - `Yes, a row came back` — proceed to Phase 6.
  - `No, it failed` — halt and surface the error; help diagnose (re-auth vs. API-access escalation), then re-ask. Do not proceed.

Narrate: `Phase 5/7: Connectivity probe... done`

---

## Phase 6 — Permission self-probe

Narrate: `Phase 6/7: Permission self-probe...`

Check whether the authenticated user holds effective deploy/admin rights — either via permission-set capability flags (`ModifyAllData` / `ModifyMetadata`, which also catch System Administrator profile users via the profile-owned permset row, and the `Dev_Sandbox_Access` permset from BC-10727) or via a dev-grade group (`Admin_Group` / `Near_Admin_Group`). This is read-only and never blocks — it only reports what to request.

Reuse the username Phase 5 already resolved (don't re-run `sf org display`). Substitute it for `<sandbox-username>` below — it is the developer's own org username (email-format, so no SOQL-quote hazard). If for some reason you don't have it, fall back to `sf org display --target-org brite-sandbox --json` to fetch `result.username`.

```bash
sf data query --target-org brite-sandbox --query "SELECT PermissionSet.PermissionsModifyAllData, PermissionSet.PermissionsModifyMetadata, PermissionSetGroup.DeveloperName FROM PermissionSetAssignment WHERE Assignee.Username = '<sandbox-username>'" --json
```

Interpret the returned records (one row per permset assignment — both profile-owned permsets and standalone permsets like `Dev_Sandbox_Access` appear):

- Any row with `PermissionSet.PermissionsModifyAllData = true` → print `OK: ModifyAllData granted (effective admin).` Continue.
- Else, any row with `PermissionSet.PermissionsModifyMetadata = true` → print `OK: ModifyMetadata granted (dev-sandbox-capable — e.g. Dev_Sandbox_Access).` Continue.
- Else, any row with `PermissionSetGroup.DeveloperName` in `Admin_Group` / `Near_Admin_Group` → print `OK: dev-grade permission group present (<group>).` Continue.
- None of the above → print:

  > MISSING: no effective `ModifyAllData`/`ModifyMetadata` and no `Admin_Group`/`Near_Admin_Group` found for this user. You can authenticate and read, but deploys/edits may be blocked. Request `Dev_Sandbox_Access` (BC-10727's sanctioned dev-sandbox-access permset) — or `Admin_Group` if you need broader rights — from your Brite Salesforce admin, then re-check with `/revops:doctor`.

  This is a reportable state, not a halt — continue.
- Query errored → surface verbatim and continue (the self-probe is advisory; do not halt the onboarding on it).

Ask via `AskUserQuestion`:

- Question: `Permission self-probe reviewed. Continue to the handoff?`
- Options:
  - `Yes, continue` — proceed to Phase 7.
  - `Stop here` — print a summary of what is set up so far and exit cleanly.

Narrate: `Phase 6/7: Permission self-probe... done`

---

## Phase 7 — First-login runbook + completion

Narrate: `Phase 7/7: Completion...`

Hand off the org-side first-login guidance and point at the next commands. Tell the user:

> First-login lockout-avoidance (org-side, if this is a brand-new SF user): see `brite-salesforce/docs/runbooks/new-user-first-login.md` in the brite-salesforce repo.

Print the completion summary (ASCII markers only):

- `OK: sf + node detected`
- `OK: revops plugin installed`
- `OK: brite-sandbox authenticated (Connected)`
- `OK: default target-org = brite-sandbox`
- `OK: connectivity probe returned a row`
- `<OK|MISSING>: dev-grade permission group` (from Phase 6)

Then the next-step hint:

> You are set up for brite-sandbox. Next:
>
> - `/revops:doctor` — re-runnable health check that re-verifies all of the above.
> - `/revops:deploy-sandbox` — your first sandbox deploy.

Narrate: `Phase 7/7: Completion... done`

This phase asks no question — it is the terminal summary.

---

## Rules

- **Never skip a gate.** Every phase ends with one `AskUserQuestion`; a non-proceed answer halts the command. One question at a time — never batch.
- **Idempotent.** If `brite-sandbox` is already authenticated and the default target-org, Phase 1 early-exits with zero mutations (no `sf org login`, no `sf config set`).
- **Always pass `--target-org brite-sandbox`** for org-scoped commands. Never rely on an ambient default for the probes.
- **`sf`, not `sfdx`.** Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **Parse `--json` via `status === 0`,** not human-readable stdout strings — the JSON envelope is stable across CLI 2.x versions.
- **Probe with the `sf` CLI, not the MCP `run_soql_query`.** The MCP rejects an alias and needs a literal username per call; the CLI accepts `--target-org brite-sandbox`.
- **Plugin install is distinct from registration.** Phase 2 checks `claude plugin list`, not marketplace.json.
- **Do not auto-retry on failure.** Surface raw output and halt; silent retries mask real issues.
