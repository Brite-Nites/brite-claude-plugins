# Linear Issues Created — GTM Campaign Orchestration

**Created**: 2026-05-12 (initial 22) + 2026-05-13 (T2-FA audit-fix BC-8752) + 2026-05-14 (milestone assignment to all 25)
**Source plan**: [`docs/project-plan-refined.md`](./project-plan-refined.md)
**Master entry point**: [`docs/gtm-campaign-orchestration-README.md`](./gtm-campaign-orchestration-README.md)
**Linear project**: [Brite Skill Packs](https://linear.app/brite-nites/project/brite-skill-packs-402b57908532)
**Milestone**: `GTM Campaign Orchestration v1.0` (id `bcd40909-aa7c-43d7-88e8-6c40b59c5a1f`)
**Team**: Brite Company (prefix `BC-`)
**Total issues created**: 25 (Task 0 + 23 BCs T1-A through T9-X + T2-FA audit-fix BC-8752; BC-8736 created in error as duplicate of BC-8752 and canceled with `duplicateOf` link)

## Issue ID → Task title mapping

| Task | Linear ID | Title | Complexity |
|---|---|---|---|
| Task 0 | [BC-8712](https://linear.app/brite-nites/issue/BC-8712) | GTM Orchestration Task 0: Generate Linear Issues and Update CLAUDE.md | S |
| T1-A | [BC-8713](https://linear.app/brite-nites/issue/BC-8713) | GTM T1-A: Deploy 4 Campaign custom fields to brite-salesforce | S |
| T1-B | [BC-8714](https://linear.app/brite-nites/issue/BC-8714) | GTM T1-B: Deploy 4 saved Campaign list views | S |
| T1-C | [BC-8715](https://linear.app/brite-nites/issue/BC-8715) | GTM T1-C: Deploy Performance Dashboard (vertical × month) | M |
| T1-D | [BC-8716](https://linear.app/brite-nites/issue/BC-8716) | GTM T1-D: Deploy Pipeline by Offer Family Dashboard (offer × quarter) | M |
| T2-E | [BC-8717](https://linear.app/brite-nites/issue/BC-8717) | GTM T2-E: Add create_sf_campaign write tool to revops:salesforce MCP | M |
| T3-G | [BC-8718](https://linear.app/brite-nites/issue/BC-8718) | GTM T3-G: Backfill 27 canonicals.yaml + _manifest.yaml | M |
| T5-K | [BC-8719](https://linear.app/brite-nites/issue/BC-8719) | GTM T5-K: Normalize entity slug short-form (O15 migration) | S |
| T5-L | [BC-8720](https://linear.app/brite-nites/issue/BC-8720) | GTM T5-L: Rename offer-tier → offer-posture (O12 Identity Q5) | M |
| T5-M | [BC-8721](https://linear.app/brite-nites/issue/BC-8721) | GTM T5-M: Rename 3 verdict parent labels (O12 State Q1) | S |
| T5-N | [BC-8722](https://linear.app/brite-nites/issue/BC-8722) | GTM T5-N: Implement discoveries.json category schema (Phase 2 7.4) | M |
| T2-F | [BC-8723](https://linear.app/brite-nites/issue/BC-8723) | GTM T2-F: Add update_sf_campaign_status write tool to revops:salesforce MCP | S |
| T4-I | [BC-8724](https://linear.app/brite-nites/issue/BC-8724) | GTM T4-I: Implement /marketing:plan-campaign command (closes O3) | L |
| T9-W | [BC-8725](https://linear.app/brite-nites/issue/BC-8725) | GTM T9-W: Implement /marketing:new-vertical \| new-offer \| new-persona sibling commands | M |
| T9-X | [BC-8726](https://linear.app/brite-nites/issue/BC-8726) | GTM T9-X: Implement /marketing:icp-refinement-review command | M |
| T6-O | [BC-8727](https://linear.app/brite-nites/issue/BC-8727) | GTM T6-O: Run first dogfood campaign through plan-campaign + capture friction | M |
| T9-V | [BC-8728](https://linear.app/brite-nites/issue/BC-8728) | GTM T9-V: Implement /marketing:offer-performance command (O13) | M |
| T6-P | [BC-8729](https://linear.app/brite-nites/issue/BC-8729) | GTM T6-P: V3 Marketing ratification meeting | S |
| T3-H | [BC-8730](https://linear.app/brite-nites/issue/BC-8730) | GTM T3-H: Document D8 persona authorship process | S |
| T7-Q | [BC-8731](https://linear.app/brite-nites/issue/BC-8731) | GTM T7-Q: Implement /marketing:portfolio-snapshot --monthly \| --quarterly | L |
| T8-R | [BC-8732](https://linear.app/brite-nites/issue/BC-8732) | GTM T8-R: Handbook PR — vocabulary.md (O14) | M |
| T8-S | [BC-8733](https://linear.app/brite-nites/issue/BC-8733) | GTM T8-S: Handbook PR — 7 framework docs (O14) | L |
| T8-T | [BC-8734](https://linear.app/brite-nites/issue/BC-8734) | GTM T8-T: Handbook PR — active-campaigns.md nav refactor (O8) | S |
| T8-U | [BC-8735](https://linear.app/brite-nites/issue/BC-8735) | GTM T8-U: Handbook PR — how-we-operate.md cadence rows (O14) | S |
| T2-FA | [BC-8752](https://linear.app/brite-nites/issue/BC-8752) | GTM T2-FA: Wire σ3 status-sync triggers (Linear status transitions → update_sf_campaign_status) | M |

## Dependency wiring summary

Dependencies are encoded as Linear `blockedBy` relations (per the Mermaid graph in the refined plan).

### Critical path

Task 0 → T1-A → T2-E → T4-I → T6-O → T6-P → T2-FA → T7-Q

`BC-8712 → BC-8713 → BC-8717 → BC-8724 → BC-8727 → BC-8729 → BC-8752 → BC-8731`

BC-8752 (T2-FA σ3 trigger automation) was added 2026-05-13 as an audit-fix per pre-implementation audit P1#1 — without it, the σ3 `update_sf_campaign_status` MCP tool (BC-8723) only fires on manual operator invocation, defeating σ3's auto-sync design intent. T7-Q (portfolio-snapshot) reads SF status which must be accurate via the trigger wiring.

### Full blockedBy map

| Issue | blockedBy |
|---|---|
| BC-8712 (Task 0) | (none — entry point) |
| BC-8713 (T1-A) | BC-8712 |
| BC-8714 (T1-B) | BC-8713 |
| BC-8715 (T1-C) | BC-8713 |
| BC-8716 (T1-D) | BC-8713 |
| BC-8717 (T2-E) | BC-8713 |
| BC-8718 (T3-G) | BC-8712 |
| BC-8719 (T5-K) | BC-8712 |
| BC-8720 (T5-L) | BC-8712 |
| BC-8721 (T5-M) | BC-8712 |
| BC-8722 (T5-N) | BC-8712 |
| BC-8723 (T2-F) | BC-8717 |
| BC-8724 (T4-I) | BC-8713, BC-8714, BC-8717, BC-8718 |
| BC-8725 (T9-W) | BC-8718 |
| BC-8726 (T9-X) | BC-8722 |
| BC-8727 (T6-O) | BC-8724 |
| BC-8728 (T9-V) | BC-8723, BC-8718 |
| BC-8729 (T6-P) | BC-8727 |
| BC-8730 (T3-H) | BC-8729 |
| BC-8731 (T7-Q) | BC-8715, BC-8716, BC-8717, BC-8723, BC-8719, BC-8727, BC-8729 |
| BC-8732 (T8-R) | BC-8729 |
| BC-8733 (T8-S) | BC-8729, BC-8732 |
| BC-8734 (T8-T) | BC-8729, BC-8714 |
| BC-8735 (T8-U) | BC-8714, BC-8715, BC-8716, BC-8729 |
| BC-8752 (T2-FA) | BC-8723, BC-8724 |

(BC-8731 (T7-Q) updated 2026-05-13 to add BC-8752 to blockedBy. Final BC-8731 blockedBy: BC-8715, BC-8716, BC-8717, BC-8723, BC-8719, BC-8727, BC-8729, BC-8752.)

## Priority assignment

Priorities are derived from dependency-graph position:

- **Urgent (1)**: BC-8712 (Task 0), BC-8713 (T1-A) — entry-points blocking everything else.
- **High (2)**: BC-8714, BC-8715, BC-8716, BC-8717, BC-8718, BC-8723, BC-8724, BC-8727, BC-8729, BC-8731 — Tier 1/2/3/4/6/7 critical-path nodes.
- **Medium (3)**: BC-8719, BC-8720, BC-8721, BC-8722, BC-8730, BC-8732, BC-8733, BC-8734, BC-8735 — Tier 5 migrations + Tier 8 handbook PRs.
- **Low (4)**: BC-8725, BC-8726, BC-8728 — Tier 9 deferrable.

## Labels

Each issue carries its complexity label (`S` / `M` / `L`) only. The plan's `tier-N` labels are not in the workspace label set; tier context is preserved in the issue body header and visible in the title prefix (`GTM T1-A`, `GTM T2-E`, etc.).

## Validation

- All 25 issues created in team **Brite Company**, project **Brite Skill Packs**, milestone **GTM Campaign Orchestration v1.0** — confirmed via Linear save_issue response + 2026-05-14 independent audit.
- Each issue body contains the required Context / Implementation Steps / Validation Criteria / Dependencies sections.
- Dependencies wired via `blockedBy` (append-only) at issue-create time; no post-create patching required.
- Source plan file (`docs/project-plan-refined.md`) updated with:
  - Top-of-file Linear project link.
  - BC-ID ↔ task-ID mapping table.
  - Per-task heading suffixes linking to each issue.

## Special handling notes

- **Parent/sub-issue relationships**: This skill defaults to using `blockedBy` rather than `parentId` because the GTM plan tasks are coordinate siblings under one project (Brite Skill Packs), not parent-shell + children. No `parentId` was set on any issue.
- **No tier labels created**: Workspace does not have a `tier-1` / `tier-2` etc. label family. Tier context is preserved in title prefix + body header. If desired, those labels can be added later as a workspace housekeeping step.
- **Linear project for downstream campaigns** (mentioned in refined plan): the "Brite GTM" project where actual campaign milestones get scaffolded by `/marketing:plan-campaign` (T4-I). That project is referenced inside issue bodies but is NOT the project these 22 platform-build issues live in.
- **Priority encoding choice**: priorities reflect dependency-graph position, not business urgency. Higher priority = sooner unblocked. Adjust manually if business urgency differs (e.g., T9-V/W/X might be raised if a strategic push reorders the tier 9 backlog).
