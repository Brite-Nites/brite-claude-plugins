# BC-5879 Session Handoff — COMPLETE (2026-04-21 evening)

**Session date:** 2026-04-21 (both passes)
**Branch:** `holden/bc-5879-fan-out-email-copywriting-active-tier-preset-library-10`
**Worktree:** `.claude/worktrees/bc-5879`

## TL;DR — DONE

Started as "fan out 10 Active-tier Nites preset files" (BC-5879 original scope). Session discovery pivoted the work to a 20-issue roadmap covering 6 Labs-experiential verticals (Zoos, Aquariums, Casinos, Hotels & Resorts, Ski Resorts, Sports Stadiums) + `references/` promotion (frameworks + vendor-landscape + per-vertical playbooks).

**Shipped across 2 passes on 2026-04-21:**
* First pass: master roadmap doc written. Zoos decision ledger preserved. 7 of 20 Linear issues filed (R-1..R-4, R-7..R-9). 6 FAILed verification and needed rewrites; 7 were unverified.
* Second pass (this resume session): diagnosed FAILs fixed inline (canonical Execution Protocol, expanded Tasks, objective Verification). 13 remaining issues filed. Roadmap ID mapping + this handoff doc updated. BC-5879 rescoped. BC-5926 closed as superseded. PR #170 ready to flip out of draft.

**All 20 issues are Filed.** See `docs/designs/email-copywriting-preset-roadmap.md` § Issue ID mapping for the complete BC-5917..BC-5942 table.

## Read-first order for downstream executors

Agents picking up any of the 20 issues (especially the Phase 2 / Phase 4 ones) should read in this order:

1. The Linear issue body itself (self-contained, canonical form).
2. **Master roadmap** (`docs/designs/email-copywriting-preset-roadmap.md`) — all 20 issues detailed with dependency graph + rubric + ID mapping.
3. **Zoos ledger** (`docs/plans/BC-5879-zoos-ledger.md`) — source material for R-4 + R-10; offer review + voice rules.
4. Memory entry `project_email_copywriting_roadmap.md` (auto-loaded) for state index.

Skip: `docs/plans/BC-5879-plan.md` — original plan, superseded by the roadmap.

## Filed issues — all 20

| Roadmap ID | Linear | Title | Phase |
|---|---|---|---|
| R-1 | [BC-5917](https://linear.app/brite-nites/issue/BC-5917) | Create offer-design-frameworks.md | 1 |
| R-2 | [BC-5918](https://linear.app/brite-nites/issue/BC-5918) | Create experiential-lighting-vendor-landscape.md | 1 |
| R-3 | [BC-5919](https://linear.app/brite-nites/issue/BC-5919) | Update SKILL.md cross-links | 1 |
| R-4 | [BC-5920](https://linear.app/brite-nites/issue/BC-5920) | Create vertical-playbooks/zoos.md | 2 |
| R-5 | [BC-5929](https://linear.app/brite-nites/issue/BC-5929) | Create vertical-playbooks/aquariums.md | 2 |
| R-6 | [BC-5930](https://linear.app/brite-nites/issue/BC-5930) | Create vertical-playbooks/casinos.md | 2 |
| R-7 | [BC-5921](https://linear.app/brite-nites/issue/BC-5921) | Create vertical-playbooks/hotels-resorts.md | 2 |
| R-8 | [BC-5922](https://linear.app/brite-nites/issue/BC-5922) | Create vertical-playbooks/ski-resorts.md | 2 |
| R-9 | [BC-5923](https://linear.app/brite-nites/issue/BC-5923) | Create vertical-playbooks/sports-stadiums.md | 2 |
| R-10 | [BC-5932](https://linear.app/brite-nites/issue/BC-5932) | Compose zoos preset files (Offer E + A) | 4 |
| R-11 | [BC-5933](https://linear.app/brite-nites/issue/BC-5933) | Compose aquariums preset files | 4 |
| R-12 | [BC-5934](https://linear.app/brite-nites/issue/BC-5934) | Compose casinos preset files | 4 |
| R-13 | [BC-5935](https://linear.app/brite-nites/issue/BC-5935) | Compose hotels-resorts preset files | 4 |
| R-14 | [BC-5936](https://linear.app/brite-nites/issue/BC-5936) | Compose ski-resorts preset files | 4 |
| R-15 | [BC-5937](https://linear.app/brite-nites/issue/BC-5937) | Compose sports-stadiums preset files | 4 |
| R-16 | [BC-5938](https://linear.app/brite-nites/issue/BC-5938) | Preset library ship readiness | 5 |
| R-17 | [BC-5939](https://linear.app/brite-nites/issue/BC-5939) | Retrieve S4 Lights customer list | 6 |
| R-18 | [BC-5940](https://linear.app/brite-nites/issue/BC-5940) | Verify Hogle Zoo case study specifics | 6 |
| R-19 | [BC-5941](https://linear.app/brite-nites/issue/BC-5941) | Confirm Facilities-VP motion (Offer B) | 6 |
| R-20 | [BC-5942](https://linear.app/brite-nites/issue/BC-5942) | Multi-offer scope decision per vertical | 6 |

## What was done in the second pass (2026-04-21 evening)

Applied the per-issue diagnosed fixes from the BC-5926 work-order and filed 13 canonical-form issues (R-5, R-6, R-10..R-20). Canonical Execution Protocol (Explore/Plan/Execute/Verify with "Stop and ask if anything is ambiguous" in Execute) applied to every issue body. Every Tasks section fully enumerated (no "3-10. Same as R-X" collapses). Every Verification section uses objective grep / regex / exit-code tests. Every Sources list includes `docs/designs/email-copywriting-preset-roadmap.md` as the master roadmap. blockedBy wiring matches the dependency graph in the roadmap.

BC-5926 (the resume tracking issue) is now superseded — all 13 sub-issues it referenced are filed. BC-5879 is rescoped to `[Superseded by roadmap] Email-copywriting preset library program — roadmap + foundational issues` with a final comment linking all 20 children.

## Known follow-up decisions needed from operator (non-blocking)

- **Offer B (zoos)** deferred pending confirmation that Brite has a Facilities-VP sales motion at zoos today. R-19 tracks this. If answer is positive, a new issue gets filed for the Offer B zoos preset pair.
- **S4 customer list** (R-17) — depends on Brite's S4 partnership contact. Blocks v2 refresh of zoos + aquariums preset proof-points.
- **Hogle Zoo case study specifics** (R-18) — program name, year, scope, outcome. Blocks v2 refresh of zoos preset proof-point.
- **Multi-offer scope per vertical** (R-20) — after all 6 playbooks land, decide whether each vertical gets just primary-offer presets or primary + tactical complement.

## Scratchpad state (NOT shipped)

- `plugins/marketing/skills/email-copywriting/presets/list-building-zoos-aquariums.md` — stale draft from session-1. Proper zoos preset comes from BC-5932 (R-10, Offer E + A composition). Untracked; excluded from commit.
- `plugins/marketing/skills/email-copywriting/presets/risk-reversal-zoos-aquariums.md` — same. Untracked; excluded from commit.

Both remain untracked in git. Anyone resuming can `git clean -f` selectively or remove in a text editor; security hook blocks `rm`. Leaving them in place is harmless since they are never added to the branch.

## Rules carried forward (binding on downstream executors)

- **Verification agent rubric** is authoritative (in roadmap § "Verification agent rubric"). If a future issue body is revised, re-run the rubric: all categories ≥ 7, average ≥ 8.5.
- **Issue template** is fixed (in roadmap § "Standardized issue template"). All 7 sections required in every issue body.
- **Voice rule** from operator correction: don't over-specify incumbent vendor type in body copy. Use "existing lighting vendor" / "incumbent" / "current seasonal-program vendor" — not "lantern vendor" / "projection vendor" / any specific sub-category.
- **Case-study anchors** for zoos: Hogle Zoo + S4 partnership. v1 presets (R-10 / BC-5932) use Hogle + generic S4-partner-venue framing. v2 refresh after R-17 (BC-5939) + R-18 (BC-5940) land.
- **ICP discipline**: regional / mid-market / boutique ICP across all 6 verticals. Enterprise flagships are explicitly out of v1 scope.
- **Offer E is primary for zoos**, Offer A is tactical complement (with fixed guarantee metric — dwell time / attendance uplift / sponsor impression, NOT photo-share).

## Contact / escalation

- Master roadmap is `docs/designs/email-copywriting-preset-roadmap.md` — change nothing in there without re-running verification on affected issues.
- If a verification agent FAILs the same issue 3 times, stop and ask the operator before forcing a file.
- If a new design decision surfaces (e.g., an offer frame not in the roadmap), add it to the roadmap + zoos ledger (or the relevant vertical ledger if created) before filing any issues that depend on it.
