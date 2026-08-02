# 010. Plugin secret-config canon (Bitwarden + `bw-run.sh`)

**Status:** Superseded in part by [ADR-044](044-secrets-manager-machine-account-broker.md) (2026-07-31)

> The **mechanism** below — the `bw-run.sh` wrapper, its contract, its `.mcp.json` shape, and the
> `BW_SESSION` preflight — was replaced by Bitwarden Secrets Manager machine accounts and `bws run`.
> The wrapper and its test suite no longer exist in the tree. This record is kept for the context,
> drivers, rejected alternatives, and the HTTP-MCP exception, all of which still stand.
> `gbrain-team-broker.sh` still follows the `BW_SESSION` pattern described here.
**Date:** 2026-05-10
**Linear:** [BC-6958](https://linear.app/brite-nites/issue/BC-6958)
**Related ADRs:** [ADR-007](007-revops-plugin-design.md), [ADR-008](008-tam-mapping-enrichment-pluggability.md), [ADR-009](009-sf-capability-adoption.md)
**Related issues:** [BC-5551](https://linear.app/brite-nites/issue/BC-5551), [BC-5832](https://linear.app/brite-nites/issue/BC-5832), [BC-5947](https://linear.app/brite-nites/issue/BC-5947), [BC-6905](https://linear.app/brite-nites/issue/BC-6905), [BC-6906](https://linear.app/brite-nites/issue/BC-6906)
**Companion docs:** [`CONTRIBUTING.md § Plugin secret-config canon`](../../CONTRIBUTING.md#plugin-secret-config-canon), [`docs/research/bw-run-spike.md`](../research/bw-run-spike.md), [`docs/designs/BC-6906-bw-run-prod-migration.md`](../designs/BC-6906-bw-run-prod-migration.md)

## Context

Brite plugins need to inject third-party API keys into stdio MCP server processes and CLI scripts at run time. The friction is *how* those secrets reach the process environment without each developer hand-editing `~/.zshrc`, rotating values machine-by-machine, or trusting `${user_config.*}` substitution paths that ship broken in current Claude Code.

Four prior issues explored the design space:

- **[BC-5551](https://linear.app/brite-nites/issue/BC-5551)** verified that `${user_config.*}` substitution into plugin-scoped HTTP MCP `headers` is broken in Claude Code v2.1.112 (token-via-curl = 200, same-token-via-Claude-Code = `Failed to connect`). Email Bison was forced into user-level registration with guided onboarding.
- **[BC-5832](https://linear.app/brite-nites/issue/BC-5832)** locked CLAUDE.md ~100-line soft budget (load-bearing-doc-artifact discipline). Any solution must be summarizable in 1–2 CLAUDE.md gotcha lines without exploding the file.
- **[BC-5947](https://linear.app/brite-nites/issue/BC-5947)** task-3 left `${user_config.*}` substitution into **stdio MCP env** (Pattern C) as unverified-but-suspect — defaulted to Pattern A (plugin-scoped stdio + `${OS_ENV}` + setup command).
- **[BC-6905](https://linear.app/brite-nites/issue/BC-6905)** spike validated a Bitwarden-broker wrapper for tam-map (Q1–Q7); GO with batch-fetch via longest-common-prefix `bw list items --search` (Q3: 3.21s constant-time, 86% savings at N=7).
- **[BC-6906](https://linear.app/brite-nites/issue/BC-6906)** shipped the wrapper to production for tam-map (3 MCPs + 5 CLI scripts) and measured the `/reload-plugins`-does-not-respawn gap (T14 — credential rotation requires Claude Code re-launch, not just plugin metadata reload).

The decision (Pattern D — Bitwarden + `bw-run.sh` broker) currently lives operationally in [`CONTRIBUTING.md § Plugin secret-config canon`](../../CONTRIBUTING.md#plugin-secret-config-canon). That section is the right venue for *how to apply* the canon. This ADR captures the *decision* — alternatives considered, drivers, consequences, promotion path — so it surfaces through the ADR index alongside ADR-007/008/009 and isn't tribal knowledge that future contributors discover only by reading CONTRIBUTING.md cover-to-cover.

## Decision Drivers

- **Vault is single source of truth.** No `~/.zshrc` edits, no per-machine env-var drift, no `dotenv` files in git history.
- **Per-spawn fetch.** Values resolve at every MCP/CLI process spawn — no cached env, no manual rotation propagation step beyond a Claude Code re-launch.
- **Spike-validated.** BC-6905 measured the wrapper against 7 functional questions (preflight, latency, batch savings, exec semantics, vault-lock UX, error paths, portability). All 7 PASS or PASS-with-known-cost.
- **CLAUDE.md line-budget discipline ([BC-5832](https://linear.app/brite-nites/issue/BC-5832)).** Solution must fit in 1–2 gotcha lines + cross-cite, not a 30-line block.
- **HTTP MCP path stays separately handled.** ([BC-5551](https://linear.app/brite-nites/issue/BC-5551)) HTTP MCPs with `Authorization: Bearer ${...}` headers cannot use this canon today — they ship as user-level registrations with guided onboarding. ADR makes the exception explicit so future contributors don't try to retrofit HTTP MCPs onto the wrapper.

## Decision

**For stdio MCPs and CLI scripts, secrets are injected via `bw-run.sh`** — a thin Bash wrapper that fetches values from the Engineering Bitwarden collection at process spawn time, exports them as env-vars, and `exec`s the wrapped command.

### 1. Wrapper contract

```bash
bw-run.sh KEY1=item-name-1 KEY2=item-name-2 ... -- <cmd> <args>...
```

- Preflight: requires `jq` on PATH + `BW_SESSION` exported + `bw status` reports `unlocked`. Any preflight failure exits non-zero with a one-line stderr remediation.
- Fetch strategy: if all `item-name-*` share a common prefix ≥ 3 chars, single `bw list items --search <prefix>` call serves all keys (BC-6905 Q3: 3.21s constant-time vs N×3.20s sequential — 86% savings at N=7). Per-item discrimination uses two `jq` calls: pass 1 emits structural status (`absent` / `wrong_type` / `ok`), pass 2 (only on `ok`) extracts the password. The two-pass shape sidesteps in-band sentinel collision risk and gracefully handles Bitwarden item types other than `login` (e.g. secure-note shape with no `.login` block). Falls back to per-key `bw get password` when no common prefix.
- Exit codes: `1` preflight, `2` usage, `3` item resolution failure (absent / wrong-type / empty-password / sequential-fetch-failure — each emits a distinct stderr line).
- Defense-in-depth: `unset BW_SESSION` before `exec` so the wrapped process cannot read the vault token from its env. The wrapped MCP/CLI processes pull in third-party transitive dependencies (spider-cloud-mcp, aiark-mcp.js, discolike-mcp.js, the Python tam-map scripts); a compromised transitive dep with `process.env` access could otherwise exfiltrate the master vault token. The wrapper has finished all `bw` calls by this point; the wrapped process only needs the per-vendor `KEY=value` exports already in env.
- Reference implementation: [`plugins/marketing/scripts/bw-run.sh`](../../plugins/marketing/scripts/bw-run.sh) — small single-file pure POSIX bash wrapper, macOS bash 3.2 portable. `wc -l` is the source of truth on size; cross-references in CONTRIBUTING.md and elsewhere cite this ADR instead of restating a line count.
- Test suite: [`plugins/marketing/scripts/bw-run.test.sh`](../../plugins/marketing/scripts/bw-run.test.sh) — pure-bash framework, `bw` stubbed via PATH-prepended temp dir. Cases grow as edge paths are discovered (BC-6906 spike validation, BC-6958 micro-fix coverage).

### 2. Plugin `.mcp.json` shape

```jsonc
{
  "mcpServers": {
    "<name>": {
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/bw-run.sh",
      "args": ["KEY=tam-map-<item>", "--", "<original cmd>", "<args>..."]
    }
  }
}
```

Drop the `env: { KEY: "${KEY}" }` block — the wrapper fills env at runtime.

### 3. Skill / CLI shape

```bash
bw-run.sh KEY=tam-map-<item> -- <original cmd>
```

The skill's instruction text is the spec; just prepend the wrapper invocation at each Bash call site.

### 4. Promotion path

**Today (single adopter — marketing plugin):** wrapper lives at `plugins/marketing/scripts/bw-run.sh`. The marketing-plugin copy is canonical until a second plugin adopts.

**On N=2 adopter (likely revops or cadence):** promote the wrapper to `scripts/bw-run.sh` (repo level). Each plugin's `.mcp.json` then references it via either a thin shim or relative `${CLAUDE_PLUGIN_ROOT}/../../scripts/bw-run.sh`. **Verify `${CLAUDE_PLUGIN_ROOT}/../../...` resolves correctly in the installed-plugin (non-monorepo) layout before promotion** — the marketplace cache is shaped `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, so `../../` from the plugin root reaches the marketplace root, not the repo root. The promotion PR must include a one-time path probe before the move.

**Single-adopter rationale ([BC-6906](https://linear.app/brite-nites/issue/BC-6906) task-3 precedent):** premature repo-level extraction would require either (a) deciding the shim shape blind, or (b) every-plugin path-probing on first adoption — both worse than waiting for the second adopter to surface real path constraints.

### 5. Rotation semantics

Values are fetched per-MCP-process-spawn, not per-tool-call. MCP server processes are persistent for the Claude Code session; tool calls reuse the running process and its in-memory env. **`/reload-plugins` does NOT re-spawn MCP processes** (BC-6906 T14: it reloads plugin metadata only). To pick up a rotated Bitwarden value:

- **Long-lived stdio MCPs:** re-launch Claude Code from a shell where `BW_SESSION` is exported. Per-server `claude mcp restart <name>` may exist in newer Claude Code versions — separate discovery if pursued.
- **One-shot CLI invocations:** new value is picked up on the next Bash call automatically.

## Rejected Alternatives

### Pattern A — env vars via `~/.zshrc`

Standard `export KEY=value` lines in the shell profile, read at terminal spawn.

**Rejected because:** requires every developer to hand-edit shell profiles per-key; rotation requires manually editing every machine and starting a fresh shell; secrets sit in plaintext in `~/.zshrc` (or `dotenv` files at the repo root, which CI scans for); no audit trail. The wrapper Pattern D dominates on every axis except "no extra runtime deps."

### Pattern B — `${user_config.*}` substitution into HTTP MCP `headers`

Claude Code supports `userConfig` declarations (with `sensitive: true` for OS keychain storage). The natural shape for HTTP MCPs is `headers: { Authorization: "Bearer ${user_config.token}" }`.

**Rejected (and tracked as exception) because:** [BC-5551](https://linear.app/brite-nites/issue/BC-5551) verified this path is broken in Claude Code v2.1.112. The literal string `Bearer ${user_config.token}` reaches the upstream server (no substitution). Upstream issues [#6204](https://github.com/anthropics/claude-code/issues/6204) and [#9427](https://github.com/anthropics/claude-code/issues/9427) track the bug. HTTP MCPs with credentialed headers (Email Bison) ship as **user-level registration** + guided onboarding command (`/marketing:setup-email-bison`) until upstream lands fixes.

### Pattern C — `${user_config.*}` substitution into stdio MCP env

Claude Code substitutes `${user_config.*}` into stdio MCP `env: {}` blocks. In principle, this would let `plugin.json` declare `userConfig.spider_api_key` (`sensitive: true` → OS keychain) and the `.mcp.json` set `env: { SPIDER_API_KEY: "${user_config.spider_api_key}" }`.

**Rejected (today) because:** [BC-5947](https://linear.app/brite-nites/issue/BC-5947) task-3 left this path **unverified-but-suspect** after Pattern B's failure on the HTTP side. Verifying it requires a controlled test against current Claude Code (separate prerequisite-research task, not gated by this ADR). Even if Pattern C verifies in the future, it would not subsume Pattern D — Pattern D also serves CLI scripts (which `userConfig` does not reach), and the rotation story is identical (re-launch Claude Code either way). Pattern C may eventually replace the stdio-MCP slice of Pattern D, but the broker remains canonical for the CLI slice.

## Consequences

### Positive

- **Vault is the single source of truth.** Rotation = update the Bitwarden item. Next process spawn picks up the new value. No file edits, no commits, no CI changes.
- **Per-plugin secrets stay self-contained.** Each plugin owns its `scripts/bw-run.sh` (until N=2 promotion), its tests, its setup command. Adding a new plugin doesn't require touching shared infrastructure.
- **CLI scripts get the same treatment as MCPs.** No second pattern for "Python script needs an API key" — the wrapper is the single shape.
- **Spike-validated cost model.** BC-6905 Q1–Q7 measured each path; future maintainers can re-run the spike's structured questions if performance regresses.

### Negative / mitigations

- **Adds `bw` and `jq` runtime deps** (`brew install bitwarden-cli jq`). Both are widely available; setup commands detect them in Phase 1. *Mitigation:* setup commands fail-fast with `brew install` remediation in stderr.
- **Vault-lock-mid-session ~30s recovery cost** ([BC-5947](https://linear.app/brite-nites/issue/BC-5947) task-3 Pattern A; [BC-6905](https://linear.app/brite-nites/issue/BC-6905) Q5). User must re-export `BW_SESSION` and re-launch Claude Code. *Mitigation:* `/marketing:setup-tam-map` re-runs idempotently; no per-key re-onboarding needed.
- **Rotation propagation is not zero-touch.** Long-lived stdio MCPs require Claude Code re-launch to re-spawn through the wrapper ([BC-6906](https://linear.app/brite-nites/issue/BC-6906) T14). *Mitigation:* documented in five places (CONTRIBUTING.md, setup-tam-map.md, the wrapper header comment, the spike findings doc, this ADR). `/reload-plugins` gap is called out explicitly to prevent the false-confidence loop.
- **Bash 3.2 portability constraint.** macOS ships bash 3.2; the wrapper must guard `"${arr[@]}"` of potentially-empty arrays under `set -u` ([BC-6905](https://linear.app/brite-nites/issue/BC-6905) task-2). *Mitigation:* gotcha is in CLAUDE.md; the test suite (TEST 9) exercises the empty-EXPORTS path.

### Neutral

- **Single-adopter canon today.** The marketing-plugin copy is canonical; rev-share with revops/cadence happens on N=2 promotion. This is intentional ([BC-6906](https://linear.app/brite-nites/issue/BC-6906) task-3) and reversed cheaply when triggered.
- **HTTP MCPs are a separate path.** Email Bison's user-level-registration onboarding pattern is the HTTP MCP canon; this ADR doesn't subsume it. Two patterns coexist because the transport difference is real (Authorization headers vs env-var injection).

## Reversibility

- **Decision-level reversal:** if upstream lands Pattern B + Pattern C fixes simultaneously and the rotation story matches, the broker becomes optional. Migration is per-plugin — replace `bw-run.sh KEY=item --` invocations with `env: { KEY: "${user_config.key}" }` blocks, drop the wrapper from `.mcp.json`, retire the `scripts/bw-run.*` files. Each plugin's setup command updates its onboarding flow. Estimated effort: ~2 hours per plugin.
- **Promotion-level reversal:** if the N=2 path-probe fails (`${CLAUDE_PLUGIN_ROOT}/../../scripts/bw-run.sh` doesn't resolve in the installed layout), the wrapper stays in `plugins/<plugin>/scripts/bw-run.sh` per-plugin. Each plugin maintains its own copy with manual cherry-pick on fixes. Trade-off documented in CONTRIBUTING.md.
- **Single-key reversal:** if a specific plugin wants to opt out of the canon (e.g., for a key that's genuinely public, like an npm registry token), drop the `bw-run.sh` wrapper from that `.mcp.json` entry and use `env: { KEY: "literal-value" }`. The canon applies to *secret* keys; it doesn't forbid plain env-var injection for non-secrets.

## Related

- [`CONTRIBUTING.md § Plugin secret-config canon`](../../CONTRIBUTING.md#plugin-secret-config-canon) — operational guide (how to apply)
- [`docs/research/bw-run-spike.md`](../research/bw-run-spike.md) — BC-6905 spike findings (Q1–Q7)
- [`docs/designs/BC-6906-bw-run-prod-migration.md`](../designs/BC-6906-bw-run-prod-migration.md) — production-migration design + wrapper contract
- [`plugins/marketing/scripts/bw-run.sh`](../../plugins/marketing/scripts/bw-run.sh) — reference implementation
- [`plugins/marketing/scripts/bw-run.test.sh`](../../plugins/marketing/scripts/bw-run.test.sh) — test suite
- [`plugins/marketing/commands/setup-tam-map.md`](../../plugins/marketing/commands/setup-tam-map.md) — first-plugin onboarding command
- [BC-5551](https://linear.app/brite-nites/issue/BC-5551) — HTTP MCP header substitution broken
- [BC-5832](https://linear.app/brite-nites/issue/BC-5832) — CLAUDE.md line-budget discipline
- [BC-5947](https://linear.app/brite-nites/issue/BC-5947) task-3 — Pattern A vs C, stdio path unverified
- [BC-6905](https://linear.app/brite-nites/issue/BC-6905) — spike validation
- [BC-6906](https://linear.app/brite-nites/issue/BC-6906) — production migration + T14 rotation measurement
