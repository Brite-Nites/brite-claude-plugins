## Design: Spike — validate `bw-run.sh` wrapper for tam-map MCP + CLI key injection

**Issue**: BC-6905 — Spike: validate bw run wrapper for tam-map MCP + CLI key injection
**Date**: 2026-05-08
**Brainstorm precedents:** BC-5947 task-3 (Pattern A canon), BC-5946 task-3 (wrapper-source-grep rule)

### Problem

`/marketing:setup-tam-map` currently asks devs to paste 8 `export` lines into `~/.zshrc` and restart Claude Code. The env-var pattern itself is correct (Anthropic-recommended for stdio MCPs; Brite Pattern A per BC-5947 task-3); the friction is in *how secrets reach env*. We want to validate `bw-run.sh` as a credential broker that replaces the human-types-into-`.zshrc` step, before committing to the production migration in BC-6906.

### Approach

Build a throwaway POC at `scripts/spike-bw-run/bw-run.sh` (~25 lines) that takes `KEY=item` args and an optional `-- cmd args...` tail, fetches each item's password via `bw get password`, exports the env, and execs the tail command. Run 7 measured questions (latency, lock UX, MCP handshake passthrough, key-rotation re-spawn, collection-share retrieval) and write findings to `docs/research/bw-run-spike.md` with a GO/NO-GO recommendation. POC stays in `main` only through the BC-6905 → BC-6906 transition; BC-6906 promotes the wrapper to `plugins/marketing/scripts/bw-run.sh` and deletes the spike directory.

### Key Decisions

1. **Hard-bind to `bw` — no broker abstraction.** Brite uses Bitwarden; no signaled intent to migrate. Keeping the POC ~25 lines per issue spec. If a 2nd broker arrives later, refactor at that point (YAGNI default).
2. **Parent-shell unlock; wrapper fails fast.** User runs `bw unlock` once per terminal session, exports `BW_SESSION`, launches Claude Code from that shell. Wrapper checks `BW_SESSION` + `bw status`; if missing/locked, exits 1 with a clear `run \`bw unlock\` and re-source` message. Matches `op run` ergonomics; the only model that works for non-interactive stdio MCP spawn (no TTY).
3. **Sequential `bw get password` per key.** Simplest interface for the spike; wrapper accepts repeatable `KEY=item` args. Issue Q2 + Q3 mandate measuring single-call AND `bw list items --search` batch-fetch latency separately — the spike *measures both* but uses sequential as the wrapper's interface. If sequential proves slow at N=3, the findings doc recommends batch-fetch for BC-6906's production wrapper.
4. **Q7 test data: create 1 per-item test entry pre-spike.** Holden manually creates one `tam-map-spider-api-key` item in the Engineering collection (real Spider key copied from existing bundle item Notes), shared via collection-level permission. This single item validates Q1 (per-item retrieval) + Q4 (MCP handshake passthrough wrapping `npx -y spider-cloud-mcp@2.1.1`) + Q7 (collection share) in one shot. If GO, BC-6906 admin step provisions the remaining 6.
5. **Spike PR scope.** POC + findings doc + Linear comment with GO/NO-GO + adapt list. No `.mcp.json` edits, no setup-command rewrite, no plugin version bump (BC-6000 doesn't apply — nothing under `plugins/<plugin>/{hooks,skills,commands,agents}/**` changes). All migration work belongs to BC-6906.

### Alternatives Considered

- **Broker-agnostic adapter (`secret-run.sh --broker bw|op|keychain`).** Doubles spike scope; speculates on infra Brite hasn't adopted. Rejected (YAGNI).
- **Wrapper-managed `bw unlock` prompt.** Breaks for stdio MCPs spawned by Claude Code (no TTY). Mixed UX — works for direct CLI invocation, fails for MCP path. Rejected — fail-fast is consistent across both surfaces.
- **Hybrid TTY-detect unlock.** Branches wrapper logic and complicates testing. Rejected for the spike; BC-6906 can revisit if measurements show CLI-script standalone use is common.
- **Mirror all 7 BC-6906 items pre-spike.** Overlaps with BC-6906's admin step; if NO-GO, 7 items provisioned for nothing. Rejected.
- **Parallel/batch fetch in spike wrapper.** Premature; measure first, optimize in BC-6906. Rejected for the wrapper *interface*; both shapes still get *measured* per issue Q3.

### Risks & Mitigations

- **`bw` CLI not installed locally.** → Install `brew install bitwarden-cli` + `bw login` before plan execution starts. Surfaced now to avoid mid-execution stall.
- **Vault locked mid-MCP-spawn produces opaque failure.** → Q5 explicitly measures the lock-UX fail message; spike GATES GO on this UX being clear (not silent).
- **`bw get password` returns nothing for collection-shared (not user-shared) items.** → Q7 directly tests this. NO-GO if it fails — Bitwarden's CLI semantics may not match expectations, would force a rethink (per-user share vs collection share, or alternative broker).
- **Spike conflates with BC-5947's open Pattern C verification.** → Explicit non-goal. The spike does NOT verify whether `${user_config.*}` substitution works for stdio. That promotion question stays open. Findings doc must call this out.
- **Wrapper-source claims drift from source code (BC-5946 task-3).** → Findings doc grep-anchors every claim about wrapper behavior to specific line numbers in `bw-run.sh`. Author memory is not authoritative.

### Scope Boundaries

- **In scope**: `scripts/spike-bw-run/bw-run.sh` POC (~25 lines), `scripts/spike-bw-run/README.md` (how to run), `docs/research/bw-run-spike.md` findings doc with measurements + GO/NO-GO + adapt list, Linear comment on BC-6905 with the GO/NO-GO decision and any surprises BC-6906 must adapt to.
- **Out of scope**: production wrapper at `plugins/marketing/scripts/bw-run.sh`, `.mcp.json` updates, CLI invocation changes in skills, `setup-tam-map.md` rewrite (all BC-6906); userConfig migration (BC-5551 / BC-5947 still-open verification, distinct angle); vendor swaps to OAuth alternatives (deferred — strategic review needed); the 8th key (ANTHROPIC_API_KEY) elimination (BC-6907, parallel track); plugin version bumps (BC-6000 doesn't apply — spike PR doesn't touch plugins/).

### Open Questions

- None blocking the plan. The 7 spike questions themselves are the unknowns we're paying to resolve; the design above commits to *how* we resolve them.
