# Design: FDA Quality + Enforcement

**Status**: Draft for approval (brainstorm + grill, 2026-05-28)
**Author**: holden + Claude
**Scope**: flow-architecture plugin (+ handbook job-story template; + new Mobbin enrichment)
**Supersedes/relates**: builds on CDR-023, Q7/Q15/Q21/Q27/Q29/Q46/Q48 locks; ADR-008 (enrichment pluggability)

---

## Problem

FDA's *mechanical* floor is mature (36-gate `/flow:audit`, 4 dedicated `validate.sh` CI sections, `fidelity-reviewer`, `verify-docs.sh`, `verify-linear-references.mts`). But the artifacts FDA *generates* have regressed below the hand-written BriteBase bar: stories are weaker and sub-flows coarser. The existing `fidelity-reviewer` only checks **template structure** (has 3–5 Gherkin, the `When/I want/so I can` regex), so it green-lights structurally-valid-but-substantively-weak output. Nothing enforces **quality**, **granularity**, or **grounding in real-world flows**.

### Evidence (6-repo teardown, 2026-05-28)

Gold standard: `brite-base` (hand-written, no `.flow/config.json`) — 398 flows / 28 domains, 4–43 flows/domain, rich job stories, 4–6 concrete Gherkin ACs each (exact field names, enum values, error strings, tenant-boundary scenarios), behavioral per-domain personas, honest gap annotations.

FDA-generated repos, by plugin version:

| Repo | Version | Key defects observed |
|---|---|---|
| `brite-roster` | (pre-version-field) | UPPERCASE codes (SFI-01); strong job stories; `blockedBy` never wired (prose-only); labels backfilled post-hoc (BC-11118); stub-flow SFI-05 still has 5 live children |
| `brand-hub` | 0.2.24 | `[flow-id]` bracket titles (old); `BRI-` (wrong-team) ID leak; status vocab drift (`NOT BUILT` vs `NOT_STARTED`); crm-sync children `NO_MILESTONE`; iter-1 zero labels |
| `brite-labs-site` | 1.2.3 | persona copy-paste across all 23 docs; infra flows forced into job-story frame ("When I'm a search engine crawler"); zero labels; no native Linear parent (title-prefix only) |
| `brite-sites` | 1.2.5 | **every** doc: job-story grammar collapse ("So I can 100-400+ pages are available"); **all 28 ACs are identical circular boilerplate** ("Then the outcome described in 'So I can…' holds true"); semantic filenames (no stable numeric FK) |
| `brite-supply-react` | 1.2.4 | grammar collapse; **label-contamination bug: all 33 `[Design]` children carry `type:eng`**; duplicate issue (DRO-586/588 both `[Design] Error Pages`); 141/208 children `NO_MILESTONE`; semantic filenames |

### Root cause (three layers)

1. **Generation bugs in the authoring agents (biggest, cheapest wins).** `story-doc-author` is *explicitly coded to defer*: its conventions say _"Never invent. … If a required field has no source, leave it as `TBD`."_ When the dispatcher passes thin `partial_state` (because substance was deferred to `/flow:plan-*`), the agent jams the flow title into the `When/I want/so I can` frame with no real motivation → grammar collapse; and emits the template's placeholder AC skeleton → boilerplate ACs. Persona copy-paste originates in the dispatcher (`flow-doc-author`) passing one generic persona for all flows. **The thinness is the designed behavior, not an accident.**
2. **Linear scaffolding defects (mechanically detectable).** Label↔discipline contamination, duplicate children, `blockedBy` never wired, children missing milestone, zero labels/priorities, parent/child by title-prefix only.
3. **Version drift + by-design deferral.** Versions span 0.2.24→1.2.5; real ACs/discipline children were *intended* to come from `/flow:plan-*`, which was **never run** on any of the 5 repos → 100% sit as thin shells.

Granularity cuts both ways: under-decomposition (coarse) *and* over-decomposition (brite-supply `entity-pages`: 6 near-identical PIM pages → 30 children; brite-labs `offer-template`: 5 sub-flows for one known offer).

---

## Resolved model (the fork)

**Front-load substance into the story doc at scaffold (Option A); `/flow:plan-*` becomes refinement, not authoring.**

| | Owner | Content |
|---|---|---|
| **WHAT** (the contract) | **story doc** @ scaffold (`story-doc-author` + `flow-doc-author`) | grammatical, outcome-specific job story · 3–5 *real* Gherkin ACs (fields, enums, errors, security/edge) · per-domain behavioral persona · preconditions · out-of-scope w/ owning IDs. Discipline-agnostic shared truth. |
| **HOW** (the execution) | **`/flow:plan-*`** @ session-start (refinement) | per-discipline elaboration *against* the fixed WHAT — eng tasks + file paths, QA test plan from the ACs, design specs/Figma, docs plan. Refines, never re-authors the WHAT. |

Keeps docs tight (BriteBase docs are 80–150 lines — depth is *precision*, not volume); per-discipline HOW lives in children and refreshes independently → avoids the monolith failure mode.

**Open wrinkle (recommendation):** with the WHAT in the doc, `plan-story` has little left. Make it a thin **"finalize AC + lock the AC↔test mapping"** step (the BriteBase `describe("X AC coverage")` binding table) or fold it into the story-doc quality gate. — *confirm before building WS-B.*

---

## Approach: hybrid by nature of check

- **Deterministic invariants** → bash/mts **lib + fixture-harness + `validate.sh` section**, cloned from `scripts/_lib/agent_skills_drift.sh` + the `2bN` pattern (honors Q7: filesystem-artifact-existence, not LLM self-report). CI-runnable.
- **Judgment-bound work** (quality/style, structural improvement) → **skill-creator-authored skills + rubric references + reviewer agents**.
- **Atomic**: one invariant / one concern per unit, regardless of mechanism.

Do **not** rebuild: the 36-gate stack, `/flow:audit`, `fidelity-reviewer`, `verify-docs.sh`, `verify-linear-references.mts`, `regenerate-flow-index.mts --check`, Q46 writeback, the four-mode enum.

---

## Atomic units, by tier

### Tier 0 — fix the generation bugs (highest leverage, cheapest)
Fixes in the flow-architecture authoring layer; each ships with a regression-lock.

- **T0-1** · `story-doc-author` mandate flip: from "never invent / leave TBD" → "derive a grammatical, outcome-specific job story + 3–5 substantive ACs grounded in intent + journey + code signals, to the BriteBase bar." (regression-lock: grammar/verb-presence + non-boilerplate-AC fixtures)
- **T0-2** · `flow-doc-author` dispatcher: pass an **individuated per-domain persona** (from journey/persona docs), not one generic string for all flows.
- **T0-3** · handbook `job-story.md` template: replace the placeholder AC skeleton ("Then the outcome described in 'So I can…' holds true") with a real BriteBase-grade exemplar. *(cross-repo: handbook PR)*
- **T0-4** · infra/platform flows: alternate story pattern (engineering-constraint spec) instead of forcing `When/I want/so I can` onto non-human actors.

### WS-A — deterministic lints (lib-trio each; CI + optionally a new `/flow:audit` gate)
- **A-1** · job-story grammar / verb-presence lint (catches the collapse)
- **A-2** · persona-not-generic lint (frontmatter persona ≠ template default; matches job-story actor)
- **A-3** · AC-not-boilerplate detector (flags the circular placeholder)
- **A-4** · **label↔title-prefix contamination lint** (catches `[Design]`→`type:eng`)
- **A-5** · `blockedBy`-wiring check (prose blocker ↔ Linear `blockedBy` edge)
- **A-6** · child-milestone-inheritance check
- **A-7** · duplicate-discipline-child detector
- **A-8** · inventory two-identifier consistency (UPPERCASE code ↔ kebab slug derivable) + reconcile the two-schema conflict
- **A-9** · flow-ID immutability guard (diff-aware; `-a/-b` split + `[DEPRECATED]` allowed)

### WS-B — story/journey quality (the prize)
- **B-0** · two-layer rubric: `story-quality-rubric.md` + `journey-quality-rubric.md` (app-agnostic **spine**) + `app-type-profiles.md` (**modifiers**: internal-ops / marketing-site / B2B-ecommerce / programmatic-SEO). Sources: BriteBase + general JTBD/PRD principles + Mobbin calibration.
- **B-1** · `quality-reviewer` agent (sonnet) — scores *substance* per rubric dimension, sibling to `fidelity-reviewer` (structure). Read-only.
- **B-2** · eval: score BriteBase high / weak repos low; fix rubric until it discriminates (skill-creator build→eval→improve).
- **B-3** · wire the rubric (+ few-shot anchors) into `story-doc-author` / `journey-doc-author` (closes the loop with Tier 0).

### WS-C — structural-improvement advisory (`/flow:improve-architecture`)
Advisory, **no CI gate**: organic explore → classify (split / merge / deepen) → graded `$TMPDIR` HTML report (Strong / Worth-exploring / Speculative) → grill → defer-to-user. Reuses L1/L3 reviewer fan-out + four-mode verdicts. Attacks the over/under-decomposition.

### WS-D — Mobbin flow-reference enrichment (two-phase)
- **D-1** (read-only): sample the 4 verticals → fill `app-type-profiles.md` + granularity bands. (Mobbin MCP connected; OAuth done.)
- **D-2**: ADR-008-shaped pluggable flow-reference provider; `.mcp.json` gains `mobbin` (deliberate Q30.4/Q32 change — needs a new ADR); consumed by inventory/journey/story authoring.

### WS-E — consumer-repo remediation (gated on Tier 0 + WS-A; **commits, no merge**; adversarial review)
Re-run FDA quality against the **7 FDA-generated repos** and fix in place — **NOT** `brite-base` (hand-written gold). Discovered 2026-05-28 via `.flow/config.json`:

| Repo | Linear project | ver | torn down? |
|---|---|---|---|
| brite-roster | Brite Roster | (pre-version) | yes |
| brand-hub | Brand Hub | 0.2.24 | yes |
| brite-labs-site | Brite Labs Website | 1.2.3 | yes |
| brite-supply-react | Brite Supply Headless Storefront (team DRO) | 1.2.4 | yes |
| brite-sites | Brite Sites | 1.2.5 | yes |
| **brite-pim** | Brite Supply PIM | 1.2.5 | **no — diagnose first** |
| **brite-lseo** | LSEO Internal Tool | 1.2.5 | **no — diagnose first** |

Per repo, one workflow, gated on the plugin fixes: (1) **re-author** weak story/journey docs with the fixed `story-doc-author`/`flow-doc-author` (Tier 0) + the quality rubric (WS-B) — grammar collapse, boilerplate ACs, generic personas, infra misfit; (2) **repair the Linear graph** via the WS-A lints — label↔discipline contamination (brite-supply's 33 `[Design]`→`type:eng`), duplicate children, `blockedBy` wiring, child-milestone inheritance, missing labels/priorities. brite-pim/brite-lseo get a diagnosis sub-phase first. **Protocol:** adversarial review per repo (quality-reviewer + lint pass converge); **git commits on a per-repo branch, NO merge** (PR left open); Linear-graph mutations previewed before applying.

---

## Sequencing

```
Tier 0 (T0-1, T0-2)  ──┐ fork-independent, start now
A-1..A-4 lints       ──┤
                       ├─→ B-0 rubric ─→ B-1 reviewer ─→ B-2 eval ─→ B-3 wire-into-authors
D-1 Mobbin sampling  ──┘                    (feeds B-0)
A-5..A-9 lints (independent)
T0-3 (handbook), T0-4 (infra pattern)
WS-C improve-architecture (reuses B-0 rubric)
D-2 Mobbin provider (after D-1 proves value)
```

Each unit = its own small PR with a same-commit plugin version bump (CLAUDE.md gotcha). Plan-* / WS-B targeting depends on confirming the `plan-story` fold (open question).

---

## Proposed Linear decomposition (preview — not yet created)

Umbrella + one BC per unit, in **Brite Plugin Marketplace** (team Brite Company, `BC-`), `blockedBy`-wired per the sequencing graph. Draft titles:

- `[FDA-Q] Epic: FDA quality + enforcement` (umbrella)
- `[FDA-Q] T0-1 story-doc-author: derive substantive job story + ACs (mandate flip)`
- `[FDA-Q] T0-2 flow-doc-author: individuated per-domain persona`
- `[FDA-Q] T0-3 handbook job-story template: replace placeholder AC skeleton` *(handbook repo)*
- `[FDA-Q] T0-4 infra-flow alternate story pattern`
- `[FDA-Q] A-1 job-story grammar lint` … `A-9 flow-ID immutability guard` (9 issues)
- `[FDA-Q] B-0 two-layer quality rubric` … `B-3 wire rubric into authors` (4 issues)
- `[FDA-Q] WS-C /flow:improve-architecture advisory skill`
- `[FDA-Q] D-1 Mobbin vertical sampling → app-type profiles`
- `[FDA-Q] D-2 Mobbin pluggable flow-reference provider (+ ADR)`

---

## Key decisions
1. Hybrid mechanism; skill-half is central (quality is irreducibly judgment).
2. Front-load WHAT into the story doc; `plan-*` refines HOW.
3. Quality rubric is two-layer (spine + app-type profiles), triangulated (BriteBase + Mobbin + principles) — not BriteBase-anchored (overfit risk, per holden).
4. Reviewer-before-author (eval-driven) for WS-B.
5. Inventory = define two identifiers + lint consistency, **not** pick-one.
6. `/flow:improve-architecture` is a separate advisory sibling, not a gate.

## Alternatives considered
- All-SKILL.md skills — rejected (fights Q7, not CI-runnable). All-deterministic-libs — rejected (no home for quality/improve-arch). Thin-doc + fix-plan-* (Option B) — rejected (0/5 real-world adoption of plan-*; "a step nobody runs" is its own verdict). Fold improve-arch into audit — rejected (conflates advisory judgment with gates).

## Risks & mitigations
- Rubric overfit → two-layer + Mobbin triangulation + eval gate.
- Mobbin paid/beta dependency → two-phase keeps WS-B independent of D-2.
- `.mcp.json` change breaks Q30.4 Linear routing → isolated to D-2 + ADR.
- Plugin-version cache staleness → same-commit version bump per unit.
- Bare repo → all work in `.claude/worktrees/`.

## Scope
**In**: Tier 0 + WS-A/B/C/D. **Out**: rebuilding the 36-gate stack / fidelity-reviewer / verify-* ; real Brand-Hub-retrofit validation (the CDR-023 v1.0 gate).

## Open questions
1. `plan-story` fold (thin "finalize AC" step vs merge into story-doc gate) — confirm before WS-B.
2. Inventory canonical-identifier model (UPPERCASE code ↔ kebab slug) — confirm before A-8.
3. Mobbin provider (`D-2`) `.mcp.json` change — ratify via ADR before building.

## Evidence pointers
- 6-repo teardown + reference-skill recon: this session's workflow + agent transcripts (2026-05-28).
- `story-doc-author` "never invent" mandate: `plugins/flow-architecture/agents/story-doc-author.md` §Conventions.
- Mobbin: https://mobbin.com/mcp · https://docs.mobbin.com/overview
