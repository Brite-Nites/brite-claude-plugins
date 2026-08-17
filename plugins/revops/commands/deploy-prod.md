---
description: Deprecated alias for /revops:push-to-production. Forwards to the CI-orchestrator production command. The break-glass path moved to /revops:emergency-deploy-to-production.
---

<!-- eval-waiver: Deprecated shim whose entire body is static prose redirecting to /revops:push-to-production; it parses nothing, decides nothing, and emits no artifact of its own, so there is nothing deterministic to fixture. -->

# /revops:deploy-prod — DEPRECATED

> **This command was renamed.** Use **`/revops:push-to-production`**.

Renamed under [ADR-026](../../../docs/decisions/026-revops-promotion-topology.md), which
names revops commands from the human's intent rather than the machine's mechanism
(the rule now lives in [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) and applies to
every plugin).

**What changed beyond the name.** It **dispatches and watches CI** rather than deploying from your laptop. brite-salesforce ADR-016 section 6, and Amendment E, retired the raw local prod deploy.

**Flags.** `--reconcile` is gone — deploy scope is CI's decision now. `--override-concurrency` is new. If you were reaching for `--break-glass`, that is now its own command: `/revops:emergency-deploy-to-production`, and it requires `--reason`.

**Do not run this flow.** Read and follow [`push-to-production.md`](./push-to-production.md) and run that
procedure end-to-end, passing along any `$ARGUMENTS`.

This shim exists so existing muscle memory, docs, and links still land somewhere
useful. It will be removed in a future release.
