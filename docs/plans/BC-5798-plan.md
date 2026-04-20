# BC-5798 Plan — Customize sf-soql with Brite object model + SOQL gotchas

**Issue:** [BC-5798](https://linear.app/brite-nites/issue/BC-5798) · **Milestone:** RevOps Plugin · **Priority:** Medium · **Blocked by:** BC-5789 (scaffold — done) · **Related:** BC-5797 (sibling template, done)

## Scope

Layer Brite's object model + SOQL-specific gotchas onto the upstream `plugins/revops/skills/sf-soql/SKILL.md`. Single-file markdown customization. No upstream `references/`, `assets/`, or `hooks/` are touched. **5th sibling** applying the BC-5793 → BC-5794 → BC-5795 → BC-5796 → BC-5797 ratified Phase 3 template.

## Departures from issue body (locked by sibling precedents — NOT re-litigated)

Four departures apply verbatim from BC-5793, per BC-5794/BC-5796/BC-5797 precedent:

| # | Issue body says | Override | Source |
|---|-----------------|----------|--------|
| 1 | (issue does not request rename — already keeps `sf-soql`) | n/a (no override needed) | — |
| 2 | Execute step 2 commit message: `customize sf-soql with Brite object model` | Keep verbatim — matches BC-5797 commit-message form | BC-5797 commit `f4771c1` |
| 3 | Verify T1: `ls plugins/revops/skills/sf-soql` | No flip needed (already upstream name) | — |
| 4 | Verify T2-T6: grep `plugins/revops/skills/sf-soql/SKILL.md` | No flip needed | — |

Per BC-5794 precedent (strengthened by BC-5797's five-sibling durability claim), no AskUserQuestion needed for template elements — the template is locked and re-deriving would waste turns.

## Template shape (BC-5797 canonical)

Placement: **Brite sections BEFORE `## When This Skill Owns the Task`.** Template variant B (majority 4/5 among ratified siblings).

Sections to add, in order:

1. Frontmatter updates (extended `author:`, new `upstream:` key, version bump)
2. Attribution HTML comment below frontmatter, above H1
3. `## Brite Context` — Brite's object-model stance + entity landmarks + See-also links
4. `## Brite SOQL Conventions` — 18 rules grounded in `brite-salesforce/CLAUDE.md` §Business Context + §Apex & Automation + §Engineering Standards
5. Preserve all original upstream sections unchanged below

## Frontmatter changes

```yaml
metadata:
  version: "1.1.0-brite.1"          # was "1.1.0"
  author: "Jag Valaiyapathy (upstream); Brite Company (customization)"
  upstream: "Jaganpro/sf-skills@ff1ab74"
  scoring: "100 points across 5 categories"
```

Also extend `description:` with the Brite-repo trigger signal (Territory__c / cross-env User lookup / Task polymorphic / Lifecycle_Stage__c filter) so the skill auto-invokes inside `brite-salesforce` and does NOT fire elsewhere (T7 + T8 verify).

## Attribution comment

```
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Business Context + §Apex & Automation. -->
```

Matches T2 grep (`"Adapted from Jaganpro"`) and the canonical form in `plugins/revops/UPSTREAM.md`.

## Brite SOQL Conventions (18 rules, grounded in brite-salesforce/CLAUDE.md)

Each rule cites a specific source line. Factual anchors verified via `gh api` fetch on 2026-04-20 (per BC-5795 ground-truth + BC-5796 bullet-count + BC-5797 Linear-citation discipline).

**Source ground truth (verified 2026-04-20 via `gh api`):**
- §Engineering Standards line 40: 1 rule (API version)
- §Business Context lines 213-221: 3 rules (4 business lines + Location FSL + Territory__c)
- §Apex & Automation lines 177-196: 9 rules (handler dispatch + trigger/schedule SOQL + Task & User gotchas + polymorphic + `with sharing` + Tooling API)
- §Metadata Authoring lines 122 / 128 / 158 / 168: 4 rules (Activity fields + Lifecycle_Stage__c picklist + Campaign Influence 2.0 + Lifecycle history audit)
- Issue body: 1 composite query-patterns rule

Total: 1 + 3 + 9 + 4 + 1 = **18 rules.**

**Linear-citation verification (BC-5797 factual-anchor check #4):**
- BC-5021: Done 2026-04-15, handbook line 183 cites verbatim ✔
- BC-5545: **In Progress** (known drift risk), handbook line 188 cites verbatim → keep parenthetical because handbook echoes
- BC-5609: Done 2026-04-17, handbook lines 181/194/195 cite verbatim ✔

**Theme layout (A-H):**

- **Theme A — Source + API context** (2 rules: §Engineering Standards + §Apex & Automation): Rule 1 API v65.0, Rule 2 Tooling API via `useToolingApi: true`
- **Theme B — Brite object model** (4 rules): Rule 3 four-business-line RT prefixes, Rule 4 Location FSL junction, Rule 5 Territory__c (not ETM), Rule 6 Lifecycle_Stage_History__c automation-written audit
- **Theme C — Task & polymorphic** (4 rules): Rule 7 semi-join limit, Rule 8 polymorphic dot-walking (TYPEOF preferred), Rule 9 Task.AccountId no cascade, Rule 10 Activity-object field naming
- **Theme D — User cross-env + sharing** (2 rules): Rule 11 User.Email cross-env lookup, Rule 12 `with sharing` User exemption
- **Theme E — Trigger + scheduler SOQL** (3 rules): Rule 13 before-update pre-update state, Rule 14 Schedulable DML 10k, Rule 15 LeadSource dispatcher
- **Theme F — Lifecycle_Stage picklist** (1 rule): Rule 16 restricted-picklist RT-level + automation-only
- **Theme G — Campaign Influence 2.0** (1 rule): Rule 17 CampaignInfluence queries available
- **Theme H — Canonical Brite query patterns** (1 composite rule): Rule 18 four pattern examples

## §Brite Context content (header section)

Brite's object model wraps a standard Salesforce core with five extensions — three custom + two standard used in Brite-specific ways. Know the four business lines, FSL/Territory distinction, and automation-written audit table before writing pipeline or attribution SOQL. Authoritative landmarks: `brite-salesforce/force-app/main/default/objects/`, `brite-salesforce/CLAUDE.md` §Business Context + §Apex & Automation, `brite-salesforce/docs/artifacts/data-dictionary.md`. SOQL gotchas trace to verified incidents: BC-5021 (before-update cascade), BC-5545 (Task re-parenting), BC-5609 (cross-env User + sharing). See also: sf-apex (DML context), sf-data (execution), sf-permissions (FLS-aware queries), sf-metadata (field shape).

## Execute

1. Edit `plugins/revops/skills/sf-soql/SKILL.md`:
   - Update frontmatter per §Frontmatter changes
   - Insert attribution comment below frontmatter, above H1
   - Insert `## Brite Context` (content per §Brite Context content)
   - Insert `## Brite SOQL Conventions` with the 18-rule table (Themes A-H)
   - Preserve all existing upstream sections below, unchanged
2. Commit: `customize sf-soql with Brite object model`

## Verify — Objective criteria (from issue body, rule-numbered)

Before running, the **verify-matrix regex pre-check** (BC-5797 Rule 5 of the factual-anchor recipe) is mandatory: run every grep below against the drafted SKILL.md **before** Execute is considered complete.

| Test | Command / Action | Pass criteria |
|------|------------------|---------------|
| T1 | `ls plugins/revops/skills/sf-soql` | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-soql/SKILL.md` | Match |
| T3 | `grep -E "Territory__c\|Lifecycle_Stage_History__c\|Location" plugins/revops/skills/sf-soql/SKILL.md` | Brite objects present (Rules 4, 5, 6) |
| T4 | `grep "semi-join" plugins/revops/skills/sf-soql/SKILL.md` | Task limit documented (Rule 7) |
| T5 | `grep -E "User\.Email\b.*Username\|cross-env" plugins/revops/skills/sf-soql/SKILL.md` | Cross-env lookup pattern (Rule 11) |
| T6 | `grep -E "polymorphic\|TYPEOF" plugins/revops/skills/sf-soql/SKILL.md` | Polymorphic gotcha (Rule 8) |
| T7 | In brite-salesforce: ask "query all Leads in my territory" | sf-soql activates; uses Territory__c pattern |
| T8 | In non-SF repo: same question | Does NOT activate |
| T9 | `./scripts/validate.sh` | Exit 0 |

T7 + T8 are deferred post-merge per BC-5793 precedent.

## Factual-anchor recipe applied (BC-5797 five checks)

1. **Line-range citation** — every rule cites a specific `brite-salesforce/CLAUDE.md` line ✔
2. **Bullet-count verification** — 20 bullets under §Apex & Automation lines 177-196, 9 in scope for sf-soql, 11 out of scope mapped to sibling skills (sf-apex: 178/179/181/195; sf-deploy: 180/182; sf-metadata: 185; sf-testing: 191/192/193) ✔
3. **Canonical path verification** — run pre-commit ✔
4. **Live Linear verification** — BC-5021 Done ✔, BC-5609 Done ✔, BC-5545 In Progress (handbook echoes) ✔
5. **Verify-matrix regex pre-check** — T2-T6 grep patterns run pre-commit ✔

## Pre-merge simplify + review fixes applied

Per BC-5797 pre-merge review pattern, `/workflows:review` thorough (4 agents: code, security, performance, cdr-compliance) was run pre-merge. Results:

**Simplify pass (4 fixes, content correctness):**
1. §Brite Context "five custom extensions" → split "three custom + two standard" (`Location` is FSL standard, `AccountContactRelation` is standard SF)
2. "BC-5545 (Task re-parenting, in-flight)" → "Rule 9 (BC-5545 Task re-parenting)" (Rule 9 uses handbook's "verified during" wording)
3. "Each rule cites a specific source line" → "cites a specific source line where possible; synthesized patterns (Rules 6, 18) also reference the BC-5798 issue body"
4. Rule 14 DML framing: expanded "query's result rows flow into downstream DML, so the DML cap constrains combined query output" + "Raising any individual query's LIMIT requires switching to Batchable"

**Review fixes (2 CONFIRMED, P3, confidence ≥7):**
1. Rule 12 citation: appended `, BC-5609` to match Rule 11's citation shape
2. Rule 8: reframed TYPEOF vs separate-query as ranked (TYPEOF preferred — single query; separate-query only when field-set/polymorphic-branch constraints don't fit)

Dismissed findings with reasons in compound-learnings commit.

## Out of scope

- Modifying `brite-salesforce` schema
- Other Phase 3 skills (BC-5799 - BC-5805)
- Upstream `references/` files under `plugins/revops/skills/sf-soql/references/`
- SOSL-specific Brite additions (issue body scopes to SOQL)

## Related

- BC-5789 (scaffold)
- BC-5793 / BC-5794 / BC-5795 / BC-5796 / BC-5797 (sibling precedents, ratified template)
- `docs/plans/revops-plugin-master-plan.md` §9 Issue 3.6
