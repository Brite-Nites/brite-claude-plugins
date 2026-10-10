---
description: Deprecated alias for /revops:setup-dev-workspace. Forwards to the guided onboarding that sets up your own brite-dev-<name> Salesforce org.
---

<!-- eval-waiver: Deprecated shim whose entire body is static prose redirecting to /revops:setup-dev-workspace; it parses nothing, decides nothing, and emits no artifact of its own, so there is nothing deterministic to fixture. -->

# /revops:setup-sandbox — DEPRECATED

> **This command was renamed.** Use **`/revops:setup-dev-workspace`**.

Renamed under [ADR-026](../../../docs/decisions/026-revops-promotion-topology.md), which
names revops commands from the human's intent rather than the machine's mechanism
(the rule now lives in [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) and applies to
every plugin).

**What changed beyond the name.** It sets up **your own `brite-dev-<name>` org**, not the shared `brite-sandbox`. Phase 3 now asks you to agree an alias first and validates it, because every deploy command resolves your org by that name.

**Flags.** No flags. If you already have `brite-sandbox` authenticated, nothing removes it — the new command sets your dev org up alongside and tells you what to switch.

**Do not run this flow.** Read and follow [`setup-dev-workspace.md`](./setup-dev-workspace.md) and run that
procedure end-to-end, passing along any `$ARGUMENTS`.

This shim exists so existing muscle memory, docs, and links still land somewhere
useful. It will be removed in a future release.
