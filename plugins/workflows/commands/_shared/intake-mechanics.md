# Intake — shared mechanics

> **Canonical source** for the intake mechanics common to the front door's two branches:
> `/workflows:raise-a-ticket` (product) and `/workflows:report-issue` (agent tooling / direct
> alias). Both commands **cite** this file rather than re-inlining these procedures, so they can't
> drift. Enforced (referenced-not-duplicated) by
> `plugins/workflows/tests/test-intake-mechanics-ref.sh`.
>
> **What stays in the command bodies (not here):** the cap-proof disambiguation *contract* — render
> candidates as a numbered text list + a single "reply with the number, or none" follow-up — is a
> behavioral invariant kept INLINE at each pick site and guarded per-site by
> `test-intake-option-cap.sh` (M3 / BC-12400). This file describes the *search/Linear mechanics*; the
> *how-to-present-the-pick* rule lives where it's enforced.

## Reachability probe (Step 0)

Before doing anything else, confirm the Linear MCP is reachable: call `list_projects` (limit 1).
If it fails, **halt immediately** with: *"Cannot reach Linear MCP. Run `/workflows:smoke-test` to
diagnose."* — and file nothing. Both branches gate on this identically.

## Plugins-repo detection (single source — BC-12535 scope-add)

Several steps need to know **"am I running inside the brite-claude-plugins repo?"** (e.g. whether the
agent-tooling branch can read/write the test registries, or whether a "product" report is actually
sitting in the tooling repo). Use this one signal everywhere:

> **You are in the plugins repo** if the repo root has `.claude-plugin/marketplace.json` **OR**
> `git remote get-url origin` resolves to `brite-claude-plugins`.

This is the robust form (it survives a bare working dir, where `git rev-parse --is-inside-work-tree`
alone would mislead). Detecting mere **repo presence** (developer vs operator mode) is a *separate*
concern — `git rev-parse --is-inside-work-tree 2>/dev/null` — and is not this signal.

## Duplicate search (before filing)

1. Extract 2–4 significant keywords from the title / description.
2. Call `list_issues` with those keywords as `query`, **scoped to the resolved team**, `limit` 10.
3. Filter to **open** issues only (not Done / Canceled).
4. If matches exist, present them for disambiguation **using the inline cap-proof contract in the
   command body** (numbered text list + "reply with the number, or none"). Do not re-derive that
   presentation rule here.
5. If the reporter picks a number → offer to add their report as a `save_comment` on that existing
   issue; after commenting, show the issue ID + link and **stop** (do not also file a new ticket).
6. If they reply "none", or the search returns nothing → proceed to filing.

## Preview & confirm gate (before any write)

Always show a structured **preview** of what will be filed and get explicit confirmation before
calling `save_issue` — **never file without the reporter confirming**. The preview's *field layout*
is command-specific (product intake shows Title / Product → Team · Project / Kind / Labels /
Priority / body; the tooling branch shows Classification / Trigger / Actual / Expected / Test case /
Environment). The shared rule is: preview first, confirm-gate ("File it" / "Edit first"), and let the
reporter correct the destination, labels, or redactions before anything is written.
