# BC-5917 — Plan

**Issue:** [BC-5917](https://linear.app/brite-nites/issue/BC-5917) — Create `plugins/marketing/references/offer-design-frameworks.md`
**Branch:** `holden/bc-5917-offer-design-frameworks`
**Worktree:** `.claude/worktrees/bc-5917/`
**Priority:** High
**Parent roadmap:** R-1 of the 20-issue preset library rollout (master: `docs/designs/email-copywriting-preset-roadmap.md`). Blocks R-3 (BC-5919 SKILL cross-links) and R-4..R-9 (6 vertical-playbook issues BC-5920..5923, 5929, 5930).

## Goal

Create a vertical-agnostic reference file capturing Hormozi Value Equation, Brunson Value Ladder, Abraham risk-reversal, and B2B-outbound frontend/backend offer characteristics. Read by every vertical playbook (Phase 2) and every preset-composition issue (Phase 4) when designing or evaluating offers.

## Scope

**In-scope**
- New file: `plugins/marketing/references/offer-design-frameworks.md`
- Cross-reference entry in `plugins/marketing/references/README.md` § Contents
- Expected-consumer entry in README.md § Expected consumers naming the vertical-playbook + preset-composition roles

**Out of scope (non-goals from issue)**
- Restricting content to zoos/aquariums (must stay vertical-agnostic)
- Reproducing Hormozi's full book (cite + extract)
- Inventing new frameworks (use Hormozi/Brunson/Abraham as-is)
- Updating `email-copywriting/SKILL.md` cross-links (that's R-3 / BC-5919 — downstream issue)

## Design decisions

**D1. Frontmatter shape (Brite-originated, not upstream-ported).**
Peer references (shelf-life-patterns, creative-thinking-models, hidden-signals-library) use frontmatter with `source:` + `upstream_path:` + `license:` — all three point to the Revgrowth upstream. This file is Brite-originated (Hormozi/Brunson/Abraham are external books, not a Revgrowth port), so it cannot cite an `upstream_path:`. Options:
- (a) No frontmatter at all — simplest, but breaks visual consistency with peers.
- (b) Frontmatter with `source:` naming the three books + no `upstream_path:` + `license:` note stating the content is Brite-paraphrased (since book text isn't copied).

**Choose (b)** — preserves frontmatter as a metadata hook for future tooling, credits the source frameworks, and sidesteps the no-upstream-path ambiguity by just omitting that key.

**D2. No HTML attribution comment on line 1.**
The UPSTREAM.md convention reserves line-1 HTML comments for files "Adapted from Revgrowth1/ai-gtm-workflows". This file isn't adapted from Revgrowth, so no HTML banner.

**D3. UPSTREAM.md manifest.**
Do NOT add this file to the UPSTREAM.md per-file manifest. That manifest is specifically for Revgrowth1/ai-gtm-workflows-ported files. This one is Brite-originated, so it belongs in README.md only.

## Tasks

Tasks are ordered by dependency. Each is ≈2-5 min.

### T1 — Verify precedent + create file skeleton with frontmatter (D1)

- **File:** `plugins/marketing/references/offer-design-frameworks.md` (new)
- **Action:** Write frontmatter + H1 + intro paragraph.
- **Frontmatter (per D1):**
  ```yaml
  ---
  source: Hormozi "$100M Offers" (2021); Brunson "DotCom Secrets" (Value Ladder); Abraham (risk-reversal principle)
  license: Brite-originated; frameworks paraphrased, no verbatim book content
  ---
  ```
- **H1:** `# Offer design frameworks`
- **Intro (≤3 sentences):** Brite-adapted reference for evaluating and designing outbound offers. Vertical-agnostic. Consumed by vertical playbooks and preset-composition issues to separate structurally-sound offers from consultant-speak / gimmicky guarantees.
- **Verify:** File exists. Frontmatter valid YAML.

### T2 — § Hormozi Value Equation

- **Section heading:** `## Hormozi value equation`
- **Content:**
  - Formula block: `Value = (Dream Outcome × Perceived Likelihood) / (Time Delay × Effort + Sacrifice)`
  - 4 input definitions in a prose bullet list (Dream Outcome, Perceived Likelihood, Time Delay, Effort + Sacrifice) — each 1-2 sentences.
  - 4 guarantee types as a small table:
    | Type | Definition | B2B-outbound example |
    |------|------------|----------------------|
    | Conditional | Refund if criterion met | "If fewer than N leads, refund X%" |
    | Unconditional | Refund no questions asked | "30-day no-questions refund" |
    | Anti-guarantee | Open disclaimer of what you won't do | "We won't promise outcomes we can't measure" |
    | Implied (performance / rev-share) | Vendor paid on outcome | "Retainer + rev-share on closed-won" |
  - Worked Brite example (1 paragraph): apply Value Equation to Offer E production-finance for a generic zoo — show how each input shifts when offering financed production vs. upfront-pay.
- **Verify:** Section defines all 4 inputs AND all 4 guarantee types.

### T3 — § Brunson Value Ladder

- **Section heading:** `## Brunson value ladder`
- **Content:**
  - Concept: frontend → mid-tier → backend, with the operating principle that frontend is about qualifying + acquiring, not making money on its own.
  - 3 bullet definitions (frontend / mid-tier / backend) — each with a B2B-outbound mapping:
    - Frontend = email CTA (e.g., custom audit, benchmark, site survey)
    - Mid-tier = workshop / paid diagnostic (if applicable)
    - Backend = full engagement / DFY
  - B2B-specific note: in outbound email, frontend is often "accept a free diagnostic" — the entire job of cold email is frontend conversion. Backend comes later.
- **Verify:** Section defines all 3 ladder tiers with B2B-outbound mappings.

### T4 — § Abraham risk-reversal

- **Section heading:** `## Abraham risk-reversal`
- **Content:**
  - Principle (1 sentence): the more risk you take off the prospect, the higher the close rate.
  - Distinction from Hormozi (2-3 sentences): Abraham is philosophical (who carries the risk?); Hormozi is structural (what exact shape does the guarantee take?). Abraham frames the move, Hormozi chooses the mechanism.
- **Verify:** Section names the principle + explains the Abraham-vs-Hormozi distinction.

### T5 — § Frontend-offer characteristics (B2B outbound)

- **Section heading:** `## Frontend-offer characteristics (B2B outbound)`
- **Content:** 6-item checklist. Each item is bold-led with a 1-line example of specific-vs-generic:
  1. **Named + specific deliverable** — "First-year lighting plan for [Venue]" vs. "We can help with lighting"
  2. **Standalone value** — useful even if they never buy from Brite vs. purely transactional qualifying tool
  3. **Low friction** — single 30-min call / no procurement vs. multi-stakeholder meeting
  4. **Qualifying** — filters for budget / timeline / decision authority in the delivery itself
  5. **Natural segue to backend** — the diagnostic conclusion points to the full engagement
  6. **Effortful-for-vendor** — commitment bias; the prospect perceives value because you sank work into it (2-3 days of analysis, not 10-minute template)
- **Verify:** ≥6 characteristics each with ≥1 specific example.

### T6 — § Backend-guarantee characteristics

- **Section heading:** `## Backend-guarantee characteristics`
- **Content:** 4-item checklist with good/bad examples:
  1. **Quantified "doesn't work" definition** — Good: "First season revenue from lighting < production cost" (clear measurable floor). Bad: "If you're not satisfied" (subjective).
  2. **Metric aligned with buyer's actual success criteria (not vanity)** — Good: "Reservation lift vs. same-season prior year" for a zoo holiday event. Bad: "Social-photo-shares benchmark" (vanity; not what the buyer's P&L tracks).
  3. **Reasonable for vendor to underwrite** — Good: "First-season-breakeven-or-no-pay" (bounded downside for vendor). Bad: "We'll refund 10x revenue" (unbounded, not credible).
  4. **Real urgency via performance alignment (not countdown-timer scarcity)** — Good: "We get paid when the event lights up, so we want it ready" (structural alignment). Bad: "Sign this week for 15% off" (fake urgency).
- **Verify:** ≥4 characteristics each with good + bad example.

### T7 — § How to use this reference

- **Section heading:** `## How to use this reference`
- **Content:** 2-3 short paragraphs:
  - **For vertical playbooks (Phase 2 / R-4..R-9):** when proposing candidate offers for a vertical, run each through the Frontend characteristics checklist and each candidate backend guarantee through the Backend-guarantee checklist. Reject offers that fail any check.
  - **For preset composition (Phase 4 / R-10..R-15):** when composing `email-copywriting/presets/<vertical>/*.md`, cite the Value Equation input that the offer leans on most (e.g., "Dream Outcome dominant" for an aspirational offer, "Time Delay dominant" for a financing offer).
  - **Anti-pattern flag:** If a proposed offer can't name a specific Hormozi guarantee type AND fails the Backend-guarantee checklist, it's consultant-speak — send it back.
- **Verify:** Section names both consumer contexts (playbooks + presets) AND gives one concrete directive per context.

### T8 — Cross-reference in README.md

- **File:** `plugins/marketing/references/README.md` (edit)
- **Actions (two edits in the same file):**
  1. § Contents — add a bullet between `creative-thinking-models.md` and `hidden-signals-library.md` (alphabetical-ish with existing ordering → place before `research-processes/` actually, or keep current ordering and insert after shelf-life-patterns). Inspect current order, choose insertion point that preserves it. Entry text:
     `- `offer-design-frameworks.md` — Hormozi Value Equation + Brunson Value Ladder + Abraham risk-reversal + B2B-outbound frontend/backend characteristics. Brite-originated; read by vertical playbooks and preset-composition issues.`
  2. § Expected consumers — append bullet at end of existing list:
     `- `vertical-playbooks/*.md` + `email-copywriting/presets/*` — offer-design-frameworks (apply frontend/backend checklists when proposing or composing offers)`
- **Verify:** both edits present; README still parses as valid markdown.

### T9 — Validation

- **Run:** `./scripts/validate.sh` from repo root.
- **Expect:** exit 0. Warnings permissible if baseline already has warnings (BC-5866 baseline = 0 errors / 16 warnings).
- **Run:** `./scripts/check-guardrails.sh --claude-md CLAUDE.md`
- **Expect:** exit 0.
- **Verify:** Both pass. If validate.sh reports new errors traceable to this PR, debug before marking T9 complete.

### T10 — Verification against issue acceptance criteria

Manual tick pass against BC-5917 verification block:
- [ ] `plugins/marketing/references/offer-design-frameworks.md` exists
- [ ] Sections present: Hormozi Value Equation, Brunson Value Ladder, Abraham Risk-Reversal, Frontend-Offer Characteristics, Backend-Guarantee Characteristics, How to use this reference
- [ ] Hormozi Value Equation defines all 4 inputs + 4 guarantee types
- [ ] Frontend-Offer has ≥6 characteristics with ≥1 specific example each
- [ ] Backend-Guarantee has ≥4 characteristics with ≥1 good + bad example each
- [ ] `./scripts/validate.sh` exits 0

## Verification commands (copy/paste)

```bash
cd .claude/worktrees/bc-5917

# File exists
test -f plugins/marketing/references/offer-design-frameworks.md && echo OK

# Required headings
grep -E "^## (Hormozi value equation|Brunson value ladder|Abraham risk-reversal|Frontend-offer characteristics|Backend-guarantee characteristics|How to use this reference)" plugins/marketing/references/offer-design-frameworks.md | wc -l
# Expect: 6

# Full validation
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```

## Non-goals + tripwires

- Do NOT write a literal quote from Hormozi / Brunson / Abraham books — paraphrase only (license: Brite-originated).
- Do NOT add to UPSTREAM.md's per-file manifest — that's Revgrowth-port only.
- Do NOT include vertical-specific content beyond the single zoo example in T2 (rest must stay vertical-agnostic per Non-Goal 1 of the issue).
- Do NOT update `email-copywriting/SKILL.md` — that's BC-5919 / R-3.

## Dependencies + follow-ups

- Unblocks on merge: BC-5919 (SKILL cross-links), BC-5920-5923, BC-5929, BC-5930 (6 vertical playbooks).
- Doesn't block: BC-5918 (experiential-lighting-vendor-landscape.md — parallel R-2 foundation).
