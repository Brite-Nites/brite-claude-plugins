# BC-8727 — First Dogfood Campaign Through `/marketing:plan-campaign`

**Linear**: <https://linear.app/brite-nites/issue/BC-8727/gtm-t6-o-run-first-dogfood-campaign-through-plan-campaign-capture>
**Milestone**: GTM Campaign Orchestration v1.0 (`bcd40909-aa7c-43d7-88e8-6c40b59c5a1f`)
**Blocked by**: BC-8724 (shipped 2026-05-19, PR #333)
**Blocks**: BC-8729 (V3 ratification), BC-8731 (T7-Q portfolio-snapshot)
**Worktree branch**: `worktree-bc-8727`
**Brite GTM project ID**: `5e25e522-0700-4f0f-86a2-bdff965126f5`

## Spec source-of-truth

1. **BC-8727 issue body** — execution acceptance criteria
2. **`docs/gtm-campaign-orchestration-README.md` § 3.6** — Path A worked example (committed `c6535a5`)
3. **Memory `project_gtm_cohort1_hotels_resorts.md`** — cohort-1 lock + Path A walk reference
4. **`plugins/marketing/commands/plan-campaign.md`** — the orchestrator being dogfooded (11 steps)

## Cohort-1 campaign identity (locked 2026-05-13)

```
Slug      hotels-resorts-director-of-resort-experience-holiday-anchor-audit-fy26-m02
Entity    labs
Vertical  hotels-resorts
Persona   director-of-resort-experience  (NEW — promote via Path A)
Offer     holiday-anchor-audit           (NEW — promote via Path A, posture=free-asset, status=draft)
Month     M02 (February 2026)            -- past date is intentional; first dogfood
Year      FY26
Launch    2026-02-03 (first Tue of M02)
Owner     marketingadmin@britenites.com
EB ws     emailbison-b2b (labs → b2b per entity map)
```

## Pre-conditions (verified)

- [x] BC-8718 canonicals shipped — `hotels-resorts.yaml` is intentional Path A bait (empty personas + offers)
- [x] BC-8717 `/revops:create-sf-campaign` shipped
- [x] BC-8723 `/revops:update-sf-campaign-status` shipped
- [x] BC-8724 `/marketing:plan-campaign` shipped (11-step orchestrator)
- [x] BC-8752 σ3 SF status-sync triggers shipped
- [x] Brite GTM project exists in Linear
- [x] `lint_canonicals.py` baseline green (27 verticals)
- [ ] **BC-8725 sibling commands NOT shipped** — `new-persona` / `new-offer` / `new-vertical` do not exist on disk → **Path A Phase 2 + Phase 3 require a manual hot-patch workaround**. This IS a friction signal worth capturing.

## Friction-log discipline

Maintain `docs/plans/gtm-campaign-orchestration-friction-log.md` throughout the run. Entry schema:

```
### F<N> — <Title> [<severity>]

**When**: <ISO timestamp>
**Step**: <plan-campaign step / phase reference>
**Friction observed**: <one paragraph>
**Root-cause hypothesis**: <one paragraph>
**Proposed fix**: <hot-patch | V3-defer | docs-only>
**Disposition**: <applied in this PR | deferred to BC-N | logged for V3>
```

Severity: `blocker` (halts dogfood) / `annoyance` (workable but rough) / `minor` (cosmetic / docs).

BC-8727 AC ≥5 entries. Target ≥7 entries to ensure adversarial-mindset push.

## Tasks

### T1 — Initialize friction log
- **Where**: `docs/plans/gtm-campaign-orchestration-friction-log.md`
- **Steps**: Write header + entry-schema documentation + empty entry table.
- **Verify**: file exists, schema visible.

### T2 — Path A Phase 1: invoke plan-campaign, expect HARD-FAIL at Step 2.2 (persona)
- **Invocation**:
  ```
  /marketing:plan-campaign --entity=labs --vertical=hotels-resorts \
      --persona=director-of-resort-experience --offer=holiday-anchor-audit \
      --month=2 --year=2026 --launch-date=2026-02-03 \
      --owner-email=marketingadmin@britenites.com \
      --eb-workspace=emailbison-b2b --situation-mining --creative-angles
  ```
- **Expected**: hard-fail at Step 2.2 because `director-of-resort-experience` is not in `personas[]` of `hotels-resorts.yaml`.
- **Friction entries to capture**:
  - F1: BC-8725 sibling commands unshipped → workaround required
  - F2: error message references `/marketing:new-persona` which doesn't exist on disk (404 / "skill not found" if the operator tries it)
- **Verify**: ASCII error message contains "Persona 'director-of-resort-experience' is not defined" + pointer to new-persona.

### T3 — Manual canonicals hot-patch (BC-8725 gap workaround)
- **What**: hand-edit `plugins/marketing/data/canonicals/hotels-resorts.yaml` to add the persona + offer per cohort-1 spec.
- **Persona payload** (from cohort-1 memory):
  ```yaml
  personas:
    - slug: director-of-resort-experience
      display: "Director of Resort Experience"
      titles:
        - "Director of Resort Experience"
        - "Director of Guest Experience"
        - "Director of Resort Activations"
        - "Director of Recreation & Resort Activations"
        - "Director of Guest Experiences"
        - "VP Resort Experience"
        - "VP Guest Experience"
  ```
- **Offer payload**:
  ```yaml
  offers:
    - slug: holiday-anchor-audit
      display: "Resort Holiday Anchor Audit"
      status: draft
      posture: free-asset
      target_personas: [director-of-resort-experience]
      prose_path: handbook/marketing/go-to-market/verticals/hotels-resorts/offers/holiday-anchor-audit.md
  ```
- **Verify**: `python3 plugins/marketing/scripts/lint_canonicals.py` exits 0.
- **Friction entries**:
  - F3: manual canonicals patch is the workaround until BC-8725 ships — capture the dev-friction (lookup spec, edit YAML, lint, re-run) and propose Phase 2 + Phase 3 priority for BC-8725.

### T4 — Path A Phase 4: re-invoke plan-campaign full scaffold
- **Invocation**: same as T2 (re-run after canonicals patch).
- **Confirm gate (Step 6)**: respond `Proceed` once dry-run preview validates.
- **Expected outputs**:
  - Real Linear milestone in Brite GTM project named with the slug.
  - Real container issue + 10 sub-issues (8 standard + Situation Mining + Creative Angles) — 9.0 container-issue pattern.
  - `docs/campaigns/labs/<slug>/manifest.json` populated.
  - SF Campaign auto-created OR soft-fail WARN line.
- **Friction entries** (capture per step):
  - F4+: Step 1b validators (any value rejected unexpectedly?)
  - F5+: Step 2 canonicality lookup latency / clarity
  - F6+: Step 3 slug computation / collision check round-trips
  - F7+: Step 4 owner-email resolution chain
  - F8+: Step 5 dry-run preview legibility
  - F9+: Step 6 confirm-gate UX
  - F10+: Step 7 manifest schema vs reality (any `null` fields confusing?)
  - F11+: Step 8a label pre-check round-trip count (advisory bound observed?)
  - F12+: Step 8b SF auto-create (soft-fail behavior + reconciliation reminder)
  - F13+: Step 9 sub-issue chain MCP latency (10× `save_issue` is the heaviest surface)
  - F14+: Step 10 optional sub-issue gating (situation-mining Labs-only enforced?)
  - F15+: Step 11 summary output completeness

### T5 — Apply obvious hot-patches mid-run
- **Criteria**: a friction is hot-patch-able if:
  - It's a 5-line-or-fewer fix in `plan-campaign.md` or a sibling command file
  - It does NOT require a new MCP shape / new skill / new ADR
  - It does NOT introduce a behavior change requiring V3 ratification
- **Bump plugin version**: every hot-patch must bump `plugins/marketing/.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json` (CLAUDE.md plugin-cache gotcha + pre-commit hook enforced).
- **Deferred friction** (annoyance / minor): captured in log only, with proposed fix annotated for V3 (BC-8729).

### T6 — Verify acceptance criteria
- [ ] 1 milestone in Linear "Brite GTM" project with correct slug + 8 standard sub-issues (issue body says "7" — see friction log F? on the off-by-one)
- [ ] 1 manifest.json populated in `docs/campaigns/labs/<slug>/`
- [ ] 1 SF Campaign Status=Planned (or soft-fail WARN documented)
- [ ] ≥1 EB campaign launched (likely defer to next session — capture friction either way; minimum: launch path documented + EB workspace assignment in manifest correct)
- [ ] Friction log committed with ≥5 entries (target ≥7)
- [ ] Hot-patches documented in PR description with file + line refs

### T7 — Out-of-session: EB launch + debrief
The BC-8727 AC asks for "≥1 EB campaign launched" + "stub debrief sub-issue." Full launch requires:
- Brief approved (sub-issue #1) — requires marketing-brief-author content for sections 2-8
- Target list (sub-issue #2) — requires `/marketing:list-building` or `/marketing:tam-mapping` (TAM-from-scratch for new vertical)
- Copy written (sub-issue #3) — requires `/marketing:email-copywriting`

If this session can reasonably stretch to a `/marketing:launch-campaign --preview` dry-run, do it. Otherwise: document the launch-readiness state + friction prediction for sub-issues #2-#6 in the friction log, and stub the debrief sub-issue with a future-state note. The BC-8727 critical path is plan-campaign exercise + friction surfacing — the rest is V3-ratification feedstock.

## Out-of-scope for this PR

- BC-8725 sibling commands implementation (would block this dogfood; explicitly NOT a pre-req per dependency graph — its absence IS the dogfood signal)
- `/marketing:campaign-debrief` implementation (BC-2719)
- Full sub-issue lifecycle execution (#1 → #8) — would span 60 days per the schedule
- V3 ratification meeting prep (BC-8729 owns)
- Handbook PR for the hotels-resorts persona + offer additions — gets drafted but lands in a separate handbook PR

## Ship checklist (T8)

- [ ] `./scripts/validate.sh` exits 0
- [ ] `python3 plugins/marketing/scripts/lint_canonicals.py` exits 0
- [ ] If marketing plugin files were edited: `plugin.json` + `marketplace.json` version bumped in same commit
- [ ] Friction log committed
- [ ] BC-8727-plan.md committed
- [ ] Linear milestone + sub-issues survive verification via `get_issue`
- [ ] PR title: `BC-8727: first dogfood campaign + friction log (T6-O)`
- [ ] PR body: `Closes BC-8727` + per-friction summary + hot-patch list (link to commits)
- [ ] Magic Issue ID hygiene: bare BC-IDs in PR body / commit body → markdown link form (per gotcha-linear-pr-title-magic-id-auto-close)

## Risks

- **R1**: SF auto-create soft-fail blocks σ3 demonstration. Mitigation: per the soft-fail philosophy, scaffold continues; manifest gets `salesforce.campaign_id: null` + reconciliation reminder. Document the path; don't halt.
- **R2**: Linear MCP `save_issue` with `parentId` + `projectMilestoneId` combo rejects (9.0 container-issue pattern unverified). Mitigation: HALT + surface partial state per the spec's explicit rollback paragraph; file follow-up.
- **R3**: 10× `save_issue` round-trip rate-limits or partial-fails mid-chain. Mitigation: capture the failure point + write a "delete + re-run" reconciliation note; manifest preserves what was created.
- **R4**: Past launch date (2026-02-03 vs today 2026-05-19) flagged by orchestrator. Mitigation: Step 1b validates ISO format only — past dates are not rejected. This is intentional (first dogfood retroactively scaffolds the cohort-1 walk).
- **R5**: `gh api` brief-template fetch fails (handbook path may not exist yet). Mitigation: inline fallback (Step 8a.4) — already designed-for.

## References

- **Code under test**: `plugins/marketing/commands/plan-campaign.md` (901 lines), `plugins/revops/commands/create-sf-campaign.md`, `plugins/marketing/data/canonicals/hotels-resorts.yaml`
- **Memory**: `project_gtm_cohort1_hotels_resorts.md`, `project_gtm_campaign_architecture.md`, `gotcha_marketing_entity_slug_short_vs_long.md`, `session_bc_8724.md`
- **Docs**: `docs/gtm-campaign-orchestration-README.md` § 3.6 + § 5 + § 6 + § 12
- **ADRs**: 012, 013, 015, 016, 017, 018, 019
