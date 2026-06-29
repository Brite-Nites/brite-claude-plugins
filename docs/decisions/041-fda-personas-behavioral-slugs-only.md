# 041. FDA `personas:` is behavioral persona-doc slugs only; RBAC/access roles live elsewhere

**Status:** Accepted
**Date:** 2026-06-28
**Linear:** [BC-14035](https://linear.app/brite-nites/issue/BC-14035) (brite-lseo `personas:` converge — the consumer that surfaced this) · [BC-11983](https://linear.app/brite-nites/issue/BC-11983) (FDA quality-enforcement epic)
**Related ADRs:** [029](029-fda-canonical-flow-doc-key.md) — `personas:` is one of the 20-key story canon; this ADR specifies its **value** semantics, which ADR-029 left implicit · [040](040-fda-flow-id-opaque-identifier.md) — the **inverse** precedent this ADR reasons from

## Context

The persona subsystem (BC-12905 C2 / flow-architecture PR #505) shipped a 3-layer stack: the deterministic existence FLOOR (`scripts/lib/flow_persona_lint.py`, BC-12573 — every non-empty story `personas:` slug must resolve to `docs/product/personas/<slug>.md`), an LLM depth grader (`quality-reviewer` `doc_kind: persona_doc`, rubric P1–P5), and the `persona-doc-author` agent. The canonical persona template (`templates/docs/templates/persona.md`) defines a persona as a **behavioral** profile of one role — anchored on the mental unit, the failure they can't absorb, how they think, what they see and don't, their hand-offs, and their own words.

The existence lint is currently **latent** — it runs only as a plugin fixture self-test in `validate.sh` (Section 2b-persona-exists), not yet against consumer repos (it is in neither `run_fda_ci_audit.py` nor `commands/audit.md`). Pointing it at the fleet surfaces a convention question ADR-029 never explicitly decided: **what does the `personas:` front-matter key MEAN?**

ADR-029's 20-key story canon lists `personas:` but never *defined its value semantics* — it was simply "the personas this flow serves," and the canonical repos (brite-roster, brite-base) happened to use lowercase behavioral role-slugs that match persona-doc filenames. One consumer diverged: **brite-lseo** uses `personas:` as **RBAC access-role enums** — `[ADMIN, MANAGER, EDITOR]` (32×), `[ADMIN, MANAGER, EDITOR, VIEWER]` (23×), plus annotated forms `[ADMIN, MANAGER (manual); SYSTEM (cron)]` — across all 97 stories. None resolve to a persona doc; meanwhile brite-lseo's two *real* behavioral persona docs (`area-executive`, `marketing-growth`) are referenced by no story. So `personas:` carries two incompatible meanings across the fleet: "the behavioral personas served" (the canon) vs "the access roles permitted" (brite-lseo).

This is structurally the same shape as the `flow_id` value-format divergence ADR-040 resolved — one consumer using a field differently than the canonical repos. But the resolution is the **opposite**, and the difference is the crux:

- ADR-040 made `flow_id` **opaque** because **nothing in the system parses its internal structure** — `domain` was always an explicit, separately-sourced fact, so the `DOMAIN-NN` shape was an accident, not a constraint. The fix was to stop treating `flow_id` as carrying meaning the tooling reads.
- `personas:` is the **inverse**: its value is **referential by design**. The existence lint's entire job is "does this slug resolve to a persona doc"; the depth grader scores the resolved doc; the journey author and each story's `## Actor` cross-link to it. The meaning *is* read, by three layers. You cannot make `personas:` opaque without gutting the persona subsystem.

So where ADR-040 protected `flow_id` by declaring it has no internal meaning to enforce, this ADR protects `personas:` by **pinning its one meaning** and keeping foreign meanings out of it.

## Decision

**The `personas:` story-doc front-matter value is a list of behavioral persona-doc slugs — nothing else. Each non-empty slug MUST resolve to `docs/product/personas/<slug>.md`. RBAC / access-control roles are NOT personas and do not belong in this field.**

Consequences of the invariant:

- **`personas:` is referential, single-meaning, fleet-wide.** A slug names a behavioral persona that has (or will have) a doc. Honest-empty (`personas: []` / absent / `null`) is legal and means "no behavioral persona is the protagonist of this flow" (e.g. pure automation) — **presence, not non-emptiness**, is what the floor checks (unchanged from BC-12572/BC-12573).
- **No gate carve.** The existence lint is **not** widened to tolerate non-resolving values (e.g. by skipping uppercase-shaped tokens). A shape-based carve would bake an accidental convention (uppercase = not-a-persona) into the floor and commit it to distinguishing "RBAC enum" from "persona slug" forever — the exact format-pluralism ADR-040 rejected for `flow_id` ("one rule, not two formats"). The lint stays strict; off-canon consumers converge.
- **RBAC / access roles, where a flow genuinely gates on them, are expressed in the story body** — the Gherkin acceptance criteria, or a prose access note — the human-readable spec surface where authorization rules already live. They do **not** get a parallel front-matter key. Minting a repo-local `access:` / `rbac_roles:` key is rejected: it is the same drift in a new field — non-canonical, read by no tooling, used by no other repo.
- **brite-lseo converges** ([BC-14035](https://linear.app/brite-nites/issue/BC-14035)): its ~97 stories re-point `personas:` to the served behavioral personas (`marketing-growth` for HQ flows, `area-executive` for field/territory-scoped, `[]` for automation), the RBAC enums leave front-matter, and its two existing persona docs are linked and migrated to the canonical spine. This is a consumer-repo migration gated on this ADR, not a tooling change.

## Consequences

- The persona-exists floor (BC-12573) needs **no code change** — it already enforces exactly this invariant. This ADR is the *spec* it enforces, written down so a future reader doesn't rediscover the convention cold from a 256-violation lint run.
- The canonical persona template comment and the `flow_persona_lint.py` docstring gain a one-line statement of the invariant, so authors meet it where they work (the template) and where they debug (the lint), not only in this ADR.
- This ADR is the convention BC-14035 (brite-lseo converge) implements and BC-14017 (fleet depth migration) applies when classifying ambiguous slugs (e.g. brite-base's `admin` — a behavioral persona, or an access-tier of `owner`?). It also un-blocks BC-14036 (wiring the floor into `/flow:audit` once the fleet is clean).
- `personas:` joins `flow_id` as a now-explicitly-specified value within the ADR-029 story canon: ADR-040 specified `flow_id`'s value (opaque, safe-charset); ADR-041 specifies `personas:`'s value (resolving behavioral-persona slugs). ADR-029's key list is untouched.
- This is a docs + template-comment + docstring PR; `templates/` and `scripts/` are cache-keyed, so it bumps `plugins/flow-architecture/.claude-plugin/plugin.json` + the matching `.claude-plugin/marketplace.json` entry (BC-6000 same-commit rule) to **1.2.28**. No new `validate.sh` section is warranted — the existing 2b-persona-exists fixture lock already guards the lint behavior this ADR specifies.

## Out of scope (flagged, not actioned)

- **The fleet depth migration** (thin / unauthored personas → canonical spine) is BC-14017; **wiring the floor into `/flow:audit` + CI** is BC-14036 (gated on the fleet being clean). This ADR decides only what `personas:` *means*.
- **brite-base's `admin` slug classification** is deferred to BC-14017's authoring pass — this ADR gives it the lens (behavioral-persona vs access-tier), not the verdict.
- **A general "where do access roles live in FDA docs" convention** beyond "not in `personas:` — use the body/AC" is not specified here. No consumer besides brite-lseo has needed it, and minting an `access:` canon speculatively would repeat the very drift this ADR closes.

## Rejected alternatives

- **Carve the gate to tolerate RBAC-shaped values** (skip uppercase / non-kebab tokens). Cheap (a few lines in `flow_persona_lint.py`), but it sanctions `personas:` carrying two meanings and commits the floor to telling them apart by shape forever — an accidental convention, not a real one. This is the format-pluralism ADR-040 explicitly rejected for `flow_id`. Rejected: protect the field's single meaning instead.
- **Re-home RBAC to a new `access:` / `rbac_roles:` front-matter key.** Keeps the information in front-matter and feels tidier than dropping it, but it is the same drift relocated: a repo-local key no FDA tooling reads and no other consumer uses, which a future gate author must then learn to ignore. Rejected in favour of expressing genuine access rules in the body/AC, where authorization is already specified.
- **Make `personas:` opaque, à la ADR-040.** Superficially symmetric with the `flow_id` precedent, but it inverts that ADR's actual reasoning: `flow_id` could be opaque because nothing reads its structure; `personas:` is read by three layers (existence floor, depth grader, journey/story cross-links). Opacity would gut the persona subsystem. Rejected: the precedent's *method* (pin the field to one well-reasoned rule) applies; its *answer* (opacity) does not.
- **Leave brite-lseo off-canon + documented** (ADR-040's rejected status-quo option, mirrored). Records the divergence but leaves 256 latent violations that false-fire the day BC-12573 is wired into `/flow:audit` — the "gate cries wolf → gets ignored" failure mode (BC-13030) the epic exists to prevent. The convention is a one-paragraph decision with a mechanical (if sizable) consumer migration; documenting-without-converging trades a contained migration now for a fleet-wide false-fire later. Rejected.
