---
description: Guided setup for the tam-map pipeline (Spider.cloud + AI Ark + Discolike MCPs + IcyPeas/BlitzAPI/Prospeo/MillionVerifier CLI scripts). Three phases — Detect, Unlock & bootstrap, Verify — no shell-profile edits required. The 7 third-party API keys live in Bitwarden (Engineering collection) and are fetched at every MCP-process spawn by `plugins/marketing/scripts/bw-run.sh`. Vault is the single source of truth; rotated values propagate at the next MCP-process spawn (re-launch Claude Code — `/reload-plugins` only reloads plugin metadata, not MCP server processes; measured BC-6906 T14). Use when tam-mapping tools are missing, a skill errors with "tool not found" for spider/aiark/discolike, or on first-time tam-map onboarding.
allowed-tools: Bash, Read, AskUserQuestion
---

# /marketing:setup-tam-map

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered checkpoint so the user explicitly acknowledges each step before moving on. If they answer anything other than the "proceed" option, halt and help with their blocker before re-asking.

Seven third-party API keys total: `SPIDER_API_KEY`, `AIARK_API_KEY`, `DISCOLIKE_API_KEY`, `ICYPEAS_API_KEY`, `BLITZAPI_KEY`, `PROSPEO_API_KEY`, `MILLIONVERIFIER_API_KEY`. Three MCPs are plugin-scoped: `spider`, `aiark`, `discolike`. Four other providers (IcyPeas, BlitzAPI, Prospeo, MillionVerifier) are CLI-only — they ship as Python scripts under `plugins/marketing/scripts/tam-map/`.

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

# Node deps — check BOTH dev-mode (repo-relative) and prod-mode (latest marketplace clone).
# The plugin auto-updater publishes a FRESH clone (without node_modules) when the version
# bumps. The OLD version's clone is left on disk with its deps intact, so a naive `*` glob
# would false-positive against the stale prior-version directory. Target the latest version
# by mtime (`ls -td`) — auto-update is by definition the newest directory.
MKT_LATEST="$(ls -td ~/.claude/plugins/cache/brite-claude-plugins/marketing/*/scripts/tam-map 2>/dev/null | head -1)"
if [ -f plugins/marketing/scripts/tam-map/node_modules/@modelcontextprotocol/sdk/package.json ]; then
  echo "npm=set (repo-relative)"
elif [ -n "$MKT_LATEST" ] && [ -f "$MKT_LATEST/node_modules/@modelcontextprotocol/sdk/package.json" ]; then
  echo "npm=set (marketplace clone — $MKT_LATEST)"
else
  echo "npm=MISSING"
fi

# Python deps — same dual-path probe against the latest marketplace clone.
if python3 -c "import requests, aiohttp, dotenv" 2>/dev/null; then
  echo "pip=set (system)"
elif [ -n "$MKT_LATEST" ] && [ -d "$MKT_LATEST/.venv" ]; then
  echo "pip=set (marketplace venv — $MKT_LATEST)"
elif [ -d plugins/marketing/scripts/tam-map/.venv ]; then
  echo "pip=set (repo venv)"
else
  echo "pip=MISSING"
fi
```

Interpret the output and route:

- `bw=MISSING` or `jq=MISSING` or `npm=MISSING` or `pip=MISSING` → go to **Phase 2, Step 2a** (one-time bootstrap).
- `vault=unauthenticated` → go to **Phase 2, Step 2a** (need `bw login`).
- `vault=locked` or `session=MISSING` → go to **Phase 2, Step 2b** (per-session unlock).
- If `vault=unlocked` + `session=set`, skip Step 2b — only Step 2a (one-time bootstrap, if any one-time gap exists) and Phase 3 (verify) remain.
- All green (`bw`, `jq`, `npm`, `pip`, `vault=unlocked`, `session=set`, all three MCPs `✓ Connected`) → jump to **Phase 3 — Verify**.
  - Bitwarden item provisioning (the 7 `tam-map-*` items) is checked only in Phase 2a's admin-provisioning step on first-time onboarding; the count probe is deferred to save a 3.2s `bw list items --search` round-trip on already-onboarded machines.
  - If Phase 3 verify shows MCPs failing to connect, the most likely cause is missing Bitwarden items — re-route to Phase 2a's admin-provisioning check.

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

**3. Install Node deps for the 2 stdio wrappers** (skip if Phase 1 showed `npm=set`).

If you are working in this repo as a developer:

```bash
(cd plugins/marketing/scripts/tam-map && npm install)
```

If you are running from the production marketplace clone (the common non-dev case — Phase 1 reports `npm=MISSING` against the marketplace clone path; same `MKT_LATEST` resolution as Phase 1):

```bash
MKT_LATEST="$(ls -td ~/.claude/plugins/cache/brite-claude-plugins/marketing/*/scripts/tam-map 2>/dev/null | head -1)"
(cd "$MKT_LATEST" && npm install)
```

**4. Install Python deps for the 5 CLI scripts** (skip if Phase 1 showed `pip=set`). Recommended: a venv.

Dev mode (this repo):

```bash
python3 -m venv plugins/marketing/scripts/tam-map/.venv
source plugins/marketing/scripts/tam-map/.venv/bin/activate
python3 -m pip install -r plugins/marketing/scripts/tam-map/requirements.txt
```

Prod mode (marketplace clone — same shape, just a different cwd; same `MKT_LATEST` resolution as Phase 1):

```bash
MKT_LATEST="$(ls -td ~/.claude/plugins/cache/brite-claude-plugins/marketing/*/scripts/tam-map 2>/dev/null | head -1)"
python3 -m venv "$MKT_LATEST/.venv"
source "$MKT_LATEST/.venv/bin/activate"
python3 -m pip install -r "$MKT_LATEST/requirements.txt"
```

Or without a venv (either mode):

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

After Phase 2 (or directly from Phase 1 if state was already green), run the checks below. Phase 3 covers all **7 providers** across **two correctness sub-boards** — **3b** (the 3 MCP providers: spider / aiark / discolike) and **3d** (the 4 CLI providers: blitzapi / prospeo / millionverifier / icypeas) — with **3a** (MCP connect) and **3c** (`--help`) as **liveness** pre-checks. **Run every check and report the full per-provider board — do not short-circuit on the first failure.**

The verdict has **three** states (a broken provider is *never* reported green):

- **GREEN** — every provider authenticated **and** returned usable, filter-respecting data.
- **⚠ DEGRADED (known)** — the only failures carry a `[known: BC-####]` tag: a drift already scoped for repair, zero surprise regressions. Not green, but not a setup error.
- **✗ RED** — at least one **untracked** failure (a `✗` with no `[known:]` tag): a surprise regression — stop and investigate.

Phase 3d computes this verdict automatically — the `[known: BC-####]` annotation is what drives the ⚠ amber state (it separates a drift already scoped for repair from a surprise regression). Phase 3b is a by-eye PASS/FAIL board with no tagged-known breaks today, so treat any 3b failure as a surprise ✗ to investigate.

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

### Phase 3b — MCP tool probe (auth + correctness)

> **Liveness vs correctness.** Phase 3a (`✓ Connected`) and Phase 3c (`--help`) prove **liveness** — the process starts and the credential authenticates. They do **not** prove **correctness** — that a real request returns real, *filtered* data. A connectivity-only probe is exactly why BC-7011's smoke went green while `aiark_search` filtering was silently 400ing (deferred to and fixed in BC-7157), and why a dead vendor endpoint passed `--help` while returning 404s (BlitzAPI, BC-12128). The probes below assert **correctness**: green means "authenticated AND returned usable, filter-respecting data."

For each connected MCP, call a tool that exercises a **real, filtered** request:

- `spider`: call `spider_get_credits` — returns the API credit balance (auth round-trip, costs nothing).
- `aiark`: call `aiark_search` with a **real filter** — `{"industries": ["software development"], "limit": 3}`.
  - **PASS** only if it returns ≥1 company whose `summary.industry` relates to the filter (contains "software") **and the first result is NOT the global default "Tata Group"**.
  - **FAIL (loud)** if the results are unfiltered (first result is "Tata Group", or `totalElements` is ≈ the whole database): the `account` filter sub-schema has regressed — see BC-7157. A bare `{"limit": 1}` / empty-query probe returns the unfiltered default and **must not** be used here — that connectivity-only gap is exactly what this check closes.
  - Second probe: `aiark_similarity` with `{"seed_domains": ["stripe.com"], "limit": 1}` → must return ≥1 record.
- `discolike`: call `discolike_search` with a 1-result seed → must return ≥1 record.

If any errors with `401` / `403` / `Invalid API key`, the Bitwarden item value is wrong. Update it in Bitwarden, then re-launch Claude Code so the affected MCP server re-spawns through `bw-run.sh` with the corrected value (`/reload-plugins` reloads plugin metadata only — it does NOT re-spawn MCP server processes; measured BC-6906 T14). Re-run `/marketing:setup-tam-map`'s Phase 3 to verify. If a probe **authenticates (no 401/403) but returns the unfiltered default or empty data**, that is a request-shape/endpoint drift in the wrapper — file + repair it (the BC-7157 / BC-12128 fixes are the model) rather than treating the run as green.

### Phase 3c — CLI script check (liveness only)

The other four providers ship as Python scripts. Check they parse `--help`:

```bash
for s in icypeas_client.py spider_crawl.py enrich_waterfall.py verify_smtp.py; do
  python3 plugins/marketing/scripts/tam-map/$s --help >/dev/null 2>&1 && echo "✓ $s" || echo "✗ $s"
done
```

All four must print `✓`. The `--help` smoke catches **import-time failures only**: missing Python deps, syntax errors, broken argparse setup. It does NOT catch missing env vars, a dead vendor endpoint, or a drifted request shape — `argparse` runs before the script body's `os.getenv()` / HTTP calls, so a script (and its key) can pass `--help` cleanly and still 404 or 400 at real invocation. **Phase 3d** below closes that gap with a real, credential-authenticated round-trip per CLI provider.

If any of the 4 `--help` checks fails:

- Missing Python deps → `python3 -m pip install -r plugins/marketing/scripts/tam-map/requirements.txt`.
- Script-level error → open the script, read the error message; the wrappers ship verbatim from upstream tam-map@`9f5c72e74b` so a runtime error likely means an upstream bug.

If a script's `--help` passes but a real invocation fails with a missing-env-var error, re-check that the corresponding Bitwarden item exists with a non-empty value (re-run Phase 2a's admin-provisioning check), then re-launch Claude Code so the wrapper picks up the corrected value on the next spawn.

### Phase 3d — CLI live round-trip (correctness)

`--help` (Phase 3c) runs before any `os.getenv()` / HTTP call, so it cannot catch an empty/bad key, a dead vendor endpoint, or a drifted request shape (the BlitzAPI BC-12128 class). This step exercises each CLI provider's key **past `argparse`** against a cheap surface and asserts a **non-auth-error, non-empty** response. **The depth differs by provider, by design:**

- **blitzapi** (`domain-to-linkedin`) and **icypeas** (`find-companies`) are probed on their **real enrichment surfaces** — green proves the **current request-shape still works** (request-shape correctness — the probe confirms the endpoint accepts the request and returns its expected envelope, not that the data is non-empty; these two are the ones that actually drift).
- **prospeo** (`account-information`) and **millionverifier** (`/credits`) are probed on cheap **auth/account side-surfaces** — green proves only that the **key authenticates and the account is reachable** (liveness++), **not** that their real enrichment/verify request-shape is intact. This is deliberate: those two aren't drifting, and a credit-free re-runnable smoke is an explicit design goal (cost note below). If either ever drifts, promote its probe to a real surface then — the way blitzapi/icypeas earned theirs.

Run via `bw-run.sh` (one invocation, all four keys):

```bash
plugins/marketing/scripts/bw-run.sh \
  BLITZAPI_KEY=tam-map-blitzapi-key \
  PROSPEO_API_KEY=tam-map-prospeo-api-key \
  MILLIONVERIFIER_API_KEY=tam-map-millionverifier-api-key \
  ICYPEAS_API_KEY=tam-map-icypeas-api-key \
  -- bash -c '
set -uo pipefail
pass=0; fail=0; known=0
# A label carrying a [known: BC-####] tag is a drift already scoped for repair:
# count it amber (known), never a surprise red. The glob must match the tag mid-string.
say(){
  case "$1" in *"[known:"*) kn=1 ;; *) kn=0 ;; esac
  if   [ "$2" = 1 ]; then echo "  ✓ $1"; pass=$((pass+1))
  elif [ "$kn" = 1 ]; then echo "  ⚠ $1  <-- known break (tracked)"; known=$((known+1))
  else echo "  ✗ $1  <-- FAIL (surprise)"; fail=$((fail+1)); fi
}

# BlitzAPI — real enrichment family (catches a dead endpoint; ~1 credit)
b=$(curl -s -m 25 -H "x-api-key: $BLITZAPI_KEY" -H "Content-Type: application/json" \
    -X POST https://api.blitz-api.ai/v2/enrichment/domain-to-linkedin -d "{\"domain\":\"stripe.com\"}")
say "blitzapi  (domain-to-linkedin returns a result object)" "$(printf "%s" "$b" | jq -e "has(\"found\")" >/dev/null 2>&1 && echo 1 || echo 0)"

# Prospeo — account-information (cheap auth surface)
p=$(curl -s -m 25 -H "X-KEY: $PROSPEO_API_KEY" -H "Content-Type: application/json" \
    -X POST https://api.prospeo.io/account-information -d "{}")
say "prospeo   (account-information error==false)" "$(printf "%s" "$p" | jq -e ".error==false" >/dev/null 2>&1 && echo 1 || echo 0)"

# MillionVerifier — /credits (zero-cost)
m=$(curl -s -m 25 "https://api.millionverifier.com/api/v3/credits?api=$MILLIONVERIFIER_API_KEY")
say "millionverifier (credits is a number)" "$(printf "%s" "$m" | jq -e "(.credits|type)==\"number\"" >/dev/null 2>&1 && echo 1 || echo 0)"

# IcyPeas — real find-companies search (catches request-shape drift)
i=$(curl -s -m 30 -H "Authorization: $ICYPEAS_API_KEY" -H "Content-Type: application/json" \
    -X POST https://app.icypeas.com/api/find-companies -d "{\"keywords\":\"software\",\"locations\":[],\"limit\":1}")
say "icypeas   (find-companies success==true) [known: BC-12163]" "$(printf "%s" "$i" | jq -e ".success==true" >/dev/null 2>&1 && echo 1 || echo 0)"

echo "  --- $pass pass, $fail surprise-fail, $known known-break ---"
if [ "$fail" = 0 ] && [ "$known" = 0 ]; then
  echo "  OVERALL: GREEN — every CLI provider authenticated AND returned usable data"
elif [ "$fail" = 0 ]; then
  echo "  OVERALL: ⚠ DEGRADED (known) — $known tracked in-flight break(s), 0 surprises. NOT green, but not a setup error: each ⚠ above carries a [known: BC-####] tag for a drift already scoped for repair. Re-run once that issue lands."
else
  echo "  OVERALL: ✗ RED — $fail untracked break(s): a surprise regression. STOP & investigate — the provider authenticates (no 401/403) but returns no usable data (endpoint / request-shape drift; cf. the BC-7157 + BC-12128 fixes). Repair before relying on tam-map enrichment; do not treat this run as green."
  if [ "$known" -gt 0 ]; then echo "           (also $known known break(s) marked ⚠ above — those are tracked, not the surprise.)"; fi
fi
'
```

The script runs **all four** providers and reports a full board (no short-circuit). A `✗` (surprise) is a **correctness** failure, not a missing-key problem: the provider authenticated (no 401/403) but its endpoint or request shape drifted — the exact silent-failure class BC-7157 (aiark) and BC-12128 (BlitzAPI) fixed. A `⚠` is the **same kind of break but already tracked** under a `[known: BC-####]` tag (amber, not a surprise). Repair (or wait out) the wrapper and re-run; **do not proceed on a `✗`.** (A transient vendor outage or an `-m` timeout also surfaces as `✗` with an empty body on an untagged provider — re-run once before concluding a request-shape drift. Caveat: on a `[known:]`-tagged provider *any* failure, including an outage, shows as `⚠`, so re-run there too to tell a real outage from the tracked break.)

(The four surfaces are deliberately cheap: MillionVerifier `/credits` and Prospeo `account-information` cost nothing; BlitzAPI `domain-to-linkedin` and IcyPeas `find-companies?limit=1` cost ~1 credit each. This keeps the smoke re-runnable without burning the per-key credit budget. Note: all four keys are expanded inside the inner `bash -c`, so the plaintext never enters your shell history — but the resolved value does sit in the `curl` process arguments (visible via `ps` / `/proc` / command-line audit logs) for the duration of each call, so treat the probe command as sensitive. MillionVerifier additionally rides its key in the URL query string (`?api=…`, vendor-mandated; the other three use a header), so it can also reach network/proxy access logs — the header-based three do not.)

> **Known in-flight (2026-06-01):** the `icypeas` probe currently reports `⚠ [known: BC-12163]` — IcyPeas redesigned `find-companies` to require a `query` object, but the wrapper still sends the flat `{keywords, locations, limit}` shape and gets `200` + `success:false` / `EmptyQueryError`. With the other six providers green and this the only break, Phase 3d's OVERALL reads **⚠ DEGRADED (known)**, not RED — the smoke working as intended (surfacing a real "200-but-no-usable-data" drift the old `--help`-only check missed, and flagging it as *tracked* rather than a surprise), not a setup error. The fix is scoped in **BC-12163**; once it lands the icypeas line flips to `✓` and OVERALL to GREEN — drop the `[known: BC-12163]` annotation then.

---

## Troubleshooting

### After a plugin auto-update — re-run setup

Claude Code's plugin auto-updater publishes a fresh marketplace clone whenever a new `marketing` plugin version ships (e.g., `~/.claude/plugins/cache/brite-claude-plugins/marketing/0.3.29/` flips to `0.3.30/`). The new clone arrives **WITHOUT** `node_modules/` AND WITHOUT `.venv/`, even if you installed them in the prior version's directory or in a dev worktree. Symptoms:

- `aiark` or `discolike` MCPs report `✗ Failed to connect` with `Error [ERR_MODULE_NOT_FOUND]: Cannot find package '@modelcontextprotocol/sdk'`.
- Python CLI scripts (`icypeas_client.py`, `spider_crawl.py`, `enrich_waterfall.py`, `verify_smtp.py`) fail with `ModuleNotFoundError` for `requests` / `aiohttp` / `dotenv`.

If you see either symptom after no intentional config change, this is almost always the cause.

**Remedy:** re-run `/marketing:setup-tam-map`. Phase 1's dual-path probes will detect `npm=MISSING` and/or `pip=MISSING` against the new marketplace clone path and route you to Step 2a's marketplace-clone install commands. Phase 1's worktree-relative paths stay green for dev mode; the new probes cover prod mode.

(Bitwarden items themselves live in the Engineering vault and are unaffected by auto-update — you do NOT need to re-run Phase 2a's admin-provisioning check unless `bw list items --search tam-map-` returns fewer than 7 rows.)

(Spider's MCP stays connected through auto-updates because `npx -y spider-cloud-mcp` resolves via npx's global cache, not local `node_modules/`. Aiark/discolike are local Node wrappers, hence the divergence.)

---

tam-map is set up. The wrapper `plugins/marketing/scripts/bw-run.sh` fetches values from Bitwarden at every MCP-process spawn. Two scenarios to be aware of:

- **Vault lock mid-session** (~30s recovery): re-run `export BW_SESSION="$(bw unlock --raw)"` in your launching shell, then re-launch Claude Code.
- **Rotated Bitwarden value**: the running MCP holds the value it was spawned with; tool calls reuse the same process. To pick up the new value, re-launch Claude Code (`/reload-plugins` reloads plugin metadata only; it does NOT re-spawn MCP server processes — measured BC-6906 T14). Per-server `claude mcp restart <name>` may exist in newer Claude Code versions; check `claude mcp --help`.

See `plugins/marketing/scripts/tam-map/README.md` for the canonical CLI invocation pattern, and `CONTRIBUTING.md § Plugin secret-config canon` for the wrapper's broader rationale.
