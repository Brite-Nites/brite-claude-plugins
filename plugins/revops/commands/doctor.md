---
description: Deprecated alias for /revops:check-environment-health. Forwards to the zero-mutation Salesforce environment health check.
---

<!-- eval-waiver: Deprecated shim whose entire body is static prose redirecting to /revops:check-environment-health; it parses nothing, decides nothing, and emits no artifact of its own, so there is nothing deterministic to fixture. -->

# /revops:doctor — DEPRECATED

> **This command was renamed.** Use **`/revops:check-environment-health`**.

Renamed under [ADR-026](../../../docs/decisions/026-revops-promotion-topology.md), which
names revops commands from the human's intent rather than the machine's mechanism
(the rule now lives in [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) and applies to
every plugin).

**What changed beyond the name.** The name now says what it does. The checks also resolve your own `brite-dev-<name>` org rather than probing the shared `brite-sandbox`, and there is a new advisory check that tells you if the retiring `brite-sandbox` is still authenticated.

**Flags.** No flags. Same zero-mutation contract.

**Do not run this flow.** Read and follow [`check-environment-health.md`](./check-environment-health.md) and run that
procedure end-to-end, passing along any `$ARGUMENTS`.

This shim exists so existing muscle memory, docs, and links still land somewhere
useful. It will be removed in a future release.
