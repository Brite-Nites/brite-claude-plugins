# tam-map scripts — invocation pattern

This directory ships 5 Python CLI scripts plus 2 stdio MCP wrappers (`aiark-mcp.js`, `discolike-mcp.js`). Each one needs a vendor API key at runtime. The keys live in the Engineering Bitwarden collection as per-item Login entries (one item per key, names prefixed `tam-map-`); the plugin-shipped `bw-run.sh` wrapper fetches them at spawn time and exports them as env vars.

This README is the canonical invocation reference. The wrapper details live in [`CONTRIBUTING.md § Plugin secret-config canon`](../../../../CONTRIBUTING.md#plugin-secret-config-canon); the spike validation that proved the pattern is in [`docs/research/bw-run-spike.md`](../../../../docs/research/bw-run-spike.md) (BC-6905).

## Required env vars and Bitwarden mapping

| Script / MCP                  | Env var                     | Bitwarden item              |
|-------------------------------|-----------------------------|-----------------------------|
| `spider` MCP, `spider_crawl.py` | `SPIDER_API_KEY`            | `tam-map-spider-api-key`    |
| `aiark` MCP                     | `AIARK_API_KEY`             | `tam-map-aiark-api-key`     |
| `discolike` MCP                 | `DISCOLIKE_API_KEY`         | `tam-map-discolike-api-key` |
| `icypeas_client.py`             | `ICYPEAS_API_KEY`           | `tam-map-icypeas-api-key`   |
| `enrich_waterfall.py`           | `BLITZAPI_KEY`              | `tam-map-blitzapi-key`      |
| `enrich_waterfall.py`           | `PROSPEO_API_KEY`           | `tam-map-prospeo-api-key`   |
| `verify_smtp.py`                | `MILLIONVERIFIER_API_KEY`   | `tam-map-millionverifier-api-key` |
| `tier_and_segment.py`           | `ANTHROPIC_API_KEY`         | (BC-6907 will replace this script with an in-session skill — out of scope for the wrapper) |

## Canonical invocation

The wrapper auto-detects the longest common prefix of item names and batches a single `bw list items --search` call when the prefix is ≥ 3 chars (BC-6905 Q3 measured 86% latency savings at N=7 vs sequential). All `tam-map-*` items share the `tam-map-` prefix, so the batch path always engages in production.

### `spider_crawl.py` (Spider.cloud crawl)

```bash
plugins/marketing/scripts/bw-run.sh \
  SPIDER_API_KEY=tam-map-spider-api-key \
  -- \
  python3 plugins/marketing/scripts/tam-map/spider_crawl.py <args>
```

### `icypeas_client.py` (IcyPeas keyword/email lookup)

```bash
plugins/marketing/scripts/bw-run.sh \
  ICYPEAS_API_KEY=tam-map-icypeas-api-key \
  -- \
  python3 plugins/marketing/scripts/tam-map/icypeas_client.py --icp <icp.json>
```

### `enrich_waterfall.py` (BlitzAPI + Prospeo enrichment)

```bash
plugins/marketing/scripts/bw-run.sh \
  BLITZAPI_KEY=tam-map-blitzapi-key \
  PROSPEO_API_KEY=tam-map-prospeo-api-key \
  -- \
  python3 plugins/marketing/scripts/tam-map/enrich_waterfall.py --in <input.jsonl> --out enriched.jsonl
```

### `verify_smtp.py` (MillionVerifier SMTP verification)

```bash
plugins/marketing/scripts/bw-run.sh \
  MILLIONVERIFIER_API_KEY=tam-map-millionverifier-api-key \
  -- \
  python3 plugins/marketing/scripts/tam-map/verify_smtp.py --in enriched.jsonl --out verified.jsonl
```

## Why the wrapper

Three reasons drove the migration from `~/.zshrc`-exported env vars to `bw-run.sh`:

1. **No shell-profile edits.** New developers run `bw login` once and `bw unlock` per session; no manual file editing.
2. **Rotation without shell-profile edits.** Vault is the single source of truth — rotating a value in Bitwarden takes effect at the next MCP-process or CLI-process spawn. For CLI invocations (one-shot processes via Bash), the new value lands on the next call. For MCP servers (long-lived per-session processes), the new value lands on the next Claude Code re-launch (`/reload-plugins` only reloads plugin metadata, not MCP server processes; measured BC-6906 T14). Either way: no `~/.zshrc` edits required (the pre-wrapper world needed both `~/.zshrc` edits AND a re-launch).
3. **Plugin canon.** Other Brite plugins needing API keys can adopt the same pattern by copying `bw-run.sh` — the integration shape is documented in [`CONTRIBUTING.md § Plugin secret-config canon`](../../../../CONTRIBUTING.md#plugin-secret-config-canon).

## Setup

Run `/marketing:setup-tam-map` in Claude Code. It detects current state, walks `bw login` (one-time) and `bw unlock` (per-session), and verifies all 3 MCPs + 5 CLI scripts before exiting.

## Python interpreter

The invocation snippets above use `python3` to match `setup-tam-map.md`'s probes. If you prefer `python`, activate `plugins/marketing/scripts/tam-map/.venv` first (`source plugins/marketing/scripts/tam-map/.venv/bin/activate`) — the venv's `bin/python` symlink will then resolve. `bw-run.sh` ends with `exec "$@"` and preserves the parent shell's `PATH` and `VIRTUAL_ENV`, so whichever interpreter resolves in your launching shell is what runs the script.

## Related

- [`plugins/marketing/scripts/bw-run.sh`](../bw-run.sh) — the wrapper itself
- [`plugins/marketing/scripts/bw-run.test.sh`](../bw-run.test.sh) — test suite (5 cases)
- [`CLAUDE.md` § Gotchas / BC-5551](../../../../CLAUDE.md) — HTTP MCP exception (the wrapper applies to stdio MCPs and CLI scripts; HTTP MCPs still need user-level registration)
- BC-6906 design doc: [`docs/designs/BC-6906-bw-run-prod-migration.md`](../../../../docs/designs/BC-6906-bw-run-prod-migration.md)
