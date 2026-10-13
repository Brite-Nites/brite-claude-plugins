---
description: Deprecated alias for /revops:run-manual-post-deploy-steps. Forwards to the manual post-deploy walkthrough.
---

<!-- eval-waiver: Deprecated shim whose entire body is static prose redirecting to /revops:run-manual-post-deploy-steps; it parses nothing, decides nothing, and emits no artifact of its own, so there is nothing deterministic to fixture. -->

# /revops:post-deploy-runbook — DEPRECATED

> **This command was renamed.** Use **`/revops:run-manual-post-deploy-steps`**.

Renamed under [ADR-026](../../../docs/decisions/026-revops-promotion-topology.md), which
names revops commands from the human's intent rather than the machine's mechanism
(the rule now lives in [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) and applies to
every plugin).

**What changed beyond the name.** Only the name. `runbook` is jargon; the new name says what you will be doing.

**Flags.** No flags. Same seven-phase walkthrough.

**Do not run this flow.** Read and follow [`run-manual-post-deploy-steps.md`](./run-manual-post-deploy-steps.md) and run that
procedure end-to-end, passing along any `$ARGUMENTS`.

This shim exists so existing muscle memory, docs, and links still land somewhere
useful. It will be removed in a future release.
