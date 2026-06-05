# 022. Unified intake front door — `raise-a-ticket` forks product vs agent-tooling

**Status:** Accepted
**Date:** 2026-06-04
**Linear:** [BC-12534](https://linear.app/brite-nites/issue/BC-12534) (front-door restructure) +
[BC-12400](https://linear.app/brite-nites/issue/BC-12400) (option-cap), under epic
[BC-12532](https://linear.app/brite-nites/issue/BC-12532). Originated in a `/grill-with-docs`
session (2026-06-04).
**Supersedes (in part):** [ADR-021](021-raise-a-ticket-intake.md) — reverses its "keep
`raise-a-ticket` and `report-issue` separate" consequence. The rest of ADR-021 (Linear-native,
cross-product, `needs-triage`→`/triage`, existence-aware labels, `bug-report` deprecation) stands.
**Related CDRs:** CDR-016 (type axis), CDR-018 (label/field standards).
**Companion docs:** [`CONTEXT.md`](../../CONTEXT.md) (glossary: Intake, Report kind, Ticket),
[`plugins/workflows/commands/raise-a-ticket.md`](../../plugins/workflows/commands/raise-a-ticket.md),
[`plugins/workflows/commands/report-issue.md`](../../plugins/workflows/commands/report-issue.md).

## Context

ADR-021 shipped `/workflows:raise-a-ticket` (product feedback → `needs-triage` → `/triage`) and
deliberately **kept it separate** from `/workflows:report-issue` (agent-tooling misbehavior →
regression-test registry). Two months of use surfaced the cost of that separation: a reporter
with "something's wrong" must **pre-classify product-vs-tooling before they can even pick a
command** — work the software should do for them. The only safety net was a **location-only
redirect**: `raise-a-ticket` redirected to `report-issue` when run *inside the plugins repo*,
based on repo location, not on what was being described. So a tooling complaint filed from a
product repo (or in operator mode) silently mis-filed as a product bug, and a product bug
described to `report-issue` was never caught.

Two adjacent defects shared the same Step-1 region:

- **Option-cap overflow (BC-12400).** `raise-a-ticket`'s duplicate-check and product picker
  built `AskUserQuestion` option lists one-per-candidate; with 6 duplicate matches or 46 active
  projects, that exceeds AskUserQuestion's hard **4-option** cap.
- **Multi-team mis-resolution (BC-12400).** A product project can span >1 team; `Brite Base`
  returns `[Brite Supply, Brite Company]` (Supply first) yet all its issues live in Brite
  Company, so a naïve "first team" pick mis-routes.

## Decision Drivers

- **The product-vs-tooling distinction isn't obvious to a reporter**, and the growth trajectory
  is toward *more, less-technical* Claude-Code users over time — "one door, no pre-classification"
  is the durable shape.
- **Cheapest to change now.** Only ~15 people hold the current two-command mental model; the
  cost of reversing ADR-021's separation rises with adoption.
- **`report-issue`'s regression-test purpose is real and must survive** — it is not a subset of
  product intake (it generates a permanent test from a misbehavior). Keep it, don't fold it away.
- **Disambiguation must never break on real data.** A prompt that can exceed the option cap is a
  latent runtime failure, not a cosmetic nit.

## Decision

Make `/workflows:raise-a-ticket` the **single intake front door**. It opens with one question —
*"Is this about a Brite **product**, or the **agent tooling** itself (a skill/command/hook)?"* —
and dispatches:

1. **Product →** the existing product-intake flow (resolve product → team+project →
   `needs-triage` → hand to `/triage`). Unchanged from ADR-021.
2. **Agent tooling →** hand off to `/workflows:report-issue`'s existing flow (failure taxonomy +
   regression-test generation), by **dispatch** ("read and follow `report-issue.md`
   end-to-end"), so `report-issue` remains the single source of truth — no inlined copy.

Supporting decisions:

- **`report-issue` stays a direct expert alias** into the tooling branch — **not deprecated.**
  Developers keep their mid-session shortcut to the test-gen flow. `bug-report` remains a
  forwarding shim to `raise-a-ticket`.
- **The fork is content-aware.** Inference of the likely side pre-selects it (confirm-gated);
  if the description *clearly* reads as the other kind, the command **offers to switch**
  branches. This **replaces** ADR-021's location-only redirect. It never silently reroutes.
- **Graceful degrade for the tooling branch.** When `report-issue`'s flow runs **outside the
  plugins repo** (operator mode, or dispatched from a product repo), it files the Linear issue
  and classifies the failure but does **not** read/write the test registries — it records that a
  maintainer can append the regression test. The guard reuses the plugins-repo signal
  (`.claude-plugin/marketplace.json` at root OR origin remote `brite-claude-plugins`) and lives
  **in `report-issue.md`**, so both the direct alias and the dispatched front-door honor it.
- **Cap-proof disambiguation (BC-12400).** Every candidate set — duplicate matches, the operator
  product picker, multi-team teams — is rendered as a **numbered text list + a single free-text
  "reply with the number, or none" follow-up**, never an `AskUserQuestion` whose options scale
  with the candidate set. A `validate.sh` lint
  ([`plugins/workflows/tests/test-intake-option-cap.sh`](../../plugins/workflows/tests/test-intake-option-cap.sh))
  enforces the invariant.
- **Multi-team modal default (BC-12400).** When a resolved project spans >1 team, default to the
  team where its issues predominantly live (a light `list_issues` tally), falling back to Brite
  Company; surface it in the preview for override.

## Alternatives Considered

- **Keep two separate commands (status quo / ADR-021).** Rejected: forces the reporter to
  pre-classify, and the location-only redirect mis-files what it can't see.
- **Inline `report-issue`'s flow into `raise-a-ticket`'s tooling branch.** Rejected: duplicates
  ~290 lines and manufactures the exact drift a sibling slice (BC-12535, shared-mechanics
  extraction) is chartered to remove; creates a "which copy is canonical?" problem for the alias.
- **Deprecate `report-issue`, fold everything into one command.** Rejected: erases the
  regression-test entry point developers rely on and removes a useful expert shortcut.
- **Keep per-candidate `AskUserQuestion`, just cap the visible matches at 3.** Rejected: leaves
  the 46-project picker unsolved and re-introduces the magic boundary number that caused the bug.
- **Always ask the fork cold (no inference).** Rejected as the default: the epic's thesis is that
  the software should do the classification work; inference-with-confirm keeps the front-door
  guarantee while making the common case one keystroke.

## Consequences

- One discoverable entry point for all reporting; the reporter never pre-classifies. `report-issue`
  and `bug-report` keep working (alias / shim) so nothing breaks during the transition.
- `report-issue` gains an out-of-repo mode (graceful degrade); its registry writes are now
  guarded rather than assumed, which also hardens the direct-alias path when a developer runs it
  from the wrong directory.
- **Shared-mechanics drift is acknowledged, not yet resolved.** The secret-redaction pattern list
  and the reachability/dedup/preview mechanics remain duplicated between the two commands (the
  product branch keeps its own copies). Extracting them to a single canonical source under the
  `commands/_shared` convention is **BC-12535** (out of scope here); this ADR deliberately ships
  the front door first so the comms/map describe the final shape. *(Resolved 2026-06-05 by BC-12535:
  the redaction list lives in `_shared/intake-redaction.md` and the reachability/dedup/preview +
  plugins-repo-detection mechanics in `_shared/intake-mechanics.md`, both cited by the two commands
  and lint-enforced; the cap-proof disambiguation contract stays inline, guarded per-site by the M3
  lint.)*
- The content-aware switch leans on a model judgment ("clearly the other kind"); it is
  confirm-gated, so a wrong inference costs one extra prompt, never a silent mis-file. *(The
  "(and vice-versa)" reverse direction is now a coded step — BC-12591 added a confirm-gated
  tooling→product switch in `report-issue.md` Step 1d; raise-a-ticket Step 1c's switch is
  one-directional product→tooling by construction, since picking "tooling" at Step 1a dispatches
  before Step 1c is reached.)*
- ADR-021's other consequences are unaffected: Linear-native cross-product routing,
  existence-aware labels, the `needs-triage`→`/triage` boundary, and `bug-report`'s deprecation
  all stand.
