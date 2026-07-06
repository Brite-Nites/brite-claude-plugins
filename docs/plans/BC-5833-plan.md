# Plan: BC-5833 — Create marketing skill: gtm-strategy

**Issue**: BC-5833 — Create marketing skill: gtm-strategy (5-phase net-new motion: research → segments → personas → pillars)
**Branch**: `corinne/bc-5833-create-marketing-skill-gtm-strategy-5-phase-net-new-motion`
**Milestone**: Marketing Plugin: GTM Workflows
**Scoping doc**: `docs/plans/marketing-gtm-expansion.md` §3.3
**Upstream**: [Revgrowth1/ai-gtm-workflows workflow 04](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/04-gtm-strategy) (MIT)
**Tasks**: 9 (estimated 1–1.5 focused days)

## Prerequisites
- `docs/marketing-context.md` exists (verified — it does)
- `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` is the scaffold
- `plugins/marketing/references/` exists from BC-5823 (shipped today)
- **CDR alignment**: N/A — scoping doc already captured decisions; no CDR INDEX queried (Context7 unavailable this session)
- **Precedent alignment**: Pattern follows BC-5823 (recently shipped) for port+adapt work

## Key context decisions (already locked by issue + scoping doc)

1. **5 phases are canonical** — don't invent new phases or drop one.
2. **Scoring formula is verbatim** — `Size(×1) + Fit(×2) + SalesCycle(×1) + DealValue(×1) + Education(×1)`. Fit at 2× is non-negotiable.
3. **Phase 4 is pillars, NOT copy** — biggest scope trap. Upstream Revgrowth generates copy in Phase 4; Brite version hands off to BC-5825 email-copywriting.
4. **Max 10 segments** — upstream ceiling, over-segmentation signal.
5. **BC-5827 account-research is NOT shipped yet** — Phase 1 delegates to it when available, falls back to inline WebSearch using `plugins/marketing/references/research-processes/` (shipped in BC-5823). Must document both paths.
6. **Entity-aware output** — Nites residential, Supply B2B installer, Labs venue partnership. Worked examples per entity matter.
7. **PQS signals must be grounded in SF data** — can't invent unfalsifiable signals.

## Open decisions (make during implementation)

1. **State JSON schema shape** — for `--phase N --resume`. Keep minimal: completed phases, per-phase artifact paths, entity, motion, timestamps.
2. **Runbook workflow selection** — which 4 of {full run, resume, preview, cross-sell, entity-switch, SF-grounded deep dive, handbook-seeded research}. Plan defaults to: full run, resume, entity cross-sell, preview.
3. **PQS rubric structure** — categorical (signals present/absent) vs numeric (weighted score). Recommend: 5–8 signals per segment, each flagged present/absent, with SF query grounding each.

## Tasks

### Task 1: Scaffold directory + frontmatter + §1 Opener
**Files**:
- `plugins/marketing/skills/gtm-strategy/SKILL.md` (new)

**Implementation**:
1. `mkdir -p plugins/marketing/skills/gtm-strategy/evals`
2. `cp plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md plugins/marketing/skills/gtm-strategy/SKILL.md`
3. Replace frontmatter:
   ```yaml
   ---
   name: gtm-strategy
   description: 5-phase net-new GTM motion scoping — research → segments (weighted scoring) → personas → messaging pillars → offer recommendations. Triggers: "gtm strategy", "go-to-market plan", "new motion scoping", "segments and personas", "messaging pillars", "new market entry strategy". Distinct from launch-strategy (product launches) and content-strategy (content marketing).
   user-invocable: true
   allowed-tools: mcp__plugin_marketing_salesforce__*, mcp__plugin_marketing_github__*, WebSearch, WebFetch, Read, Write, Glob
   metadata:
     version: 0.1.0
     upstream: Revgrowth1/ai-gtm-workflows
     category: Outbound Lead Gen
   ---
   ```
4. Delete all HTML comment blocks from template.
5. Write §1 Opener (1 paragraph): audience (marketing lead/RevOps/founder scoping a new motion), problem (no repeatable GTM scoping today — ad-hoc), outcome (segments + personas + pillars + offer tier recommendations in a single doc keyed to Brite entity). Explicitly state "distinct from launch-strategy (product launches) and content-strategy (content marketing)."

**Verify**: `grep -c "^---$" plugins/marketing/skills/gtm-strategy/SKILL.md` → 2 (frontmatter delimiters). `grep -E "^name: gtm-strategy$" plugins/marketing/skills/gtm-strategy/SKILL.md` returns 1 match.

---

### Task 2: §2 Before Starting + §3 Methodology
**Files**: `plugins/marketing/skills/gtm-strategy/SKILL.md`

**Implementation**:
1. §2 Before Starting:
   - Marketing-context check (mandatory boilerplate, do NOT remove)
   - Entity detection (Nites/Supply/Labs from `docs/marketing-context.md`)
   - Motion identification (prompt user if `--domain` and `--context` not provided)
   - Account-research availability check (if BC-5827 shipped, prefer; else note fallback)
   - Resume-from-state check (if `--resume` flag, read `.state.json` at expected path)
2. §3 Methodology (the load-bearing section — document all 5 phases):
   - **Phase 1 Research**: delegates to `account-research` (BC-5827) with `mode: full|deep`. Fallback: inline WebSearch using PRIMARY queries from `plugins/marketing/references/research-processes/` (find-profiles, find-competitors, find-growth-signals). Output: research.md artifact per segment.
   - **Phase 2 TAM Segments**: identify 3–10 industry segments. Apply weighted scoring: `Segment Score = (Size × 1) + (Fit × 2) + (SalesCycle × 1) + (DealValue × 1) + (Education × 1)`. Document WHY Fit is 2× (large-market-poor-fit wastes more than small-market-strong-fit). Output: ranked segments with NAICS, scoring breakdown, rationale.
   - **Phase 3 Deep Dive**: per segment: 3 personas (title, jobs-to-be-done, pain signals), PQS rubric (5–8 signals per segment, each SF-grounded present/absent), data-sourceability check against Brite enrichment + SF.
   - **Phase 4 Messaging Pillars (NOT copy)**: 2–3 pillars per segment (theme + value prop), recommended offer tier (T1 knowledge / T2 free asset / T3 DFY trial / T4 risk reversal — aligned with BC-5825 offer framework), PQS triggers (which signals fire an outreach moment). **HARD RULE**: never generate subject lines or email bodies.
   - **Phase 5 Output**: markdown at `docs/strategy/{entity}-{motion}-gtm-{YYYY-MM-DD}.md` + proposed updates to `docs/marketing-context.md` (via "proposed patch" section, not direct write). State JSON at `docs/strategy/{entity}-{motion}-gtm-{YYYY-MM-DD}.state.json`.

**Verify**:
- `grep -E "Size.*1.*Fit.*2.*SalesCycle.*1.*DealValue.*1.*Education.*1" plugins/marketing/skills/gtm-strategy/SKILL.md` returns match (scoring formula with Fit at 2×).
- `grep -cE "^### Phase [1-5]" SKILL.md` → 5.
- Section §3 explicitly names "pillars" and explicitly says "NOT copy" or "no copy generation."

---

### Task 3: §4 Brite Implementation (scope guard + cross-skill boundaries)
**Files**: `plugins/marketing/skills/gtm-strategy/SKILL.md`

**Implementation**:
1. Tool table: columns = Tool | Used in Phase | Purpose | ADR. Rows for each allowed tool with brief rationale and ADR cite where applicable.
2. Entity-specific output paths:
   - Nites residential: `docs/strategy/nites-{motion}-gtm-{date}.md`
   - Supply B2B: `docs/strategy/supply-{motion}-gtm-{date}.md`
   - Labs venue: `docs/strategy/labs-{motion}-gtm-{date}.md`
3. Cross-skill boundaries table:
   | Skill | Role | Interface |
   |---|---|---|
   | BC-5827 account-research | Phase 1 delegate (when available) | output: research.md per company |
   | BC-2722 outbound-playbook | Downstream consumer (conductor) | reads segments + pillars + PQS triggers |
   | BC-5825 email-copywriting | Downstream consumer (copy generation) | reads pillars + offer tier → produces EB-formatted JSON |
   | BC-5829 MSPA | Downstream consumer (MAP mode) | reads segments + personas + angles → experiment matrix |
4. **PHASE 4 SCOPE GUARD** — bolded explicit callout:
   > **Phase 4 produces messaging PILLARS (themes + value props + offer tier + PQS triggers). It MUST NOT produce subject lines, email bodies, or copy of any kind. Copy generation is BC-5825 email-copywriting's exclusive responsibility. If a user asks for copy during Phase 4, hand off: "Pillars ready. Pass to email-copywriting for subject + body generation."**

**Verify**:
- `grep -cE "BC-2722|BC-5825|BC-5827|BC-5829" plugins/marketing/skills/gtm-strategy/SKILL.md` → ≥4.
- `grep -iE "SCOPE GUARD|pillars.*NOT.*copy" plugins/marketing/skills/gtm-strategy/SKILL.md` returns match.

---

### Task 4: §5 MCP Tool Reference + §6 Operational Runbook
**Files**: `plugins/marketing/skills/gtm-strategy/SKILL.md`

**Implementation**:
1. §5 MCP Tool Reference — grouped by phase (not by server per ADR 2f):
   - **Phase 1 Research workflow**: WebSearch → WebFetch (when queries return hits to investigate) → optional SF MCP if prospect domain matches Account
   - **Phase 3 PQS grounding workflow**: SF MCP → SOQL against Account/Opportunity → correlate signals to outcomes
   - **Phase 5 Handbook read**: github MCP reads (per ADR 2d — no local clones) to pull entity-canon from brite-nites/handbook
2. §6 Operational Runbook — 4 workflows:
   - **Workflow A: New-motion full run** — user invokes with `--client brite-supply --domain "HOA landscape lighting"`. 5-phase sequential run. Each phase reads/writes state.json. Final artifact + proposed marketing-context patch.
   - **Workflow B: Resume after Phase 2 crash** — user invokes `--resume --phase 3`. Skill reads state.json, validates prior phases are marked complete, resumes at Phase 3.
   - **Workflow C: Entity cross-sell motion** — user invokes with multiple entities (e.g., `--client brite-nites,brite-supply` for HOA cross-sell). Phases 2–4 produce entity-specific sections in a single output doc.
   - **Workflow D: Preview mode** — `--preview` runs 3-segment abbreviated research, skips deep PQS design, produces quick strategy sketch. Useful for early-stage ideation.

**Verify**: `grep -cE "^### Workflow [A-D]" SKILL.md` → 4.

---

### Task 5: §7 Health Scoring + §8 Anti-Slop + §9 Behavioral Tests
**Files**: `plugins/marketing/skills/gtm-strategy/SKILL.md`

**Implementation**:
1. §7 Health Scoring Rubric — adopt template's rubric shape (scoring dimensions: Completeness / Specificity / Alignment / Adherence). Include dimension: "Phase 4 produces pillars, not copy."
2. §8 Anti-Slop Guardrails — 4 base + skill-specific:
   - (base) Check marketing-context.md before asking questions
   - (base) Ground every claim in data, not generic marketing tropes
   - (base) Never invent MCP tool names
   - (base) Cite sources for non-obvious claims
   - (specific) Phase 4 produces pillars, NEVER copy. Hand off to BC-5825.
   - (specific) Segment scoring formula weights Fit at 2× — exact match to upstream.
   - (specific) Always cite data-sourceability per segment (can Brite actually build this list?).
   - (specific) Never invent PQS signals without SF data to validate against.
   - (specific) Maximum 10 segments — over-segmentation signal.
3. §9 Behavioral Tests — 6+ scenarios in prose:
   1. **Tier 1 happy path**: user invokes full run on Brite Supply landscape motion → 5 phases complete, artifact written.
   2. **Tier 1 Phase 4 scope-guard**: mid-Phase-4, user asks "write me the first email for this pillar." Skill refuses, hands off with message naming BC-5825.
   3. **Tier 1 resume**: state.json marks Phase 2 complete. User invokes `--resume --phase 3`. Skill validates state and resumes.
   4. **Tier 1 entity cross-sell**: two entities in `--client`, output has per-entity sections.
   5. **Tier 2 missing marketing-context**: warns, degrades, proceeds with user-provided inputs.
   6. **Tier 2 invented PQS signal**: skill proposes signal X; anti-slop check flags "no SF query grounds this" — skill removes and proposes a grounded alternative.
   7. (optional) **Tier 2 research fallback**: BC-5827 unavailable → skill falls back to inline WebSearch using research-processes queries.

**Verify**:
- `grep -cE "^#### Scenario [0-9]" SKILL.md` → ≥6.
- `grep -iE "scope.guard|refuses.copy|hands off.*email-copywriting" SKILL.md` returns match.

---

### Task 6: evals/evals.json
**Files**: `plugins/marketing/skills/gtm-strategy/evals/evals.json` (new)

**Implementation**:
Mirror the 6+ scenarios from §9 as JSON. Structure per prior evals files (reference: `plugins/marketing/skills/campaign-orchestration/evals/evals.json` if present):
```json
{
  "scenarios": [
    {
      "name": "happy-path-full-run",
      "tier": 1,
      "input": {"client": "brite-supply", "domain": "HOA landscape lighting"},
      "assertions": [
        "artifact written to docs/strategy/supply-hoa-landscape-lighting-gtm-*.md",
        "state.json exists with all 5 phases marked complete",
        "output contains >=3 segments with scoring breakdown",
        "Fit weighted at 2x in every segment score"
      ]
    },
    ...
  ]
}
```
6+ scenarios total — one per behavioral test in §9.

**Verify**:
- `jq '.scenarios | length' plugins/marketing/skills/gtm-strategy/evals/evals.json` → ≥6.
- `jq -e '.scenarios[] | select(.name=="phase-4-scope-guard")' evals.json` returns a match.

---

### Task 7: Document artifact + state schema
**Files**: `plugins/marketing/skills/gtm-strategy/SKILL.md` (append to §4 or §5)

**Implementation**:
1. Output markdown artifact structure — document these sections:
   - Header: `# GTM Strategy: {Entity} — {Motion}` + frontmatter (entity, motion, generated_at, version)
   - `## Phase 1: Research Summary` (or link to research artifacts per segment)
   - `## Phase 2: TAM Segments` — ranked table with scoring breakdown
   - `## Phase 3: Personas + PQS Rubric` — per segment: personas, PQS signals, data-sourceability verdict
   - `## Phase 4: Messaging Pillars` — per segment: 2–3 pillars, offer tier, PQS triggers
   - `## Phase 5: Proposed marketing-context.md Patch` — markdown patch block
2. State JSON schema:
   ```json
   {
     "schema_version": "1.0",
     "entity": "brite-nites|brite-supply|brite-labs",
     "motion": "string",
     "started_at": "ISO-8601",
     "phases_completed": [1, 2, 3],
     "current_phase": 4,
     "artifact_path": "docs/strategy/...md",
     "inputs": {"client": "...", "domain": "...", "context": "..."},
     "phase_outputs": {
       "1": {"research_artifacts": ["..."]},
       "2": {"segments": [{"name": "...", "score": 9, "breakdown": {...}}]},
       "3": {"deep_dives": {"segment_name": {"personas": [...], "pqs": {...}}}}
     }
   }
   ```

**Verify**: `grep -E "state.json|schema_version" SKILL.md` returns matches. `grep -E "^## Phase [1-5]:" SKILL.md` shows 5 output-artifact sections (distinct from methodology phases).

---

### Task 8: Cross-link §Consumers on downstream skills
**Files**:
- `plugins/marketing/skills/outbound-playbook/SKILL.md` (BC-2722 — not yet shipped, skip if file doesn't exist)
- `plugins/marketing/skills/email-copywriting/SKILL.md` (BC-5825 — not yet shipped, skip)
- `plugins/marketing/skills/message-market-fit/SKILL.md` (BC-5829 — not yet shipped, skip)
- `plugins/marketing/skills/account-research/SKILL.md` (BC-5827 — not yet shipped, skip)

**Implementation**:
Since all 4 downstream skills are not yet shipped, this task **cannot execute fully in this PR**. Two options:
1. **Defer**: note in gtm-strategy's §4 cross-skill boundaries that cross-linking will happen when consumer skills ship. Add a follow-up issue noting "BC-5833: when consumer skills ship, add gtm-strategy to their §Consumers."
2. **Partial**: check if any of those skill dirs exist. For each that does, add a §Consumers entry (or create one) naming `gtm-strategy` as an upstream producer. For those that don't, no-op this PR.

**Recommended**: Option 1 (defer) + create follow-up issue. This PR ships the skill; downstream hookup ships when those skills do.

**Verify**:
- `ls plugins/marketing/skills/{outbound-playbook,email-copywriting,message-market-fit,account-research}/ 2>/dev/null` → confirm none exist (or partial count).
- Plan file (this doc) captures deferral rationale.

---

### Task 9: Validate + ship prep
**Files**: none new — runs existing scripts.

**Implementation**:
1. `./scripts/validate.sh` — should exit 0. If it fails, read error, fix, rerun.
2. `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — should exit 0. Guardrail is on CLAUDE.md line budget and anti-slop; this skill add shouldn't affect CLAUDE.md.
3. Spot-check SKILL.md: preview renders cleanly, frontmatter parses, all 9 sections present in order, no placeholder `{...}` left behind.
4. `grep -c "^## " plugins/marketing/skills/gtm-strategy/SKILL.md` → 9 (all sections present).
5. `grep -iE "\{.*\}" plugins/marketing/skills/gtm-strategy/SKILL.md | grep -vE "VARIABLE|example|placeholder by design"` → 0 unwanted placeholder leftovers.
6. Commit with message: `BC-5833: create gtm-strategy skill (5-phase net-new motion scoping)` + co-author line.
7. Run `/workflows:review` → fix any P1s from review agents.
8. Run `/workflows:ship` → opens PR, updates Linear status, compounds learnings.

**Verify**:
- `./scripts/validate.sh; echo $?` → 0
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md; echo $?` → 0
- PR URL returned by `/workflows:ship`.

---

## Task Dependencies

- Tasks 1 → 2 → 3 → 4 → 5 → 6 → 7 are strictly sequential (each writes into the same SKILL.md).
- Task 8 is effectively deferred (consumer skills not shipped yet).
- Task 9 runs last after 1–7 complete.

No parallelization inside this plan — it's a single-file skill authoring task.

## Verification Checklist (PR-level)

- [ ] SKILL.md has all 9 required sections in order
- [ ] Frontmatter matches template shape with `name: gtm-strategy` and correct `allowed-tools`
- [ ] Scoring formula weights Fit at 2× (exact match to upstream)
- [ ] Phase 4 scope-guard documented as hard rule with BC-5825 handoff
- [ ] ≥6 behavioral test scenarios including Phase 4 scope-guard + resume
- [ ] evals/evals.json has ≥6 scenarios matching §9
- [ ] Output artifact path + state JSON schema documented
- [ ] `./scripts/validate.sh` exits 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0
- [ ] Cross-linking deferred via follow-up issue (consumer skills not yet shipped)
- [ ] PR created, Linear issue status updated to In Review

## Risks + mitigations

1. **Scope creep into Phase 4 copy generation.** Mitigation: the scope guard is the hardest invariant in this skill. Validate via anti-slop rule + behavioral test.
2. **PQS rubric vagueness.** Mitigation: require every signal to name a SF query that validates it. Encode as anti-slop rule.
3. **Entity examples drift into generic B2B content.** Mitigation: every worked example must cite a Brite-specific product/ICP (residential lighting design, landscape installer procurement, venue partnership events).
4. **Upstream vs Brite divergence.** Mitigation: keep upstream citation at the top of §3 methodology; any divergence from upstream is annotated inline with rationale (`# Brite departure: ...`).
