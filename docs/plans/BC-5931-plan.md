# BC-5931 Plan — Customize Phase 3 skills: sf-data + sf-docs + sf-integration (Group C)

**Issue:** [BC-5931](https://linear.app/brite-nites/issue/BC-5931)
**Phase:** 3 (per-skill customization) — Group C of A/B/C
**Absorbs:** BC-5803 (sf-data, Low) fully + BC-5805 (sf-integration, Low) fully + BC-5804 (sf-docs, Low) **partially** — see Design decision #1 below
**Follow-up:** [BC-6081](https://linear.app/brite-nites/issue/BC-6081) authors the sibling sf-internal-docs skill (filed during review pass, see §Task 4).
**Worktree:** `.claude/worktrees/bc-5931/`
**Branch:** `holden/bc-5931-customize-phase-3-skills-sf-data-sf-docs-sf-integration`

---

## Post-review amendments (after `/workflows:review`)

The /workflows:review pass surfaced a P1+P2+P3 set covering description bloat, Brite Context bullet duplication, dead-reference forward pointers, and `brite-salesforce/CLAUDE.md` section miscitations. The user invoked ultrathink and asked for all findings to be fixed. Amendments applied (all behavior-preserving):

1. **Section miscitations fixed (P2 9/10, cdr-compliance):** sf-data Rule 2/3 citations + header attribution comment had `§Apex & Automation` for lines 143-144, but those lines actually live in `§Metadata Authoring` in `brite-salesforce/CLAUDE.md` (verified by grep against source). Already shipped in commit `d02e830`.
2. **Description tightening (P1 9/10, efficiency):** sf-data + sf-integration descriptions trimmed from ~1000 chars to ~600 chars by removing parenthetical asides that restated body content; backticks dropped where prose works; all trigger keywords preserved.
3. **Brite Context simplified to headline form (P2 9/10, efficiency):** sf-data + sf-integration `## Brite Context` sections changed from 4 dense narrative bullets restating numbered rules into 4 headline bullets pointing at the rules. "stance:" preambles + "These rules govern..." narrative lines deleted (P3 8/10 each).
4. **sf-data Rule 7 dual citation trimmed (P3 7/10):** "BC-5545 + drift audit 2026-04-24" → "BC-5545" (drift audit appears in 3 other rules; BC-5545 is the more specific incident).
5. **sf-docs attribution updated with real BC-#### (P3 8/10):** `BC-6081` filed during review pass; sf-docs attribution comment now points at it instead of "filed as a follow-up to BC-5931" (which was a forward-promise).
6. **UPSTREAM.md Lineage classes section added (P3 7/10):** Three classes documented — Adapted from upstream / Adopted verbatim from upstream / Added by Brite. Names sf-docs as the precedent-setter for class 2 and sf-internal-docs (BC-6081) as the planned precedent-setter for class 3.
7. **Plan doc resync:** §Task 1 + §Task 2 Brite Context drafts updated to match shipped headline form. §Task 4 marked DONE (BC-6081) and clarified the T6 distinction (BC-5931's §Task 3 sf-docs T6 = web-retrieval; BC-6081's verify T6 = internal-docs activation).

**Skipped findings** (with rationale): numbered rule subheadings restating body — most rules extend rather than restate, the apparent duplication is mechanism explanation; speculative "move citations to footnote" — inline citations are better UX; cross-reference asymmetry on Email Bison/OutboundSync — `handshake` and `data shape` are genuinely distinct concerns, agent's claim was wrong; patch vs minor version bump — either defensible, no user-facing change; description backticks — already partially addressed in description tightening.

**Template divergence flag:** BC-5927 + BC-5928 sister-batch skills still use the older "stance:" preamble + "These rules govern..." filler + dense Brite Context bullets pattern. BC-5931 sets the new template form going forward. A coordinated rebaseline of BC-5927/BC-5928 to match should be filed as a follow-up if template parity matters; otherwise the divergence is intentional (BC-5931 is precedent-setting).

---

## Design decisions

1. **sf-docs split.** Brainstorm surfaced an architectural mismatch: the upstream sf-docs skill is a **web-retrieval playbook** for *official Salesforce-owned documentation* (`developer.salesforce.com`, `help.salesforce.com`, etc.) with explicit non-goals "no local corpus, no repo-specific scripts" (line 197-203). The issue's Brite additions (artifact inventory, ADR convention, cross-repo references) are a **different concern** (Brite-internal navigation), not a customization of the same concern. Resolution: sf-docs adopted **verbatim** (attribution comment only); a new sibling skill `sf-internal-docs` will own the Brite-internal concern, **authored in a follow-up issue** (Brite-original = lineage precedent-setter, deserves its own audit). BC-5804 lands here only at the attribution-comment depth; full BC-5804 absorption completes in the follow-up.

2. **Overlap policy for sf-data ↔ sf-integration: single-owner with cross-references.** Source-material survey shows the overlap is narrow once mapped: sf-data owns ETL mechanics + email-as-Task + Bulk API gotchas (data semantics); sf-integration owns Named Credentials + Queueable silent-retry + ECA story (external-system handshake). HubSpot migration is referenced from both but described mechanically only in sf-data. Departs from BC-5927/BC-5928 "restate with cross-reference" because in this batch the surfaces are genuinely different — restating would be redundant.

3. **Scope.** `plugins/revops/skills/sf-data/SKILL.md`, `plugins/revops/skills/sf-integration/SKILL.md`, and `plugins/revops/skills/sf-docs/SKILL.md` only. Reference files untouched (consistent with all 10 prior Phase 3 ports).

4. **Frontmatter pattern (sf-data + sf-integration).** BC-5927 template: `version: <upstream>-brite.1`, `upstream: Jaganpro/sf-skills@ff1ab74`, `author: "Jag Valaiyapathy (upstream); Brite Company (customization)"`, description expanded with Brite triggers, title suffix `(Brite edition)`. Upstream versions: sf-data `1.2.0`, sf-integration `1.2.0` — both become `1.2.0-brite.1`. **sf-docs frontmatter unchanged** (verbatim adoption per #1).

5. **Attribution.**
   - sf-data + sf-integration: HTML comment per BC-5927 template (`<!-- Adapted from ... layers Brite conventions from ... -->`).
   - sf-docs: minimal attribution comment naming the verbatim-adoption decision and the sibling pointer (`<!-- Adopted verbatim from ... Brite-internal docs live in sf-internal-docs (see BC-XXXX). -->`).

6. **Section structure (sf-data + sf-integration).** Matches BC-5927/BC-5928: `## Brite Context` (4 bullets + See also) → `## Brite <Domain> Discipline` (numbered rules from issue-spec bullets, density tuned to source-material density) → existing upstream body retained verbatim.

7. **Batch order.** sf-data first (largest customization, bundles plugin version bump), checkpoint, sf-integration, checkpoint, sf-docs (attribution-only).

8. **Plugin version bump.** revops `0.2.1` → `0.2.2` (patch — single-batch customization, not catch-up). BC-6000 rule: any edit under `plugins/revops/skills/**` requires bumping both `plugins/revops/.claude-plugin/plugin.json` and the revops entry in `.claude-plugin/marketplace.json` in the same commit. Bundle bump into Commit 1 (sf-data).

9. **Follow-up issue scope (filed at end of this PR, before ship).** New BC issue: "Author sf-internal-docs (Brite-original SF-internal reference map skill)" — absorbs the unfinished portion of BC-5804. Captures the sf-internal-docs verify matrix items (T3-T5 from issue spec sf-docs verify table) plus lineage-precedent decisions: skill author convention, frontmatter shape (`version: 0.1.0`, no `upstream` field), UPSTREAM.md "Added by Brite" subsection.

---

## Task 1 — Customize `plugins/revops/skills/sf-data/SKILL.md`

**Absorbs:** BC-5803

### Frontmatter edits

- `description` — append Brite triggers (HubSpot migration ETL, email-as-Task semantics, `setSaveAsActivity` Email Logs monitoring, Bulk API session-permset gotchas, `CreateAuditFields` INSERT-only behavior, `#N/A` null sentinel, Task.AccountId re-parenting via WhatId). Tightened during review pass — see Post-review amendments §2.
- `metadata.version`: `"1.2.0"` → `"1.2.0-brite.1"`
- `metadata.author`: `"Jag Valaiyapathy"` → `"Jag Valaiyapathy (upstream); Brite Company (customization)"`
- `metadata.upstream`: new field `"Jaganpro/sf-skills@ff1ab74"`

### Title edit

`# Salesforce Data Operations Expert (sf-data)` → `# Salesforce Data Operations Expert (sf-data) (Brite edition)`

### Attribution comment (insert before `# Salesforce Data Operations Expert` title)

```html
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Metadata Authoring (lines 130, 143-144) + §Permissions & Security (lines 175-176) + §Apex & Automation (lines 182, 191-193) + §Migration Reference + scripts/migration/. -->
```

### New `## Brite Context` section (insert after attribution, before existing "Use this skill when..." paragraph)

**Headline orientation — 4 bullets pointing at numbered rules** (per review-pass simplification — see Post-review amendments at top of doc):

- **HubSpot migration is complete** (Phase 1 2026-03-20, Phase 2 2026-03-24) — see Rule 1 for ETL layout.
- **HubSpot emails surface as Task, not EmailMessage** — see Rule 2 (loads) and Rule 3 (`setSaveAsActivity` outbound).
- **Bulk API has session-permset and audit-field gotchas** — see Rules 4 and 5.
- **Task re-parenting follows `WhatId`, not Contact** — see Rule 7.

**See also:** [sf-soql](../sf-soql/SKILL.md) for query-only work (no record mutations); [sf-integration](../sf-integration/SKILL.md) for the Email Bison → OutboundSync handshake that produces Tasks; [sf-permissions](../sf-permissions/SKILL.md) for the 7-permset FLS sync discipline.

### New `## Brite Data Discipline` section (numbered rules, insert after `## Brite Context`)

1. **HubSpot migration architecture.** ETL scripts in `brite-salesforce/scripts/migration/` are layered: `extract/` (HubSpot pull), `transform/` (Brite mapping), `load/` (SF push), `validate/` (post-load reconciliation), `fix/` (drift remediation), `coverage/` (Jest mapping coverage). When asked "load 5000 records into Salesforce" or "fix migration drift," reference these scripts as the starting point — do not author one-off load scripts.
2. **HubSpot emails migrate as Task, not EmailMessage.** HubSpot email engagements load as `Task` records with `Type: "Email"`. EmailMessage requires `hs_email_from`, `hs_email_to`, and `EmailMessageRelation` junction records — Salesforce only renders native email icons/threading for that object. The migration's Task-shape choice is intentional. Source: §Metadata Authoring line 143.
3. **`Messaging.SingleEmailMessage` + `setSaveAsActivity(false)` → no EmailMessage record AND no Task activity.** Outbound emails sent this way leave zero rows in both objects. The ONLY monitoring path is Setup → Email Logs (24-hour rolling window). Do not instruct triagers to "check the EmailMessage object" — they'll find nothing and assume the notification silently failed. `NewsletterSignupNotificationService` is the current example. See `docs/artifacts/email-notification-matrix.md`. Source: §Metadata Authoring line 144.
4. **Bulk API does not honor session-based permsets.** `HubSpot_Migration` permset has `hasActivationRequired:true` — activation only happens per UI session via `SessionPermissionSetActivation`, NOT in Bulk API or `sf` CLI sessions. For data loads that need the bypass, verify with `FeatureManagement.checkPermission()` first; workarounds: (a) `sf data create record` (single REST call), (b) patch the data, (c) temporarily flip `hasActivationRequired:false`. Source: §Permissions & Security line 175.
5. **`CreateAuditFields` is INSERT-only.** API name is **capitalized** (`createAuditFields` is rejected at deploy time with "Unknown user permission"). Records inserted without the permission must be DELETED and re-inserted to set `CreatedDate` — upsert takes the UPDATE path for existing records and silently leaves `CreatedDate` unchanged. Requires the org-level **"Set Audit Fields upon Record Creation"** toggle enabled in Setup → User Interface. Verified during BC-2744. Source: §Permissions & Security line 176.
6. **Bulk API empty CSV cells = "skip", not "set null"; use `#N/A` for null.** Leaving a field empty in `sf data update bulk` CSVs causes Bulk API v1 to NOT UPDATE that field. To actually null out a field via bulk update, the cell must be literally `#N/A`. Common trap when writing migration/cleanup scripts that need to null foreign keys (`WhatId`, `AccountId`, `OwnerId`). Verified during drift audit 2026-04-24. Source: §Apex & Automation line 193.
7. **`Task.AccountId` follows `Task.WhatId`, not `Contact.AccountId`.** Task.AccountId is set at creation from `WhatId` (or derived from the `WhoId` Contact's AccountId at that moment) and **does not cascade** when the related Contact's AccountId later changes. To re-parent Tasks, explicitly `UPDATE Task SET WhatId = :newAccountId` — `WhatId` is polymorphic and Account is a valid target. Setting `WhatId = null` ALSO nulls AccountId, orphaning the task. Verified during BC-5545 contact re-parenting. Source: §Apex & Automation lines 191-192.
8. **Salesforce seed sample data may carry real correspondence.** Orgs provisioned with default sample data (`Acme (Sample)`, `salesforce.com (Sample)`, `Global Media (Sample)`) can accumulate real emails via HubSpot / Email Bison domain matching. Before deleting seed Accounts, ALWAYS check: `SELECT COUNT() FROM Task WHERE Account.Name = '...' AND Subject LIKE 'Email:%'`. Preserve by re-parenting Tasks (`UPDATE Task SET WhatId = [AccountId]`) and EmailMessages (`UPDATE EmailMessage SET RelatedToId = [AccountId]`) before the cascade. Verified during drift audit 2026-04-24: `salesforce.com (Sample)` had 58 real Slack/FSL emails mixed with 2 seed tasks. Source: §Metadata Authoring line 130.

### Verify — sf-data (T1-T7, per issue body)

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | `ls plugins/revops/skills/sf-data` | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-data/SKILL.md` | Match |
| T3 | `grep -E "HubSpot.*migration\|scripts/migration" plugins/revops/skills/sf-data/SKILL.md` | Migration tooling referenced |
| T4 | `grep -E "Task.*EmailMessage\|setSaveAsActivity" plugins/revops/skills/sf-data/SKILL.md` | Email migration caveat present |
| T5 | `grep -E "Bulk API\|session.based permset" plugins/revops/skills/sf-data/SKILL.md` | Bulk API gotcha present |
| T6 | In brite-salesforce: ask "load 5000 records into Salesforce" | sf-data activates; guides through Brite tools |
| T7 | `./scripts/validate.sh` | Exit 0 |

### Commit message

`BC-5931: customize sf-data + bump revops 0.2.1 → 0.2.2` (bundled commit — sf-data SKILL.md edit + plan doc + plugin.json bump + marketplace.json bump)

---

## Task 2 — Customize `plugins/revops/skills/sf-integration/SKILL.md`

**Absorbs:** BC-5805

### Frontmatter edits

- `description` — append Brite triggers (NC PLACEHOLDER URL strategy, namedCredentials .forceignore exclusion + BC-5609 lesson, Queueable silent-retry diagnostic, Email Bison → OutboundSync sync path, Brite_Base REST integration, ECA story post-Spring '26). Tightened during review pass — see Post-review amendments §2.
- `metadata.version`: `"1.2.0"` → `"1.2.0-brite.1"`
- `metadata.author`: `"Jag Valaiyapathy"` → `"Jag Valaiyapathy (upstream); Brite Company (customization)"`
- `metadata.upstream`: new field `"Jaganpro/sf-skills@ff1ab74"`

### Title edit

`# sf-integration: Salesforce Integration Patterns Expert` → `# sf-integration: Salesforce Integration Patterns Expert (Brite edition)`

### Attribution comment (insert before title)

```html
<!-- Adapted from Jaganpro/sf-skills@ff1ab74 (MIT). This file layers Brite conventions from brite-salesforce/CLAUDE.md §Engineering Standards (line 45) + §Apex & Automation (lines 182-184) + §External Client Apps (lines 148-152) + namedCredentials/Slack_Webform_Alerts. -->
```

### New `## Brite Context` section (insert after attribution, before existing "Use this skill when..." paragraph)

**Headline orientation — 4 bullets pointing at numbered rules** (per review-pass simplification):

- **Named Credentials are mandatory for outbound callouts** — see Rule 1.
- **NC URLs are PLACEHOLDER per-org** — see Rules 2 and 3 (`Slack_Webform_Alerts` is the canonical example; BC-5609 is the regression).
- **Queueable silent-retry = NC misconfig signature** — see Rule 4.
- **ECAs replace Connected Apps post-Spring '26** — see Rule 7 + sibling [sf-connected-apps](../sf-connected-apps/SKILL.md).

**See also:** [sf-connected-apps](../sf-connected-apps/SKILL.md) for ECA OAuth lifecycle; [sf-apex](../sf-apex/SKILL.md) for the Queueable silent-retry diagnostic in code; [sf-data](../sf-data/SKILL.md) for the Email Bison → OutboundSync → Task data shape; [sf-deploy](../sf-deploy/SKILL.md) for safe NC redeploy sequencing (commenting out `.forceignore` exclusions).

### New `## Brite Integration Discipline` section (numbered rules, insert after `## Brite Context`)

1. **Named Credentials are mandatory for outbound callouts.** No hardcoded endpoints or credentials in Apex, Flow XML, LWC, or anywhere else in source. Auth via External Credentials where supported (newer pattern); legacy NCs still acceptable. Source: §Engineering Standards line 45.
2. **Source-controlled NC URLs are PLACEHOLDER, not real.** Every NC `url` element in `force-app/main/default/namedCredentials/*.namedCredential-meta.xml` carries a placeholder. After deploying a NEW NC or redeploying NC shape changes, manually update the URL in **each** org via Setup → Named Credentials → Edit. Current Brite-active NC requiring per-org URL config: `Slack_Webform_Alerts`. Source: §Apex & Automation line 183.
3. **`.forceignore` exclusion for NCs is non-negotiable.** `namedCredentials/*.namedCredential-meta.xml` lives in `.forceignore` precisely because ongoing `sf project deploy start --source-dir force-app/` runs would silently re-push PLACEHOLDER over the working URL. To deploy a NEW NC or redeploy NC shape changes, **temporarily** comment out the `.forceignore` line, deploy, then restore (same pattern as ConnectedApp/ECA/Prompt/ListView exclusions). BC-5609 post-ship regression: pre-`.forceignore`, Slack callouts failed with the classic 1-original + 3-silent-retry pattern. Source: §Apex & Automation line 183.
4. **Queueable silent-retry = NC misconfig signature.** N consecutive `Completed` Apex jobs for the same class = 1 original + (N-1) silent retries. Jobs show `Completed` because the exception is caught — the diagnostic surface is the duplicate-Completed pattern in the Apex Jobs list, not a Failed status. **Always check the Named Credential endpoint first** when this signature appears (`Slack_Webform_Alerts` → `SlackWebformAlertJob` is the canonical example). See [sf-debug](../sf-debug/SKILL.md) for the full diagnostic walk-through. Source: §Apex & Automation line 182.
5. **OutboundSync is the canonical Email Bison → Salesforce sync path.** Email Bison sends webhook events to OutboundSync, which writes Contact updates and reply events into Salesforce. Skills do **not** subscribe Email Bison webhooks directly. When asked "how do I sync sequence replies into SF?", route to OutboundSync — not direct webhook handlers in Apex. (Architectural decision; see brite-data-platform for the OutboundSync deployment.)
6. **Brite_Base REST integration: SF is read-only status mirror.** Brite_Base sends WorkOrder/ServiceAppointment status updates to Salesforce via REST. Salesforce does not write back; updates flow only Brite_Base → SF. When designing new WO/SA-related automation, confirm whether the change belongs in Brite_Base (source of truth) or in SF (mirror) before writing Apex.
7. **ECAs replace Connected Apps post-Spring '26.** New auth integrations use `ExternalClientApplication` metadata, NOT `ConnectedApp`. ECA OAuth settings split across up to 4 metadata types; the org-local `oauthLink` makes `ExtlClntAppOauthSettings` non-portable cross-org. JWT-from-ECA + `sf org create scratch` is broken (CLI bugs forcedotcom/cli#3025, #3482) — workaround: `SFDX_AUTH_URL` via the CLI's built-in `PlatformCLI` Connected App. See [sf-connected-apps](../sf-connected-apps/SKILL.md) for the 4-active-ECA inventory and full OAuth lifecycle. Source: §External Client Apps lines 148-152.

### Verify — sf-integration (T1-T8, per issue body)

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | `ls plugins/revops/skills/sf-integration` | Exists |
| T2 | `grep "Adapted from Jaganpro" plugins/revops/skills/sf-integration/SKILL.md` | Match |
| T3 | `grep -E "Named Credentials.*PLACEHOLDER\|placeholder" plugins/revops/skills/sf-integration/SKILL.md` | Placeholder strategy present |
| T4 | `grep "OutboundSync" plugins/revops/skills/sf-integration/SKILL.md` | Canonical sync referenced |
| T5 | `grep -E "\.forceignore\|forceignore" plugins/revops/skills/sf-integration/SKILL.md` | NC forceignore gotcha present |
| T6 | `grep -E "Queueable.*silent\|silent.retry" plugins/revops/skills/sf-integration/SKILL.md` | Diagnostic pattern present |
| T7 | In brite-salesforce: ask "how do I add a new outbound webhook?" | sf-integration activates |
| T8 | `./scripts/validate.sh` | Exit 0 |

### Commit message

`BC-5931: customize sf-integration with Brite integration patterns`

---

## Task 3 — Apply attribution comment to `plugins/revops/skills/sf-docs/SKILL.md`

**Absorbs:** BC-5804 (partially — full absorption completes in follow-up)

### Frontmatter edits

None. Verbatim adoption per Design decision #1.

### Title edit

None.

### Attribution comment (insert before `# sf-docs` title)

```html
<!-- Adopted verbatim from Jaganpro/sf-skills@ff1ab74 (MIT). Web-retrieval concern only (developer.salesforce.com, help.salesforce.com, etc.). Brite-internal SF documentation (artifacts inventory, ADR convention, cross-repo pointers) lives in the sibling sf-internal-docs skill — see BC-6081. -->
```

(Filed during the review phase — see BC-6081.)

### Verify — sf-docs (revised; T3-T5 from issue spec move to sf-internal-docs follow-up)

| Test | Command / Action | Pass criteria |
|---|---|---|
| T1 | `ls plugins/revops/skills/sf-docs` | Exists |
| T2 | `grep "Adopted verbatim from Jaganpro" plugins/revops/skills/sf-docs/SKILL.md` | Match |
| T2b | `grep "sf-internal-docs" plugins/revops/skills/sf-docs/SKILL.md` | Sibling pointer present |
| T6 | In brite-salesforce: ask "find the Apex docs for `Database.Stateful`" | sf-docs activates (web-retrieval contract preserved) |
| T7 | `./scripts/validate.sh` | Exit 0 |

**Issue-spec T3-T5** (artifact dir / ADR convention / cross-repo references) **deferred to sf-internal-docs verify in follow-up issue.**

### Commit message

`BC-5931: adopt sf-docs verbatim with attribution comment + sf-internal-docs sibling pointer`

---

## Task 4 — File follow-up issue for sf-internal-docs (DONE — BC-6081)

Filed during the review phase as **BC-6081** (RevOps Plugin milestone, Low priority): "Author sf-internal-docs (Brite-original SF-internal reference map skill)". Sister-issue to BC-5931; predecessor BC-5804 also linked. Brought forward from "ship phase" per the BC-5928 task-1 precedent (mechanical ports surface follow-up scope during review; file early so the attribution-comment forward reference points at a real BC-#### rather than a promise).

Summary of issue scope:

- **Context.** Split surfaced during BC-5931 brainstorm. sf-docs (web retrieval) is upstream-pure; sf-internal-docs owns the Brite-internal concern.
- **Scope.** New skill at `plugins/revops/skills/sf-internal-docs/SKILL.md`. Frontmatter: `version: 0.1.0`, no `upstream:` field, `author: "Brite Company"`. UPSTREAM.md gets a new "Added by Brite (no upstream)" subsection naming this skill (the broader Lineage Classes taxonomy lands in this PR — see Task 5 below).
- **Content.** Issue-spec sf-docs items: artifact-dir inventory (25 artifacts under `brite-salesforce/docs/artifacts/`), ADR convention (`docs/decisions/001-010`), cross-repo references (handbook for company brain, brite-data-platform for dbt + audience views). Documentation hierarchy: CLAUDE.md > docs/artifacts (canonical) > docs/plans/{issue-id}-plan.md (per-issue).
- **Lineage precedent.** First Brite-original revops skill — establishes naming convention for future Brite-only skills, frontmatter shape, and UPSTREAM.md treatment.
- **Verify.** Issue-spec sf-docs T3 (`grep "brite-salesforce/docs/artifacts"`), T4 (`grep ADR\|decisions`), T5 (`grep handbook\|brite-data-platform`) re-targeted at `plugins/revops/skills/sf-internal-docs/SKILL.md`. The activation test "where are our schema docs?" (originally issue-spec T6) moves to BC-6081's verify matrix as well, distinct from BC-5931's §Task 3 sf-docs T6 which tests web-retrieval activation ("find the Apex docs for `Database.Stateful`") and stays in this PR.

## Task 5 — Add Lineage Classes section to UPSTREAM.md

`plugins/revops/UPSTREAM.md` gains a new `## Lineage classes` section documenting the three classes (Adapted from upstream / Adopted verbatim from upstream / Added by Brite) so future contributors can place new skills correctly. sf-docs is named as the precedent-setter for class 2; sf-internal-docs (BC-6081) is named as the planned precedent-setter for class 3.

---

## Verify — full matrix (revised for split)

| Skill | Tests | Notes |
|---|---|---|
| sf-data | 7 (T1-T7) | Unchanged from issue spec |
| sf-integration | 8 (T1-T8) | Unchanged from issue spec |
| sf-docs | 5 (T1, T2, T2b, T6, T7) | T3-T5 deferred to sf-internal-docs follow-up; T2b new (sibling pointer grep) |
| **Total** | **20** | (down from issue's 22 = 3 sf-docs tests deferred + T2b added) |

Paste all 20 test results into PR body alongside the deferral note.

---

## Out of scope (this PR)

- sf-internal-docs author (follow-up issue, see Task 4)
- Modifying actual integrations in brite-salesforce (no live NC changes; sf-integration tests skill ecosystem only)
- Authoring any new brite-salesforce docs (sf-docs and the future sf-internal-docs reference existing docs only)
- Other Phase 3 skills (Group A and Group B already shipped: BC-5927, BC-5928)

---

## Commit plan

| # | Subject | Files |
|---|---|---|
| 1 | `BC-5931: customize sf-data + bump revops 0.2.1 → 0.2.2` | `plugins/revops/skills/sf-data/SKILL.md`, `docs/plans/BC-5931-plan.md`, `plugins/revops/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` |
| 2 | `BC-5931: customize sf-integration with Brite integration patterns` | `plugins/revops/skills/sf-integration/SKILL.md` |
| 3 | `BC-5931: adopt sf-docs verbatim with attribution comment + sf-internal-docs sibling pointer` | `plugins/revops/skills/sf-docs/SKILL.md` |

---

## Phase transition

**Plan → Worktree.** Decisions: 9 (locked above). Artifacts: `docs/plans/BC-5931-plan.md`. Next: worktree setup at `.claude/worktrees/bc-5931/` from `origin/main`.
