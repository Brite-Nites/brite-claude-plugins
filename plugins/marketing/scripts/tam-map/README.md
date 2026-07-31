# tam-map scripts — invocation pattern

This directory ships 4 Python CLI scripts plus 2 stdio MCP wrappers (`aiark-mcp.js`, `discolike-mcp.js`). Each one needs a vendor API key at runtime. The keys live in the Bitwarden Secrets Manager project `brite-claude-tam-map`, one secret per key, each named exactly as its environment variable. `bws run` injects the whole project at spawn time.

This README is the canonical invocation reference. The pattern is documented in [`CONTRIBUTING.md § Plugin secret-config canon`](../../../../CONTRIBUTING.md#plugin-secret-config-canon) and decided in [ADR-044](../../../../docs/decisions/044-secrets-manager-machine-account-broker.md).

Every invocation below resolves the project id inline. Export it once (`export TAM_PID=$(bws project list | jq -r '.[]|select(.name=="brite-claude-tam-map")|.id')`) if you are running several in a row.

## Required env vars and Secrets Manager mapping

The secret's name **is** the environment variable name — there is no mapping step
to get wrong. Provision each one under `brite-claude-tam-map` named exactly as
the middle column.

| Script / MCP                    | Env var = Secrets Manager secret name |
|---------------------------------|---------------------------------------|
| `spider` MCP, `spider_crawl.py` | `SPIDER_API_KEY`                      |
| `aiark` MCP                     | `AIARK_API_KEY`                       |
| `discolike` MCP                 | `DISCOLIKE_API_KEY`                   |
| `icypeas_client.py`             | `ICYPEAS_API_KEY`                     |
| `enrich_waterfall.py`           | `BLITZAPI_KEY`                        |
| `enrich_waterfall.py`           | `PROSPEO_API_KEY`                     |
| `verify_smtp.py`                | `MILLIONVERIFIER_API_KEY`             |

> The LLM tier-scoring step (formerly `tier_and_segment.py`) now runs inline via the `icp-scoring` skill (`abc` rubric) and needs no API key — the session's own Claude credentials apply. Removed per BC-6907.

## Canonical invocation

`bws run --project-id` injects **every** secret in the project in one call — there is no per-key selection and no batching to tune. That is why the project, not the individual secret, is the unit of blast radius: each command below sees all 7 tam-map keys, not just the one it needs.

`bws` joins the command argv with spaces and runs the result through `sh -c`. Paths that could contain a space therefore need their quotes carried **into** the joined string, as the snippets below do.

### `spider_crawl.py` (Spider.cloud crawl)

```bash
bws run --project-id "$TAM_PID" -- \
  "exec python3 plugins/marketing/scripts/tam-map/spider_crawl.py <args>"
```

### `icypeas_client.py` (IcyPeas keyword/email lookup)

```bash
bws run --project-id "$TAM_PID" -- \
  "exec python3 plugins/marketing/scripts/tam-map/icypeas_client.py --icp <icp.json>"
```

### `enrich_waterfall.py` (BlitzAPI + Prospeo enrichment)

```bash
bws run --project-id "$TAM_PID" -- \
  "exec python3 plugins/marketing/scripts/tam-map/enrich_waterfall.py --in <input.jsonl> --out enriched.jsonl"
```

### `verify_smtp.py` (MillionVerifier SMTP verification)

```bash
bws run --project-id "$TAM_PID" -- \
  "exec python3 plugins/marketing/scripts/tam-map/verify_smtp.py --in enriched.jsonl --out verified.jsonl"
```

## Why a broker at all

Three reasons drove the migration from `~/.zshrc`-exported per-key env vars:

1. **One credential instead of seven.** A developer exports a single `BWS_ACCESS_TOKEN` once per machine; the seven vendor keys never touch a shell profile.
2. **Rotation without shell-profile edits.** Vault is the single source of truth — rotating a value in Bitwarden takes effect at the next MCP-process or CLI-process spawn. For CLI invocations (one-shot processes via Bash), the new value lands on the next call. For MCP servers (long-lived per-session processes), the new value lands on the next Claude Code re-launch (`/reload-plugins` only reloads plugin metadata, not MCP server processes; measured BC-6906 T14). Either way: no `~/.zshrc` edits per key (the pre-broker world needed both `~/.zshrc` edits AND a re-launch).
3. **Plugin canon.** Other Brite plugins needing API keys adopt the same pattern with their own Secrets Manager project — no script to copy, no wrapper to maintain. The integration shape is in [`CONTRIBUTING.md § Plugin secret-config canon`](../../../../CONTRIBUTING.md#plugin-secret-config-canon).

## Setup

Run `/marketing:setup-tam-map` in Claude Code. It detects current state, walks installing `bws` and exporting `BWS_ACCESS_TOKEN` (both one-time per machine — there is no per-session unlock step), and verifies all 3 MCPs + 4 CLI scripts before exiting.

## Python interpreter

The invocation snippets above use `python3` to match `setup-tam-map.md`'s probes. If you prefer `python`, activate `plugins/marketing/scripts/tam-map/.venv` first (`source plugins/marketing/scripts/tam-map/.venv/bin/activate`) — the venv's `bin/python` symlink will then resolve. `bws run` inherits the parent environment — including `PATH` and `VIRTUAL_ENV` — and strips only its own `BWS_ACCESS_TOKEN`, so whichever interpreter resolves in your launching shell is what runs the script. (Do not add `--no-inherit-env` for these: it clears the environment and the venv stops resolving.)

## Related

- [ADR-044](../../../../docs/decisions/044-secrets-manager-machine-account-broker.md) — why the in-repo wrapper was removed rather than hardened
- [`CLAUDE.md` § Gotchas / BC-5551](../../../../CLAUDE.md) — HTTP MCP exception (this pattern applies to stdio MCPs and CLI scripts; HTTP MCPs still need user-level registration)
- [Bitwarden Secrets Manager CLI](https://bitwarden.com/help/secrets-manager-cli/) — `bws` install and usage
