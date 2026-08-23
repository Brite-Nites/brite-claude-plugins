---
description: Deprecated alias for /revops:preview-changes. Forwards to the inner-loop deploy command, which targets your own brite-dev-<name> org instead of the retiring shared brite-sandbox.
---

<!-- eval-waiver: Deprecated shim whose entire body is static prose redirecting to /revops:preview-changes; it parses nothing, decides nothing, and emits no artifact of its own, so there is nothing deterministic to fixture. -->

# /revops:deploy-sandbox — DEPRECATED

> **This command was renamed.** Use **`/revops:preview-changes`**.

Renamed under [ADR-026](../../../docs/decisions/026-revops-promotion-topology.md), which
names revops commands from the human's intent rather than the machine's mechanism
(the rule now lives in [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) and applies to
every plugin).

**What changed beyond the name.** It targets **your own `brite-dev-<name>` org**, resolved at run time, instead of pinning the shared `brite-sandbox` — which is retiring, and which this command used to refuse to look past.

**Flags.** `--reconcile` still works. Two flags are new: `--target-org brite-dev-<name>` to name your org explicitly, and `--override-concurrency` for the blocking probe.

**Do not run this flow.** Read and follow [`preview-changes.md`](./preview-changes.md) and run that
procedure end-to-end, passing along any `$ARGUMENTS`.

This shim exists so existing muscle memory, docs, and links still land somewhere
useful. It will be removed in a future release.
