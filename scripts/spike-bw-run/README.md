# bw-run.sh — POC credential broker (BC-6905 spike)

**This is a throwaway POC.** Production wrapper lives in BC-6906 at
`plugins/marketing/scripts/bw-run.sh`. Findings doc:
`docs/research/bw-run-spike.md`.

## What it does

Takes `KEY=item` args, fetches each item's password from Bitwarden via
`bw get password`, exports the env, and execs the wrapped command:

```
bw-run.sh SPIDER_API_KEY=tam-map-spider-api-key -- npx -y spider-cloud-mcp@2.1.1
```

## Preconditions

1. `bw` CLI installed (`brew install bitwarden-cli`).
2. User authenticated (`bw login`).
3. Vault unlocked in the parent shell:
   ```sh
   export BW_SESSION="$(bw unlock --raw)"
   ```
4. Launch the wrapped tool (Claude Code, npx, etc.) from the same shell so
   it inherits `BW_SESSION`.

If `BW_SESSION` is missing or the vault is locked mid-session, the wrapper
exits 1 with a clear message. It does not prompt — there's no TTY when
spawned by Claude Code's stdio MCP path.

## Exit codes

- `0` — wrapped command exit code (via `exec "$@"`)
- `1` — `BW_SESSION` missing or vault locked
- `2` — usage error (bad arg shape, missing `--` separator)
- `3` — `bw get password` failed for one of the items

## Scope (BC-6905 spike only)

This POC validates 7 questions for BC-6906:
- Q1: per-item retrieval works non-interactively
- Q2: single-call latency
- Q3: `bw list items --search` batch latency
- Q4: MCP `initialize` handshake passes through cleanly
- Q5: vault-locked-mid-session UX
- Q6: rotation propagation (wrapper side; lifecycle side deferred)
- Q7: collection-share retrieval semantics

It does NOT verify Pattern C (`${user_config.*}` substitution for stdio) —
that's BC-5947 task-3's still-open promotion question.

## Uninstall

```sh
rm -rf scripts/spike-bw-run/
```

BC-6906 will replace this directory with the production wrapper.
