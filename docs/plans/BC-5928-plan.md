# BC-5928 Plan — Customize Phase 3 skills: sf-flow + sf-lwc

**Issue:** [BC-5928](https://linear.app/brite-nites/issue/BC-5928)
**Phase:** 3 (per-skill customization) — Group B
**Absorbs:** BC-5801 (sf-flow, Medium) + BC-5802 (sf-lwc, Low) — both Canceled
**Worktree:** `.claude/worktrees/bc-5928/`
**Branch:** `holden/bc-5928-customize-phase-3-skills-sf-flow-sf-lwc-declarative-ui`

---

## Design decisions (template inherited from BC-5927)

1. **Overlap policy** — restate with `See also:` cross-references. Each skill stands alone on retrieval; sf-flow restates the Apex-first flow policy that also lives in sf-apex / sf-testing (intentional overlap, consistent with BC-5927 pattern).
2. **Scope** — `plugins/revops/skills/sf-flow/SKILL.md` and `plugins/revops/skills/sf-lwc/SKILL.md` only. Reference files untouched (consistent with all 8 prior Phase 3 ports).
3. **Frontmatter pattern** — BC-5927 template: `version: 2.1.0-brite.1`, `upstream: Jaganpro/sf-skills@ff1ab74`, `author: "Jag Valaiyapathy (upstream); Brite Company (customization)"`, description expanded with Brite triggers, title suffix `(Brite edition)`. Note: upstream version on these two skills is `2.1.0` (not `1.1.0` like sf-testing/sf-debug) — preserve upstream major.minor, append `-brite.1`.
4. **Attribution** — HTML comment at top of body: `<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §<sections>. -->`
5. **Section structure** — matches BC-5927: `## Brite Context` (narrative framing + See also) → `## Brite <Domain> <Topic>` (numbered rules from issue-specified bullets) → existing upstream body retained verbatim.
6. **Batch order** — sf-flow first (per issue), commit + checkpoint, then sf-lwc.
7. **Plugin version bump** — `plugins/revops/.claude-plugin/plugin.json` and the revops entry in `.claude-plugin/marketplace.json` are at `0.2.0` (post-BC-5927). Bundle bump `0.2.0 → 0.2.1` (patch — this PR is a single 2-skill batch, not a catch-up like BC-5927) into Commit 1 alongside the sf-flow edit. BC-6000 rule applies: any edit under `plugins/revops/skills/**` requires bumping both files in the same commit.

---

## Task 1 — Customize `plugins/revops/skills/sf-flow/SKILL.md`

**Absorbs:** BC-5801

### Frontmatter edits

- `description` — extend with Brite triggers: Apex-first flow policy (screen flows + simple notifications only), Screen-Flow-deploy-as-Draft gotcha, post-deploy Tooling API verification, scratch org applicability, cross-reference to `/revops:post-deploy-runbook`.
- `metadata.version`: `"2.1.0"` → `"2.1.0-brite.1"`
- `metadata.author`: `"Jag Valaiyapathy"` → `"Jag Valaiyapathy (upstream); Brite Company (customization)"`
- `metadata.upstream`: new field `"Jaganpro/sf-skills@ff1ab74"`

### Title edit

`# sf-flow: Salesforce Flow Creation and Validation` → `# sf-flow: Salesforce Flow Creation and Validation (Brite edition)`

### Attribution comment (insert before `# sf-flow:` title)

```html
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Engineering Standards (line 41) + §Apex & Automation (line 189, screen-flow activation). -->
```

### New `## Brite Context` section (insert after attribution, before existing "Use this skill when..." paragraph)

Narrative framing — 4 bullets:

- **Apex-first by policy.** Brite uses Flows only for (a) Screen Flows (user-facing UI), (b) simple notifications where Apex would be overkill. Never auto-launched flows for business logic. Source: `brite-salesforce/CLAUDE.md` §Engineering Standards line 41.
- **Screen Flows deploy as Draft regardless of source `<status>Active</status>`.** `sf data update record` cannot activate flows (fails serializing complex Metadata fields). Activation is a manual Setup-UI step that ships in `/revops:post-deploy-runbook` Phase 2.
- **Post-deploy verification is non-optional.** After every deploy that includes flows, verify activation via Tooling API SOQL. The deploy `Status: Succeeded` line is necessary but not sufficient.
- **Scratch orgs share the Draft trap.** Same activation gap applies to scratch-org CI runs after a deploy preprocess.

**See also:** [sf-apex](../sf-apex/SKILL.md) for the Apex-first automation patterns (trigger handler dispatch, Queueable design); [sf-deploy](../sf-deploy/SKILL.md) for safe deployment sequencing; [sf-lwc](../sf-lwc/SKILL.md) when a flow embeds an LWC for richer UI; `/revops:post-deploy-runbook` for the post-deploy activation walk-through.

### New `## Brite Flow Policy` section (numbered rules, insert after `## Brite Context`)

1. **Flow policy — Apex-first; Flows only for screen flows + simple notifications.** Auto-launched flows for business logic are out — use Apex. Record-triggered flows for trivial branching only. Source: §Engineering Standards line 41.
2. **Screen Flows deploy as Draft.** Even when source XML specifies `<status>Active</status>`, newly-deployed screen flows land in Draft in the target org. Activate via Setup → Flows → find the flow → click Activate on the version row. Verified during BC-5021 prod deploy (2026-04-16).
3. **`sf data update record` cannot activate flows.** It fails serializing the complex `Metadata` field on the Flow object. Use Setup UI; do not script the activation.
4. **Post-deploy SOQL verification — Tooling API.** After a flow deploy: `SELECT Status FROM Flow WHERE Definition.DeveloperName = '<Flow_Name>'`. Confirm `Status = 'Active'` before treating the deploy as landed.
5. **Scratch org applicability.** The Draft trap applies to scratch orgs too; CI deploys that run flows must include the activation step (or skip flow-dependent assertions).
6. **Some Screen Flow settings are UI-only.** Like Kanban Group By selection (sf-metadata), certain flow runtime configurations live at the Lightning UI layer and aren't deployable. Document any UI-only setup per-org so sandbox refreshes don't lose it.
7. **`/revops:post-deploy-runbook` cross-reference.** Phase 2 of the post-deploy runbook walks through Screen Flow activation diff-driven (only prompts when the deploy includes new/changed flows). Use it as the canonical post-deploy gate.

### Verify — sf-flow (T1-T7, per issue body)

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | `ls plugins/revops/skills/sf-flow` | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-flow/SKILL.md` | Match |
| T3 | `grep -E "Apex-first\|Flows only" plugins/revops/skills/sf-flow/SKILL.md` | Policy referenced |
| T4 | `grep -E "Draft.*Active\|deploy.*Draft" plugins/revops/skills/sf-flow/SKILL.md` | Deploy gotcha present |
| T5 | `grep "/revops:post-deploy-runbook" plugins/revops/skills/sf-flow/SKILL.md` | Cross-reference present |
| T6 | In brite-salesforce: ask "should I use a flow for this trigger logic?" | sf-flow activates; redirects to Apex |
| T7 | `./scripts/validate.sh` | Exit 0 |

### Commit message

`BC-5928: customize sf-flow + bump revops 0.2.0 → 0.2.1` (bundled commit — sf-flow SKILL.md edit + plan doc + plugin.json bump + marketplace.json bump)

### Checkpoint gate

User confirms T1-T5 + T7 pass before sf-lwc starts. T6 is a user-driven activation probe — deferred to PR-review time.

---

## Task 2 — Customize `plugins/revops/skills/sf-lwc/SKILL.md`

**Absorbs:** BC-5802

### Frontmatter edits

- `description` — extend with Brite triggers: Jest pre-commit, Dynamic Forms FLS-required-even-for-admins, field-level vs section-level visibility, Flexipage IndexedDB cache, two-column template name, DateTime `uiBehavior=readonly`, LWC security primitives.
- `metadata.version`: `"2.1.0"` → `"2.1.0-brite.1"`
- `metadata.author`: `"Jag Valaiyapathy"` → `"Jag Valaiyapathy (upstream); Brite Company (customization)"`
- `metadata.upstream`: new field `"Jaganpro/sf-skills@ff1ab74"`

### Title edit

`# sf-lwc: Lightning Web Components Development` → `# sf-lwc: Lightning Web Components Development (Brite edition)`

### Attribution comment

```html
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Engineering Standards (line 43) + §Metadata Authoring (Dynamic Forms + Flexipage gotchas, lines 137-142). -->
```

### New `## Brite Context` section

- **Jest required for all LWCs.** The pre-commit hook runs Jest tests on staged LWC files; any new LWC ships with Jest coverage. Source: §Engineering Standards line 43.
- **Dynamic Forms requires FLS even for admins.** `View All Data` / `Modify All Data` do NOT bypass Field-Level Security. A custom field with no `FieldPermissions` records is invisible in Dynamic Forms — even for System Administrators. Always deploy FLS alongside new fields.
- **Flexipage caches in IndexedDB for hours.** Hard browser refresh does NOT clear it. Three flush options: log out and back in, run `indexedDB.deleteDatabase("actions")` in Chrome console, or open the page in Lightning App Builder and click Save.
- **Two-column template name is `flexipage:recordHomeTemplateDesktop`** — NOT `...TwoColTemplateDesktop` (that name does not exist). Regions: `sidebar` (left) + `main` (right).

**See also:** [sf-apex](../sf-apex/SKILL.md) for `@AuraEnabled` controllers and security primitives; [sf-flow](../sf-flow/SKILL.md) when an LWC embeds in a screen flow; [sf-metadata](../sf-metadata/SKILL.md) for the broader Dynamic Forms / Flexipage gotcha set; [sf-deploy](../sf-deploy/SKILL.md) for FLS-alongside-fields deploy discipline.

### New `## Brite LWC Discipline` section (numbered rules)

1. **Jest required for all LWCs.** The pre-commit hook runs `npm test` against staged LWC files. Any new LWC ships with Jest coverage. Canonical commands: `npm test`, `npm run test:unit:coverage`. Source: §Engineering Standards line 43.
2. **Dynamic Forms requires FLS even for admins.** `View All` / `Modify All Data` do NOT bypass Field-Level Security. Deploy FLS alongside any new field used in a Dynamic Form. If `--source-dir` deploys roll back (e.g., ECA failures), deploy fields and FLS individually with `-m` flags.
3. **Field-level vs section-level visibility evaluate differently.** Field-level rules (`visibilityRule` on `fieldItem`) evaluate reactively during editing. Section-level rules (`visibilityRule` on `fieldSection`) evaluate only on saved record values. Use field-level when a field should appear/disappear as the user edits a controlling picklist.
4. **Flexipage cache lives in IndexedDB and persists for hours.** Hard refresh (`Cmd+Shift+R`) does NOT clear it. Flush via: log out and back in, OR `indexedDB.deleteDatabase("actions")` in Chrome console, OR open the page in Lightning App Builder and click Save. For sandbox dev, consider disabling durable caching: Setup → Session Settings → uncheck "Enable secure and persistent browser caching."
5. **Two-column template name** — `flexipage:recordHomeTemplateDesktop` (NOT `flexipage:recordHomeTwoColTemplateDesktop` — that name does not exist). Regions: `sidebar` (left) + `main` (right). Three-column equivalent: `flexipage:recordHomeThreeColTemplateDesktop` with regions `leftsidebar`, `main`, `rightsidebar`.
6. **Dynamic Forms `uiBehavior` for DateTime fields — use `readonly`, not `none`.** `none` can cause the field to not render. `readonly` is the standard pattern for auto-populated DateTime fields on flexipages.
7. **LWC security primitives inherit platform permissions via `@AuraEnabled`.** Apex methods exposed with `@AuraEnabled(cacheable=true)` enforce CRUD/FLS through the calling user's profile + permission sets. Don't bypass; use stripInaccessible / Schema.DescribeFieldResult checks when defending against partial-FLS scenarios.

### Verify — sf-lwc (T1-T7, per issue body)

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | `ls plugins/revops/skills/sf-lwc` | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-lwc/SKILL.md` | Match |
| T3 | `grep "Jest" plugins/revops/skills/sf-lwc/SKILL.md` | Jest requirement present |
| T4 | `grep -E "Dynamic Forms.*FLS\|FLS.*Dynamic" plugins/revops/skills/sf-lwc/SKILL.md` | FLS gotcha present |
| T5 | `grep "flexipage" plugins/revops/skills/sf-lwc/SKILL.md` | Flexipage gotcha present |
| T6 | In brite-salesforce: ask "build me a record-page LWC" | sf-lwc activates; flags FLS requirement |
| T7 | `./scripts/validate.sh` | Exit 0 |

### Commit message

`customize sf-lwc with Brite LWC discipline (BC-5928)`

### Checkpoint gate

User confirms T1-T5 + T7 pass before final verify task.

---

## Task 3 — Final verify

1. Run full 14-test matrix (sf-flow T1-T7 + sf-lwc T1-T7); capture output for PR body.
2. `./scripts/validate.sh` exits 0.
3. Worktree `git log --oneline` shows 2 commits on the branch:
   - `BC-5928: customize sf-flow + bump revops 0.2.0 → 0.2.1`
   - `customize sf-lwc with Brite LWC discipline (BC-5928)`
4. No changes outside `plugins/revops/skills/sf-flow/SKILL.md`, `plugins/revops/skills/sf-lwc/SKILL.md`, `plugins/revops/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and this plan doc.

---

## Out of scope

- Reference files (`sf-flow/references/*`, `sf-lwc/references/*`, `sf-flow/assets/*`, `sf-lwc/assets/*`) — keep upstream-MIT; Brite context lives in SKILL.md only.
- `sf-flow/scripts/*`, `sf-flow/hooks/*`, `sf-lwc/hooks/*` — upstream Jaganpro artifacts; not Brite hooks.
- sf-data, sf-docs, sf-integration — Group C (BC-5931), separate issue.

---

## Rollback

`git worktree remove -f .claude/worktrees/bc-5928 && git branch -D holden/bc-5928-customize-phase-3-skills-sf-flow-sf-lwc-declarative-ui` — no external state mutated; all changes are local repo edits.
