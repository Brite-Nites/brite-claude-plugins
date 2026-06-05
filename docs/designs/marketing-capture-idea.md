# Design — `/marketing:capture-idea` (lightweight GTM Concept Library intake)

> Crystallized from a `/grill-with-docs` requirements session, 2026-06-02. Authored as a marketing plugin command via `/write-a-skill`.

## Problem

Brite has a documented **Concept Library** — the `[CONCEPT LIBRARY] Half-Baked GTM Offer Ideas` milestone (id `1714a6b6-64cb-4ddf-8e95-ab7eb844d3b8`) in the **Brite GTM** Linear project (id `5e25e522-0700-4f0f-86a2-bdff965126f5`) — where early campaign ideas incubate before being promoted to their own campaign milestone via `/marketing:plan-campaign`. The milestone description defines a 9-field concept-issue template, promotion criteria, and process. **But there is no tooling for it** — concepts are filed by hand, and the two live concepts (BC-11167, BC-11163) don't even follow the template (freeform bullet notes). This command automates tier-1 capture and makes concepts conform.

## What this is / isn't

- **Is**: a fast, low-friction command that files ONE Concept Library issue. Tier-1 of the thin→thick GTM brief stack.
- **Isn't**: a brief generator (the milestone-description + handbook `campaign-brief-template.md` already cover tiers 2–3, filled by `plan-campaign`), and **not** a promoter (promotion stays a deliberate human act via `/marketing:plan-campaign`). See parked follow-up `memory/project_gtm_brief_template_followup.md` for the brief-template-system gaps to revisit after this ships.

## Resolved decisions (grill output)

| # | Decision | Resolution |
|---|---|---|
| 1 | Scope | One command, capture end only. No brief generation, no promotion. |
| 2 | Build form | Marketing plugin **command** `/marketing:capture-idea` (`plugins/marketing/commands/capture-idea.md`), team-facing, Brite conventions. |
| 3 | Fields | Mirror the canonical **9-field template** (below). Status auto-derived `[Sketch]`/`[Maturing]`, never auto-`[Ready-to-promote]`. |
| 4 | Canonical mapping | Free-text + **non-blocking** canonical hint (reads `data/canonicals/`). Never requires/creates canonicals. |
| 5 | Interaction | **Brain-dump-first + optional flags + one confirm.** Dump as arg or prompted. Min to file: Concept name + one-sentence offer — the offer is **enforced** (prompted if missing; never filed offerless). |
| 6 | Linear metadata | Project Brite GTM · milestone `[CONCEPT LIBRARY]` (verify, **hard-fail** if absent) · team Brite Company · state **Backlog** · priority **None** · **assignee empty** · Status in body **+ `status:sketch\|maturing` label** (create-if-missing; never auto-create `status:ready-to-promote`). |
| 7 | Handoff | Body adds promotion-criteria checklist + conditional `plan-campaign` suggestion + provenance footer. Terminal prints URL + missing-fields + promotion command. |
| 8 | Dedup | **Soft-warn-then-confirm** — one `list_issues` similarity check, never blocks. |
| 9 | v1 boundary | **Create-only.** `--update`/`--list` deferred; promotion permanently `plan-campaign`'s job. |

## Canonical 9-field concept template (source: `[CONCEPT LIBRARY]` milestone description)

**Required:** 1. Concept name (5–10 word issue title) · 2. One-sentence offer (what we'd sell · to whom · why they'd buy) · 3. Brand fit (Brite Nites / Brite Labs / Brite Supply / multi / unsure) · 4. Source / inspiration · 5. Status (`[Sketch]`/`[Maturing]`/`[Ready-to-promote]`)
**Encouraged:** 6. Target ICP guess · 7. Commercial model guess (install fee / rev-share / ticketed / sponsor / co-invest / hybrid) · 8. Cross-references · 9. Next move to mature

**Status auto-derivation:** `[Maturing]` iff all three required content fields beyond the Concept name (offer · brand fit ≠ `unsure` · source) are present AND ≥1 encouraged field (ICP guess or commercial model); else `[Sketch]` (floor: name + offer). `[Ready-to-promote]` is never auto-set (human call against the promotion criteria).

**Promotion criteria (rendered as an unchecked checklist in the body):** named lead/champion · target ICP defined · commercial model decided · ≥1 named reference account/prospect · Phase-2+ owner assigned.

## Linear filing (observed conventions)

- Title = Concept name, Title Case, no prefix.
- State `Backlog`, priority `No priority`, assignee empty, team Brite Company.
- Status label: ensure the derived `status:sketch` / `status:maturing` **flat** label exists (`create_issue_label` if missing — flat, no group, matching the existing `status:planning` on campaign rollups), apply it; never auto-create `status:ready-to-promote`. _Traceability:_ this extends the GTM `status:` namespace (documented closed set `status:planning/active/completed/killed/paused` in the orchestration design) with three concept-pool values — they live on the `[CONCEPT LIBRARY]` milestone, a distinct surface from campaign milestones, so there's no collision.
- Hard-fail if the `[CONCEPT LIBRARY]` milestone can't be resolved — never auto-create an evergreen milestone.

## Canonical soft-match (Q4(a))

Read `data/canonicals/_manifest.yaml` (valid vertical slugs) + per-vertical `<vertical>.yaml` (personas[], offers[]). Three-way match (most verticals are skeletons today — empty personas/offers — so the partial case is the common one, surfaced by the dry-run 2026-06-02):
- **Full** (vertical + persona + offer canonical) → footer `/marketing:plan-campaign --vertical … --persona … --offer …`.
- **Vertical-only** (vertical canonical, persona/offer empty) → footer: run `/marketing:new-persona` + `/marketing:new-offer` first, then `plan-campaign`.
- **No match** → `/marketing:new-vertical` first.
Never block; never write canonicals.

## Tool palette

`Read, AskUserQuestion, mcp__plugin_workflows_linear-server__{list_projects, list_milestones, list_issues, list_issue_labels, create_issue_label, save_issue}`. (No `Glob` — canonicals are read by explicit path. No gbrain context-load in v1 — kept lightweight; a "similar prior concepts" query is a future enhancement.)

## Out of scope / follow-ups

- `--update <BC-id>` (enrich a `[Sketch]` toward `[Maturing]`) and `--list` (maturity-filtered browse) — fast-follow.
- Authoring the canonical Concept Library issue-template file + reconciling `brite-gtm/docs/milestone-template.md` vs handbook templates — tracked in **BC-12392** (Brite GTM).
