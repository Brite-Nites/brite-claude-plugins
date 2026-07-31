# 044. Secrets Manager machine accounts replace the in-repo Bitwarden broker

**Status:** Accepted
**Date:** 2026-07-31
**Supersedes:** [ADR-010 § Decision](010-plugin-secret-config-canon.md) (the `bw-run.sh` mechanism). ADR-010's context, drivers, and HTTP-MCP exception still stand.
**Related ADRs:** [ADR-010](010-plugin-secret-config-canon.md), [ADR-027](027-sf-capability-adoption-artifact-class.md)
**Companion docs:** [`CONTRIBUTING.md § Plugin secret-config canon`](../../CONTRIBUTING.md#plugin-secret-config-canon)

## Context

ADR-010 chose an in-repo Bash broker, `bw-run.sh`, which read secrets from the
Engineering Bitwarden collection using an exported `BW_SESSION`. It worked, and
its two operational costs were documented and accepted: developers had to run
`bw unlock` and export `BW_SESSION` before launching Claude Code, and a vault
lock mid-session cost ~30s to recover.

An attempt to remove those costs (PR #565) added opt-in self-unlock: the
wrapper would read the vault **master password** from the macOS Keychain and
mint its own session. That PR went through nine review rounds and eight
distinct security findings before being abandoned:

1. `BW_RUN_BW_BIN` bypassed the wrapper's own trusted-path check
2. the Keychain lookup was unscoped by account
3. the minted session was exported to PATH-resolved `bw` and `jq`
4. path ownership was inferred from traversability rather than checked, and only the immediate parent was examined
5. the known-install allowlist skipped all validation, and symlinks were never resolved
6. the trust check's own helpers (`ls`, `find`, `readlink`) were PATH-resolved, so the attacker it defended against could steer its verdict
7. the binary file's own mode and owner were never checked, only its directory
8. the validated path and the invoked path were different, leaving a check-then-use gap

Three findings were in the original change. **Five were introduced by the
hardening itself** — each an omission in the layer written to close the previous
one.

## Decision Drivers

- **The findings shared one root cause.** A broker held a credential worth far
  more than the secrets it brokered. `bw-run.sh` fetched eleven vendor API keys
  and, to do so, was handed the key to the entire vault. Every finding was an
  attempt to defend that inversion rather than remove it.
- **The blast radius should equal the job.** The secrets are injected into the
  wrapped process by design, so a credential scoped to exactly those secrets
  adds no exposure the design does not already accept. A master password does.
- **No mainstream tool caches a human's master password.** AWS SSO, `gh`, and
  the Docker and git credential helpers all cache a short-lived or scoped
  credential and delegate the sensitive step. The abandoned approach was not a
  risky variant of common practice; it was outside it.
- **Less code beats better-defended code.** The replacement deletes ~140 lines
  of wrapper and ~420 of tests, and needs no trust-checking apparatus at all.

## Decision

**Secrets reach stdio MCPs and CLI scripts through `bws run`, authenticated by a
Bitwarden Secrets Manager machine-account access token.**

```
bws run --project-id <uuid> -- "exec <cmd> <args>..."
```

- **Credential.** `BWS_ACCESS_TOKEN`, exported per developer in their shell
  profile. Scoped to the projects its machine account can read; expirable;
  revocable per account without touching anyone else. Grant `Can read` only.
- **No vault session.** No `bw`, no `bw unlock`, no `BW_SESSION`, no master
  password anywhere in the runtime path.
- **Token containment.** `bws` removes `BWS_ACCESS_TOKEN` from the child
  environment (`command.env_remove` in its `run` implementation), preserving the
  property ADR-010 got from `unset BW_SESSION` — verified in the vendor source,
  not assumed.
- **Naming.** A secret's name **is** the injected environment variable name.
- **Project sizing.** `bws run --project-id` injects every secret in the
  project; there is no per-key selection. Projects are the unit of blast radius.

### Two projects for the marketing plugin

`brite-claude-tam-map` (7 secrets) and `brite-claude-enrichment` (8). This split
is **forced, not preferred**: `PROSPEO_API_KEY` and `ICYPEAS_API_KEY` are each
fed from a different vault item depending on caller (`tam-map-*` for the Python
CLI scripts, `enrichment-*` for the enrichment MCP). `bw-run.sh` took `KEY=item`
pairs, so one variable could resolve to different items at different call sites.
That indirection is gone — one project cannot hold two secrets with the same
name.

### Consequences accepted

- **`bws` has no Homebrew formula.** Installed from Bitwarden's script or the
  `bitwarden/sdk-sm` releases. `bitwarden-cli` on Homebrew is `bw`, a different
  tool. This is a real onboarding step.
- **The token sits in plaintext in a shell profile.** Accepted: it is scoped,
  expirable, and revocable, which a master password is not. It must never be
  committed to `.mcp.json`.
- **Commands are shell-parsed.** `bws` joins the command argv with spaces and
  runs `sh -c`. `bw-run.sh` used `exec "$@"` and never shell-parsed. Paths that
  may contain spaces must carry literal quotes into the joined string. This is
  the migration's main behavioural risk and is covered in CONTRIBUTING.
- **Rotation propagation is unchanged.** Values resolve per process spawn, so a
  rotated secret still needs an MCP re-spawn — but no longer a shell with
  `BW_SESSION` exported.

## Scope

`gbrain-team-broker.sh` is a second, independent vault consumer, duplicated
across six plugins, and is **not** covered here. It resolves a per-teammate
OAuth client from a personal vault, so it still requires `BW_SESSION` and the
unlock tax does not fully lift until it moves too. That is a separate decision
about a per-human credential and gets its own ADR.

The HTTP-MCP exception in ADR-010 is unaffected.

## Reversibility

Reverting means restoring `bw-run.sh` from git history and re-pointing
`.mcp.json` at it; the Bitwarden Password Manager items were not deleted by the
migration. The secrets exist in both stores until someone deliberately removes
the originals, so the rollback window stays open as long as that is true.

## References

- [ADR-010](010-plugin-secret-config-canon.md) — the superseded mechanism, and the still-valid context
- PR #565 — the abandoned self-unlock attempt and its nine review rounds
- [Bitwarden Secrets Manager CLI](https://bitwarden.com/help/secrets-manager-cli/)
- [Access tokens and machine accounts](https://bitwarden.com/help/access-tokens/)
