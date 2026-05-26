---
schema_version: 1
generated_at: 2026-05-22T20:36:09Z
ratification_meeting: BC-8729
packet_pr: https://github.com/Brite-Nites/brite-claude-plugins/pull/352
packet_source: docs/v3-ratification-packet-2026-05-21.md @ holden/v3-ratification-packet-prep
attendees: [Sarah Cullen, Kells Nixon, Holden Halford]
fork_decision: M2
status: ratified
---

# V3 Ratification Outcome — GTM Campaign Orchestration v1.0

## TL;DR

**M2 — full ratification across all 8 packet items, zero modifications, zero deferred open ambiguities.** Marketing (Sarah Cullen + Kells Nixon) confirmed the architecture for GTM Campaign Orchestration v1.0 as designed: plugin-side thin canonicals schema (item 1), 4-layer offer model + Posture rename retroactively (item 2, PR #346), ICP=template / Segment=instance vocabulary (item 3), three distinct verdict vocabularies retroactively (item 4, PR #347), four-category discoveries.json pattern (item 5), the 5-section portfolio-snapshot packet shape with strict previous-calendar-month --monthly window (item 6, load-bearing), SF list view as portfolio rollup home with the 7-column spec (item 7, most behavior-changing for daily workflow), and the SF JWT auth runbook + weekly `/revops:doctor` JWT-validity probe as monitoring cadence Option B (item 8). M2 commits the 5-BC downstream cascade — BC-8731 (`/marketing:portfolio-snapshot`), BC-8732 (handbook vocabulary canon PR), BC-8733 (handbook framework docs PR — verdicts + offer-postures), BC-8734 (handbook active-campaigns nav refactor), BC-8735 (handbook how-we-operate cadence rows) — plus one follow-up BC for the `/revops:doctor` JWT probe wire-up + alert routing. The Monday GTM sync agenda will shift to SF-first as soon as BC-8734 ships. BC-8729 closes on this PR's merge.

---

## Per-item decisions

### Item 1 — Canonicals YAML structure (T3-G output sample)

**Decision:** RATIFY

**Rationale (Marketing):**

> Sarah + Kells accepted the recommendation to keep the thin schema as-is. No ICP nesting back into canonicals. Four reasons aligned to lead:
>
> 1. Item 3's vocabulary lock (ICP=template) makes ICP-in-YAML incoherent — templates carry nuance that YAML reduces away.
> 2. No current consumer needs firmographic validation at scaffold time; plan-campaign runs before list-building, so there's nothing to validate against.
> 3. The discoveries.json → handbook-PR loop (item 5) IS the right ICP update mechanism; moving ICP to YAML would fight the loop being ratified in item 5.
> 4. ADR-016 already litigated this on the merits two weeks ago; re-opening absent a concrete consumer is churn.

**Modifications:** —

**Action items filed:** none. Open ambiguity #5 (ICP nesting re-introduction) resolved as **no nesting; keep current schema**. If a concrete machine-readable-ICP consumer surfaces in the next ~3 months, ADR-016 can be amended at that point.

---

### Item 2 — 4-layer offer model + Offer Posture rename (retroactive — PR #346 shipped 2026-05-22)

**Decision:** RATIFY

**Rationale (Marketing):**

> Sarah + Kells accepted retroactive ratification of PR #346 / ADR-017. Three reasons aligned to lead:
>
> 1. Code is in production; the BC-8727 manifest already encodes `posture: free-asset`. Reject = real revert + re-introduces the Title-Tier vs. Offer-Tier letter-code collision that prompted the rename.
> 2. The 4-layer model (Family / Posture / Angle / Specific Instance) is genuinely orthogonal; merging layers was rejected in ADR-017's Alternatives.
> 3. 6mo deprecation window is the right middle ground — long enough to absorb mid-flight artifacts, short enough not to leave dual-read surface area indefinitely.

**Modifications:** —

**Action items filed:** none. Open ambiguity #6 (letter-codes deprecation window) resolved as **6 months, no change** per ADR-017 § Consequences as written.

---

### Item 3 — ICP=template / Segment=instance vocabulary

**Decision:** RATIFY

**Rationale (Marketing):**

> Sarah + Kells ratified. The 4-term lock (Vertical=template / Market=instance / ICP=template / Segment=instance) graduates from `memory/project_marketing_vocabulary.md` to `handbook/marketing/frameworks/vocabulary.md` via BC-8732. Three reasons aligned to lead:
>
> 1. Item 1's ratification (no ICP nesting in canonicals) relied on ICP=template as load-bearing — this confirms the architectural premise.
> 2. The Vertical/Market and ICP/Segment disambiguation preserves MSPA's diagnostic capacity (M column = hypothesis; S column = sub-cluster being tested).
> 3. Handbook path follows existing `frameworks/` convention (sibling to asymmetry-rubric, offer-postures, verdicts-cross-reference).

**Modifications:** —

**Action items filed:** none. Open ambiguity #8 (vocabulary canon handbook path) resolved as **`handbook/marketing/frameworks/vocabulary.md`** (proposed path stands).

---

### Item 4 — 3-verdict translation table (retroactive — PR #347 shipped 2026-05-22)

**Decision:** RATIFY

**Rationale (Marketing):**

> Sarah + Kells ratified. PR #347 / ADR-018 in production. Three reasons aligned to lead:
>
> 1. The three vocabularies are not redundant — they're orthogonal across time + evidence (Gate 1 prediction / Gate 2 in-flight signal / Gate 3 retrospective). Collapsing loses the diagnostic decomposition.
> 2. Item 6's portfolio-snapshot Section 3 already depends on three separate verdict-distribution subsections; rejecting item 4 cascades to item 6's structure.
> 3. The handbook framework doc (BC-8733 verdicts-cross-reference.md) carries the unified-view UX concern at the doc layer, leaving the three vocabularies distinct at the skill-emission layer where evidence-base matters.

**Modifications:** —

**Action items filed:** none. Open ambiguity #7 (BC-8721/BC-8731 ordering) stays resolved as **moot — PR #347 shipped first; BC-8731 will read all three distinct vocabularies natively when it lands**.

---

### Item 5 — discoveries.json category-tagged pattern

**Decision:** RATIFY

**Rationale (Marketing):**

> Sarah + Kells ratified. 4 categories stand (title-discovery / icp-refinement / offer-retirement / persona-discovery). "Skills emit, humans promote" pattern locked. Three reasons aligned to lead:
>
> 1. The 4 categories cover frequent mutation paths (per-campaign + per-quarter); vertical promotion is rare (1-2x/year) and is a synthesis question, not a logging question.
> 2. Ad-hoc handling fits the cadence better than a 5th category — vertical promotion surfaces as a pattern across many campaigns, not a single signal.
> 3. Keeping the enum tight reduces maintenance cost across `lint_discoveries.py` + JSON Schema + promotion-path docs + Marketing review training.

**Modifications:** —

**Action items filed:** none. Open ambiguity #3 (5th `vertical-discovery` category) resolved as **no 5th category — add later if vertical promotion churn surfaces in a real campaign cycle**.

---

### Item 6 — T7-Q portfolio-snapshot dry-run packet (LOAD-BEARING)

**Decision:** RATIFY

**Rationale (Marketing):**

> Sarah + Kells ratified. 5-section structure as drawn (Portfolio shape / Pipeline summary / Verdict distribution / Transferable insights / Action items). Anti-creep guards locked (no --weekly, no --forecast, no --charts, no re-aggregation, no writes outside `_reviews/`). Three reasons aligned to lead:
>
> 1. The 5 sections each answer one natural Monday-GTM-sync question; cutting any section drops a question Marketing has no other surface for.
> 2. Anti-creep guards keep the command focused — every "what if it also did X?" temptation is pre-rejected.
> 3. Graceful degradation is proven by the BC-8727 dogfood (worst-case sparse data, packet still emits cleanly).
>
> Window choice: **Option A — strict previous-calendar-month**. Reproducibility + alignment with SF closed-won + alignment with first-Monday review cadence. The "freshest view right now" question is handled by SF list view (item 7), not by the review packet.

**Modifications:** —

**Action items filed:** none. Open ambiguity #2 (--monthly window definition) resolved as **strict previous-calendar-month per BC-8731 spec**. This load-bearing ratification sets up M2 as the natural fork.

---

### Item 7 — Operator workflow shift: SF list view replaces handbook active-campaigns.md

**Decision:** RATIFY

**Rationale (Marketing):**

> Sarah + Kells ratified. SF list view becomes portfolio rollup home; handbook `active-campaigns.md` refactors to a navigation page (BC-8734 cascades). Three reasons aligned to lead:
>
> 1. The architecture is already half-deployed (σ3 SF auto-create + BC-8715/BC-8716 dashboards shipped); item 7 names what already exists rather than introducing new infrastructure.
> 2. Day-in-the-life impact is concentrated at Monday GTM sync (5-min handbook scroll → 10-sec SF view); daily personal work (My Issues, briefs, sub-issues) is UNCHANGED.
> 3. Linear genuinely cannot express pipeline-by-vertical or closed-won aggregations; the alternative to SF isn't "Linear takes over" but "no portfolio rollup at all" (the pre-design state that didn't work).
>
> Column set: **Option ① — ratify the § 7.8 / ADR-014 7-column spec as written** (Status / Slug / Vertical / Persona / Offer / Owner / StartDate). BC-8714 deploys these; refine post-launch if real-use surfaces gaps.

**Modifications:** —

**Action items filed:** none. Open ambiguity #4 (SF list view default columns) resolved as **Option ① — ratify spec as written; refine post-deployment with evidence from real use**.

---

### Item 8 — BC-10653 SF JWT auth runbook + monitoring cadence (forward-looking)

**Decision:** RATIFY (both parts)

**Cadence option selected:** **B — weekly /revops:doctor probe**

**Rationale (Marketing):**

> Sarah + Kells + Holden ratified. Part (a): `brite-salesforce/docs/runbooks/sf-prod-auth-rotation.md` (PR #249) is canonical re-auth path; plan-campaign + create-sf-campaign soft-fail error messages will cite it directly. Part (b): Option B chosen for monitoring. Three reasons aligned to lead:
>
> 1. The BC-10303 + BC-10653 pattern is silent + recurring (both within ~30 days, different auth surfaces, same failure mode); Option C (accept-as-is) is what's been happening and the evidence says it's not sustainable.
> 2. `/revops:doctor` already exists with 9 read-only SF health checks (BC-10660 / PR #341); adding a JWT-validity probe is additive, not new tooling.
> 3. The 7-day worst-case blind window is below the meaningful-Marketing-surface threshold (monthly review packet never includes a degraded window); Option A's 90-day worst case would corrupt a full quarter of portfolio reviews.
>
> Option D rejected because refresh-token expiry is likely activity-based rather than calendar-deadline-based; a calendar reminder doesn't catch the actual failure mode.

**Modifications:** —

**Action items filed:**

- **[BC-11098](https://linear.app/brite-nites/issue/BC-11098)** — *Wire weekly JWT-validity probe into `/revops:doctor` + decide alert routing.* Priority: Medium. Assignee: Holden (RevOps). Filed 2026-05-22 alongside this outcome doc.

---

## M2 vs M3 fork decision

**Decision:** **M2 — ratify packet**

**Rationale:**

> Sarah + Kells + Holden confirmed M2. Items 1-8 were all ratified without modification across the meeting; M3 at this point would have meant ratifying the architecture (canonicals, vocabulary, verdicts, discoveries, portfolio-snapshot shape, SF as portfolio home) while rejecting its operationalization — structurally incoherent. Three load-bearing commitments specifically forced M2:
>
> 1. **Item 6 ratification commits to M2.** The 5-section portfolio-snapshot packet was ratified as load-bearing. BC-8731 is the command that emits that packet; M3 would have shipped "yes, this is the right output" without the thing that produces it.
> 2. **Item 7 ratification commits to M2.** SF list view as portfolio home was ratified. BC-8734 (handbook active-campaigns refactor) + BC-8735 (how-we-operate cadence rows) operationalize that lock; without them, the handbook still pretends to be a rollup home it isn't.
> 3. **Items 2 + 3 + 4 commit to M2.** Vocabulary canon (item 3) + offer-posture framework (item 2) + verdicts cross-reference (item 4) need BC-8732 + BC-8733 to graduate from `memory/` operator-private to `handbook/` team-canonical.

**Triggered downstream actions (M2 cascade):**

- **BC-8731** — `/marketing:portfolio-snapshot` command → **ship as designed** (5-section shape per item 6; strict previous-calendar-month --monthly window; anti-creep guards locked)
- **BC-8732** — handbook vocabulary canon PR → **ship** (vocabulary.md at `handbook/marketing/frameworks/vocabulary.md` per item 3)
- **BC-8733** — handbook framework docs PR → **ship** (`offer-postures.md` per item 2 + `verdicts-cross-reference.md` per item 4)
- **BC-8734** — handbook active-campaigns nav refactor PR → **ship** (refactors `active-campaigns.md` from tracking table to navigation page pointing at SF list view, per item 7)
- **BC-8735** — handbook how-we-operate cadence rows PR → **ship** (Daily / Weekly / Monthly / Quarterly cadence codification, per item 7)
- **BC-8716** — Pipeline by Offer Family Dashboard → **stays as canon** (already shipped 2026-05-21; item 7 ratification makes it load-bearing for quarterly planning)
- **BC-8714** — Coverage by Vertical view → **ships** (independent of fork; underwrites item 6 Section 5c coverage-gap callouts)
- **BC-8715** — SF Performance Dashboard → **stays as canon** (already shipped; item 7 makes it the monthly review surface)

**Reviews going forward:** Monthly + quarterly review packets ship with full qualitative merge (item 6 output + SF dashboards combined). No SF-only fallback.

---

## Action items — filed as follow-up Linear issues before Tier 8 begins

| ID | Title | Source item | Owner | Status |
|---|---|---|---|---|
| [BC-11098](https://linear.app/brite-nites/issue/BC-11098) | Wire weekly JWT-validity probe into `/revops:doctor` + decide alert routing (Slack / Linear issue / digest) | Item 8 — Option B cadence | Holden (RevOps) | filed Backlog |

---

## Open ambiguities — resolved

| # | Open ambiguity (from packet § "Open ambiguities") | Resolution |
|---|---|---|
| 1 | Item 8 cadence option default (packet recommendation: B) | **Option B** — weekly `/revops:doctor` JWT-validity probe |
| 2 | Item 6 dry-run window expansion (strict --monthly vs rolling 30-day) | **Strict previous-calendar-month** per BC-8731 spec (reproducibility + SF closed-won alignment + first-Monday review cadence) |
| 3 | Item 5 discoveries.json fifth category (vertical-discovery) | **No 5th category** — add later if vertical promotion churn surfaces in a real campaign cycle |
| 4 | Item 7 SF list view default columns reconciliation vs § 7.8 | **Option ① — ratify 7-column spec as written** (Status / Slug / Vertical / Persona / Offer / Owner / StartDate); refine post-deployment with evidence from real use |
| 5 | Item 1 schema modification scope (re-introducing ICP nesting) | **No ICP nesting** — keep current thin schema; ADR-016 can be amended later if a concrete machine-readable-ICP consumer surfaces |
| 6 | Item 2 letter-codes deprecation window (current default: 6mo per ADR-017) | **6 months, no change** — ADR-017 § Consequences stands as written |
| 7 | Item 4 BC-8721 / BC-8731 ordering | Pre-resolved — BC-8721 / PR #347 shipped 2026-05-22, ordering moot |
| 8 | Item 3 vocabulary canon handbook path (`handbook/marketing/frameworks/vocabulary.md`) | **Proposed path stands** — `handbook/marketing/frameworks/vocabulary.md` (sibling to asymmetry-rubric, offer-postures, verdicts-cross-reference) |

All 8 ambiguities resolved in-meeting. None deferred.

---

## References

- [BC-8729 Linear issue](https://linear.app/brite-nites/issue/BC-8729) — ratification target (closes on this PR's merge)
- [PR #352](https://github.com/Brite-Nites/brite-claude-plugins/pull/352) — V3 ratification packet (the agenda)
- [V3 ratification packet](v3-ratification-packet-2026-05-21.md) — source items 1-8
- [GTM master README](gtm-campaign-orchestration-README.md) — § 5 (M2/M3 callout) / § 7.8 (workflow shift)
- [ADR-014](decisions/014-gtm-salesforce-portfolio-rollup.md) — SF as portfolio home
- [ADR-016](decisions/016-gtm-plugin-side-canonicals.md) — plugin-side canonicals
- [ADR-017](decisions/017-gtm-offer-posture-rename.md) — Offer Posture rename
- [ADR-018](decisions/018-gtm-verdict-vocabularies.md) — 3-verdict vocabularies
