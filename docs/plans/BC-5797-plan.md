# BC-5797 Plan — Customize sf-metadata with Brite metadata-authoring discipline

**Issue:** [BC-5797](https://linear.app/brite-nites/issue/BC-5797) · **Milestone:** RevOps Plugin · **Priority:** High · **Blocked by:** BC-5789 (scaffold — done) · **Related:** BC-5796 (sibling template, done)

## Scope

Layer Brite's metadata-authoring discipline onto the upstream `plugins/revops/skills/sf-metadata/SKILL.md`. Single-file markdown customization. No upstream `references/`, `assets/`, or `hooks/` are touched. 4th sibling applying the BC-5793 → BC-5794 → BC-5795 → BC-5796 ratified Phase 3 template.

## Departures from issue body (locked by sibling precedents — NOT re-litigated)

Four departures apply verbatim from BC-5793, per BC-5794/BC-5796 precedent:

| # | Issue body says | Override | Source |
|---|-----------------|----------|--------|
| 1 | (issue does not request rename — already keeps `sf-metadata`) | n/a (no override needed) | — |
| 2 | Execute step 3 commit message: `customize sf-metadata with Brite authoring gotchas` | Keep verbatim — matches BC-5796 commit-message form | BC-5796 commit `70e64dd` |
| 3 | Verify T1: `ls plugins/revops/skills/sf-metadata` | No flip needed (already upstream name) | — |
| 4 | Verify T3-T7: grep `sf-metadata/SKILL.md` | No flip needed | — |

Unlike BC-5794/BC-5795/BC-5796, BC-5797's issue body **does not** request a rename, so the directory-name override is a no-op. All other template elements (frontmatter keys, attribution comment, two-section layout, placement) inherit.

Per BC-5794 precedent, no AskUserQuestion is needed for template elements — the template is locked and re-deriving would waste turns.

## Template shape (BC-5796 canonical, matches siblings sf-deploy / sf-permissions / sf-connected-apps / sf-apex)

Placement: **Brite sections BEFORE `## When This Skill Owns the Task`.** Template variant B (majority 3/4 among ratified siblings).

Sections to add, in order:

1. Frontmatter updates (extended `author:`, new `upstream:` key, version bump)
2. Attribution HTML comment below frontmatter, above H1
3. `## Brite Context` — Brite's metadata stance + entity landmarks + See-also links
4. `## Brite Metadata Conventions` — ~18 rules grounded in `brite-salesforce/CLAUDE.md` §Metadata Authoring + §Engineering Standards
5. Preserve all original upstream sections unchanged below

## Frontmatter changes

```yaml
metadata:
  version: "1.2.0-brite.1"          # was "1.2.0"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
  scoring: "120 points across 6 categories"
```

Also extend `description:` with the Brite-repo trigger signal (Activity fields / Kanban Group By / Flexipage IndexedDB / ListView column aliases) so the skill auto-invokes inside `brite-salesforce` and does NOT fire elsewhere (T8 + T9 verify).

## Attribution comment

```
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Metadata Authoring. -->
```

Matches T2 grep (`"Adapted from Jaganpro"`) and the canonical form in `plugins/revops/UPSTREAM.md`.

## Brite Metadata Conventions (21 rules, grounded in brite-salesforce/CLAUDE.md)

Each rule cites a specific source line. Factual anchors verified via `gh api` fetch on 2026-04-20 (per BC-5795 ground-truth + BC-5796 bullet-count discipline).

**Source ground truth (verified 2026-04-20):**
- §Engineering Standards: lines 37–50 (4 rules distilled for sf-metadata → Rules 1-4)
- §Metadata Authoring: lines 120–143, **20 bullets confirmed** (18 in-scope for sf-metadata → 17 distinct rules because lines 135+140 merged into Rule 20; 2 out-of-scope below → lines 141, 142)

Total: 4 + 17 = **21 rules**.

**Theme A — Source format & authoring principles (4 rules from §Engineering Standards)**

| # | Rule | Source line |
|---|------|-------------|
| 1 | SFDX source format (not MDAPI); all metadata under `force-app/main/default/` | §Engineering Standards line 39 |
| 2 | API version 65.0, set in `sfdx-project.json` — all new metadata inherits `sourceApiVersion` | §Engineering Standards line 40 |
| 3 | "Standard fields first" — exhaust standard fields (especially FSL standard data model: `Location`, `WorkType`, `WorkOrderLineItem`) before proposing custom | §Engineering Standards line 45 |
| 4 | Only `Minimum Access` profile tracked in source; all permissions via Permission Sets — new `CustomField` FLS goes to permsets, not profiles | §Engineering Standards line 47 |

**Theme B — Metadata API / retrieve-and-deploy authoring constraints (7 rules)**

| # | Rule | Source line |
|---|------|-------------|
| 5 | Activity fields defined on `Activity` object — NOT Task/Event standalone (Metadata API rejects). FLS references still use `Task.Field__c` / `Event.Field__c` | §Metadata Authoring line 122 |
| 6 | Retrieved `StandardValueSet` may be incomplete — returns only Salesforce-tracked standard values; deploying can strip org values. Cross-check RT `<picklistValues>` before deploy | §Metadata Authoring line 123 |
| 7 | Profile XML field ordering must stay alphabetical (`fieldPermissions`, `layoutAssignments`, `recordTypeVisibilities`) — out-of-order entries cause spurious diffs on next retrieve | §Metadata Authoring line 124 |
| 8 | ListView: `<booleanFilter>` must immediately follow `<fullName>` — deploys accept any order, but retrieve rewrites canonical alphabetical and creates spurious diffs | §Metadata Authoring line 125 |
| 9 | ListView column aliases are object-specific — Lead uses `LEAD_SOURCE`, Contact uses `CONTACT.LEAD_SOURCE`, Opportunity uses `OPPORTUNITY.LEAD_SOURCE` | §Metadata Authoring line 126 |
| 10 | Layout related list format — custom lookups use `{ChildObject}.{LookupField}` (e.g., `Lead.Territory__c`), NOT `{relationshipName}__r`; standard related lists use `RelatedContactList`-style names | §Metadata Authoring line 127 |
| 11 | Restricted-picklist custom fields using global value sets (e.g., `Lifecycle_Stage__c`) need explicit `picklistValues` on **each** record type, even though the GVS defines all values | §Metadata Authoring line 128 |

**Theme C — Setup-UI / declarative-rendering constraints (3 rules)**

| # | Rule | Source line |
|---|------|-------------|
| 12 | PathAssistant `recordTypeName` must resolve to a real RT — objects without RTs (Contact) cannot deploy PathAssistant via metadata; use Setup UI. Flexipage `pathAssistant` component still deployable | §Metadata Authoring line 129 |
| 13 | Metadata API supports `FloatingPanel` only on named pages — `Walkthrough` displayType + record-page targets rejected. Create through Setup > User Engagement > In-App Guidance. `delayDays` must be 1–30 (not 0) | §Metadata Authoring line 130 |
| 14 | Dev sandbox rejects **ALL** Prompt metadata — prompts excluded via `.forceignore`; deploy directly to prod and configure sandbox manually | §Metadata Authoring line 131 |

**Theme D — Cache + declarative-deployment gaps (5 rules)**

| # | Rule | Source line |
|---|------|-------------|
| 15 | Kanban Group By dropdown caches stale field metadata — newly-deployed picklist fields on standard objects don't appear until a layout change flushes the cache (verified against `Contact.Lead_Status__c`, BC-4734) | §Metadata Authoring line 132 |
| 16 | Kanban Group By selection is NOT deployable — no `KanbanView` sObject, no `kanbanGroupingField` element. Per-list-view UI-only; sandbox refreshes lose the setting. Document manual steps | §Metadata Authoring line 133 |
| 17 | Flexipage record-page assignments are NOT deployable as org defaults — `FlexipageAssignment` is not a metadata type. Use `actionOverrides` in app metadata (e.g., `Business_Development.app-meta.xml`) to assign per-app | §Metadata Authoring line 137 |
| 18 | Flexipage two-column template is `flexipage:recordHomeTemplateDesktop` (NOT `...TwoColTemplateDesktop` — that name doesn't exist). Regions: `sidebar`, `main`. Three-column: `flexipage:recordHomeThreeColTemplateDesktop` with `leftsidebar`, `main`, `rightsidebar` | §Metadata Authoring line 138 |
| 19 | Flexipage changes cached in IndexedDB (`actions` database) with hours-long TTL — `Cmd+Shift+R` does NOT clear it. Options: log out + in, `indexedDB.deleteDatabase("actions")` in Chrome console, or open in App Builder + Save | §Metadata Authoring line 139 |

**Theme E — Dynamic Forms (field-level semantics + FLS) — 2 rules**

| # | Rule | Source line |
|---|------|-------------|
| 20 | Dynamic Forms visibility + uiBehavior semantics: field-level rules (`fieldItem.visibilityRule`) evaluate reactively during editing; section-level rules (`fieldSection.visibilityRule`) evaluate only on saved values. For auto-populated DateTime fields, use `uiBehavior: readonly` (not `none`) — `none` can cause the field not to render | §Metadata Authoring lines 135 + 140 |
| 21 | Dynamic Forms requires FLS even for System Administrators — `View All Data` / `Modify All Data` do NOT bypass FLS. Fields with no `FieldPermissions` records are hidden. Deploy FLS alongside new fields; if `--source-dir` roll-backs occur (e.g., ECA failures), deploy field + FLS individually with `-m` | §Metadata Authoring line 136 |

**Rule count: 21.** Source ground truth was 20 bullets in §Metadata Authoring + 4 rules distilled from §Engineering Standards = 24 candidate rules. Merges: (a) bullet §Metadata Authoring line 135 + line 140 → Rule 20 (both Dynamic Forms field-level semantics); (b) bullets §Metadata Authoring lines 141 + 142 excluded as out-of-scope (below).

**Out of scope for sf-metadata (2 bullets from §Metadata Authoring):**
- Line 141: "HubSpot emails migrate as Task, not EmailMessage" — ETL/data-model concern; belongs in `sf-data` (BC-5803) + `sf-integration` (BC-5805)
- Line 142: "`Messaging.SingleEmailMessage` with `setSaveAsActivity(false)` leaves no EmailMessage record" — Apex-runtime concern; belongs in `sf-apex` (BC-5796, already shipped) + `sf-debug` (BC-5800)

Both excluded because sf-metadata covers **metadata XML authoring**, not Apex runtime or data-migration ETL. Documenting them here prevents review agents from flagging the omission.

## See-also links (below § Brite Context)

- `brite-salesforce/CLAUDE.md` §Metadata Authoring lines 120–143 (source of 20 bullets; 18 distilled here, 2 excluded as out-of-scope)
- `brite-salesforce/CLAUDE.md` §Engineering Standards lines 37–50 (SFDX source format, API v65.0, Standard fields first, Minimum Access profile)
- `brite-salesforce/.forceignore` (canonical Prompt-exclusion list)
- `brite-salesforce/docs/plans/bc-1720-prompt-creation-guide.md` (referenced by Rule 13 — FloatingPanel alternative path through Setup UI)
- `plugins/revops/skills/sf-deploy/SKILL.md` (BC-5793 sibling — deploy-time post-verify conventions)
- `plugins/revops/skills/sf-permissions/SKILL.md` (BC-5794 sibling — Profile FLS + 7-permset sync discipline)
- BC-4734 (Kanban Group By cache empirical verification referenced in Rule 15)

## Execute steps

1. **No `git mv`** — directory name stays `sf-metadata/` (issue body does not request rename).
2. Edit `plugins/revops/skills/sf-metadata/SKILL.md`:
   - Update frontmatter (version, author, upstream, description)
   - Add attribution comment above H1
   - Insert `## Brite Context` + `## Brite Metadata Conventions` between H1 and `## When This Skill Owns the Task`
   - Leave all existing sections unchanged
3. No changes to `references/`, `CREDITS.md`, `assets/`, `hooks/`, or `README.md`.
4. Commit: `customize sf-metadata with Brite authoring gotchas (BC-5797)` — body cites BC-5793 precedent for the departure block per BC-5758 3-location audit trail pattern.

## Verify — 10 objective tests (issue body, unchanged)

| T | Command | Pass criteria |
|---|---------|---------------|
| T1 | `ls plugins/revops/skills/sf-metadata` | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-metadata/SKILL.md` | Match |
| T3 | `grep -E "Activity.*fields\|objects/Activity" plugins/revops/skills/sf-metadata/SKILL.md` | Match — Rule 5 present |
| T4 | `grep -E "Kanban.*cache\|Kanban Group By" plugins/revops/skills/sf-metadata/SKILL.md` | Match — Rules 15/16 present |
| T5 | `grep -E "restricted picklist\|record type.*picklistValues" plugins/revops/skills/sf-metadata/SKILL.md` | Match — Rule 11 present |
| T6 | `grep -E "flexipage\|IndexedDB" plugins/revops/skills/sf-metadata/SKILL.md` | Match — Rules 17-19 present |
| T7 | `grep "ListView" plugins/revops/skills/sf-metadata/SKILL.md` | Match — Rules 8/9 present |
| T8 | In brite-salesforce: ask "add a new Lead.CustomerType__c field" | Deferred — cross-repo manual check post-merge, per BC-5793 deferral pattern |
| T9 | In non-SF repo: same question | Deferred — cross-repo manual check post-merge |
| T10 | `./scripts/validate.sh` | Exit 0 |

T8/T9 deferred in keeping with BC-5793 precedent — cross-repo manual verification only feasible post-merge. T1-T7 + T10 all runnable locally before PR.

## Factual-anchor discipline (BC-5795/BC-5796 lesson) — RESULTS

Three checks run during Explore (Task 1, 2026-04-20):

1. **Line-range citation** ✓ — `§Engineering Standards` at lines 37–50; `§Metadata Authoring` at lines 120–143. Every rule source column populated with exact line numbers above.
2. **Bullet-count verification** ✓ — `gh api … | sed -n '120,143p' | grep -c "^- \*\*"` → **20** bullets in §Metadata Authoring. Narrative §Brite Context claims "20 bullets distilled" — matches source.
3. **Canonical path verification** ✓ — all 4 paths confirmed via §Project Structure (lines 50–82): `force-app/main/default/` root, `objects/`, `standardValueSets/`, `profiles/`, `.forceignore` at repo root.

All three anchors held before Task 3 began.

## Check-in cadence

Standard Phase 3 gates: Explore (verification checks above) → **this plan → approval before Execute** → Verify (10 objective tests → paste results). One plan-gate check-in is THIS APPROVAL.

## Out of scope

- Modifying brite-salesforce metadata itself (we document Brite conventions, we don't touch Brite's metadata)
- Other Phase 3 skills (sf-soql, sf-testing, sf-debug, sf-flow etc. each get their own issue)
- Dynamic Forms migration planning — Rules 20-21 document current reality, not a migration plan
- Flow deploy-as-Draft gotcha — lives in sf-flow's customization (BC-5801), not sf-metadata

## Artifacts produced

- `docs/plans/BC-5797-plan.md` (this file)
- `plugins/revops/skills/sf-metadata/SKILL.md` (edited in Execute)

## Related

- `plugins/revops/UPSTREAM.md` (canonical attribution line)
- `plugins/revops/skills/sf-apex/SKILL.md` (BC-5796 canonical template — 4th-sibling pattern inherited)
- `plugins/revops/skills/sf-connected-apps/SKILL.md` (BC-5795 v2 — placement before `## When This Skill Owns the Task`)
- `plugins/revops/skills/sf-permissions/SKILL.md` (BC-5794 — sibling-one template)
- `plugins/revops/skills/sf-deploy/SKILL.md` (BC-5793 — sibling-zero template)
- `brite-salesforce/CLAUDE.md` §Metadata Authoring (source of record)
- `docs/plans/revops-plugin-master-plan.md` §9 Issue 3.5
- BC-5400 (metadata retrieve `--metadata` flag lesson, referenced in Rule 11)
