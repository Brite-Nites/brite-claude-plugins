---
description: Guided setup for the tam-map pipeline (Spider.cloud + AI Ark + Discolike MCPs + IcyPeas/BlitzAPI/Prospeo/MillionVerifier CLI scripts). Three phases — Detect, Unlock & bootstrap, Verify — no shell-profile edits required. The 7 third-party API keys live in Bitwarden (Engineering collection) and are fetched at every MCP-process spawn by `plugins/marketing/scripts/bw-run.sh`. Vault is the single source of truth; rotated values propagate at the next MCP-process spawn (re-launch Claude Code — `/reload-plugins` only reloads plugin metadata, not MCP server processes; measured BC-6906 T14). Use when tam-mapping tools are missing, a skill errors with "tool not found" for spider/aiark/discolike, or on first-time tam-map onboarding.
allowed-tools: Bash, Read, AskUserQuestion
---

# /marketing:setup-tam-map

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered checkpoint so the user explicitly acknowledges each step before moving on. If they answer anything other than the "proceed" option, halt and help with their blocker before re-asking.

Seven third-party API keys total: `SPIDER_API_KEY`, `AIARK_API_KEY`, `DISCOLIKE_API_KEY`, `ICYPEAS_API_KEY`, `BLITZAPI_KEY`, `PROSPEO_API_KEY`, `MILLIONVERIFIER_API_KEY`. Three MCPs are plugin-scoped: `spider`, `aiark`, `discolike`. Four other providers (IcyPeas, BlitzAPI, Prospeo, MillionVerifier) are CLI-only — they ship as Python scripts under `plugins/marketing/scripts/tam-map/`. (Note: `ANTHROPIC_API_KEY` previously belonged to this set; its elimination is tracked separately as BC-6907 and is not managed by this command.)

Pattern: plugin-scoped stdio MCPs + Bitwarden-backed credential broker (`plugins/marketing/scripts/bw-run.sh`). The wrapper resolves each `KEY=tam-map-<item>` argument against the Engineering vault at every spawn and `exec`s the wrapped command. Vault is the single source of truth — rotated values reach a running MCP only on its next process spawn, which currently means re-launching Claude Code (`/reload-plugins` reloads plugin metadata but does NOT re-spawn MCP server processes; measured BC-6906 T14). Pre-req: `BW_SESSION` exported in the shell that launches Claude Code. For background see `docs/research/tam-map-port-policy.md` § 1, `docs/designs/BC-6906-bw-run-prod-migration.md`, and `CONTRIBUTING.md § Plugin secret-config canon`.

---

## Phase 1 — Detect

Probe state, then route to the next phase based on what's missing. Run all checks in one block and parse the output:

```bash
# Dependencies
command -v bw >/dev/null && echo "bw=set" || echo "bw=MISSING"
command -v jq >/dev/null && echo "jq=set" || echo "jq=MISSING"

# Vault state (unauthenticated | locked | unlocked | MISSING)
if command -v bw >/dev/null; then
  bw status 2>/dev/null | jq -r '"vault=" + .status' 2>/dev/null || echo "vault=MISSING"
else
  echo "vault=MISSING"
fi

# Session token
[ -n "${BW_SESSION:-}" ] && echo "session=set" || echo "session=MISSING"

# MCP registration state
claude mcp list 2>&1 | grep -E "spider|aiark|discolike" || echo "mcps=NONE_REGISTERED"

# Node deps
[ -f plugins/marketing/scripts/tam-map/node_modules/@modelcontextprotocol/sdk/package.json ] \
  && echo "npm=set" || echo "npm=MISSING"

# Python deps
python3 -c "import requests, aiohttp, dotenv" 2>/dev/null \
  && echo "pip=set" || echo "pip=MISSING"
```

Interpret the output and route:

- `bw=MISSING` or `jq=MISSING` or `npm=MISSING` or `pip=MISSING` → go to **Phase 2, Step 2a** (one-time bootstrap).
- `vault=unauthenticated` → go to **Phase 2, Step 2a** (need `bw login`).
- `vault=locked` or `session=MISSING` → go to **Phase 2, Step 2b** (per-session unlock).
- All green (`bw`, `jq`, `npm`, `pip`, `vault=unlocked`, `session=set`, all three MCPs `✓ Connected`) → jump to **Phase 3 — Verify**. Bitwarden item provisioning (the 7 `tam-map-*` items) is checked as part of Phase 2a's admin-provisioning step on first-time onboarding; on subsequent runs the count probe is skipped (saves a 3.2s `bw list items --search` round-trip every time the command runs on an already-onboarded machine). If Phase 3 verify shows MCPs failing to connect, the most likely cause is missing Bitwarden items — re-route to Phase 2a's admin-provisioning check.

If multiple categories are red, run Step 2a first, then Step 2b, then Phase 3.

## Phase 2 — Unlock & bootstrap

Two sub-steps. Skip Step 2a entirely if the Phase 1 probe shows everything one-time is already in place; you only need it on first-time onboarding (or after a Bitwarden vault provisioning change).

### Step 2a [ONE-TIME, skip if done]

Tell the user: "Run these one-time commands in a terminal outside Claude Code. Skip any block whose check in Phase 1 already showed green."

**1. Install Bitwarden CLI and jq** (skip if Phase 1 showed `bw=set` and `jq=set`):

```bash
brew install bitwarden-cli jq
```

**2. Authenticate with Bitwarden** (skip if Phase 1 showed `vault=locked` or `vault=unlocked` — `bw login` is only needed when status is `unauthenticated`):

```bash
bw login
```

**3. Install Node deps for the 2 stdio wrappers** (skip if Phase 1 showed `npm=set`):

```bash
(cd plugins/marketing/scripts/tam-map && npm install)
```

**4. Install Python deps for the 5 CLI scripts** (skip if Phase 1 showed `pip=set`). Recommended: a venv:

```bash
python3 -m venv plugins/marketing/scripts/tam-map/.venv
source plugins/marketing/scripts/tam-map/.venv/bin/activate
python3 -m pip install -r plugins/marketing/scripts/tam-map/requirements.txt
```

Or without a venv:

```bash
python3 -m pip install -r plugins/marketing/scripts/tam-map/requirements.txt
```

Ask via `AskUserQuestion`:
- Question: "Dependencies installed and `bw login` complete?"
- Options: "Yes" / "Errors — need help"

If "Errors — need help" → halt and triage. Common causes: outdated `npm` (`npm install -g npm@latest` and retry), outdated `pip` (`python3 -m pip install --upgrade pip`), Python older than 3.10 (upstream verified against 3.11+), or Homebrew not on PATH.

**Admin-provisioning check.** The 7 expected Bitwarden items in the Engineering collection are:

- `tam-map-spider-api-key`
- `tam-map-aiark-api-key`
- `tam-map-discolike-api-key`
- `tam-map-icypeas-api-key`
- `tam-map-blitzapi-key`
- `tam-map-prospeo-api-key`
- `tam-map-millionverifier-api-key`

Each must exist with a non-empty value in its login.password field. Probe the count automatically (only runs here, not in Phase 1's happy path):

```bash
items=$(bw list items --search tam-map- 2>/dev/null | jq 'length')
echo "items=$items"
```

If `items < 7`, the count below 7 directly identifies missing provisioning. Halt with: "Reach out to your Brite admin for provisioning. The 7 expected items are listed above. Re-run `/marketing:setup-tam-map` after provisioning." Exit.

If `items >= 7`, the count is sufficient — proceed to Step 2b (or Phase 3 if Step 2b is already satisfied).

### Step 2b [PER-SESSION]

Tell the user: "Open a fresh terminal *outside* Claude Code and run:

```bash
export BW_SESSION=\"$(bw unlock --raw)\"
```

Answer the prompt with your Bitwarden master password. Then launch Claude Code from that same shell so it inherits `BW_SESSION`. The wrapper `plugins/marketing/scripts/bw-run.sh` reads `BW_SESSION` at every MCP/CLI spawn; without it, every MCP will fail to authenticate."

Ask via `AskUserQuestion`:
- Question: "Did Claude Code launch from a shell where you exported `BW_SESSION`?"
- Options: "Yes" / "No, need to retry"

If "No, need to retry" → halt with: "Quit Claude Code, return to your terminal, run `export BW_SESSION=\"$(bw unlock --raw)\"`, then re-launch Claude Code from that same shell. Re-run `/marketing:setup-tam-map` once Claude Code is back up."

## Phase 3 — Verify

After Phase 2 (or directly from Phase 1 if state was already green), run three checks.

### Phase 3a — MCP connection check

```bash
claude mcp list 2>&1 | grep -E "spider|aiark|discolike"
```

Branching:

- All three show `✓ Connected` → continue to Phase 3b.
- Any show `✗ Failed to connect` → troubleshooting loop:
  1. Ask user to open a fresh terminal and run `for v in SPIDER_API_KEY AIARK_API_KEY DISCOLIKE_API_KEY; do printf "%s=%s\n" "$v" "${!v:+set}"; done` — expect `set` for all three.
  2. If any prints empty → `BW_SESSION` didn't reach the shell that launched Claude Code, or the wrapper couldn't resolve the item against the vault. Re-launch Claude Code from a shell where you exported `BW_SESSION` (Step 2b), then re-run Phase 3.
  3. If all `set` but Spider still fails → confirm the package is reachable: `npx -y spider-cloud-mcp --help` (network call to npm). If that errors, npm is the issue, not the key.
  4. If all `set` but `aiark` or `discolike` fail → those wrappers live at `plugins/marketing/scripts/tam-map/{aiark,discolike}-mcp.js`. Run the wrapper directly: `node plugins/marketing/scripts/tam-map/aiark-mcp.js` — it should print a stdio handshake or error to stderr if the key is bad. The wrappers were ported from upstream tam-map and carry an `!! VERIFY BEFORE USING !!` warning about endpoint paths; if you hit a 4xx error, the wrapper may need its endpoints updated against `docs.ai-ark.com/reference` (a Brite-known limitation tracked in the wrapper source).

### Phase 3b — MCP tool probe

For each connected MCP, call one cheap tool to confirm auth round-trips:

- `spider`: call `spider_get_credits` — returns the API credit balance, costs nothing.
- `aiark`: call `aiark_search` with a 1-result query (e.g., `{"query": "test", "limit": 1}`).
- `discolike`: call `discolike_search` with a 1-result seed.

If any errors with `401` / `403` / `Invalid API key`, the Bitwarden item value is wrong. Update it in Bitwarden, then re-launch Claude Code so the affected MCP server re-spawns through `bw-run.sh` with the corrected value (`/reload-plugins` reloads plugin metadata only — it does NOT re-spawn MCP server processes; measured BC-6906 T14). Re-run `/marketing:setup-tam-map`'s Phase 3 to verify.

### Phase 3c — CLI script check

The other four providers ship as Python scripts. Check they parse `--help`:

```bash
for s in icypeas_client.py spider_crawl.py enrich_waterfall.py verify_smtp.py tier_and_segment.py; do
  python3 plugins/marketing/scripts/tam-map/$s --help >/dev/null 2>&1 && echo "✓ $s" || echo "✗ $s"
done
```

All five must print `✓`. The `--help` smoke catches **import-time failures only**: missing Python deps, syntax errors, broken argparse setup. It does NOT catch missing env vars — `argparse` runs before the script body's `os.getenv()` lookups, so a script can pass `--help` cleanly and still fail at real invocation if its env var is missing or its Bitwarden item is empty. For end-to-end env-var coverage, either invoke each script via `bw-run.sh` against a one-shot test input or rely on Phase 3b's MCP tool probes (which exercise the full credential round-trip for spider/aiark/discolike).

If any of the 5 `--help` checks fails:

- Missing Python deps → `python3 -m pip install -r plugins/marketing/scripts/tam-map/requirements.txt`.
- Script-level error → open the script, read the error message; the wrappers ship verbatim from upstream tam-map@`9f5c72e74b` so a runtime error likely means an upstream bug.

If a script's `--help` passes but a real invocation fails with a missing-env-var error, re-check that the corresponding Bitwarden item exists with a non-empty value (re-run Phase 2a's admin-provisioning check), then re-launch Claude Code so the wrapper picks up the corrected value on the next spawn.

---

tam-map is set up. The wrapper `plugins/marketing/scripts/bw-run.sh` fetches values from Bitwarden at every MCP-process spawn. Two scenarios to be aware of:

- **Vault lock mid-session** (~30s recovery): re-run `export BW_SESSION="$(bw unlock --raw)"` in your launching shell, then re-launch Claude Code.
- **Rotated Bitwarden value**: the running MCP holds the value it was spawned with; tool calls reuse the same process. To pick up the new value, re-launch Claude Code (`/reload-plugins` reloads plugin metadata only; it does NOT re-spawn MCP server processes — measured BC-6906 T14). Per-server `claude mcp restart <name>` may exist in newer Claude Code versions; check `claude mcp --help`.

See `plugins/marketing/scripts/tam-map/README.md` for the canonical CLI invocation pattern, and `CONTRIBUTING.md § Plugin secret-config canon` for the wrapper's broader rationale.
