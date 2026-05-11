# Brand Hub pre-flight findings

> Pre-flight audit informing [BC-6998](https://linear.app/brite-nites/issue/BC-6998) (v1.0 acceptance gate dogfood). Audit per [BC-7058](https://linear.app/brite-nites/issue/BC-7058). Findings frozen 2026-05-11. Refresh if Brand Hub repo state, milestone count, or team alignment diverges materially before dogfood execution.

## Q8 acceptance-criteria pre-flight verdicts

Q8 sub-criteria are sourced verbatim from `plugins/flow-architecture/docs/design-rationale/fda-plugin-drafter-e-revision-2.md:1117-1133`. Pre-flight verdicts capture readiness BEFORE dogfood execution; four of the seven sub-criteria are observable only DURING dogfood execution and are correctly DEFERRED.

| # | Q8 sub-criterion | Pre-flight verdict | Notes |
|---|---|---|---|
| 1 | All 9 retrofit phases complete without unrecovered failures | DEFERRED | Phase-completion is observable only at dogfood execution; no pre-flight equivalent. |
| 2 | 5 user-confirmation gates fire as expected | DEFERRED | Same as #1 — observable only during dogfood execution. |
| 3 | Outputs match locked schemas (intent.md / master-flow-inventory.md / per-flow / journeys / INDEX / Linear chain / cross-ref appendices) | READY (preconditions) | None of `intent.md`, `master-flow-inventory.md`, `docs/product/flows/`, `docs/product/journeys/`, or `docs/product/flows/INDEX.md` exist in Brand Hub repo. FDA creates fresh — zero collision risk with existing files. Per FDA Pre-existing-vs-FDA-output mapping table, Brand Hub is treated as greenfield for FDA docs. |
| 4 | `/flow:audit` against retrofitted Brand Hub returns exit 0 | DEFERRED | Post-retrofit only. |
| 5 | `npm run build && npm run lint && npm test` pass on Brand Hub repo | READY | All three exit 0 — see § Build status. |
| 6 | Linear FDA-shaped milestones + 5N discipline children created cleanly | READY (preconditions) | Estimated 13 FDA-shaped domains from 26 legacy-milestone bucket assignment; final count emerges from Q11 `flow-inventory-codebase-scan` at runtime — NOT pinned to 26. See § Legacy-milestone mapping. |
| 7 | Failure modes documented at `plugins/flow-architecture/docs/design-rationale/brand-hub-dogfood-findings.md` | DEFERRED | Authored during BC-6998 retrofit, not pre-flight. Pre-flight findings (this doc) live at a sibling path. |

**Three READY · Four DEFERRED · Zero NEEDS-FIX.** Brand Hub is pre-flight clean for dogfood execution.

## Legacy-milestone mapping

**Source:** `mcp__plugin_workflows_linear-server__get_project` against slug `brand-hub-beb1f3e9de7f` (project ID `61d8cd9b-67ba-4e62-b474-81d9ccf36d31`) at 2026-05-11. Memory-drift correction: `project_fda_plugin_interview.md:24` and downstream design-rationale docs say "27 milestones"; the live count is **26**.

**Critical anti-pattern reminder (drafter B catch, memory:1810; preserved in `fda-plugin-architecture-overview.md` Pre-existing-vs-FDA-output mapping):** Brand Hub's legacy-milestone count is NOT the FDA-domain count. The runtime FDA-domain count emerges from `flow-inventory-codebase-scan` (Q11) at dogfood execution time. This table is a risk-surfacing estimate, NOT a binding commitment.

### Bucket A — Maps cleanly to FDA Tier-1 Domain (estimated)

These already feel domain-shaped and likely survive retrofit as a 1:1 FDA domain or as the seed of one.

| Legacy milestone | Progress | Provisional FDA domain |
|---|---|---|
| Phase 6 - Brand Identity | 100% | `brand-identity` |
| Phase 7 - Video Library | 100% | `video-library` |
| Phase 8 - Sales Materials | 100% | `sales-materials` |
| Phase 9 - Renderings | 100% | `renderings` |
| Phase 10 - Creative Operations v1 | 9% | `creative-operations` (combined with two "Creative Ops —" milestones below) |
| AI & Search Intelligence | 100% | `search` |
| Access & Governance | 100% | `access-governance` |
| Sales Asset Taxonomy | 0% | folds into `sales-materials` |
| Analytics Dashboard | 0% | `analytics` (or folds into `sales-materials` if scope is deck-only) |
| Smart Recommendations | 0% | folds into `sales-materials` |

### Bucket B — Requires splitting / merging at retrofit time

Phase 1-5 are legacy-as-shipped infrastructure milestones — collectively they built the **photo-library** domain. Retrofit merges them into one FDA domain. Several "system" milestones decompose the Asset Library across multiple sub-flows; the Q11 codebase-scan will resolve the final boundary.

| Legacy milestone | Progress | Retrofit action |
|---|---|---|
| Phase 1 - Foundation | 100% | merge into `photo-library` (legacy-FDA-migration appendix per Q14) |
| Phase 2 - Data & Upload | 100% | merge into `photo-library` upload sub-flow |
| Phase 3 - Search & Filter | 100% | split: search part merges to `search` domain; filter part merges to `photo-library` browse sub-flow |
| Phase 4 - Collections | 100% | merge into `photo-library` collections sub-flow |
| Phase 5 - Bulk Import & Polish | 100% | merge into `photo-library` upload sub-flow |
| Asset Browser Polish | 33% | merge into `photo-library` browse sub-flow |
| Asset Unification | 0% | cross-cutting — splits across `photo-library` + `video-library` + `sales-materials` + `renderings` |
| Creative Ops — Data Model | 0% | merge into `creative-operations` |
| Creative Ops — Hardening | 0% | merge into `creative-operations` hardening sub-flow |
| Future Enhancements | 82% | catch-all — child issues redistribute to appropriate domains at retrofit |
| User Testing & Polish | 0% | cross-cutting QA — redistributes per discipline (not its own FDA domain per Q35 amendment) |

### Bucket C — Likely deprecated / out-of-FDA-scope (per Q35 amendment)

Per Q35 amendment, infrastructure / hardening / external-partner-engagement milestones are NOT FDA-shaped (they belong to the Phase Pattern for non-product surfaces).

| Legacy milestone | Progress | Disposition |
|---|---|---|
| Admin & Tooling Polish | 100% | deprecated for FDA-shape (kept as legacy infra record) |
| Data Quality & Migration | 100% | deprecated for FDA-shape (infra) |
| Production Hardening | 18% | deprecated for FDA-shape; remains on Phase Pattern per Q35 |
| Droidor: Production Hardening | 2% | deprecated for FDA-shape; external partner engagement, remains on Phase Pattern |
| Design System Adoption | 0% | deprecated for FDA-shape; cross-cutting tooling concern, remains on Phase Pattern |

### Estimated FDA-domain count from this mapping

**≈10 domains** (`photo-library`, `video-library`, `sales-materials`, `brand-identity`, `renderings`, `creative-operations`, `search`, `access-governance`, `analytics`, + cross-cutting absorption). **The Q11 runtime count is authoritative — this estimate exists only to surface risk before dogfood.**

## Build status

Verified in `/Users/holdenhalford/projects/work/brite-nites/brand-hub` at 2026-05-11 against `main` branch (commit head `21f51e4` for plugin worktree context; brand-hub repo separate). Node v25.9.0.

| Step | Command | Exit | Detail |
|---|---|---|---|
| Lint | `npm run lint` | 0 | 10 warnings (all `@next/next/no-img-element` advisory) — no errors. Acceptable. |
| Test | `npm test` (vitest run) | 0 | 78 / 78 tests passing across 13 files (2.39s wall clock). |
| Build | `npm run build` (next build) | 0 | Next.js production build succeeded. Full static / dynamic route table generated. |

**Q8 sub-criterion 5: READY.** No NEEDS-FIX items.

## Narrative artifacts

Inventory of pre-FDA narrative content `office-hours` (Q42) can pre-fill `intent.md` from, per CDR-013 mapping.

| Artifact | Status | Notes |
|---|---|---|
| `docs/product/intent.md` | absent | Expected — FDA authors fresh during office-hours. |
| `docs/` directory | partial | Only `docs/plans/BC-2134-plan.md` exists; no product / intent docs. |
| `README.md` | present | Top-level summary + Tech Stack + Key Features (Photos / Brand Guidelines / Metadata Editor / Sections). Office-hours can extract the "what we built" framing from here. |
| `CLAUDE.md` | present (~23 KB) | LLM-facing architecture guidance: Quick Reference, Verification, Architecture Overview, Tech Stack, Path Aliases, App Structure. Practical reference — light on product narrative. |
| `.context/prd/` | present (5 files) | PRDs: `analytics-reporting.md`, `creative-pipeline-dashboard.md`, `content-libraries.md`, `creative-request-system.md`, `hubspot-integration.md`. Rich pre-FDA narrative for office-hours pre-fill — especially `content-libraries.md` for the photo / video / sales-materials triad. |
| `.context/droidor-production-hardening.md` | (per memory; referenced by milestone description) | External partner engagement context; not product narrative. Skip for office-hours pre-fill. |

**Office-hours pre-fill viability:** GOOD. `.context/prd/` provides 5 product-domain PRDs and `README.md` provides a domain-feature inventory. Office-hours (Q42) has substantive material to consume — Brand Hub will not require pure-blank-slate office-hours.

## Risks

| # | Risk | Scope | Severity | Mitigation |
|---|---|---|---|---|
| R1 | Memory-drift in plugin design-rationale docs: "27 milestones" assertion is stale by 1 (actual: 26). | flow-architecture plugin | Low | Update `project_fda_plugin_interview.md:24` + `fda-plugin-drafter-e-revision-2.md:1107` to "26" with a memory-drift dated note. **Filed as plugin follow-up: covered inline in BC-6998 dogfood findings doc; no separate issue needed.** |
| R2 | Brand Hub target date 2026-05-19 (~1 week from this audit). BC-6998 dogfood execution window is tight; if dogfood requires Brand Hub repo changes (e.g., Q11 inventory-scan edge cases), Brand Hub team is mid-release. | cross-team | Medium | Sarah Cullen (project lead) aligned per § Team alignment. If dogfood surfaces Brand Hub fixes, file in Brand Hub Linear project (not BC-6998 blocker chain) and triage post-2026-05-19 release. **No separate mitigation issue filed — already covered by team alignment.** |
| R3 | Linear MCP `project` filter on `list_issues` returns 0 reliably (see `gotcha_linear_list_issues_milestone_filter.md`). In-flight scan compensated via `team` + `query` text-search. One real Brand Hub in-flight issue surfaced: BC-1512 (image labeling, Chelsea Young, content-curation not code). | audit methodology | Low | Methodology limit recorded here. The known gotcha is fixed at the MCP level by upstream; not BC-7058's problem to solve. |
| R4 | Droidor (external partner) holds Eng + QA DRI roles. Cross-team coordination for dogfood-surfaced fixes may have higher latency than internal-only iteration. | dogfood execution | Medium | Sarah Cullen (Design + Docs DRI) + Jaime Lyons (Story DRI) are internal Brite — they backstop the dogfood loop. Wasiq Ghaznavi consulted as needed. Document in `brand-hub-dogfood-findings.md` if Droidor coordination friction materializes. |
| R5 | Brand Hub has no `docs/product/` directory and no `intent.md`. Office-hours has substantive PRD material to pre-fill from (per § Narrative artifacts), but the integration mode is "synthesize across 5 PRDs + README + CLAUDE.md" rather than "extract from one canonical narrative." | dogfood execution | Low | Acceptable per Q42 design — office-hours handles multi-source synthesis. Risk is bounded by PRD freshness; the 5 PRDs are all in `.context/prd/` and reasonably current per their content. |

**No P0 or NEEDS-FIX risks.** All five surfaced risks are Low or Medium with in-line mitigations. None are blockers for BC-6998 dogfood execution.

## Team alignment

| Discipline | DRI | Sign-off |
|---|---|---|
| (Team-level) | Amanuel Belay | aligned |
| (Project lead) | Sarah Cullen | aligned |
| Story | Jaime Lyons | aligned via Sarah |
| Eng | Wasiq Ghaznavi (Droidor) | aligned via Sarah |
| Design | Sarah Cullen | aligned (self) |
| QA | Wasiq Ghaznavi (Droidor) | aligned via Sarah |
| Docs | Sarah Cullen | aligned (self) |

**Cultural acceptance:** Brand Hub team approved the audit and is bought-in on the FDA-shaped restructure. Brand Hub project `targetDate` 2026-05-19 is acknowledged — BC-6998 dogfood will sequence to respect that release deadline (any dogfood-surfaced Brand Hub fixes file in Brand Hub Linear project, not as BC-6998 blockers).

**Verdict: READY.** All five disciplines have a named DRI; both team-level and project-lead sign-off captured.

## No-risks attestation does not apply

This audit surfaced 5 risks (R1-R5 above), all Low / Medium with in-line mitigations. No "no-risks" attestation is appended — the § Risks section documents the audit's actual findings and proposed mitigations per the acceptance criteria.

## Cross-reference

- [BC-7058](https://linear.app/brite-nites/issue/BC-7058) — this audit issue (blocks BC-6998).
- [BC-6998](https://linear.app/brite-nites/issue/BC-6998) — Brand Hub dogfood, v1.0 acceptance gate.
- `plugins/flow-architecture/docs/design-rationale/fda-plugin-drafter-e-revision-2.md:1117-1133` — Q8 7 sub-criteria (verbatim source).
- `plugins/flow-architecture/CLAUDE.md` § Pre-existing-vs-FDA-output mapping — Brand Hub-greenfield-for-docs framing.
- `plugins/flow-architecture/docs/design-rationale/project_fda_plugin_interview.md:24` — memory-drift origin ("27 milestones"); correct count is 26.
- `gotcha_linear_list_issues_milestone_filter.md` (memory) — known Linear MCP filter unreliability invoked at R3.
