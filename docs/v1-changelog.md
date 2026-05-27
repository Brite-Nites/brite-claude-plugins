# GTM Campaign Orchestration v1.0 — Shipped

> Consolidated release notes for the GTM Campaign Orchestration v1.0 milestone. For ratification details see [`v3-ratification-outcome-2026-05-22.md`](v3-ratification-outcome-2026-05-22.md); for design + architecture see [`gtm-campaign-orchestration-README.md`](gtm-campaign-orchestration-README.md); for operator usage see [`handbook/marketing/go-to-market/QUICKSTART.md`](https://github.com/Brite-Nites/handbook/blob/main/marketing/go-to-market/QUICKSTART.md).

**Status**: ✅ M2 ratified 2026-05-22 (Sarah Cullen + Kells Nixon + Holden Halford, zero modifications across 8 packet items)
**Period**: design 2026-05-11/13 → execution 2026-05-15 → 2026-05-27
**Lead**: Holden Halford
**Net**: 25 atomic BCs across 9 tiers + 6 post-V3/dogfood additions + the 4-layer infrastructure (Handbook + Linear + Plugin + Salesforce)

---

## TL;DR

Before v1.0, Brite had **three parallel "campaign" systems** with three different definitions of what a campaign IS — a handbook portfolio (44 entries by Vertical × Offer × Quarter), an active-campaigns tracking table that nobody maintained, and per-launch artifact bundles used by 7 marketing skills. None were integrated; slugs, statuses, and phase models were all inconsistent. The 2026-05-11/13 design session unified them into a **3-layer split with Salesforce as portfolio reporting surface**, locked ~30 architectural decisions across 8 ADRs, and broke implementation into 25 atomic Linear issues across 9 tiers.

The build shipped against that plan: every BC closed, V3 ratified M2 with zero modifications, the operational tail (weekly JWT probe + Linear-issue alert routing) activated, and the cohort-1 dogfood (Brite Labs × Hotels-Resorts × Director of Resort Experience × Holiday Anchor Audit) ran end-to-end through the system. The system is now in operational mode pending first real monthly portfolio-snapshot run + cohort-2 selection.

---

## The 4-layer system

```
   HANDBOOK = HOW                 LINEAR = ORCHESTRATION         PLUGIN = WHAT                  SALESFORCE = REPORTING
   brite-nites/handbook           Brite GTM project              britenites-claude-plugins      brite-salesforce
   
   • vocabulary.md (canon)        • Per-campaign milestone       • canonicals (27 verticals)    • Campaign records (σ3 auto-
   • 7 framework docs             • 8 standard sub-issues          + personas + offers            create + status sync)
   • campaign-lifecycle.md        • Status labels (planning /    • Slash commands (plan,        • 4 saved list views
   • how-we-operate cadence         active / completed / killed)   portfolio-snapshot, etc.)    • Performance Dashboard
   • canonicals-authorship        • Brief = milestone desc       • Skills (campaign-debrief,    • Pipeline by Offer Family
   • active-campaigns (nav-stub)  • σ3 status sync to SF           email-copywriting, MSPA)       Dashboard
   • Campaign brief template      • Linear is for WORK            • Per-launch artifacts        • Live portfolio rollup home
     ({{slot}} placeholders)        (handbook for thinking)         (manifests, learnings,        (V3 item 7)
                                                                   discoveries.json)
   
   NEVER holds live state.        Per-campaign orchestration.    Entity + state authority.      Reporting + attribution.
                                                                                                Bottom-funnel data Linear
                                                                                                never will.
```

---

## What got shipped

Organized by tier per [the master README §7](gtm-campaign-orchestration-README.md#7-the-23-linear-issues).

### Task 0 — Bootstrap

| BC | What | PR |
|---|---|---|
| [BC-8712](https://linear.app/brite-nites/issue/BC-8712) | Generate Linear issues + update CLAUDE.md + provision Brite GTM project | — |

### Tier 1 — Salesforce infrastructure

| BC | What | PR |
|---|---|---|
| [BC-8713](https://linear.app/brite-nites/issue/BC-8713) | 4 SF Campaign custom fields (Vertical, Offer, Persona, Entity, etc.) | brite-salesforce #221 |
| [BC-8714](https://linear.app/brite-nites/issue/BC-8714) | 4 SF saved list views (Active Campaigns, Launch Calendar, Coverage by Vertical, etc.) + AMOUNT_ALL source-sync | brite-salesforce #228, #229 |
| [BC-8715](https://linear.app/brite-nites/issue/BC-8715) | Performance Dashboard (vertical × month) | brite-salesforce #242 |
| [BC-8716](https://linear.app/brite-nites/issue/BC-8716) | Pipeline by Offer Family Dashboard | brite-salesforce #246 |

### Tier 2 — σ3 (Salesforce integration)

| BC | What | PR |
|---|---|---|
| [BC-8717](https://linear.app/brite-nites/issue/BC-8717) | `/revops:create-sf-campaign` slash command — σ3 auto-create at scaffold time | #329 |
| [BC-8723](https://linear.app/brite-nites/issue/BC-8723) | `/revops:update-sf-campaign-status` slash command — status sync writes | #331 |
| [BC-8752](https://linear.app/brite-nites/issue/BC-8752) | σ3 trigger automation — Linear status changes auto-propagate to SF | #336 |
| [BC-10510](https://linear.app/brite-nites/issue/BC-10510) | Phase 0 metadata cache backport to create-sf-campaign | #349 |
| [BC-10511](https://linear.app/brite-nites/issue/BC-10511) | `--target-org` regex validation backport | #349 |

### Tier 3 — Canonicals data layer

| BC | What | PR |
|---|---|---|
| [BC-8718](https://linear.app/brite-nites/issue/BC-8718) | Backfill 27 verticals + personas + offers in `plugins/marketing/data/canonicals/` | — |
| [BC-8730](https://linear.app/brite-nites/issue/BC-8730) | D8 persona authorship process doc | handbook #559 |

### Tier 4 — Plan-campaign orchestrator

| BC | What | PR |
|---|---|---|
| [BC-8724](https://linear.app/brite-nites/issue/BC-8724) | `/marketing:plan-campaign` orchestrator command (the central operator entry point) | #333 |

### Tier 5 — Vocabulary + schema migrations

| BC | What | PR |
|---|---|---|
| [BC-8719](https://linear.app/brite-nites/issue/BC-8719) | Entity slug short-form migration (`brite-{entity}/` → `{entity}/`) | #361 |
| [BC-8720](https://linear.app/brite-nites/issue/BC-8720) | `offer-tier` → `offer-posture` rename + 4 posture values | #346 |
| [BC-8721](https://linear.app/brite-nites/issue/BC-8721) | 3-verdict parent labels rename (Angle / Experiment / Campaign) + translation table | #347 |
| [BC-8722](https://linear.app/brite-nites/issue/BC-8722) | discoveries.json category schema (4 categories) + lint + skill integrations | #355 |

### Tier 6 — Dogfood + V3 ratification

| BC | What | PR |
|---|---|---|
| [BC-8727](https://linear.app/brite-nites/issue/BC-8727) | Cohort-1 dogfood: Brite Labs × Hotels-Resorts × Director of Resort Experience × Holiday Anchor Audit × M02 | #338 |
| [BC-8729](https://linear.app/brite-nites/issue/BC-8729) | V3 Marketing ratification meeting → M2 outcome | #358 |

### Tier 7 — Portfolio synthesis

| BC | What | PR |
|---|---|---|
| [BC-8731](https://linear.app/brite-nites/issue/BC-8731) | `/marketing:portfolio-snapshot --monthly|--quarterly` — load-bearing M2 deliverable | #367 |

### Tier 8 — Handbook canon (M2-ratified)

| BC | What | PR |
|---|---|---|
| [BC-8732](https://linear.app/brite-nites/issue/BC-8732) | Handbook PR: `frameworks/vocabulary.md` (5-category canon) | handbook #566 |
| [BC-8733](https://linear.app/brite-nites/issue/BC-8733) | Handbook PR: 7 framework docs (MSPA, Kellen's Laws, Asymmetry, Postures, Value Equation, Recency Waterfall, Verdicts) | handbook #568 + plugins #371 |
| [BC-8734](https://linear.app/brite-nites/issue/BC-8734) | Handbook PR: active-campaigns.md nav refactor (SF list view as primary portfolio rollup home) | handbook #565 |
| [BC-8735](https://linear.app/brite-nites/issue/BC-8735) | Handbook PR: how-we-operate cadence rows (daily / weekly / monthly / quarterly with SF URLs + plugin commands) | handbook #564 |

### Tier 9 — Post-V3 ships (originally deferrable, all shipped on M2)

| BC | What | PR |
|---|---|---|
| [BC-8725](https://linear.app/brite-nites/issue/BC-8725) | `/marketing:new-vertical` + `/new-offer` + `/new-persona` commands — canonicals bootstrap | #372 |
| [BC-8726](https://linear.app/brite-nites/issue/BC-8726) | `/marketing:icp-refinement-review` command — discoveries.json triage | #366 |
| [BC-8728](https://linear.app/brite-nites/issue/BC-8728) | `/marketing:offer-performance` command + Rule-of-Three `_shared/` extraction (canonicals_reader / slug_parts / manifest_loader) | #370 |

### Dogfood-driven follow-ups + operational tail

| BC | What | PR |
|---|---|---|
| [BC-10653](https://linear.app/brite-nites/issue/BC-10653) | Fix SF JWT auth refresh + `sf-prod-auth-rotation.md` runbook (surfaced BC-8727 dogfood F12) | brite-salesforce #249 |
| [BC-10654](https://linear.app/brite-nites/issue/BC-10654) | Handbook campaign-brief `{{slot}}` placeholders (BC-8727 dogfood F7) — deterministic brief population | handbook #560 + plugins #364 |
| [BC-11098](https://linear.app/brite-nites/issue/BC-11098) | Weekly `/revops:doctor` JWT-validity probe + Linear-issue alert routing (V3 item 8 Option B) | #375 + #378 |

---

## V3 outcome highlights

The 2026-05-22 V3 ratification meeting (Sarah Cullen + Kells Nixon + Holden Halford) ratified **M2 with zero modifications across all 8 packet items**. The packet items were:

1. ✅ Canonicals YAML structure
2. ✅ 4-layer offer model + Offer Posture rename rationale (ADR-017)
3. ✅ `ICP = template` / `Segment = instance` vocabulary
4. ✅ 3-verdict translation table (Angle / Experiment / Campaign — ADR-018)
5. ✅ discoveries.json category-tagged pattern (4 categories)
6. ✅ T7-Q portfolio-snapshot dry-run packet against BC-8727 dogfood (load-bearing)
7. ✅ Operator workflow shift — SF list view replaces handbook `active-campaigns.md` as portfolio rollup home (the most behavior-changing item per the packet)
8. ✅ BC-10653 SF JWT auth fix + Option B monitoring cadence (weekly `/revops:doctor` probe)

**M2 vs M3 fork:** ratification of M2 unlocked 5 BCs (BC-8731 portfolio-snapshot + 4 handbook PRs BC-8732/8733/8734/8735). M3 would have dropped them. M2 chosen unanimously.

---

## Compound learnings worth preserving

The build surfaced 30+ documented gotchas + patterns. The highest-leverage:

- **Rule-of-Three extraction trigger** — when a shared pattern hits 3+ consumers, bundle the extraction with the (N+1)th consumer's session/PR. BC-8728 worked example: extracted `_shared/canonicals_reader, slug_parts, manifest_loader` from BC-8722 + BC-8731 + BC-8726 inline reimplementations on the way INTO BC-8728 (offer-performance). Zero-regression migration. See `memory/pattern_rule_of_three_extraction_trigger.md`.
- **MDAPI `changed` flag is structurally inflated post-deploy** — platform XML normalization (default-false booleans stripped, formatting reflowed) means `componentSuccesses[].changed` never converges to false after deploy. Tooling API SOQL is the reliable post-deploy check. Surfaced BC-11107 reconciliation. See `memory/gotcha_mdapi_changed_flag_structural_inflation.md`.
- **`.forceignore` ECA pattern bug** — `**/externalClientApplications/*.eca-meta.xml` doesn't match the actual directory `externalClientApps/`. Pre-existing latent bug; ECA leaks through on full-tree deploys. Workaround: explicit `--source-dir` scoping. Fix queued. See `memory/gotcha_forceignore_eca_pattern_mismatch.md`.
- **sf CLI 2.x `--sfdx-url-stdin` is parser-fragile** — fails on CI with "Unexpected argument" because the flag is value-taking, not boolean. Use `printf '%s' "$URL" > "$RUNNER_TEMP/auth.txt"` + `--sfdx-url-file` instead. Surfaced BC-11098 PR #378. See `memory/gotcha_sf_cli_sfdx_url_stdin_parser_fragile.md`.
- **Linear `save_issue` milestone tagging requires `project` set in same call** — silently no-ops if the issue isn't already in the milestone's parent project. Pass both `project:` + `milestone:` together. Surfaced BC-11098 milestone tagging. See `memory/gotcha_linear_save_issue_milestone_needs_project.md`.
- **Linear cross-repo auto-close is inconsistent** — handbook → Linear `Closes BC-NNNN` magic-ID auto-close fires reliably for some PRs (BC-8732, BC-8735, BC-11098) but not others (BC-8733, BC-8734 needed manual `save_issue state: "Done"` flip). No documented workaround beyond verify-post-merge.
- **`/marketing:plan-campaign` canonicality gate is the load-bearing operator UX** — when plan-campaign hard-fails on a missing vertical/persona/offer, the error message tells the operator exactly which `/marketing:new-*` command to run. This is the system's discovery surface — operators learn the canonicals layer through bumping into the gate.
- **σ3 soft-fail contract is load-bearing** — `/revops:create-sf-campaign` + `/revops:update-sf-campaign-status` exit 0 with structured `{error: ...}` JSON on every failure path. Orchestrators (`plan-campaign` Step 7b) detect failure by parsing the error JSON key, NOT by exit code. Proven under real failure (BC-10653 SF JWT auth pre-fix); BC-8727 dogfood validated the contract end-to-end.

The full memory library (~30 gotchas + patterns + session narratives) lives in `memory/` and is indexed in `memory/MEMORY.md`.

---

## Operational tail (post-build, ongoing)

- **Weekly `/revops:doctor` JWT-validity probe** — auto-runs Mondays 09:00 UTC; auto-files a `[urgent] brite-prod SF auth expired` Linear issue on probe failure. First scheduled run: 2026-06-01. First predicted real-world test: ~2026-06-22 if Holden's 30-day refresh-token window holds. See [BC-11098](https://linear.app/brite-nites/issue/BC-11098).
- **Cohort-2 selection** — strategic decision pending. Cohort-1 was Hotels & Resorts × Holiday Anchor Audit (BC-8727). System is built for N cohorts; cohort-2 has no current candidate selected.
- **First real `/marketing:portfolio-snapshot --monthly` run** — default window is previous calendar month. April 2026 would be the first eligible window. Exercises the V3 operator workflow shift in practice.
- **σ3 shared-ref extraction** — [BC-10512](https://linear.app/brite-nites/issue/BC-10512) deferred per Rule of Two. Waits for the 3rd σ3 SF-write surface to land (candidate: `/revops:create-campaign-member`, `/revops:close-sf-campaign`, or similar future Campaign-mutation command). On trigger, extract alias→username resolution + Phase 0 cache pattern to `plugins/revops/references/sf-username-resolution.md` per ADR-015 amendment.

---

## Plugin version trajectory

```
marketing plugin:  0.3.41 (pre-v1.0)
                   ↓ BC-8720, BC-8721, BC-8722, BC-8726, BC-8731, BC-8728, BC-8725, BC-10654
                   0.7.1 (v1.0 + all dogfood follow-ups + Rule-of-Three extraction)

revops plugin:     0.4.3 (pre-v1.0)
                   ↓ BC-11030 + BC-10510/10511 + BC-11098 + BC-11037
                   0.5.3 (v1.0 + deploy-prod hardening + Phase 0.5 + JWT probe + cache-flush)
```

For per-version detail see [`plugins/marketing/CHANGELOG.md`](../plugins/marketing/CHANGELOG.md) and `plugins/revops/CHANGELOG.md`.

---

## Out of scope (intentional)

Per master README §12 + V3 ratification:

- **Cross-tenant rollup** — single-tenant only per ADR-014
- **Forecast / chart sections** in portfolio-snapshot — rejected at V3 (anti-creep guards)
- **Weekly portfolio cadence** — V3 ratified daily=none / weekly=GTM sync / monthly + quarterly only
- **brite-gtm regen from Linear** — conflicts with O7 (pre-Linear ideation queue role)
- **Per-vertical retro meeting** — subsumed by Coverage by Vertical view drilling
- **Annual retro** — subsumed by quarterly × 4
- **gh CLI auth audit (V1)** — cross-tool concern; out of scope
- **Post-launch metric writeback (O4)** — campaign-analysis weekly post; tracked separately if surfaces

---

## Where to learn more

| Topic | Doc |
|---|---|
| Master engineering README | [`gtm-campaign-orchestration-README.md`](gtm-campaign-orchestration-README.md) (v1.2) |
| V3 ratification outcome | [`v3-ratification-outcome-2026-05-22.md`](v3-ratification-outcome-2026-05-22.md) |
| Architectural decisions | [`decisions/012-019/*.md`](decisions/) (8 ADRs) |
| Operator quickstart | [handbook QUICKSTART](https://github.com/Brite-Nites/handbook/blob/main/marketing/go-to-market/QUICKSTART.md) |
| Operator full lifecycle | [handbook campaign-lifecycle.md](https://github.com/Brite-Nites/handbook/blob/main/marketing/go-to-market/campaign-lifecycle.md) (post-V3 refresh) |
| Vocabulary canon | [handbook vocabulary.md](https://github.com/Brite-Nites/handbook/blob/main/marketing/frameworks/vocabulary.md) |
| 7 framework docs | [handbook frameworks/](https://github.com/Brite-Nites/handbook/blob/main/marketing/frameworks/) |
| Cadence + SF URLs | [handbook how-we-operate.md § Portfolio Review Surfaces](https://github.com/Brite-Nites/handbook/blob/main/marketing/how-we-operate.md) |
| Compound learnings + gotchas | `memory/MEMORY.md` index + per-entry files |
| Per-plugin per-version detail | `plugins/marketing/CHANGELOG.md` + `plugins/revops/CHANGELOG.md` |
