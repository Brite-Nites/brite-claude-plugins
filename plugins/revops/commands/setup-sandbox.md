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
echo "sf:   $(sf --version 2>/dev/null | head -1 || echo MISSING)"
echo "node: $(node --version 2>/dev/null || echo MISSING)"
echo "gh:   $(gh auth status 2>&1 | head -1 || echo MISSING)"
echo "--- sf org list ---"
sf org list --json 2>/dev/null || echo "SF_ORG_LIST_FAILED"
echo "--- default target-org ---"
sf config get target-org --json 2>/dev/null || echo "NO_DEFAULT"
```

Interpret:

- **`sf` MISSING** → halt. Tell the user: *"The Salesforce CLI (`sf`) is not installed. Install it (`npm install -g @salesforce/cli`, needs Node 18+), open a fresh terminal, then re-run `/revops:setup-sandbox`."* Do not continue.
- **`node` MISSING** → halt with the equivalent Node install guidance.
- **`gh` MISSING** → note it as a warning (the revops flow needs `gh` later for shipping, but it does not block sandbox auth). Continue.
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

> Log in to the sandbox in your browser. Run this in a terminal — you can run it directly in this Claude Code session with the `!` prefix, or in your own terminal:
>
> ```bash
> sf org login web --alias brite-sandbox
> ```
>
> A browser tab opens at the Salesforce login page. Use your **sandbox** credentials (sandbox usernames carry a suffix such as `.bndev` after your normal username). After the browser shows "successfully authorized," return here.

After the user says they have logged in, verify:

```bash
sf org list --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); orgs=[o for o in (d.get('result',{}).get('nonScratchOrgs',[]) + d.get('result',{}).get('sandboxes',[])) if o.get('alias')=='brite-sandbox' or o.get('username','').find('brite-sandbox')>=0]; print('CONNECTED' if any(o.get('connectedStatus')=='Connected' for o in orgs) else 'NOT_CONNECTED')" 2>/dev/null || sf org list 2>/dev/null | grep -i brite-sandbox || echo "NOT_FOUND"
```

- `Connected` / a `brite-sandbox` line present → continue.
- `NOT_CONNECTED` / `NOT_FOUND` → the login did not complete. Surface `sf org list` verbatim, do not auto-retry, and re-ask the gate below after the user retries the login.

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
sf config set target-org brite-sandbox --json
```

Parse the JSON via `status === 0`:

- `status: 0` → confirm with `sf config get target-org` and report the resolved value. Continue.
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

- Both `status: 0` and the query returns one record → print the resolved username and instance URL from `sf org display`, and confirm the SOQL returned a row. Continue.
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

Check whether the authenticated user holds a dev-grade permission set group. This is read-only and never blocks — it only reports what to request.

First get the authenticated username, then query its permission-set-group assignments:

```bash
SF_USER="$(sf org display --target-org brite-sandbox --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['username'])" 2>/dev/null)"
echo "Authenticated user: ${SF_USER:-UNKNOWN}"
sf data query --target-org brite-sandbox --query "SELECT PermissionSetGroup.DeveloperName FROM PermissionSetAssignment WHERE Assignee.Username = '${SF_USER}' AND PermissionSetGroupId != null" --json
```

Interpret the returned `PermissionSetGroup.DeveloperName` values:

- Includes `Admin_Group` or `Near_Admin_Group` → print `OK: dev-grade permission group present (<group>).` Continue.
- Neither present → print:

  > MISSING: no dev-grade permission group found for this user. You can authenticate and read, but deploys/edits may be blocked. Request `Admin_Group` (or `Near_Admin_Group`) from your Brite Salesforce admin, then re-check with `/revops:doctor`.

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
