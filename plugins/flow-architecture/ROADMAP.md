# flow-architecture — Roadmap

The FDA plugin ships in **6 phases** spanning design, org-prerequisites, scoping, implementation, dogfood, and release. Phases 1-3 closed during the design interview (May 2026); Phase 4 is the current focus.

## Phase status

| # | Phase | Status | Date |
|---|---|---|---|
| 1 | Design close | Done | 2026-05-08 |
| 2 | Org PRs landed | Done | 2026-05-10 |
| 3 | Linear scoping | Done | 2026-05-10 |
| 4 | Plugin implementation | **In progress** | starting 2026-05-10 |
| 5 | Brand Hub dogfood | Pending | — |
| 6 | Release v1.0 | Pending | — |

## Phase 1 — Design close (done 2026-05-08)

54 active Q-numbers locked across the multi-session design interview, 16 amendments, 55 parking-lot entries. Canonical record at `docs/design-rationale/fda-plugin-interview.md` (2,306 lines). Synthesis at `docs/design-rationale/fda-plugin-architecture-overview.md`.

## Phase 2 — Org PRs landed (done 2026-05-10)

- handbook PR #513 — CDR-023 (Flow-Driven Architecture) + CDR-014 amendment + ops-standards FDA page
- handbook PR #514 — 12 FDA templates in about-handbook/style-guide/templates/

## Phase 3 — Linear scoping (done 2026-05-10)

Milestone **Flow-Driven Architecture Plugin v1.0** in the Brite Skill Packs project (Layer C; renamed from "Brite Plugin Marketplace" 2026-05-27), 21 issues (3 parents + 18 standalones) under label `flow-architecture`. Per Q1 amendment 1, plugin infrastructure is non-UI-bearing per the Q1 scope test, so it tracks under the CDR-014 Phase Pattern (not the FDA 5-discipline pattern that this plugin is for OTHER products to use).

## Phase 4 — Plugin implementation (in progress)

Bottom-up, drafter-solo per Q9 narrowed lock:

- **4a Foundation** — `skills/_shared/` utilities + `scripts/` bash helpers + `flow-preflight` skill ([BC-6954](https://linear.app/brite-nites/issue/BC-6954) / [BC-6955](https://linear.app/brite-nites/issue/BC-6955) / [BC-6956](https://linear.app/brite-nites/issue/BC-6956) / [BC-6957](https://linear.app/brite-nites/issue/BC-6957))
- **4b Sub-skills + agents** — Q11-Q21 (9 sub-skills + 12 named agents) ([BC-6959](https://linear.app/brite-nites/issue/BC-6959) / [BC-6960](https://linear.app/brite-nites/issue/BC-6960))
- **4c Orchestrators** — `/flow:start-project`, `/flow:retrofit-project`, `/flow:add-domain`, `/flow:add-sub-flow` (Q37, Q47) ([BC-6962](https://linear.app/brite-nites/issue/BC-6962) / [BC-6963](https://linear.app/brite-nites/issue/BC-6963) / [BC-6964](https://linear.app/brite-nites/issue/BC-6964) / [BC-6965](https://linear.app/brite-nites/issue/BC-6965))
- **4d Utility commands** — `/flow:audit`, `/flow:office-hours`, `/flow:retro` (Q38, Q42, Q44) ([BC-6969](https://linear.app/brite-nites/issue/BC-6969) / [BC-6971](https://linear.app/brite-nites/issue/BC-6971) / [BC-6972](https://linear.app/brite-nites/issue/BC-6972))
- **4e Clone-and-swap** — `/flow:session-start`, `/flow:review`, `/flow:ship` cloned from workflows plugin with FDA-swap (Q50-Q53) ([BC-6973](https://linear.app/brite-nites/issue/BC-6973) / [BC-6975](https://linear.app/brite-nites/issue/BC-6975) / [BC-6977](https://linear.app/brite-nites/issue/BC-6977))
- **4f Plugin CLAUDE.md + production readiness** — Q55 spinoff + Q40 release gate ([BC-6996](https://linear.app/brite-nites/issue/BC-6996) / [BC-6997](https://linear.app/brite-nites/issue/BC-6997))

Implementation goal is vertical slices — get one orchestrator end-to-end working before adding depth.

## Phase 5 — Brand Hub dogfood (pending; Q8 v1.0 acceptance gate)

Run `/flow:retrofit-project` against the Brand Hub product. First clean retrofit = v1.0 acceptance. Promote parking-lot items revealed by the dogfood pass to v1.1 backlog. Tracked at [BC-6998](https://linear.app/brite-nites/issue/BC-6998).

## Phase 6 — Release v1.0 (pending)

- Tag plugin v1.0.0
- Flip CDR-023 status: Proposed → Accepted in handbook
- Re-triage parking lot for v1.1 backlog
- Trigger CDR-023 dual-event triage (per Q40 release sequence)

Tracked at [BC-6999](https://linear.app/brite-nites/issue/BC-6999).

## Reference

- Canonical design rationale: `docs/design-rationale/fda-plugin-interview.md` (2,306 lines, 54 Q-locks)
- Architecture synthesis: `docs/design-rationale/fda-plugin-architecture-overview.md`
- Resume bridge: `docs/design-rationale/00-resume-bridge.md`
- Handbook CDR: [CDR-023 Flow-Driven Architecture](https://github.com/Brite-Nites/handbook/blob/main/decisions/CDR-023-flow-driven-architecture.md)
