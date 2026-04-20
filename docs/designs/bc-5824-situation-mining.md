---
issue: BC-5824
status: approved
drafted: 2026-04-20
author: Holden Halford (brainstorm w/ Claude)
precedent-touched: BC-5823 (Supply-deferred vertical scope — reversed here, see Decision 4)
---

# BC-5824 Situation Mining — Design Doc

## Context

Create `plugins/marketing/skills/situation-mining/SKILL.md` — per-prospect research + worldview inference + 3-4 diagnostic messaging angles. "Diagnostic over promotional" philosophical anchor for Brite outbound. Upstream: [Revgrowth1/ai-gtm-workflows workflow 05](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/05-situation-mining) (MIT).

The BC-5824 issue body (`list_issues` → `get_issue BC-5824`) already specifies Scope, Tool Surface, Cross-Skill Boundaries, JSON schema, 9 tasks, 16 verification items. This design doc captures the **decisions not in the issue body** — primarily where content lives, how we handle a missing dependency, and the coverage scope for Brite-adaptation rows.

## Decisions

### D1. Worldview matrix + adjacent-offering logic live inline in §3 Methodology

**Choice:** Inline in `SKILL.md` §3, not in `references/`.

**Why:** Upstream Revgrowth 05 has both inline in the workflow `.md`. BC-5823 ported 4 foundational refs but not these two. Keeping inline scopes the content to the one skill that owns the inference layer today. If BC-5828 (creative-angles Deep Mode) or BC-5833 (gtm-strategy) later need the same patterns, extract in a follow-up refactor issue — don't pre-DRY.

**Implication for plan:** §3 contains 10 worldview-inference rows + 5 adjacent-offering rows as upstream-ported content, plus Brite-adaptation rows (see D4).

### D2. `brite-enrichment` MCP is tertiary with graceful degradation

**Choice:** Include `mcp__plugin_marketing_enrichment__*` in `allowed-tools`. §5 MCP Tool Reference marks it as the tertiary workflow and documents graceful degradation when the MCP isn't registered (BC-5538 is still in flight; the integration guide `brite-enrichment.md` does not yet exist).

**Why:** Non-blocking. Skill works when enrichment is unavailable (falls back to WebSearch firmographic inference). When BC-5538 ships, the guide becomes citable without a skill rewrite.

**Implication for plan:** §5 enrichment block starts with availability check (per ADR 2c degradation policy). Cite BC-5538 as the future source of record. Do not stub `brite-enrichment.md` — that's BC-5538's job.

**Implication for verification:** One Tier-2 behavioral test must cover the "enrichment MCP unavailable → skill degrades to WebSearch-only inference" path.

### D3. Situation-mining owns the 6 searches + inference; BC-5827 is orthogonal

**Choice:** The skill runs the 6 parallel searches in-skill using query patterns from `references/research-processes/` — no dependency on BC-5827 `account-research`.

**Why:** BC-5827 is scoped as a "thin orchestrator over references/research-processes/" producing a raw research artifact. Situation-mining consumes research AND owns the inference chain — those are two distinct outputs. Coupling them now forces schema decisions on a skill (BC-5827) that hasn't been built. When BC-5827 ships, a follow-up can refactor situation-mining to delegate raw research if the shared-subroutine pattern proves valuable.

**Implication for plan:** `§2 Before Starting` does NOT require BC-5827 output; `§4 Cross-Skill Boundaries` documents the "Receives from" as `BC-2717 list-building (optional)` and direct user invocation, NOT BC-5827.

### D4. Brite-adaptation coverage = all 23 handbook verticals (consistent with BC-5823, no precedent departure)

**Choice:** Add Brite-adaptation rows to both the worldview matrix and adjacent-offering logic for all 23 handbook verticals (6 Active + 8 Exploring + 9 Future, per `Brite-Nites/handbook@main:marketing/go-to-market/verticals/README.md`).

**Why:** Situation-mining's value is highest where the prospect universe is widest. Constraining to 6 Active leaves Exploring / Future prospects without diagnostic anchoring; covering all 23 is a small marginal cost for real inference-breadth gain.

**The 23 verticals, authoritatively (fetched from handbook during Task 1 execution):**

- **6 Active:** Municipalities, HOAs, Landscape Lighting, Landscape Architects, Builders & Developers, Universities
- **8 Exploring:** Casinos, Hotels & Resorts, Bars & Restaurants, Event Venues, Auto Dealerships, Ski Resorts, Country Clubs / Golf Courses, Corporate Campuses
- **9 Future:** Theme Parks / Amusement Parks, Sports Stadiums, Zoos / Aquariums, Botanical Gardens / Arboretums, Historic Sites / Landmarks, Shopping Centers / Malls, Wineries / Vineyards / Breweries, Churches / Houses of Worship, Hospitals / Healthcare

**Explicitly excluded per handbook canon:** High-end residential (inbound-driven) and **Brite Supply verticals — professional installers, property management** (Supply GTM motion handled separately). The 23-vertical set is Nites + Labs only. This is consistent with BC-5823's Supply-deferred precedent; **no BC-5823 precedent reversal is required**.

**Precedent impact:** BC-5823 precedent ("handbook-canon-first for vertical/ICP/persona decisions") is fully honored — applying it literally produces exactly this 23-vertical set.

**New precedent worth capturing (BC-5824):** *Process improvement* — handbook-canon fetch should happen at brainstorm/design time, not execution time. An earlier version of this design doc framed the 23 as "reversing Supply-deferred," which was wrong — the handbook itself already excludes Supply. The mistake surfaced during Task 1 execution when the handbook file was actually read. Codify as: **when any brainstorm touches handbook-governed scope (verticals/ICPs/personas/entity canon), fetch and read the handbook source during brainstorm, not afterward.**

**Implication for plan:**
- Fetch handbook 23-vertical list via `gh api` (already done in Task 1).
- Draft 23 worldview rows + 23 adjacent-offering rows. Rows are one-liners — signal + inference + one-line messaging implication.
- Each row anchored to a specific handbook trigger (offer page, persona, procurement / budget cycle).
- Total content addition: ~46 rows of Brite-adaptation on top of the upstream-ported 10 + 5 baseline.
- Cross-link to `hidden-signals-library.md` Brite-entity tables for Municipalities / HOAs / Universities (already present) to avoid content duplication.
- **Do NOT write rows for installer hiring, property management, or any Supply-flavored trigger** — those are out of scope per handbook.

**Implication for verification:**
- `§3 Methodology contains Brite-adaptation rows for all 23 handbook verticals (6 Active + 8 Exploring + 9 Future)`
- `Each Brite-adaptation row cites a specific handbook section (offer page, persona, procurement cycle, or vertical README trigger)`
- `§3 Methodology contains NO rows keyed to Supply verticals (installers, property management) — per handbook canon`

## Architecture

Standard 9-section template per ADR 2f. Section roles, keyed to BC-5824 issue tasks:

1. **Opener** — "diagnostic over promotional" anchor + one-line outcome.
2. **Before Starting** — marketing-context check + `docs/designs/outbound-agent-architecture.md` read + existing-SF-account detection rule.
3. **Methodology** — 6-research-source pattern; worldview matrix (10 upstream + 23 Brite); adjacent-offering logic (5 upstream + 23 Brite); hypothesis framing rule.
4. **Brite Implementation** — tool table with ADR citations (2a, 2c, 2d); cross-skill boundaries; SF enrichment conditional path; research-processes reference reads.
5. **MCP Tool Reference** — grouped by workflow (research / SF lookup / enrichment fallback); each mutating workflow starts with availability check; enrichment degradation documented.
6. **Operational Runbook** — 4–8 tasks: standard prospect research, existing-SF-account deep dive, ambiguous-name clarification, handoff to creative-angles Deep, handoff to email-copywriting.
7. **Health Scoring Rubric** — anchor 10-score to "applies all 3 frameworks with specific data + hypothesis framing on every inference + source citation on every data point."
8. **Anti-Slop Guardrails** — 4 base + ≥3 skill-specific: hypothesis framing (not facts), source citation on every data point, no fabricated evidence.
9. **Behavioral Tests** — ≥6 scenarios covering happy path, existing-SF-account, ambiguous-name, thin-data/T4, missing-marketing-context, MCP unavailability (enrichment specifically).

## Output artifact shape

Per issue body — `docs/research/situations/{domain}-{YYYY-MM-DD}.md`. YAML frontmatter keys (final set decided during execution, documented in §6 Runbook):

```yaml
---
domain: example.com
company_name: "Example Co"
generated_at: 2026-04-20T14:30:00Z
entity: brite-nites | brite-supply | brite-labs
confidence: HIGH | MEDIUM | LOW
sf_enriched: true | false
research_sources: [find-profiles, find-hiring, ...]
---
```

Body: `## Raw Data` / `## Situations` / `## Diagnostic Messages` / `## Recommendations`.

## Open questions carried to the plan

- Confidence rating decision rule (HIGH/MEDIUM/LOW) — decide in §3 based on source count + quality.
- Thin-data T4 fallback — decide in §6 Runbook as a distinct operational path.
- Ambiguous-name disambiguation trigger — ask at §2 Before Starting if input name is ambiguous, vs surface mid-research.

These are local SKILL.md authoring decisions — document the choice in the relevant section when writing. Not blocking for the plan.

## References

- BC-5824 Linear issue (Scope, Tool Surface, Cross-Skill Boundaries, JSON schema, Tasks, Verification)
- `docs/plans/marketing-gtm-expansion.md` §1.2
- `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` — 9-section scaffold (ADR 2f)
- `plugins/marketing/skills/campaign-orchestration/SKILL.md` — canonical shipped exemplar
- `plugins/marketing/references/research-processes/` — 16 query patterns (6 consumed by this skill)
- `plugins/marketing/references/hidden-signals-library.md` — Brite-entity tables (Municipalities, HOAs, Universities) — cross-link target
- `plugins/marketing/tools/integrations/salesforce.md` — SF MCP reference
- `docs/precedents/BC-5823.md` — handbook-canon-first precedent (clarified by D4 above)
- `memory/reference_handbook_access.md` — `gh api` fallback for private handbook reads
- `Brite-Nites/handbook@main:marketing/go-to-market/verticals/README.md` — 23-vertical canonical taxonomy
- [Revgrowth1/ai-gtm-workflows workflow 05](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/05-situation-mining) — upstream
