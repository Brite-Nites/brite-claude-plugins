# BC-5879 Session Handoff — Resume Instructions

**Session date:** 2026-04-21 (ended mid-roadmap rollout)
**Branch:** `holden/bc-5879-fan-out-email-copywriting-active-tier-preset-library-10`
**Worktree:** `.claude/worktrees/bc-5879`
**Resume trigger:** "Resume BC-5879 email-copywriting preset roadmap rollout per this handoff doc."

## TL;DR — what happened, what's next

The session started as "fan out 10 Active-tier Nites preset files" (BC-5879 original scope). Session discovery pivoted the work to a 20-issue roadmap covering 6 verticals (Labs-experiential: Zoos, Aquariums, Casinos, Hotels & Resorts, Ski Resorts, Sports Stadiums) + references/ promotion (frameworks + vendor-landscape + per-vertical playbooks).

**Shipped tonight:** 7 of 20 Linear issues filed with dependency wiring. Master roadmap doc written. Zoos decision ledger preserved.

**Remaining:** 13 of 20 Linear issues. 6 of those are FAILing verification (need template-compliance rewrites). 7 are unverified.

**Next session's job:** revise the 6 FAILs, verify the 7 unverified, file all 13 in dependency order, then rescope/close BC-5879 and ship the PR.

## Read-first order for resuming agent

1. **This doc** (`docs/plans/BC-5879-session-handoff.md`) — resume context
2. **Master roadmap** (`docs/designs/email-copywriting-preset-roadmap.md`) — all 20 issues detailed with dependency graph + rubric + ID mapping
3. **Zoos ledger** (`docs/plans/BC-5879-zoos-ledger.md`) — source material for R-4 + R-10; offer review + voice rules
4. Memory entry `project_email_copywriting_roadmap.md` (auto-loaded) for state index

Skip: `docs/plans/BC-5879-plan.md` — original plan, superseded.

## Filed issues (7 of 20)

| Roadmap ID | Linear | Title | Status |
|---|---|---|---|
| R-1 | [BC-5917](https://linear.app/brite-nites/issue/BC-5917) | Create offer-design-frameworks.md | Filed |
| R-2 | [BC-5918](https://linear.app/brite-nites/issue/BC-5918) | Create experiential-lighting-vendor-landscape.md | Filed |
| R-3 | [BC-5919](https://linear.app/brite-nites/issue/BC-5919) | Update SKILL.md cross-links | Filed (blockedBy BC-5917, BC-5918) |
| R-4 | [BC-5920](https://linear.app/brite-nites/issue/BC-5920) | Create vertical-playbooks/zoos.md | Filed (blockedBy BC-5917/18/19) |
| R-7 | [BC-5921](https://linear.app/brite-nites/issue/BC-5921) | Create vertical-playbooks/hotels-resorts.md | Filed (blockedBy BC-5917/18/19) |
| R-8 | [BC-5922](https://linear.app/brite-nites/issue/BC-5922) | Create vertical-playbooks/ski-resorts.md | Filed (blockedBy BC-5917/18/19) |
| R-9 | [BC-5923](https://linear.app/brite-nites/issue/BC-5923) | Create vertical-playbooks/sports-stadiums.md | Filed (blockedBy BC-5917/18/19) |

## Pending issues (13 of 20)

### Need revision before filing — FAIL verification (6)

| Roadmap ID | Title | FAIL score | Blocker |
|---|---|---|---|
| R-5 | Create vertical-playbooks/aquariums.md | 8.1/10 | Collapsed Tasks section; missing "stop and ask"; loose source-path annotation |
| R-6 | Create vertical-playbooks/casinos.md | 6.6/10 | Execution Protocol abbreviated; Tasks collapsed; Sources missing paths |
| R-17 | Get S4 Lights customer list | 7.6/10 | Missing roadmap source; Execute step too terse |
| R-18 | Verify Hogle Zoo case study specifics | 6.6/10 | Execution Protocol + Verification + Context all abbreviated |
| R-19 | Confirm Facilities-VP sales motion | 6.7/10 | Subjective checkboxes; Sources sparse |
| R-20 | Multi-offer scope decision per vertical | 6.3/10 | Tasks collapsed ("3-6. Same for..."); Execution Protocol terse |

**Fix pattern (applies to most of the 6):** restore canonical Execution Protocol 4-step form (Explore names exact paths; Plan requires TaskCreate; Execute includes "Stop and ask if anything is ambiguous"; Verify references checkbox list); tighten Verification checkboxes to objective grep / regex / exit-code tests; add `docs/designs/email-copywriting-preset-roadmap.md` to Sources of every issue; expand any "Same pattern as R-X" Tasks to inline enumeration. Full per-issue fix lists are preserved in the verification agent reports from the 2026-04-21 session — re-run the verification agents if needed to regenerate them.

### Not yet verified (7)

| Roadmap ID | Title | blockedBy | blocks |
|---|---|---|---|
| R-10 | Compose zoos preset files (Offer E + A) | R-4 (BC-5920) | R-16 |
| R-11 | Compose aquariums preset files | R-5 (pending) | R-16 |
| R-12 | Compose casinos preset files | R-6 (pending) | R-16 |
| R-13 | Compose hotels & resorts preset files | R-7 (BC-5921) | R-16 |
| R-14 | Compose ski resorts preset files | R-8 (BC-5922) | R-16 |
| R-15 | Compose sports stadiums preset files | R-9 (BC-5923) | R-16 |
| R-16 | Ship readiness (README manifest + grep + validate) | R-10..R-15 | none |

## Resume-agent workflow

1. Read this doc + roadmap + zoos ledger (step 1 above)
2. For each of the 6 FAILs — revise the roadmap section, re-verify via verification agent (rubric in roadmap § "Verification agent rubric"), file via save_issue with proper blockedBy when pass
3. For each of the 7 unverified — verify via verification agent, file on pass
4. Fix any FAIL → revise → re-verify (cap at 3 attempts, escalate if fail)
5. File order by dep graph: Phase 2 (R-5, R-6) → Phase 4 (R-10..R-15) → Phase 5 (R-16). Phase 6 (R-17..R-20) is unblocked, can file anytime.
6. After all 20 filed: rescope BC-5879 (title + description + comment linking all children + note the scope pivot).
7. Commit the final roadmap doc state (with all BC-XXXX mappings filled in) + any new plan docs.
8. Open the PR.

## Known follow-up decisions needed from operator (non-blocking)

- **Offer B (zoos)** deferred pending confirmation that Brite has a Facilities-VP sales motion at zoos today. R-19 tracks this. If answer is positive, a new issue gets filed for the Offer B zoos preset pair.
- **S4 customer list** (R-17) — depends on Brite's S4 partnership contact. Blocks v2 refresh of zoos + aquariums preset proof-points.
- **Hogle Zoo case study specifics** (R-18) — program name, year, scope, outcome. Blocks v2 refresh of zoos preset proof-point.
- **Multi-offer scope per vertical** (R-20) — after all 6 playbooks land, decide whether each vertical gets just primary-offer presets or primary + tactical complement.

## Scratchpad state (NOT shipped)

- `plugins/marketing/skills/email-copywriting/presets/list-building-zoos-aquariums.md` — stale draft, DO NOT build on. Proper zoos preset will come from R-10 (Offer E + A via the composition issue).
- `plugins/marketing/skills/email-copywriting/presets/risk-reversal-zoos-aquariums.md` — same.

Both are untracked in git and excluded from commit. Delete at your discretion next session (security hook blocks `rm` — use `git clean -f` selectively or a text editor).

## Rules carried forward

- **Verification agent rubric** is authoritative (in roadmap § "Verification agent rubric"). All 13 pending issues must PASS (all categories ≥ 7, average ≥ 8.5) before filing.
- **Issue template** is fixed (in roadmap § "Standardized issue template"). All 7 sections required in every issue body.
- **Voice rule** from operator correction: don't over-specify incumbent vendor type in body copy. Use "existing lighting vendor" / "incumbent" / "current seasonal-program vendor" — not "lantern vendor" / "projection vendor" / any specific sub-category.
- **Case-study anchors** for zoos: Hogle Zoo + S4 partnership. v1 presets use Hogle + generic S4-partner-venue framing. v2 refresh after R-17 + R-18 land.
- **ICP discipline**: regional / mid-market / boutique ICP across all 6 verticals. Enterprise flagships are explicitly out of v1 scope.
- **Offer E is primary for zoos**, offer A is tactical complement (with fixed guarantee metric — dwell time / attendance uplift / sponsor impression, NOT photo-share).

## Contact / escalation

- Master roadmap is `docs/designs/email-copywriting-preset-roadmap.md` — change nothing in there without re-running verification on affected issues.
- If a verification agent FAILs the same issue 3 times, stop and ask the operator before forcing a file.
- If a new design decision surfaces (e.g., an offer frame not in the roadmap), add it to the roadmap + zoos ledger (or the relevant vertical ledger if created) before filing any issues that depend on it.
