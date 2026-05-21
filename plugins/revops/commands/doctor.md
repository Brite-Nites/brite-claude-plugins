---
description: Re-runnable, zero-mutation Salesforce environment health check for the revops plugin — the SF-specific analogue of /workflows:smoke-test. Verifies the sf CLI, node, gh auth, revops plugin install, revops MCP connectivity, brite-sandbox authentication, default target-org, a trivial SOQL probe, and dev-grade permission-set membership, then prints a PASS/FAIL/WARN/SKIP table with targeted remediation. Run it when /revops:deploy-sandbox mysteriously fails, after a laptop change, or to confirm a teammate is ready before pairing. Triggers on "revops doctor", "salesforce health check", "is my sf environment ok", "diagnose sf".
allowed-tools: Bash
---

# /revops:doctor

A re-runnable, **zero-mutation** diagnostic that answers "is my Salesforce environment still good?" — the SF-specific analogue of `/workflows:smoke-test` (which only checks git/gh/node/npx + Linear generically and knows nothing about the `sf` CLI, sandbox auth, default target-org, or permsets). Run it when a `/revops:deploy-sandbox` mysteriously fails, after a laptop change, or to confirm a teammate is ready before a pairing session.

This command **performs no mutations and asks no questions** — it has no gates. It runs one read-only probe script, then renders the results. Contrast with `/revops:setup-sandbox` (BC-10657), the one-time *mutating* onboarding flow that logs you in and sets the default target-org; `/revops:doctor` only reads and reports. When auth or the default target-org is the gap, the remediation points back at `/revops:setup-sandbox`.

Conventions (shared with `/revops:setup-sandbox` and `/revops:deploy-sandbox`):

- Sandbox alias is `brite-sandbox`. Org-scoped probes always pass `--target-org brite-sandbox` explicitly — never rely on an ambient default.
- Use `sf`, never legacy `sfdx`.
- Parse `--json` output via top-level `status === 0`, not human-readable stdout strings.
- Probe with the `sf` CLI, **not** the MCP `run_soql_query`: the MCP requires a literal username per call (it rejects an alias), whereas the `sf` CLI accepts `--target-org brite-sandbox` directly.

Out of scope: anything mutating (use `/revops:setup-sandbox`), the first deploy (use `/revops:deploy-sandbox`), and SF org-side user/permission provisioning (admin work).

---

## Step 1 — Run the read-only probe

Run this single block with the Bash tool. Every command is a read (`--version`, `auth status`, `plugin list`, `mcp list`, `sf org list`, `sf config get`, `SELECT`) — it performs **zero mutations** and **no retries**. It prints one tab-separated `STATUS<TAB>CHECK<TAB>NOTE` line per check; `STATUS` is one of `PASS` / `FAIL` / `WARN` / `SKIP`. Downstream org checks `SKIP` (not `FAIL`) when a prerequisite is unavailable, so the output is deterministic and identical across runs.

```bash
# /revops:doctor probe — read-only. Emits: STATUS<TAB>CHECK<TAB>NOTE
# No `set -e`: individual checks legitimately return non-zero (e.g. grep -q miss).
emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }
command -v python3 >/dev/null 2>&1 && PY_OK=1 || PY_OK=0

# 1. sf CLI present + v2.x
if command -v sf >/dev/null 2>&1; then
  sf_ver="$(sf --version 2>/dev/null | head -1)"
  sf_major="$(printf '%s' "$sf_ver" | grep -oE '@salesforce/cli/[0-9]+' | grep -oE '[0-9]+$')"
  if [ "$sf_major" = "2" ]; then emit PASS "sf CLI" "$sf_ver"; SF_OK=1
  else emit FAIL "sf CLI" "expected v2.x, got: ${sf_ver:-unknown} — npm install -g @salesforce/cli"; SF_OK=0; fi
else
  emit FAIL "sf CLI" "not installed — npm install -g @salesforce/cli (needs Node 18+)"; SF_OK=0
fi

# 2. node present
if command -v node >/dev/null 2>&1; then emit PASS "node" "$(node --version 2>/dev/null)"
else emit FAIL "node" "not installed — required by the sf CLI"; fi

# 3. gh authenticated
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then emit PASS "gh auth" "authenticated"
  else emit WARN "gh auth" "present but not authenticated — run: gh auth login"; fi
else
  emit SKIP "gh auth" "gh not installed (advisory — needed later for shipping, not for SF probes)"
fi

# 4. revops plugin installed (claude plugin list — registration != install)
if command -v claude >/dev/null 2>&1; then
  if claude plugin list 2>/dev/null | grep -q "revops@"; then emit PASS "revops plugin" "installed"
  else emit FAIL "revops plugin" "registered but not installed — run: claude plugin install revops@brite-claude-plugins"; fi
else
  emit SKIP "revops plugin" "claude CLI not on PATH — cannot check install state"
fi

# 5. revops MCP reachable (claude mcp list shows salesforce connected)
if command -v claude >/dev/null 2>&1; then
  mcp_line="$(claude mcp list 2>/dev/null | grep -i 'salesforce' | head -1)"
  if printf '%s' "$mcp_line" | grep -qi 'connected'; then emit PASS "revops MCP" "salesforce connected"
  elif [ -n "$mcp_line" ]; then emit WARN "revops MCP" "salesforce listed but not connected: $mcp_line"
  else emit WARN "revops MCP" "salesforce MCP not listed by 'claude mcp list' — re-launch Claude Code"; fi
else
  emit SKIP "revops MCP" "claude CLI not on PATH — cannot check MCP state"
fi

# 6. brite-sandbox authenticated (Connected)
SB_OK=0
if [ "${SF_OK:-0}" = "1" ] && [ "$PY_OK" = "1" ]; then
  sb="$(sf org list --json 2>/dev/null | python3 -c "
import json,sys
try: r=json.load(sys.stdin).get('result',{})
except Exception: print('PARSE_FAILED'); sys.exit(0)
orgs=r.get('nonScratchOrgs',[])+r.get('sandboxes',[])
m=[o for o in orgs if o.get('alias')=='brite-sandbox']
print('CONNECTED' if any(o.get('connectedStatus')=='Connected' for o in m) else ('NOT_CONNECTED' if m else 'ABSENT'))
" 2>/dev/null || echo PY_FAIL)"
  case "$sb" in
    CONNECTED) emit PASS "brite-sandbox auth" "Connected"; SB_OK=1;;
    NOT_CONNECTED) emit FAIL "brite-sandbox auth" "present but not Connected — run /revops:setup-sandbox";;
    ABSENT) emit FAIL "brite-sandbox auth" "no brite-sandbox alias — run /revops:setup-sandbox";;
    *) emit FAIL "brite-sandbox auth" "could not parse 'sf org list' ($sb) — run /revops:setup-sandbox";;
  esac
elif [ "${SF_OK:-0}" != "1" ]; then emit SKIP "brite-sandbox auth" "sf CLI unavailable"
else emit SKIP "brite-sandbox auth" "python3 unavailable — cannot parse sf --json"; fi

# 7. default target-org == brite-sandbox (WARN, not FAIL, on a different/unset org)
if [ "${SF_OK:-0}" = "1" ] && [ "$PY_OK" = "1" ]; then
  tgt="$(sf config get target-org --json 2>/dev/null | python3 -c "
import json,sys
try: r=json.load(sys.stdin).get('result',[])
except Exception: print(''); sys.exit(0)
v=[x.get('value') for x in r if x.get('name')=='target-org']
print(v[0] if v and v[0] else '')
" 2>/dev/null)"
  if [ "$tgt" = "brite-sandbox" ]; then emit PASS "default target-org" "brite-sandbox"
  elif [ -n "$tgt" ]; then emit WARN "default target-org" "set to '$tgt', not brite-sandbox — run /revops:setup-sandbox or pass --target-org explicitly"
  else emit WARN "default target-org" "unset — run /revops:setup-sandbox or pass --target-org explicitly"; fi
elif [ "${SF_OK:-0}" != "1" ]; then emit SKIP "default target-org" "sf CLI unavailable"
else emit SKIP "default target-org" "python3 unavailable — cannot parse sf --json"; fi

# 8. trivial SOQL via the sf CLI (proves auth works against the org)
SOQL_OK=0
if [ "$SB_OK" = "1" ]; then
  q="$(sf data query --target-org brite-sandbox --query "SELECT Id FROM Organization LIMIT 1" --json 2>/dev/null | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print('PARSE_FAILED'); sys.exit(0)
print('ROW' if d.get('status')==0 and d.get('result',{}).get('records') else 'NO_ROW')
" 2>/dev/null || echo PY_FAIL)"
  if [ "$q" = "ROW" ]; then emit PASS "trivial SOQL" "SELECT Id FROM Organization returned a row"; SOQL_OK=1
  else emit FAIL "trivial SOQL" "query failed ($q) — session may be expired (re-run /revops:setup-sandbox) or API access missing (escalate to a Brite SF admin)"; fi
else
  emit SKIP "trivial SOQL" "brite-sandbox not Connected"
fi

# 9. PermissionSetAssignment self-probe (informational — never blocks)
if [ "$SOQL_OK" = "1" ]; then
  uname="$(sf org display --target-org brite-sandbox --json 2>/dev/null | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('result',{}).get('username',''))
except Exception: print('')
" 2>/dev/null)"
  if [ -n "$uname" ]; then
    # Query both capability flags (ModifyAllData / ModifyMetadata — picks up
    # profile-owned permsets like SysAdmin AND standalone permsets like
    # Dev_Sandbox_Access from BC-10727) and group developer names in one shot.
    psp="$(sf data query --target-org brite-sandbox --query "SELECT PermissionSet.PermissionsModifyAllData, PermissionSet.PermissionsModifyMetadata, PermissionSetGroup.DeveloperName FROM PermissionSetAssignment WHERE Assignee.Username = '$uname'" --json 2>/dev/null | python3 -c "
import json,sys
try: r=json.load(sys.stdin).get('result',{}).get('records',[])
except Exception: print('0|0|'); sys.exit(0)
mad = any((rec.get('PermissionSet') or {}).get('PermissionsModifyAllData') for rec in r)
mmd = any((rec.get('PermissionSet') or {}).get('PermissionsModifyMetadata') for rec in r)
grps = [g for g in [(rec.get('PermissionSetGroup') or {}).get('DeveloperName') for rec in r] if g]
dev_grp = next((g for g in grps if g in ('Admin_Group','Near_Admin_Group')), '')
print(f'{int(mad)}|{int(mmd)}|{dev_grp}')
" 2>/dev/null)"
    IFS='|' read -r mad mmd dev_grp <<<"$psp"
    if [ "$mad" = "1" ]; then emit PASS "permset self-probe" "ModifyAllData granted (effective admin)"
    elif [ "$mmd" = "1" ]; then emit PASS "permset self-probe" "ModifyMetadata granted (dev-sandbox-capable, e.g. Dev_Sandbox_Access)"
    elif [ -n "$dev_grp" ]; then emit PASS "permset self-probe" "dev-grade group present (${dev_grp})"
    else emit WARN "permset self-probe" "no effective ModifyAllData/ModifyMetadata and no Admin_Group/Near_Admin_Group — read works but deploys/edits may be blocked; request Dev_Sandbox_Access (or Admin_Group) from a Brite SF admin, then re-check with /revops:doctor"; fi
  else
    emit SKIP "permset self-probe" "could not resolve username from 'sf org display'"
  fi
else
  emit SKIP "permset self-probe" "trivial SOQL did not return a row"
fi
```

---

## Step 2 — Report

From the emitted `STATUS<TAB>CHECK<TAB>NOTE` lines, render a results table (mirror `/workflows:smoke-test`). Use the `NOTE` field verbatim in the Notes column:

```
## /revops:doctor — SF environment health

| Check               | Status | Notes                                            |
|---------------------|--------|--------------------------------------------------|
| sf CLI              | PASS   | @salesforce/cli/2.x ...                          |
| node                | PASS   | v22.x                                            |
| gh auth             | PASS   | authenticated                                    |
| revops plugin       | PASS   | installed                                        |
| revops MCP          | PASS   | salesforce connected                             |
| brite-sandbox auth  | PASS   | Connected                                        |
| default target-org  | PASS   | brite-sandbox                                    |
| trivial SOQL        | PASS   | SELECT Id FROM Organization returned a row       |
| permset self-probe  | PASS   | dev-grade group present (Admin_Group)            |

**Overall**: N PASS, N FAIL, N WARN, N SKIP — <verdict>
```

Compute the Overall counts from the emitted statuses, then a one-word verdict:

- **healthy** — 0 FAIL and 0 WARN.
- **ready, with advisories** — 0 FAIL, at least one WARN.
- **not ready** — at least one FAIL.

If there is any `FAIL` or `WARN`, add a **Remediation** section below the table — one line per failing/warning check, taken from its `NOTE`. Auth / default-org gaps route to `run /revops:setup-sandbox`; the permset gap routes to a Brite SF admin (request `Dev_Sandbox_Access` per BC-10727, or `Admin_Group`) + re-run. Do not invent fixes beyond what the `NOTE` states.

---

## Rules

- **Zero mutation.** Every probe is read-only — `sf config list` and `sf org list` are byte-identical before and after a run. Never run `sf org login`, `sf config set`, or any deploy/DML from this command.
- **Idempotent.** Two consecutive runs produce identical reports (the SKIP-cascade makes downstream output deterministic when a prerequisite is missing).
- **No gates, no questions.** This command never calls `AskUserQuestion` — it is pure diagnosis. (Use `/revops:setup-sandbox` for the gated, mutating setup.)
- **No retry.** If a probe fails, surface its status and note; never silently re-run it — silent retries mask real issues.
- **`sf`, not `sfdx`.** Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **Parse `--json` via `status === 0`,** not human-readable stdout — the JSON envelope is stable across CLI 2.x versions.
- **Probe with the `sf` CLI, not the MCP `run_soql_query`.** The MCP rejects an alias and needs a literal username per call; the CLI accepts `--target-org brite-sandbox`.
- **Always pass `--target-org brite-sandbox`** for org-scoped probes — never rely on an ambient default.
- **Plugin install is distinct from registration.** The plugin check reads `claude plugin list`, not marketplace.json.
- **WARN never blocks.** A wrong/unset default target-org and a missing permset group are advisory (WARN), not FAIL — the environment may still be usable with explicit `--target-org`.
