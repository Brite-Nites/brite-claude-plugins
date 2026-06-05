# Campaign sub-issue templates

Per-phase sub-issue body templates that `/marketing:plan-campaign` stamps into Linear when scaffolding a GTM campaign (§ 9.1 / Step 10 of the command). Extracted from the command's inline specs in BC-12564 so the templates are maintained in one place and the contract test (`plugins/marketing/tests/test_plan_campaign_contracts.py`) can assert against them as the source of truth.

**Plugin-local, not handbook-canonical.** These templates encode orchestration internals — the `blockedBy` dependency chain, per-phase `dueDate` offsets, and expected-command routing — not human doctrine. They live with the orchestrator on purpose: coupling them to a cross-repo handbook fetch would recreate the lockstep-drift hazard the campaign-brief template's own spec warns about. Contrast: the campaign-brief template (tier-3, human-filled doctrine) *is* handbook-canonical and *is* fetched live via `gh api` at plan-campaign Step 8a.2. The *doctrine* each sub-issue cites (the `handbook@main:.../processes/*.md` pages) can live in the handbook; these machine-stamped scaffolds do not.

## How this file is consumed

Each sub-issue is one section: a fenced `yaml` block (the machine-critical fields) followed by a **Description** blockquote that is stamped verbatim as the Linear issue body. The command reads the fields; the contract test parses the same blocks. Only fenced ` ```yaml ` blocks are sub-issue records — this schema doc uses a `text` fence so it is not parsed as one.

Field schema (per `yaml` block):

```text
id:                  integer 1..10, unique
title:               string — the Linear issue title
dueDate_offset_days: integer — days relative to <launch-date>; the command does the arithmetic
blockedBy:           list[int] — ids this sub-issue is blocked by ([] = root gate). The
                     authoritative dependency graph; the command wires it in a second pass.
optional:            bool — false = one of the 8 standard sub-issues; true = optional (#9 / #10)
labs_gated:          bool — true only for a Labs-only optional sub-issue (#9); enforced by Step 10
```

**The command owns the orchestration; this file owns the data.** Date arithmetic (`<launch-date>` + `dueDate_offset_days`), index→Linear-ID resolution, the two-pass `blockedBy` write, the runtime append of enabled optionals (#9 / #10) to #1's downstream set, the container-issue parent (§ 9.0), the Labs HARD-FAIL (Step 10), and the 8-label set applied to every sub-issue (§ 8a.6) all stay in `commands/plan-campaign.md`.

**No `blocks` field.** The forward `blocks` edge is the exact inverse of `blockedBy` and is auto-rendered by Linear, so it is not stored here — storing it would duplicate derivable data, which is exactly what produced the inconsistency this extraction fixed (the inline source's `#1.blocks` listed the transitive closure and `#2.blocks` was wrong). The command writes only `blockedBy`; those direct edges were always correct, so this normalization is doc-only with no runtime effect.

---

## Standard sub-issues

The 8 sub-issues created on every campaign scaffold (`optional: false`).

### #1 — Brief approved (gate)

```yaml
id: 1
title: "Brief approved"
dueDate_offset_days: -21   # T-21d per README § 3.6.5
blockedBy: []
optional: false
labs_gated: false
```

Description (stamped verbatim as the issue body):

> Marketing brief author finalizes the brief in this milestone's description. GTM lead reviewer approves. Closes when the brief is approved.
>
> **Handbook citation**: `handbook@main:marketing/go-to-market/templates/campaign-brief-template.md`
> **Sub-issue role**: gate — blocks all downstream work. Per [D5](../../docs/decisions/) the brief template is 8 sections; the marketing brief author owns sections 2-8 content.
> **Expected plugin command**: none directly; brief is edited in Linear milestone description.

### #2 — Target list built

```yaml
id: 2
title: "Target list built"
dueDate_offset_days: -14   # T-14d
blockedBy: [1]
optional: false
labs_gated: false
```

Description (stamped verbatim as the issue body):

> Outbound operator builds the enriched lead CSV for this campaign — typically via `/marketing:list-building` (which assumes a dbt audience view exists for this canonical persona+offer combo) OR `/marketing:tam-mapping` (if the TAM doesn't exist yet — Phase 1 source discovery → Phase 7 enrichment hand-off).
>
> **Handbook citation**: `handbook@main:marketing/go-to-market/processes/list-building.md`
> **Sub-issue role**: produces the enriched lead CSV that feeds Phase 1 of `/marketing:launch-campaign` at sub-issue #6.
> **Expected plugin command**: `/marketing:list-building` or `/marketing:tam-mapping`.

### #3 — Copy written + approved

```yaml
id: 3
title: "Copy written + approved"
dueDate_offset_days: -10   # T-10d
blockedBy: [1]   # NOT [2] — copy and target list run in parallel (gated only by the Brief)
optional: false
labs_gated: false
```

Description (stamped verbatim as the issue body):

> Marketing brief author runs `/marketing:email-copywriting` to produce the BC-5825 JSON copy artifact (step_1 + step_2 + custom_variables). GTM lead reviewer approves the rendered copy before Phase 1 of launch-campaign.
>
> **Handbook citation**: `handbook@main:marketing/go-to-market/processes/email-copywriting.md`
> **Sub-issue role**: produces the copy artifact that feeds Phase 1 of `/marketing:launch-campaign` at sub-issue #6.
> **Expected plugin command**: `/marketing:email-copywriting`.

### #4 — Salesforce setup

```yaml
id: 4
title: "Salesforce setup"
dueDate_offset_days: -7   # T-7d
blockedBy: [3]
optional: false
labs_gated: false
```

Description (stamped verbatim as the issue body):

> Verify the SF Campaign record created at scaffold time (σ3 / `/revops:create-sf-campaign`). Populate audience members (CampaignMember records linked from EB lead suppress export). Wire Opportunity links if the offer is a pilot/risk-reversal posture.
>
> **Handbook citation**: `handbook@main:marketing/go-to-market/processes/sf-campaign-setup.md`
> **Sub-issue role**: SF reconciliation post-σ3 auto-create. If auto-create soft-failed at scaffold, manual `/revops:create-sf-campaign` re-run lands here.
> **Expected plugin command**: `/revops:create-sf-campaign` (reconciliation) + manual SF UI work.

### #5 — Pre-launch QA

```yaml
id: 5
title: "Pre-launch QA"
dueDate_offset_days: -3   # T-3d
blockedBy: [4]
optional: false
labs_gated: false
```

Description (stamped verbatim as the issue body):

> Run the launch-campaign pre-flight checklist: copy renders correctly with sample leads, custom variables resolve, sender warm-up status, EB workspace health, SF Campaign linkage.
>
> **Handbook citation**: `handbook@main:marketing/go-to-market/processes/pre-launch-qa.md`
> **Sub-issue role**: catches launch-blocking issues before sub-issue #6 fires sending.
> **Expected plugin command**: `/marketing:launch-campaign --preview` (dry-run mode) + manual review.

### #6 — Launch executed

```yaml
id: 6
title: "Launch executed"
dueDate_offset_days: 0   # T+0 (launch date)
blockedBy: [5]
optional: false
labs_gated: false
```

Description (stamped verbatim as the issue body):

> Outbound operator runs `/marketing:launch-campaign` (Phase 11 ACTIVATE) to create + activate the EB campaign. Single EB campaign per [D1] (no sender splits).
>
> **Handbook citation**: `handbook@main:marketing/go-to-market/processes/launch.md`
> **Sub-issue role**: the moment the campaign goes live. EB campaign_id flows back into manifest.email_bison.campaign_id at this point.
> **Expected plugin command**: `/marketing:launch-campaign --activate` (consumes copy artifact from #3 + enriched CSV from #2).

### #7 — Active management — weekly reviews

```yaml
id: 7
title: "Active management — weekly reviews"
dueDate_offset_days: 28   # T+28d
blockedBy: [6]
optional: false
labs_gated: false
```

Description (stamped verbatim as the issue body):

> Outbound operator runs `/marketing:campaign-analysis` weekly during the active sending window. GTM lead reviews. Adjustments (pause / unpause / sender swaps) per the analysis.
>
> **Handbook citation**: `handbook@main:marketing/go-to-market/processes/active-management.md`
> **Sub-issue role**: weekly cadence during the ~4-week active window. Pause/kill decisions land here via `/marketing:sync-campaign-status` (T2-FA / BC-8752).
> **Expected plugin command**: `/marketing:campaign-analysis` weekly; `/marketing:sync-campaign-status` on status transitions.

### #8 — Campaign closed + debrief

```yaml
id: 8
title: "Campaign closed + debrief"
dueDate_offset_days: 40   # T+40d
blockedBy: [7]
optional: false
labs_gated: false
```

Description (stamped verbatim as the issue body):

> Run `/marketing:campaign-debrief` to produce the learnings.md artifact and update the MSPA results log. Linear status flips to `completed` (or `killed`) which triggers σ3 status-sync (BC-8752) to update SF Campaign.
>
> **Handbook citation**: `handbook@main:marketing/go-to-market/processes/debrief.md`
> **Sub-issue role**: terminal step. Closes the campaign loop into the compounding MSPA flywheel.
> **Expected plugin command**: `/marketing:campaign-debrief`.

---

## Optional sub-issues

Created only when their flag is passed (`optional: true`). #9 is additionally Labs-gated — Step 10 HARD-FAILs if `--situation-mining` is passed with a non-Labs entity. Both hang off the Brief (#1); the command appends enabled optionals to #1's downstream set at runtime.

### #9 — Situation Mining (Labs-gated)

```yaml
id: 9
title: "Situation Mining"
dueDate_offset_days: -12   # T-12d
blockedBy: [1]
optional: true
labs_gated: true
```

Description (stamped verbatim as the issue body):

> Run `/marketing:situation-mining` (Labs framework) to surface the latent situations that this campaign's persona is in BUT hasn't articulated yet. Output feeds the brief's Audience section (#1) and the copy artifact's angle hypotheses (#3).
>
> **Handbook citation**: `handbook@main:marketing/labs/situation-mining-framework.md`
> **Sub-issue role**: pre-launch discovery; parallel with #2 and #3.
> **Expected plugin command**: `/marketing:situation-mining`.

### #10 — Creative Angles

```yaml
id: 10
title: "Creative Angles"
dueDate_offset_days: -12   # T-12d
blockedBy: [1]
optional: true
labs_gated: false
```

Description (stamped verbatim as the issue body):

> Run `/marketing:creative-angles` to generate 3-5 angle hypotheses to test in copy. Output feeds the copy artifact at sub-issue #3.
>
> **Handbook citation**: `handbook@main:marketing/go-to-market/processes/creative-angles.md`
> **Sub-issue role**: pre-copy discovery; parallel with #2. Especially important for NEW offers that haven't been tested yet.
> **Expected plugin command**: `/marketing:creative-angles`.
