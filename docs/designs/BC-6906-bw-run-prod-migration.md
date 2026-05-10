# BC-6906 — Production migration: tam-map MCPs + CLI scripts to `bw-run.sh` wrapper; setup-tam-map ≤3 phases

## Status
Design draft. Brainstorm output for [BC-6906](https://linear.app/brite-nites/issue/BC-6906). Promotes BC-6905's POC ([PR #258](https://github.com/Brite-Nites/brite-claude-plugins/pull/258), spike findings at `docs/research/bw-run-spike.md`) to production. All four design forks resolved with user; recorded below for execution.

## Goal
Eliminate `~/.zshrc` edits and Claude Code restarts from tam-map onboarding. Establish `bw-run.sh` as the canonical Brite plugin secret-config pattern in `CONTRIBUTING.md`.

## Inputs
- BC-6906 issue body (acceptance criteria, file list, scope boundaries).
- BC-6905 spike: 6-item adapt list + Q1–Q7 measurements + 4 precedents (`docs/precedents/BC-6905.md`).
- BC-6905 POC: `scripts/spike-bw-run/bw-run.sh` (~46-line throwaway).
- Current state: `plugins/marketing/commands/setup-tam-map.md` (7 phases), `plugins/marketing/.mcp.json`, the 2 affected skills (`tam-mapping`, `list-building`), CLAUDE.md BC-5551 gotcha at line 93.

## Resolved design forks (user-confirmed)

### Fork 1 — Test framework: **pure-bash assertions, PATH-mocked `bw`**
Single self-contained `plugins/marketing/scripts/bw-run.test.sh`. No new test-runner deps (matches the repo's anti-dependency rule already codified for embedded Python). Continuity with BC-6905 spike scripts (`measure.sh`, `exercise-q4.sh`, `exercise-rotation.sh`, `verify-q7.sh` are all pure-bash). Stub `bw` via a temp dir prepended to PATH; `assert_eq <actual> <expected> <name>` helper tracks fail count.

### Fork 2 — Batch interface: **auto-detect longest common prefix; fallback to sequential when prefix < 3 chars**
Wrapper computes the LCP of item names in `EXPORTS`. If ≥ 3 chars, single `bw list items --search <prefix>` round-trip + jq filter per item (delivers BC-6905 Q3's 86% savings at N=7). If < 3 chars (divergent naming), per-item `bw get password`. Zero call-site change vs issue spec. Makes the mandated "divergent naming" test case meaningful (exercises the real fallback path, not a tautology). Contains privacy spread (only items matching the common prefix flow through wrapper memory; not the entire user-accessible vault).

### Fork 3 — Env-var fallback: **vault always wins; no escape hatch**
Forced by AC #10 ("rotate one Bitwarden value; the affected MCP picks up the new value WITHOUT Claude Code restart"). If the wrapper honored a pre-existing env var, rotation would not propagate without first unsetting that env. Stale `~/.zshrc` exports become harmless dead weight — `export KEY=val` overwrites them. Local-debug bypass is naturally accommodated by "don't invoke the wrapper" — no `--passthrough` flag needed (YAGNI; reintroduces hidden state).

### Fork 4 — setup-tam-map shape: **Shape 2 (3 top-level phases; Phase 2 sub-divided into 2a/2b)**
```
Phase 1 — Detect      (state probe: MCPs, vault, items, deps, auth)
Phase 2 — Unlock & bootstrap
  Step 2a [ONE-TIME]: bw login + npm install + pip install + admin-provisioning check
  Step 2b [PER-SESSION]: export BW_SESSION="$(bw unlock --raw)"
Phase 3 — Verify       (probes 6a/6b/6c verbatim per issue spec)
```
Mirrors the existing 6a/6b/6c sub-step convention so a reader who knew the old command can locate things in the new one. Issue spec's "≤3 phases" interpreted as ≤3 top-level headings; sub-divisions are fine (the original Phase 6 had three).

## Wrapper contract (`plugins/marketing/scripts/bw-run.sh`)

**Usage:** `bw-run.sh KEY=item [KEY=item ...] -- cmd args...`

**Pre:** `BW_SESSION` exported in parent env, vault unlocked.

**Behavior:**
1. Preflight: assert `BW_SESSION` is set; assert `bw status` reports `unlocked` (use `jq -e '.status == "unlocked"'`, replacing the spike's fragile grep — adapt-list item 6).
2. Parse `KEY=item` args until `--` separator. Reject unexpected arg shapes with exit 2.
3. Compute longest common prefix of item names. If ≥ 3 chars: one `bw list items --search <prefix>` call, parse JSON, resolve each item by name. If < 3 chars: per-item `bw get password`.
4. Empty-array guard around the loop (BC-6905 task-2: macOS bash 3.2 + `set -u` rejects `"${arr[@]}"` for empty arrays).
5. `export KEY=value` for each resolved item.
6. `exec "$@"` — transparent stdio passthrough (BC-6905 Q4 verified).

**Exit codes:**
- `0` — wrapped command exit (via exec)
- `1` — `BW_SESSION` missing or vault locked
- `2` — usage error (bad arg shape, missing `--` separator)
- `3` — `bw get password` or batch-resolve failed for one of the items

**Out of scope (deliberately):**
- Pattern C (`${user_config.*}` substitution into stdio MCP env) — BC-5947 task-3 still open; not unblocked by this issue.
- 8th key (`ANTHROPIC_API_KEY`) elimination — BC-6907.

## Test surface (`plugins/marketing/scripts/bw-run.test.sh`)

Four mandated cases (per AC #1):
1. **Locked vault** — `bw status` returns `{"status":"locked"}` → wrapper exits 1, exec blocked, stderr names remediation.
2. **Missing item** — batch returns `[]` (or per-item `bw get password` fails) → wrapper exits 3.
3. **Multi-key batch** — 3 items with shared prefix → 1 `bw list items --search` call (verified via stub call counter), all 3 keys exported correctly.
4. **Divergent naming** — 2 items with no common prefix ≥ 3 chars → wrapper falls back to sequential `bw get password` (verified via stub call counter).

Plus 1 baseline case: usage errors (missing `--`, bad arg shape) exit 2.

`bw` stub: PATH-mocked via `mktemp -d`; emits scripted JSON depending on argv. Stub records call count to `$STUB_CALL_LOG` so tests can assert batching vs sequential.

## `.mcp.json` rewrite

```json
{
  "mcpServers": {
    "salesforce": { /* unchanged — uses SFDX local auth, not env vars */ },
    "spider": {
      "type": "stdio",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh",
      "args": [
        "SPIDER_API_KEY=tam-map-spider-api-key",
        "--",
        "npx", "-y", "spider-cloud-mcp@2.1.1"
      ]
    },
    "aiark": {
      "type": "stdio",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh",
      "args": [
        "AIARK_API_KEY=tam-map-aiark-api-key",
        "--",
        "node", "${CLAUDE_PLUGIN_ROOT}/scripts/tam-map/aiark-mcp.js"
      ]
    },
    "discolike": {
      "type": "stdio",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh",
      "args": [
        "DISCOLIKE_API_KEY=tam-map-discolike-api-key",
        "--",
        "node", "${CLAUDE_PLUGIN_ROOT}/scripts/tam-map/discolike-mcp.js"
      ]
    }
  }
}
```

Drops the `env` block (wrapper fills env). Each MCP's command is now the wrapper; the original command becomes the wrapped target after `--`.

## CLI invocation rewrites (skills)

Audit found 8 invocation sites across 2 skills:

**`plugins/marketing/skills/tam-mapping/SKILL.md`** — 5 sites at L198, L201, L299, L339, L459.
**`plugins/marketing/skills/list-building/SKILL.md`** — 4 sites at L140, L141, L229, L237.

Pattern: each `Bash` → `python plugins/marketing/scripts/tam-map/<script>.py ...` becomes `Bash` → `plugins/marketing/scripts/bw-run.sh KEY=item -- python plugins/marketing/scripts/tam-map/<script>.py ...`.

Per-script env-var mapping:
- `icypeas_client.py` → `ICYPEAS_API_KEY=tam-map-icypeas-api-key`
- `spider_crawl.py` → `SPIDER_API_KEY=tam-map-spider-api-key`
- `enrich_waterfall.py` → `BLITZAPI_KEY=tam-map-blitzapi-key PROSPEO_API_KEY=tam-map-prospeo-api-key`
- `verify_smtp.py` → `MILLIONVERIFIER_API_KEY=tam-map-millionverifier-api-key`
- `tier_and_segment.py` → unchanged (uses ANTHROPIC_API_KEY; BC-6907 separately replaces the script with an in-session skill).

## Documentation deltas

- **`plugins/marketing/scripts/tam-map/README.md`** (NEW): canonical CLI invocation pattern using `bw-run.sh` for the 4 (later 5) scripts; per-script key list.
- **`CONTRIBUTING.md`** (NEW section "Plugin secret-config canon"): bw-run.sh as reference implementation; how to adopt in a new plugin (one bullet: copy the script + write a `bw-run.test.sh` mirroring the pattern); link to BC-5551 gotcha for stdio vs HTTP-headers framing.
- **`CLAUDE.md`** BC-5551 gotcha (line 93 parenthetical): rewrite from "broken, ship user-level reg" to "broken for HTTP MCP headers; for stdio MCPs the recommended pattern is OS env-vars filled by `bw-run.sh` (see CONTRIBUTING.md § Plugin secret-config canon)."

## Version bump (BC-6000 same-commit rule)

`plugins/marketing/.claude-plugin/plugin.json`: 0.3.28 → 0.3.29
`.claude-plugin/marketplace.json` (marketing entry): 0.3.28 → 0.3.29

## Acceptance gate (issue AC mapping)

| AC | Vehicle |
|----|---------|
| #1 ≥4 unit tests passing | `bw-run.test.sh` runs locally; CI green |
| #2 3 MCPs wrapped | `.mcp.json` diff shows wrapper substitution |
| #3 4 CLI invocations updated | Grep for `bw-run.sh` in 2 SKILL.md files |
| #4 setup ≤3 phases | `grep -c '^## Phase'` ≤ 3 |
| #5 zero `~/.zshrc` refs | `grep -c '~/\.zshrc'` == 0 in setup-tam-map.md |
| #6 zero "restart Claude Code" refs | grep ditto |
| #7 CLAUDE.md gotcha rewritten | Line 93 reframed |
| #8 CONTRIBUTING.md section added | grep for "Plugin secret-config canon" |
| #9 version bump in both files | `git log -p plugins/marketing/.claude-plugin/plugin.json .claude-plugin/marketplace.json` |
| #10 fresh-machine smoke test | Manual: simulate fresh dev (no `~/.zshrc` exports + fresh `bw unlock`) → run `/marketing:setup-tam-map` end-to-end |
| #11 rotation smoke test | **Measured 2026-05-10:** MCP server processes are persistent for the Claude Code session — tool calls reuse the running process and its in-memory env. `/reload-plugins` reloads plugin metadata only; it does NOT re-spawn MCP server processes. Rotation propagates only on a real MCP-process re-spawn (full Claude Code re-launch, or per-server `claude mcp restart` if available). The wrapper-side rotation works (BC-6905 Q6); the lifecycle-side gap is upstream-Claude-Code behavior, not in BC-6906 scope. AC #11 as originally worded ("MCP re-spawn behavior is sufficient — no Claude Code restart") is NOT met; CONTRIBUTING.md and setup-tam-map.md updated to document the actual remediation (re-launch). Net story still better than pre-wrapper world (which required `~/.zshrc` edits AND re-launch). |
| #12 `/workflows:review` clean | Run after build |
| #13 `/workflows:ship` clean | Run after review |

## Risks & open questions

- **Lifecycle-side rotation** (BC-6905 adapt-list item 3, MEASURED in T14): MCP processes persist for the Claude Code session and `/reload-plugins` does NOT re-spawn them. Rotation propagates only via full Claude Code re-launch (or, if available, `claude mcp restart <name>`). This is upstream Claude Code behavior, not a wrapper limitation. Documented in CONTRIBUTING.md § Plugin secret-config canon and setup-tam-map.md. Future improvement: investigate `claude mcp restart` semantics across versions; if it exists and re-spawns cleanly, it becomes the preferred remediation.
- **Bitwarden item provisioning is admin-gated.** The setup command can detect missing items but cannot fix them (collection-write requires admin). Phase 2a halts with a "ask Brite admin" message if items are missing.
- **`jq` dependency** is now load-bearing (preflight check + batch parsing). The spike used jq via `measure.sh`; production wrapper makes it required. Phase 1 (detect) verifies `command -v jq` and halts with `brew install jq` remediation if missing. Add to acceptance criteria internally.
- **Batch search prefix ambiguity.** If two items share an LCP that also matches an unrelated vault item, the JSON includes the unrelated item; jq filter ignores it. Safe but slightly wasteful. Comment explains.
