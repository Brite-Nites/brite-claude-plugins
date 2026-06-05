# 021. `raise-a-ticket` — Linear-native, cross-product intake that feeds `/triage`

**Status:** Accepted — *amended 2026-06-04 by [ADR-022](022-unified-intake-front-door.md)*,
which supersedes the **"keep `raise-a-ticket` and `report-issue` separate"** consequence:
`raise-a-ticket` is now the single intake **front door** with a Step-1 product-vs-tooling fork
that dispatches tooling reports to `report-issue`. Everything else in this ADR (Linear-native,
cross-product routing; `needs-triage`→`/triage`; existence-aware labels; `bug-report`
deprecation) still stands.
**Date:** 2026-06-02
**Linear:** [BC-12394](https://linear.app/brite-nites/issue/BC-12394) (originated in a `/grill-with-docs` design session, 2026-06-02)
**Related ADRs:** [ADR-003](003-plugin-distribution-architecture.md)
**Related CDRs:** CDR-016 (Issue Standards — the `type:*` axis + bug repro requirement), CDR-018 (Label & Field Standards — `severity:*`, `executor:*`, triage flat labels)
**Companion docs:** [`CONTEXT.md`](../../CONTEXT.md) (glossary: Product, Build Project, Report kind, Severity, Intake, Triage, Ticket), [`docs/agents/issue-tracker.md`](../agents/issue-tracker.md), [`docs/agents/triage-labels.md`](../agents/triage-labels.md)

## Context

Reporting a bug or giving feedback on a Brite **Product** (Brite Base, Brite Sites, Brite
Supply, a Brite Labs site, …) had no good home. Three overlapping intake paths existed, none
fitting:

- **`/qa`** — conversational intake, but **deprecated upstream** (`mattpocock/skills/skills/deprecated/qa/`) and hardcoded to `gh issue create`. It never read the tracker config, so it files to GitHub Issues — the wrong tracker (Brite issues live in Linear). It is also a user-level vendored skill, not a Brite plugin.
- **`/workflows:bug-report`** — Linear-native but **developer-only and single-destination**: it makes the reporter hand-pick the team/project every time (no cross-product routing), is Bug-only, applies a non-canonical `"Bug"` label (CDR-016 canon is `type:bug`), and never applies `needs-triage`.
- **`/workflows:report-issue`** — narrowly about **plugin misbehavior** (regression-test registry), not product feedback.

Separately, the `mattpocock/skills` architecture (which Brite already uses) is a **config-consumer pattern**: a one-time `/setup-matt-pocock-skills` writes `docs/agents/issue-tracker.md` + `docs/agents/triage-labels.md`, and consumer skills speak abstract operations ("publish to the issue tracker"). Per that repo's `docs/adr/0001`, only **hard-dependency** skills (`to-issues`, `to-prd`, `triage`) must have that config. Linear is supported via the "other/custom" escape hatch — exactly what Brite's `docs/agents/issue-tracker.md` already is. `/triage` is the downstream processor (state machine, reproduction, grilling, agent briefs); intake is meant to be **thin** and feed it.

The gap: a **Linear-native, cross-product, operator-friendly intake** command that produces a clean `needs-triage` issue and hands off to `/triage`.

## Decision Drivers

- **Routing is the unfilled need.** Products span multiple Linear teams (Brite Company, Droidor, Brite Supply, Brite Labs). The reporter shouldn't have to know the destination.
- **Don't duplicate `/triage`.** Reproduction, grilling, and agent-brief authoring belong downstream. Intake stays thin to keep the boundary clean.
- **Reuse the established config surface.** `docs/agents/issue-tracker.md` already encodes a repo's Linear destination; reusing it adds no new config type and rides the upstream-sanctioned consumer pattern.
- **Canonical labels, existence-aware.** Apply the CDR-016 type axis (`type:bug` / `type:task`), `needs-triage`, the `executor:hybrid` default, and CDR-018 `severity:sevN` (bugs) — but only labels actually provisioned in the target team (the canon is mid-rollout; e.g. `severity:*` is not yet created in Brite Company). Fixes bug-report's non-canonical `"Bug"` label in the product-intake path.
- **One reporter, two contexts.** Engineers (in a repo) and operators (anywhere) both file through one command.

## Decision

Ship **`/workflows:raise-a-ticket`** — a typed command in the `workflows` plugin that performs **Intake** and hands off to `/triage`. It:

1. **Resolves the Product → Linear (team, project)** repo-context-first: inside a known product repo it reads `docs/agents/issue-tracker.md`; on a miss it lazy-creates that config inline (confirm before writing); outside a repo it asks for a product name / GitHub repo and resolves live. It live-confirms the destination against Linear before filing.
2. Offers **two reporter-facing kinds**: **Bug** → `type:bug` (mandatory Reproduction section; severity captured as a CDR-018 `severity:sevN` label when provisioned, plus Linear priority) and **Idea/Feedback** → `type:task` (the CDR-016 default for non-bugs; no severity). Both get **`needs-triage`** + **`executor:hybrid`**. These are intake buckets, not the full CDR-016 type axis (`type:spike` / `type:chore` / `type:doc` exist too) — the triage stage may re-type.
3. Is **adaptive**: developer mode (in a repo) auto-detects environment and is FDA-aware (proposes a `domain:*` label when the repo is FDA-shaped, best-effort, confirmed); operator mode (anywhere) is plain-language with no dev questions.
4. **Adopts the intake mechanics bug-report established** (now the sole home, since bug-report is reduced to a shim) — Linear-reachability check, duplicate search (+ comment-on-existing), secret redaction, and a draft preview before filing — and adds a **provenance footer**.
5. Is **conversational in, structured preview out**, and deliberately **does not** reproduce, grill, or write agent briefs.

`/workflows:bug-report` is **deprecated** and forwarded to `raise-a-ticket` via a shim. `/workflows:report-issue` (plugin misbehavior) is unaffected. *(Amended by [ADR-022](022-unified-intake-front-door.md): `report-issue` is now also reachable as the agent-tooling branch of the `raise-a-ticket` front door, while remaining a direct expert alias.)*

## Alternatives Considered

- **Extend `bug-report` in place** — rejected: rewrites a command in muscle memory and bends its simple single-destination shape; a clean successor + shim is lower-risk.
- **Revive / Brite-ify `/qa`** — rejected: it's deprecated upstream and architecturally a non-consumer (hardcoded `gh`); wrong exemplar.
- **A central product→destination registry** (one file or user-level index) — rejected for v1: per-repo `issue-tracker.md` is the established pattern, co-locates routing with each product, and needs no new surface. Revisitable if out-of-repo runs dominate.
- **New plugin (`brite-core` / `feedback`)** — rejected: splits Linear-MCP commands across plugins and leaves the `docs/agents` pattern's home; `brite-core` has no commands yet.
- **Thick intake (reproduce/grill at intake)** — rejected: duplicates `/triage` and blurs the intake/triage boundary.
- **Make Linear a first-class tracker template upstream** — out of scope (upstream limits first-class trackers to mainstream tools; Linear rides the "other" escape hatch, which Brite already uses).

## Consequences

- One canonical product-intake path; `bug-report` retired (shim points to the successor). The legacy `"Bug"` label drift is fixed **in the product-intake path** — `report-issue` still emits `"Bug"` and is left as a separate follow-up (this ADR scopes it out). *(Resolved 2026-06-05 by BC-12592: `report-issue` now files `type:bug` + `needs-triage` + `executor:hybrid`, existence-aware, mirroring the product branch — both branches of the front door file under one label convention.)*
- Product repos gain a (lazy-created, committable) `docs/agents/issue-tracker.md` as their routing config — the same per-repo config the mattpocock `/triage` and `/to-issues` skills consume. Those consumers are **user-level vendored skills** (`~/.claude/skills/`), not Brite plugins, so the shared-consumer benefit holds only where they're installed.
- Intake quality leans on the triage stage downstream (by design). The `needs-triage` → `ready-for-agent`/`ready-for-human` pipeline is now fed by a Linear-native, cross-product front door.
- **`/triage` is an external dependency.** The handoff target is the user-level mattpocock `/triage` skill, not a Brite plugin command. Where it isn't installed, `needs-triage` tickets simply wait for manual triage — intake is still complete, but the automated pickup the flow implies requires that skill present. The command's confirmation says so rather than promising pickup.
- **Label canon is mid-rollout.** CDR-016/CDR-018 define more labels than the Linear workspace has provisioned (e.g. `severity:*` is not yet created in Brite Company; a legacy flat `"Bug"`/`"Feature"` set persists). Intake is therefore existence-aware: it applies canonical labels that exist and falls back (priority for severity; the built-in **Triage** state for `needs-triage`) otherwise, never auto-creating workspace groups. The `severity:sevN` ↔ Critical/High/Medium/Low ↔ Linear-priority mapping the command uses is a local operationalization — CDR-018 fixes `sev2` as the default but does not define the full sevN→priority mapping; making it canonical is a follow-up handbook (CDR-018) edit, not part of this change.
- Future option: a user-level index to make out-of-repo guessing smarter; promote only if that path proves common.
