# 045. The gbrain broker reads its OAuth client from the environment

**Status:** Accepted
**Date:** 2026-07-31
**Completes:** [ADR-044 § Scope](044-secrets-manager-machine-account-broker.md#scope), which deferred `gbrain-team-broker.sh` to its own decision
**Supersedes:** the `BW_SESSION` credential path in [ADR-010](010-plugin-secret-config-canon.md) for this broker. ADR-010's context, drivers, and HTTP-MCP exception still stand.
**Related ADRs:** [ADR-010](010-plugin-secret-config-canon.md), [ADR-044](044-secrets-manager-machine-account-broker.md), [ADR-007](007-revops-plugin-design.md)
**Related issues:** BC-11006 (broker origin), BC-11758 (per-teammate clients), BC-12113 (write client), BC-11757 (`plugins/_shared/` consolidation, still open)
**Companion docs:** [`CONTRIBUTING.md § Team gbrain credentials`](../../CONTRIBUTING.md#team-gbrain-credentials)

## Context

ADR-044 moved the marketing plugin's vendor API keys to Bitwarden Secrets
Manager and deleted `bw-run.sh`. It deliberately left `gbrain-team-broker.sh`
alone, because that broker resolves a *per-human* OAuth client from a personal
vault rather than a shared collection of vendor keys.

The result was that ADR-044 removed almost none of the pain it set out to
remove. `gbrain-team-broker.sh` is registered in **six** plugins — `cadence`,
`core`, `flow-architecture`, `marketing`, `revops`, `workflows` — and the
brain-first pattern means most sessions touch it. The marketing MCP servers it
freed are used by a handful of people on a handful of workflows. So `bw unlock`
and an exported `BW_SESSION` remained the price of a working session for the
whole team, to serve one server.

The broker's vault logic did three lookups:

| Item | Role |
|---|---|
| `Brite team gbrain — my client` | the teammate's own tier-scoped client, personal vault |
| `Brite team gbrain — plugin OAuth client` | shared Engineering fallback, open tier only, for teammates whose personal client hadn't landed (BC-11758) |
| `Brite team gbrain — write OAuth client` | the `write`-scope client (BC-12113), no fallback by design |

About sixty lines of discovery, preflight, and fallback logic, none of which
protected anything: the credential it fetched buys exactly one thing — a
tier-scoped gbrain token — and the broker was about to mint that token and hand
it to the wrapped process anyway.

## Decision Drivers

- **The blast radius already equals the job.** The gbrain client secret
  authenticates for one scope on one service. That is the same test ADR-044
  applied to `BWS_ACCESS_TOKEN`. A vault master password failed that test; this
  credential passes it.
- **It is already a machine credential.** An OAuth `client_secret` issued to a
  registered client is not a human's password. The vault was storing a machine
  credential and charging a human-password ceremony to read it.
- **Consistency settles it.** If a scoped credential exported from a shell
  profile is acceptable for `BWS_ACCESS_TOKEN`, it is acceptable here. Holding
  two standards would mean the team pays `bw unlock` for a credential weaker
  than one we already accept in plaintext.
- **Less code beats better-defended code** (ADR-044's fourth driver, unchanged).
  The vault path is ~60 lines across six copies; the environment path is a
  variable read.
- **The fallback chain was an artefact of discovery.** The broker chained
  personal → shared because it had to *find out* which item existed. A developer
  who exports a variable already knows which client they hold.

## Decision

**`gbrain-team-broker.sh` reads its OAuth client from the environment. Each
developer exports the pair in their shell profile, alongside
`BWS_ACCESS_TOKEN`.**

```sh
export GBRAIN_CLIENT_ID=...
export GBRAIN_CLIENT_SECRET=...
# Only for teammates with gbrain write access (/workflows:ship, /workflows:review):
export GBRAIN_WRITE_CLIENT_ID=...
export GBRAIN_WRITE_CLIENT_SECRET=...
```

Bitwarden still **stores** the values — the teammate copies them out of
`Brite team gbrain — my client` once at onboarding. It leaves the runtime path
only.

- **No vault session.** No `bw`, no `bw unlock`, no `BW_SESSION`. With ADR-044,
  this repo has no `BW_SESSION` consumer left on any live path. The only
  remaining references are `scripts/spike-bw-run/`, the throwaway BC-6905 proof
  of concept, which nothing invokes; the broker still `unset`s `BW_SESSION`
  before `exec` as belt-and-braces for a developer who has one exported from the
  old world.
- **Read and write are separate variable pairs, and write never falls back.**
  `--write` reads `GBRAIN_WRITE_CLIENT_*` and nothing else. A missing write
  client is a hard exit 3, not a silent downgrade to a read identity — the
  BC-12113 property, preserved structurally rather than by a comment. Two
  distinct names cannot fall back to each other by accident.
- **A half-set pair is a hard failure.** Exporting the id but not the secret
  exits 3 naming the missing half. This replaces the vault-era warning that
  fired when a retrievable-but-malformed personal item would otherwise have been
  masked as working-but-wrong-identity. Same reasoning, same loudness.
- **The broker scrubs the credentials before `exec`.** This is a **new
  obligation**, not a carry-over. In the vault era `client_id`/`client_secret`
  were shell locals read from `bw` and never exported, so the wrapped process
  could not see them. They now arrive as real environment variables and would be
  inherited by `mcp-remote` and every transitive npm dependency it loads. The
  broker `unset`s all four the moment it copies them into locals. This is the
  containment property `bws` provides for free via `command.env_remove`
  (ADR-044 § Token containment); here the script owns it.
- **The tier is server-side.** The broker cannot tell a personal tier-scoped
  client from the shared open-tier one, and does not need to. Scope is a
  property of the registered client, enforced at the `/token` endpoint.

### Verification

`plugins/core/tests/test_gbrain_team_broker.sh` (wired into `validate.sh`
§2b-gbrain) locks the contract: 48 assertions covering argument handling,
both credential-resolution failure modes per mode, the write-mode no-fallback
rule, scope selection, and the credential scrub — the last checked by exec'ing a
stub that dumps its inherited environment. The happy-path cases run against a
local `/token` stub; the failure cases need no network.

The same harness asserts the six copies are byte-identical. That guard did not
exist before: each plugin's `.mcp.json` execs its **own**
`${CLAUDE_PLUGIN_ROOT}` copy, so a fix landing in one copy and missing five was
silent. `docs/audits/002` named this DEBT-1 and gated the real fix — moving the
broker into `plugins/_shared/` — on BC-11757, which is still open. Until it
lands, CI enforces the invariant that the duplication requires.

## Rejected Alternatives

- **Per-teammate Secrets Manager machine accounts.** Give each teammate a
  Secrets Manager project holding their gbrain client, and wrap the broker in
  `bws run`. Rejected as over-engineered: it adds a project, a machine account,
  and an access token per teammate, and the access token then lives in the shell
  profile anyway. It adds a layer without removing one.
- **One shared Secrets Manager project for gbrain clients.** Rejected on the
  same collision that forced two projects in ADR-044: a secret's name is the
  injected variable name, so one project cannot hold a different
  `GBRAIN_CLIENT_ID` per teammate.
- **Keep the vault for gbrain only.** Rejected: it charges the whole team
  `bw unlock` every session so that one server can avoid a profile export, and
  it keeps the `bw` preflight and the discovery chain alive in six copies.
- **Collapse read and write onto one pair plus a scope flag.** Rejected: a
  single pair means a developer without write access silently authenticates as
  read and discovers it as a `put_page` 403 much later. That is precisely the
  failure BC-12113's no-fallback rule exists to prevent.

## Consequences accepted

- **This breaks every existing install.** A teammate who has not exported the
  pair gets a hard exit 3 at MCP spawn — including teammates who were silently
  riding the shared Engineering fallback and never had a personal item. Like
  ADR-044, this needs an announcement **before** merge, not after.
- **Rotation gets worse, and this is the real cost.** In the vault era, rotating
  a client secret meant editing one Bitwarden item; every teammate picked it up
  at their next spawn. Now each teammate must edit their own profile and
  relaunch. For the per-teammate read client that is already a per-teammate
  event, so little changes. For the **shared write client** it means telling
  everyone with write access to update their profile — a coordinated step the
  vault did not require. Accepted as the price of deleting the vault path;
  revisit if write-client rotation becomes frequent.
- **Two more plaintext secrets in the profile** (three with `BWS_ACCESS_TOKEN`,
  four for teammates with write access). Accepted on ADR-044's reasoning: each
  is scoped, revocable per client, and worth strictly less than the vault
  password the old path required.
- **The personal → shared fallback is gone.** Unmigrated teammates export the
  shared client's values directly until their own client lands (BC-11758). The
  broker no longer distinguishes them, and the specific
  "personal item exists but is malformed" warning has no analogue.
- **`client_secret` still crosses `curl`'s argv**, so it is visible in `ps` for
  the life of the `/token` request. This is unchanged from the vault era and is
  **deliberately out of scope here** — PR #565 is the record of what happens
  when a credential change grows extra hardening mid-review. Tracked as a
  follow-up; fixing it means feeding curl its options over stdin (`--config -`)
  and deserves its own change and its own test.
- **The six copies stay duplicated** until BC-11757 moves the broker to
  `plugins/_shared/`. CI now enforces their identity, which is the mitigation,
  not the fix.

## Reversibility

Reverting means restoring the previous broker from git history in all six
plugins and re-exporting `BW_SESSION`. The Bitwarden items were not deleted —
they remain the system of record for the values — so the rollback window stays
open indefinitely.

## References

- [ADR-044](044-secrets-manager-machine-account-broker.md) — the Secrets Manager decision that deferred this one
- [ADR-010](010-plugin-secret-config-canon.md) — the superseded `BW_SESSION` mechanism, and the still-valid context
- [`docs/audits/002-repo-audit-2026-07-05.md`](../audits/002-repo-audit-2026-07-05.md) § DEBT-1 — the six-copy duplication hazard
- [RFC 6749 § 4.4](https://www.rfc-editor.org/rfc/rfc6749#section-4.4) — client credentials grant
