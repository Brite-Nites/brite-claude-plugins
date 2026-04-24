---
description: Guided setup for the tam-map pipeline (Spider.cloud + AI Ark + Discolike MCPs + IcyPeas/BlitzAPI/Prospeo/MillionVerifier CLI scripts). Detects current state, walks the developer through getting 8 API keys from Bitwarden, exports them in the shell profile, and verifies all 3 MCP servers connect + 5 CLI scripts pass --help. Use when tam-mapping tools are missing, a skill errors with "tool not found" for spider/aiark/discolike/, or on first-time tam-map onboarding.
allowed-tools: Bash, Read, AskUserQuestion
---

# /marketing:setup-tam-map

Execute the phases below sequentially. Use `AskUserQuestion` at each numbered checkpoint so the user explicitly acknowledges each step before moving on. If they answer anything other than the "proceed" option, halt and help with their blocker before re-asking.

Eight env vars total — seven third-party API keys plus `ANTHROPIC_API_KEY` (used by the `tier_and_segment.py` fit-scoring CLI script, not the MCPs). Three MCPs are plugin-scoped: `spider`, `aiark`, `discolike`. Four other providers (IcyPeas, BlitzAPI, Prospeo, MillionVerifier) are CLI-only — they ship as Python scripts under `plugins/marketing/scripts/tam-map/` and the env vars feed those scripts directly.

Pattern: plugin-scoped stdio + OS env-vars (no `userConfig` substitution). For background see `docs/research/tam-map-port-policy.md` § 1 and `memory/gotcha_http_mcp_substitution_broken.md`.

---

## Phase 1 — Detect current state

Run:

```bash
claude mcp list 2>&1 | grep -E "spider|aiark|discolike" || echo "NONE_REGISTERED"
```

Interpret the output:

- All three lines show `✓ Connected` → check env exports next: run `for v in SPIDER_API_KEY AIARK_API_KEY DISCOLIKE_API_KEY ICYPEAS_API_KEY BLITZAPI_KEY PROSPEO_API_KEY MILLIONVERIFIER_API_KEY ANTHROPIC_API_KEY; do printf "%s=%s\n" "$v" "${!v:+set}"; done`. If all eight print `set`, print `✓ tam-map is already set up on this machine.` and **exit**. If any are unset, jump to Phase 3 — only missing exports need fixing.
- `NONE_REGISTERED` → proceed to Phase 2 (full setup).
- One or two MCPs present, or any line shows `✗ Failed to connect` / `✗ Needs authentication` → proceed to Phase 2; mention at the start of Phase 2 that only the missing/broken side needs work, but walk through the steps for completeness.

## Phase 2 — Bitwarden access

Tell the user (paraphrase fine):

> You'll need eight API keys for tam-map. They live in the Engineering collection of Bitwarden, in an item called **tam-map — API tokens** (or the closest match — your Brite admin is the source of truth on the item name). Open your Bitwarden client and find that item — its Notes field has eight `export` lines ready to copy:
>
> - `SPIDER_API_KEY` — Spider.cloud (web crawl)
> - `AIARK_API_KEY` — AI Ark (company discovery)
> - `DISCOLIKE_API_KEY` — Discolike (lookalike expansion)
> - `ICYPEAS_API_KEY` — IcyPeas (email lookup)
> - `BLITZAPI_KEY` — BlitzAPI (owner discovery, unlimited credits but 5 req/s)
> - `PROSPEO_API_KEY` — Prospeo (email enrichment fallback)
> - `MILLIONVERIFIER_API_KEY` — MillionVerifier (SMTP verification)
> - `ANTHROPIC_API_KEY` — Anthropic (used by `tier_and_segment.py` fit-scoring; the MCPs do not need this one)

Ask via `AskUserQuestion`:
- Question: "Bitwarden item open and all eight tokens visible?"
- Options: "Yes, I see them" / "I don't have access" / "Item missing or incomplete"

If "I don't have access" → halt. Tell the user: *"Request Engineering-collection access from your Brite admin or IT, then re-run `/marketing:setup-tam-map`."* Exit.
If "Item missing or incomplete" → halt. Tell the user: *"Reach out in #marketing-eng so the missing tokens get added to Bitwarden, then re-run."* Exit.

## Phase 3 — Shell profile

Tell the user:

> Copy all eight `export` lines from the Bitwarden Notes field. Paste them into `~/.zshrc` (or `~/.bashrc` if you use bash). Save the file. Then either run `source ~/.zshrc` in a terminal *outside* Claude Code, or open a fresh terminal — env vars must propagate from the shell that launches Claude Code.

Ask:
- Question: "Exports pasted and shell re-sourced?"
- Options: "Yes" / "Not yet"

Wait for "Yes" before proceeding.

## Phase 4 — Reload plugins

Tell the user:

> Run `/reload-plugins` in Claude Code. If you just updated your shell profile, a full Claude Code restart is more reliable than `/reload-plugins` alone — the plugin loader needs to inherit the new env vars from the shell that launched Claude Code. The 3 MCPs (`spider`, `aiark`, `discolike`) are plugin-scoped at `plugins/marketing/.mcp.json` — they ship with the plugin, but stdio servers can't read env vars that didn't exist when Claude Code launched.

Ask:
- Question: "Plugins reloaded (or Claude Code restarted)?"
- Options: "Yes, done" / "Not yet"

Wait for "Yes" before proceeding.

## Phase 5 — Verify end-to-end

After the user confirms reload, run three checks.

### Phase 5a — MCP connection check

```bash
claude mcp list 2>&1 | grep -E "spider|aiark|discolike"
```

Branching:

- All three show `✓ Connected` → continue to Phase 5b.
- Any show `✗ Failed to connect` → troubleshooting loop:
  1. Ask user to open a fresh terminal and run `for v in SPIDER_API_KEY AIARK_API_KEY DISCOLIKE_API_KEY; do printf "%s=%s\n" "$v" "${!v:+set}"; done` — expect `set` for all three.
  2. If any prints empty → env var didn't reach the shell that launched Claude Code. Tell user to restart Claude Code fully (not just `/reload-plugins`) from the freshly-sourced shell, then re-run from Phase 5.
  3. If all `set` but Spider still fails → confirm the package is reachable: `npx -y spider-cloud-mcp --help` (network call to npm). If that errors, npm is the issue, not the key.
  4. If all `set` but `aiark` or `discolike` fail → those wrappers live at `plugins/marketing/scripts/tam-map/{aiark,discolike}-mcp.js`. Run the wrapper directly: `node plugins/marketing/scripts/tam-map/aiark-mcp.js` — it should print a stdio handshake or error to stderr if the key is bad. The wrappers were ported from upstream tam-map and carry an `!! VERIFY BEFORE USING !!` warning about endpoint paths; if you hit a 4xx error, the wrapper may need its endpoints updated against `docs.ai-ark.com/reference` (a Brite-known limitation tracked in the wrapper source).

### Phase 5b — MCP tool probe

For each connected MCP, call one cheap tool to confirm auth round-trips:

- `spider`: call `spider_get_credits` — returns the API credit balance, costs nothing.
- `aiark`: call `aiark_search` with a 1-result query (e.g., `{"query": "test", "limit": 1}`).
- `discolike`: call `discolike_search` with a 1-result seed.

If any errors with `401` / `403` / `Invalid API key`, the corresponding `*_API_KEY` is wrong — back to Bitwarden, double-check the value, update `~/.zshrc`, restart Claude Code, re-run from Phase 5.

### Phase 5c — CLI script check

The other four providers ship as Python scripts. Check they parse `--help`:

```bash
for s in icypeas_client.py spider_crawl.py enrich_waterfall.py verify_smtp.py tier_and_segment.py; do
  python3 plugins/marketing/scripts/tam-map/$s --help >/dev/null 2>&1 && echo "✓ $s" || echo "✗ $s"
done
```

All five must print `✓`. If any fails:

- Missing Python deps → `pip install -r plugins/marketing/scripts/tam-map/requirements.txt`.
- Missing env var → re-check the export in `~/.zshrc` and restart.
- Script-level error → open the script, read the error message; the wrappers ship verbatim from upstream tam-map@`9f5c72e74b` so a runtime error likely means an upstream bug.

## Phase 6 — Completion

Tell the user:

> tam-map is now set up. Three plugin-scoped MCPs (`spider`, `aiark`, `discolike`) and five CLI scripts are reachable. The pattern is plugin-scoped stdio + OS env-vars — your `~/.zshrc` is the source of truth for the eight keys. If you rotate any key, update `~/.zshrc` and restart Claude Code (a `/reload-plugins` is not always enough — env vars only propagate at process launch).
>
> Next step: invoke `/marketing:tam-map <vertical>` once BC-5832 (tam-mapping skill) ships, or call any of the CLI scripts directly. See `plugins/marketing/references/tam/UPSTREAM.md` for upstream attribution and `plugins/marketing/tools/integrations/{spider-cloud,ai-ark,discolike,icypeas,blitzapi,prospeo,millionverifier}.md` for per-provider integration details.

Exit.
