---
description: Re-runnable, zero-mutation Salesforce environment health check for the revops plugin — the SF-specific analogue of /workflows:smoke-test. Verifies the sf CLI, node, gh auth, revops plugin install, revops MCP connectivity, your own brite-dev-<name> org resolving, whether the retiring brite-sandbox is still authenticated, default target-org, a trivial SOQL probe, dev-grade permission-set membership, and brite-prod auth validity, then prints a PASS/FAIL/WARN/SKIP table with targeted remediation. Run it when /revops:preview-changes mysteriously fails, after a laptop change, or to confirm a teammate is ready before pairing. Triggers on "revops doctor", "check environment health", "salesforce health check", "is my sf environment ok", "diagnose sf". Formerly /revops:doctor.
allowed-tools: Bash
---

<!-- eval-waiver: Zero-mutation SF environment health check: a single read-only probe block (sf --version, auth status, plugin list, mcp list, org list, config get, a trivial SOQL) whose entire output depends on live host, org, and auth state; there is no decide(inputs, injected_reads)-to-artifact, since every PASS/FAIL/WARN/SKIP line is computed inline against the real machine. -->

# /revops:check-environment-health

A re-runnable, **zero-mutation** diagnostic that answers "is my Salesforce environment still good?" — the SF-specific analogue of `/workflows:smoke-test` (which only checks git/gh/node/npx + Linear generically and knows nothing about the `sf` CLI, org auth, default target-org, or permsets). Run it when a `/revops:preview-changes` mysteriously fails, after a laptop change, or to confirm a teammate is ready before a pairing session.

This command **performs no mutations and asks no questions** — it has no gates. It runs one read-only probe script, then renders the results. Contrast with `/revops:setup-dev-workspace` (BC-10657), the one-time *mutating* onboarding flow that logs you in and sets the default target-org; `/revops:check-environment-health` only reads and reports. When auth or the default target-org is the gap, the remediation points back at `/revops:setup-dev-workspace`.

Conventions (shared with `/revops:setup-dev-workspace` and `/revops:preview-changes`):

- Org-scoped probes run against the developer's own `brite-dev-<name>` org, resolved by check 6 with the same resolver the deploy commands use. They always pass `--target-org` explicitly — never an ambient default.
- Use `sf`, never legacy `sfdx`.
- Parse `--json` output via top-level `status === 0`, not human-readable stdout strings.
- Probe with the `sf` CLI, **not** the MCP `run_soql_query`: the MCP requires a literal username per call (it rejects an alias), whereas the `sf` CLI accepts `--target-org brite-dev-<name>` directly.

Out of scope: anything mutating (use `/revops:setup-dev-workspace`), the first deploy (use `/revops:preview-changes`), and SF org-side user/permission provisioning (admin work).

---

## Step 1 — Run the read-only probe

Run this single block with the Bash tool. Every command is a read (`--version`, `auth status`, `plugin list`, `mcp list`, `sf org list`, `sf config get`, `SELECT`) — it performs **zero mutations** and **no retries**. It prints one tab-separated `STATUS<TAB>CHECK<TAB>NOTE` line per check; `STATUS` is one of `PASS` / `FAIL` / `WARN` / `SKIP`. Downstream org checks `SKIP` (not `FAIL`) when a prerequisite is unavailable, so the output is deterministic and identical across runs.

<!-- guard:target-org -->

**`--target-org` guard — read before the probe below (checks 8 and 9 are its earliest sinks).** Checks 8 and 9 interpolate `$DEV_ORG` into a double-quoted `sf` argument. Bash expands `$(...)` and backticks even inside double quotes, so a `--target-org` value that has not been validated reaches a shell before any guard. `$DEV_ORG` is validated at its source, not at the sink: check 6 sets it **only** from `promotion_topology.py --resolve-dev-org`, which emits an alias solely when it matches `^brite-dev-[a-z0-9][a-z0-9-]*$` — a strict subset of the canonical Salesforce org-alias character set `^[a-zA-Z0-9._@-]+$` shared with `/revops:create-sf-campaign`, `/revops:update-sf-campaign-status`, and the marketing siblings. Every other resolver outcome (`ambiguous`, `none`, `unusable`, a parse failure) leaves `$DEV_ORG` empty, and checks 8 and 9 then `SKIP` rather than shelling out. So no unvalidated value can reach a sink.

That resolver regex is behaviorally eval'd in `scripts/test_promotion_topology.sh`, which asserts both that injection payloads (`$(touch pwned)`, backticks, metacharacters) are rejected and that no side-effect file is created. Keep the canonical regex byte-identical — the consolidating lint (`scripts/_lib/lint_target_org_guard.py`) enforces the byte-identity and that this marker precedes the sink.

```bash
# /revops:check-environment-health probe — read-only. Emits: STATUS<TAB>CHECK<TAB>NOTE
# No `set -e`: individual checks legitimately return non-zero (e.g. grep -q miss).
emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }
command -v python3 >/dev/null 2>&1 && PY_OK=1 || PY_OK=0

# 1. sf CLI present + v2.x, minimum 2.135.7 (BC-12348: 2.134.x OAuth token-exchange bug)
if command -v sf >/dev/null 2>&1; then
  sf_ver="$(sf --version 2>/dev/null | head -1)"
  sf_full="$(printf '%s' "$sf_ver" | grep -oE '@salesforce/cli/[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  sf_major="$(printf '%s' "$sf_full" | cut -d. -f1)"
  if [ "$sf_major" != "2" ]; then
    emit FAIL "sf CLI" "expected v2.x, got: ${sf_full:-${sf_ver:-unknown}} — npm install -g @salesforce/cli"; SF_OK=0
  else
    sf_ok="$(awk -v v="$sf_full" 'BEGIN {
      split(v, a, ".")
      if (a[2]+0 > 135) { print 1; exit }
      if (a[2]+0 < 135) { print 0; exit }
      print (a[3]+0 >= 7)
    }')"
    if [ "$sf_ok" = "1" ]; then emit PASS "sf CLI" "$sf_full"; SF_OK=1
    else emit FAIL "sf CLI" "version $sf_full below minimum 2.135.7 (2.134.x OAuth token-exchange bug — sf org login web raises misleading AuthCodeExchangeError despite server-side success) — npm install -g @salesforce/cli@latest"; SF_OK=0; fi
  fi
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

# 6. per-developer dev org resolvable (ADR-026 — replaces the brite-sandbox pin)
# The resolver is the same one the deploy commands use, so this check answers the
# question that actually matters: "will /revops:preview-changes find my org?"
DEV_ORG=""
if [ "${SF_OK:-0}" = "1" ] && [ "$PY_OK" = "1" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  dv="$(sf org list --json 2>/dev/null \
        | python3 "$CLAUDE_PLUGIN_ROOT/scripts/promotion_topology.py" --resolve-dev-org - 2>/dev/null \
        | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print('PARSE_FAILED||'); sys.exit(0)
cands=[c.get('alias','') for c in d.get('candidates',[])]
print(f\"{d.get('decision','')}|{d.get('alias','')}|{','.join(cands)}\")
" 2>/dev/null || echo "PY_FAIL||")"
  IFS='|' read -r dv_decision dv_alias dv_cands <<<"$dv"
  case "$dv_decision" in
    resolved)  emit PASS "dev org" "$dv_alias (Connected)"; DEV_ORG="$dv_alias";;
    ambiguous) emit WARN "dev org" "several dev orgs authenticated ($dv_cands) — deploy commands will ask which; pass --target-org to skip the question";;
    none)      emit FAIL "dev org" "no authenticated brite-dev-<name> org — run /revops:setup-dev-workspace";;
    *)         emit FAIL "dev org" "could not resolve a dev org ($dv_decision) — run /revops:setup-dev-workspace";;
  esac
elif [ "${SF_OK:-0}" != "1" ]; then emit SKIP "dev org" "sf CLI unavailable"
elif [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then emit SKIP "dev org" "CLAUDE_PLUGIN_ROOT unset — cannot reach the resolver"
else emit SKIP "dev org" "python3 unavailable — cannot parse sf --json"; fi

# 6b. legacy brite-sandbox still authenticated (advisory — the retirement nudge)
if [ "${SF_OK:-0}" = "1" ] && [ "$PY_OK" = "1" ]; then
  sb="$(sf org list --json 2>/dev/null | python3 -c "
import json,sys
try: r=json.load(sys.stdin).get('result',{})
except Exception: print('PARSE_FAILED'); sys.exit(0)
orgs=r.get('nonScratchOrgs',[])+r.get('sandboxes',[])
print('PRESENT' if [o for o in orgs if o.get('alias')=='brite-sandbox'] else 'ABSENT')
" 2>/dev/null || echo PY_FAIL)"
  case "$sb" in
    ABSENT)  emit PASS "legacy brite-sandbox" "not authenticated — nothing to migrate";;
    PRESENT) emit WARN "legacy brite-sandbox" "still authenticated — brite-sandbox is retiring (ADR-026). Inner-loop work moves to brite-dev-<name>; shared integration moves to brite-integration via PR. Deploy commands no longer target it";;
    *)       emit SKIP "legacy brite-sandbox" "could not parse 'sf org list' ($sb)";;
  esac
else emit SKIP "legacy brite-sandbox" "sf CLI or python3 unavailable"; fi

# 7. default target-org points at the resolved dev org (WARN, never FAIL)
if [ "${SF_OK:-0}" = "1" ] && [ "$PY_OK" = "1" ]; then
  tgt="$(sf config get target-org --json 2>/dev/null | python3 -c "
import json,sys
try: r=json.load(sys.stdin).get('result',[])
except Exception: print(''); sys.exit(0)
v=[x.get('value') for x in r if x.get('name')=='target-org']
print(v[0] if v and v[0] else '')
" 2>/dev/null)"
  if [ -n "$DEV_ORG" ] && [ "$tgt" = "$DEV_ORG" ]; then emit PASS "default target-org" "$tgt"
  elif [ "$tgt" = "brite-sandbox" ]; then emit WARN "default target-org" "still set to the retiring brite-sandbox — run /revops:setup-dev-workspace to point it at your own dev org"
  elif [ -n "$tgt" ]; then emit WARN "default target-org" "set to '$tgt'${DEV_ORG:+, not your dev org $DEV_ORG} — run /revops:setup-dev-workspace or pass --target-org explicitly"
  else emit WARN "default target-org" "unset — run /revops:setup-dev-workspace or pass --target-org explicitly"; fi
elif [ "${SF_OK:-0}" != "1" ]; then emit SKIP "default target-org" "sf CLI unavailable"
else emit SKIP "default target-org" "python3 unavailable — cannot parse sf --json"; fi

# 8. trivial SOQL via the sf CLI (proves auth works against the resolved dev org)
SOQL_OK=0
if [ -n "$DEV_ORG" ]; then
  q="$(sf data query --target-org "$DEV_ORG" --query "SELECT Id FROM Organization LIMIT 1" --json 2>/dev/null | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print('PARSE_FAILED'); sys.exit(0)
print('ROW' if d.get('status')==0 and d.get('result',{}).get('records') else 'NO_ROW')
" 2>/dev/null || echo PY_FAIL)"
  if [ "$q" = "ROW" ]; then emit PASS "trivial SOQL" "SELECT Id FROM Organization returned a row from $DEV_ORG"; SOQL_OK=1
  else emit FAIL "trivial SOQL" "query failed ($q) — session may be expired (re-run /revops:setup-dev-workspace) or API access missing (escalate to a Brite SF admin)"; fi
else
  emit SKIP "trivial SOQL" "no dev org resolved"
fi

# 9. PermissionSetAssignment self-probe (informational — never blocks)
if [ "$SOQL_OK" = "1" ]; then
  uname="$(sf org display --target-org "$DEV_ORG" --json 2>/dev/null | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('result',{}).get('username',''))
except Exception: print('')
" 2>/dev/null)"
  if [ -n "$uname" ]; then
    # Query both capability flags (ModifyAllData / ModifyMetadata — picks up
    # profile-owned permsets like SysAdmin AND standalone permsets like
    # Dev_Sandbox_Access from BC-10727) and group developer names in one shot.
    psp="$(sf data query --target-org "$DEV_ORG" --query "SELECT PermissionSet.PermissionsModifyAllData, PermissionSet.PermissionsModifyMetadata, PermissionSetGroup.DeveloperName FROM PermissionSetAssignment WHERE Assignee.Username = '$uname'" --json 2>/dev/null | python3 -c "
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
    else emit WARN "permset self-probe" "no effective ModifyAllData/ModifyMetadata and no Admin_Group/Near_Admin_Group — read works but deploys/edits may be blocked; request Dev_Sandbox_Access (or Admin_Group) from a Brite SF admin, then re-check with /revops:check-environment-health"; fi
  else
    emit SKIP "permset self-probe" "could not resolve username from 'sf org display'"
  fi
else
  emit SKIP "permset self-probe" "trivial SOQL did not return a row"
fi

# 10. brite-prod auth validity (weekly JWT probe surface — BC-11098)
if [ "${SF_OK:-0}" = "1" ] && [ "$PY_OK" = "1" ]; then
  prod_cs="$(sf org display --target-org brite-prod --json 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if d.get('status',1)!=0: print('NOT_AUTHED'); sys.exit(0)
    print(d.get('result',{}).get('connectedStatus','UNKNOWN'))
except Exception: print('PARSE_FAILED')
" 2>/dev/null || echo PY_FAIL)"
  case "$prod_cs" in
    Connected) emit PASS "brite-prod auth" "Connected";;
    NOT_AUTHED) emit WARN "brite-prod auth" "brite-prod alias not authenticated — run: sf org login web --alias brite-prod --instance-url https://login.salesforce.com";;
    *) emit WARN "brite-prod auth" "not Connected ($prod_cs) — see brite-salesforce/docs/runbooks/sf-prod-auth-rotation.md";;
  esac
elif [ "${SF_OK:-0}" != "1" ]; then emit SKIP "brite-prod auth" "sf CLI unavailable"
else emit SKIP "brite-prod auth" "python3 unavailable — cannot parse sf --json"; fi
```

---

## Step 2 — Report

From the emitted `STATUS<TAB>CHECK<TAB>NOTE` lines, render a results table (mirror `/workflows:smoke-test`). Use the `NOTE` field verbatim in the Notes column:

```
## /revops:check-environment-health — SF environment health

| Check               | Status | Notes                                            |
|---------------------|--------|--------------------------------------------------|
| sf CLI              | PASS   | @salesforce/cli/2.x ...                          |
| node                | PASS   | v22.x                                            |
| gh auth             | PASS   | authenticated                                    |
| revops plugin       | PASS   | installed                                        |
| revops MCP          | PASS   | salesforce connected                             |
| dev org             | PASS   | brite-dev-holden (Connected)                     |
| legacy brite-sandbox| PASS   | not authenticated — nothing to migrate           |
| default target-org  | PASS   | brite-dev-holden                                 |
| trivial SOQL        | PASS   | SELECT Id FROM Organization returned a row       |
| permset self-probe  | PASS   | dev-grade group present (Admin_Group)            |
| brite-prod auth     | PASS   | Connected                                        |

**Overall**: N PASS, N FAIL, N WARN, N SKIP — <verdict>
```

Compute the Overall counts from the emitted statuses, then a one-word verdict:

- **healthy** — 0 FAIL and 0 WARN.
- **ready, with advisories** — 0 FAIL, at least one WARN.
- **not ready** — at least one FAIL.

If there is any `FAIL` or `WARN`, add a **Remediation** section below the table — one line per failing/warning check, taken from its `NOTE`. Auth / default-org gaps route to `run /revops:setup-dev-workspace`; the permset gap routes to a Brite SF admin (request `Dev_Sandbox_Access` per BC-10727, or `Admin_Group`) + re-run. Do not invent fixes beyond what the `NOTE` states.

---

## Rules

- **Zero mutation.** Every probe is read-only — `sf config list` and `sf org list` are byte-identical before and after a run. Never run `sf org login`, `sf config set`, or any deploy/DML from this command.
- **Idempotent.** Two consecutive runs produce identical reports (the SKIP-cascade makes downstream output deterministic when a prerequisite is missing).
- **No gates, no questions.** This command never calls `AskUserQuestion` — it is pure diagnosis. (Use `/revops:setup-dev-workspace` for the gated, mutating setup.)
- **No retry.** If a probe fails, surface its status and note; never silently re-run it — silent retries mask real issues.
- **`sf`, not `sfdx`.** Legacy `sfdx` subcommands are deprecated per `brite-salesforce/CLAUDE.md`.
- **Parse `--json` via `status === 0`,** not human-readable stdout — the JSON envelope is stable across CLI 2.x versions.
- **Probe with the `sf` CLI, not the MCP `run_soql_query`.** The MCP rejects an alias and needs a literal username per call; the CLI accepts `--target-org brite-dev-<name>`.
- **Always pass `--target-org "$DEV_ORG"`** for org-scoped probes — never rely on an ambient default. `$DEV_ORG` is whatever check 6 resolved, and it always matches `^brite-dev-[a-z0-9][a-z0-9-]*$`.
- **Plugin install is distinct from registration.** The plugin check reads `claude plugin list`, not marketplace.json.
- **WARN never blocks.** A wrong/unset default target-org, a missing permset group, and a non-Connected brite-prod alias are advisory (WARN), not FAIL — the environment may still be usable with explicit `--target-org`.
- **brite-prod is advisory, not blocking.** The brite-prod auth check (check 10) emits WARN/SKIP, never FAIL — expired prod auth does not block sandbox development. The weekly CI probe (`.github/workflows/jwt-validity-probe.yml`) is the authoritative enforcement mechanism; it auto-files a Linear issue on failure.
