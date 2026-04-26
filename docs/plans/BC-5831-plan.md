# BC-5831 Plan: Create marketing skill `icp-scoring`

**Issue:** [BC-5831](https://linear.app/brite-nites/issue/BC-5831/create-marketing-skill-icp-scoring-0-100-parallel-prospect-scoring)
**Goal:** Net-new `plugins/marketing/skills/icp-scoring/SKILL.md` — pre-outreach prospect prioritization with dual-mode rubric (`score_0_100` standalone, `abc` for tam-mapping delegation).
**Branch:** `holden/bc-5831-icp-scoring` (worktree at `.claude/worktrees/bc-5831/`)

---

## Brainstorm decisions (recorded 2026-04-26)

| # | Question | Decision | Rationale |
|---|---|---|---|
| 1 | Where does the abc-mode prompt live? | **Reference `plugins/marketing/references/tam/fit-scoring.md`** (do not inline). | Single source of truth — when upstream tam-map updates, we re-port to fit-scoring.md and SKILL.md inherits. Matches BC-5946 references/ pattern. |
| 2 | Cost cap UX | **AskUserQuestion confirmation gate at thresholds + cost estimate; NO hard 10K cap.** | User explicit (2026-04-26) — replaces issue spec's `--max-records 10000` hard limit. Two-call gate matches BC-2707/BC-5826 destructive-action precedent. |
| 3 | Entity detection when `--client` not passed | **Auto-detect + warn. Multi-entity → ask. Missing file → 3-way prompt (delegate to `/marketing:product-marketing-context`, inline pick, or cancel).** | `docs/marketing-context.md` doesn't exist yet (`product-marketing-context` skill creates it). User always sees entity choice before scoring runs; missing-file path delegates to the skill that owns the file's contract. |
| 4 | Parallel-research worker shape | **Per-record workers** — each of 20 workers takes one CSV row end-to-end (research + score). | Matches Revgrowth 03 upstream. Simplest mental model. WebSearch rate-limit only pauses one worker. |

### Scope amendments vs issue

- Replaces `--max-records 10000 hard limit` (Tam-map addendum § Added scope item 5) with `AskUserQuestion gate + cost estimate at threshold(s)`.
- Adds explicit 3-way fallback flow for missing `marketing-context.md` (issue spec says "warn user" but doesn't define recovery).

---

## Reference reads (mandatory before writing SKILL.md)

1. `plugins/marketing/skills/_template/OUTBOUND-SKILL-TEMPLATE.md` — 9-section structure
2. `plugins/marketing/skills/gtm-strategy/SKILL.md` — recently-shipped sibling (PR #156, 444 lines), uses entity-detection + resume-state pattern
3. `plugins/marketing/skills/email-copywriting/SKILL.md` — sibling that consumes pillar handoff (downstream of icp-scoring)
4. `plugins/marketing/skills/account-research/SKILL.md` — sibling for parallel-research pattern reference
5. `plugins/marketing/references/tam/fit-scoring.md` — A/B/C prompt source (verbatim use in abc mode)
6. `plugins/marketing/references/tam/icp-definition.md` — ICP JSON schema
7. `docs/research/tam-map-port-policy.md` § 4 — dual-mode rubric policy
8. `plugins/marketing/tools/integrations/salesforce.md` — SF MCP tool surface
9. `plugins/marketing/tools/integrations/brite-enrichment.md` — enrichment MCP tool surface
10. Upstream [Revgrowth1/ai-gtm-workflows workflow 03](https://github.com/Revgrowth1/ai-gtm-workflows/tree/main/workflows/03-icp-scoring) — original methodology
11. CLAUDE.md gotchas (especially `allowed-tools` cross-validation against `.mcp.json`)
12. `memory/MEMORY.md` (already loaded)

---

## Tasks

Each task is 2–5 min of focused work. File paths absolute from worktree root `.claude/worktrees/bc-5831/`.

### Phase A — Scaffold (3 tasks)

**A1. Create skill directory.**
- Create `plugins/marketing/skills/icp-scoring/`
- Create `plugins/marketing/skills/icp-scoring/evals/` subdirectory
- Verify: `ls plugins/marketing/skills/icp-scoring/` shows the dir + evals/

**A2. Write SKILL.md frontmatter.**
- Path: `plugins/marketing/skills/icp-scoring/SKILL.md`
- Frontmatter:
  - `name: icp-scoring`
  - `description:` — opens with one-sentence skill purpose; ends with trigger phrases: "icp score", "icp verify", "qualify prospects", "score this list", "rank companies", "tier by icp"
  - `user-invocable: true`
  - `allowed-tools: mcp__plugin_marketing_salesforce__*, WebSearch, WebFetch, Read, Write, Glob, Bash`
  - `metadata: { version: 0.1.0, upstream: Revgrowth1/ai-gtm-workflows + Revgrowth1/tam-map, category: Outbound Lead Gen }`
  - **Phase A3 finding:** `mcp__plugin_marketing_enrichment__*` is intentionally EXCLUDED from `allowed-tools` — that server is NOT registered in `plugins/marketing/.mcp.json` (only `salesforce`, `spider`, `aiark`, `discolike` exist; BC-5537/5538 not yet shipped). Per CLAUDE.md gotcha, listing an unregistered server causes silent runtime failure. SKILL.md §4 documents the graceful-degrade path (research falls back to WebSearch + SF Account lookup) and the BC-5537/5538 pickup point.
- Verify: `head -15 SKILL.md` shows valid YAML frontmatter; cross-check `allowed-tools` servers exist in `plugins/marketing/.mcp.json` (per CLAUDE.md gotcha)

**A3. Cross-validate allowed-tools against .mcp.json. (DONE pre-A2)**
- Confirmed registered: `salesforce`, `spider`, `aiark`, `discolike`. `enrichment` is NOT registered — excluded from `allowed-tools` per finding above.
- Verify: every `mcp__plugin_marketing_<server>__*` entry in final `allowed-tools` has a corresponding key in `.mcp.json`. ✅

### Phase B — Body sections (9 tasks, one per template section)

**B1. §1 Opener.**
- One paragraph: who the skill helps (BDR/RevOps/marketing operator with a raw prospect list), what problem (no pre-outreach prioritization today, lists are run-them-all or hand-filtered), one-line outcome (split into qualified/disqualified or A/B/C tier CSVs with reasoning).
- Mention dual-mode rubric (`score_0_100` default standalone, `abc` when delegated from tam-mapping).
- Distinct-from-`lead-routing` callout (pre-outreach vs post-reply).
- Verify: opener is one paragraph (≤8 lines), no tool/MCP names, ends with the dual-mode mention.

**B2. §2 Before Starting.**
- Marketing-context.md check (read if exists; else fall through to entity-detection logic in B2.5).
- Entity detection logic per **brainstorm decision 3**:
  - File exists, single entity → use it, print "Using entity=X (override with --client)".
  - File exists, multiple entities → AskUserQuestion to pick from existing.
  - File missing → AskUserQuestion: (1) Run `/marketing:product-marketing-context`, (2) Pick entity inline for this run, (3) Cancel.
- Invocation flags: `--client`, `--threshold` (default 70, score_0_100 only), `--workers` (default 20, max 20), `--preview` (sample 5), `--rubric` (default `score_0_100`; `abc` when delegated), `--criteria` (inline), `--criteria-file`, `--max-records` (no hard cap; gate threshold default 1000 in score_0_100 / 10000 in abc), `--model` (override).
- CSV schema validation: required `domain` or `company_domain`; optional `company_name`, `industry`, `employees`.
- Verify: section enumerates all 3 ICP criteria sources; all flags listed; entity-detection 3-way fallback documented.

**B3. §3 Methodology.**
- ICP criteria sources (3): auto via marketing-context, inline `--criteria`, JSON `--criteria-file`.
- Both rubrics:
  - `score_0_100`: 4-bucket (80–100 Strong / 60–79 Likely / 40–59 Partial / 0–39 Poor); output adds `icp_score`, `icp_label`, `icp_reasoning`, `company_summary`.
  - `abc`: Haiku letter-only — **read prompt template from `plugins/marketing/references/tam/fit-scoring.md` verbatim** (per brainstorm decision 1; do not inline).
- Parallel-research flow per **brainstorm decision 4**: per-record workers, each takes one row end-to-end (research via WebSearch + SF MCP availability probe + enrichment MCP availability probe → score). Cap 20 workers.
- Pre-filter optimization: if input CSV already has `industry` + `employees` matching ICP must-haves/must-not-haves, score from columns alone (skip research).
- Research-failure fallback: WebSearch timeout / no result → score 40 (conservative default), reasoning notes "research failed; conservative score" (score_0_100 only); abc mode → C tier (per fit-scoring.md tuning notes "model defaults to C due to missing signal").
- Verify: §3 documents 3 criteria sources; both rubrics; parallel flow; pre-filter; research fallback. Reference to fit-scoring.md is explicit.

**B4. §4 Brite Implementation.**
- Tool table — one row per tool with purpose + ADR cite (ADR 2c for `salesforce`, ADR 008 for `enrichment` graceful-degrade).
- Entity-specific criteria path: `docs/marketing-context.md` ICP section per entity (Nites residential / Supply installer / Labs venue).
- Tam-mapping delegation contract: when invoked with `--rubric abc` from tam-mapping Phase 7, return `tier-a.csv`, `tier-b.csv`, `tier-c.csv`, `catch-all.csv` to caller's working directory. Pass-through `--max-records`, `--model`, `--workers`.
- Cross-skill boundaries (verbatim from issue spec): owns / receives from / hands off to / does not own (distinguish from BC-2725 lead-routing).
- Cost-cap gate per **brainstorm decision 2**: `score_0_100` >1000 records → AskUserQuestion gate with cost estimate; `abc` >10000 → same gate; no hard refuse.
- Verify: ADRs cited; entity paths documented; delegation contract documented; cost-cap gate documented (no hard 10K cap).

**B5. §5 MCP Tool Reference.**
- WebSearch: research query patterns (industry classification, employee count via LinkedIn-style queries, geography).
- SF MCP `run_soql_query`: optional Account lookup for existing-customer signal (excluded from positive score in score_0_100; counts as catch-all signal in abc).
- Enrichment MCP: optional firmographic fill (graceful-degrade with "pending BC-5537/5538" notice when unavailable).
- Verify: each MCP tool has purpose + example query + graceful-degrade behavior.

**B6. §6 Operational Runbook.**
- Workflow A: entity-auto criteria, ad-hoc list (most common path).
- Workflow B: inline `--criteria` for one-off scoring.
- Workflow C: criteria JSON file for shareable rubrics.
- Workflow D: `--preview` mode (sample 5) for sanity-check.
- Workflow E: parallel-scoring 500+ list (cost gate fires).
- Workflow F: tam-mapping delegated abc batch (`--rubric abc` invocation).
- Verify: 6 workflows documented (issue minimum 5); each has invocation, expected output, 1-line success criterion.

**B7. §7 Health Scoring Rubric.**
- Adapt the standard skill rubric (per `_template/OUTBOUND-SKILL-TEMPLATE.md`) to skill-specific health checks:
  - Frontmatter complete + valid
  - All 9 sections present in order
  - Both rubrics documented in §3
  - Cost-gate logic in §4
  - Entity-detection 3-way fallback in §2
- Verify: rubric has 5+ check items; references real skill structure.

**B8. §8 Anti-Slop.**
- 4 base anti-slop items (from template) + skill-specific:
  - Reasoning required per score in `score_0_100` mode (abc is letter-only by design).
  - Tier-aware confidence: T4 companies get lower confidence — flag in reasoning.
  - Parallel worker cap 20 (research API rate limits).
  - LLM timeout → conservative default (40 in score_0_100, C in abc); never reject.
  - Cost gate AskUserQuestion confirmation required before run >threshold (per brainstorm decision 2).
  - Never inline the abc prompt — always read `references/tam/fit-scoring.md` (per brainstorm decision 1).
- Verify: 4 base + 6 skill-specific = 10 items.

**B9. §9 Behavioral Tests.**
- 6+ scenarios:
  1. Entity-auto criteria (marketing-context.md exists, single entity).
  2. Inline `--criteria` for one-off.
  3. Criteria JSON file.
  4. Pre-filter hit (CSV columns satisfy must-haves; no research needed).
  5. Research-failure fallback (WebSearch returns nothing → score 40 / tier C).
  6. Preview mode (`--preview` samples 5).
  7. Tam-mapping delegated abc batch (`--rubric abc`, output is tier CSVs).
  8. Cost-cap gate fires at 1500 records in score_0_100 (gate is AskUserQuestion, not hard fail).
  9. Missing marketing-context.md → 3-way prompt fires.
- Verify: ≥3 scenarios per rubric mode (score_0_100 covers 1/2/3/4/5/6/8; abc covers 7); cost-gate scenario explicitly tests AskUserQuestion gate (not hard cap).

### Phase C — Evals + cross-links + validation (5 tasks)

**C1. Write evals/evals.json.**
- Path: `plugins/marketing/skills/icp-scoring/evals/evals.json`
- 6+ scenarios mirroring §9 (≥3 per rubric mode). Each scenario: `name`, `input`, `expected_output_shape`, `assertion` field.
- Verify: `jq . evals.json` parses; 6+ entries; each has all 4 fields.

**C2. Document output CSV columns + split convention.**
- score_0_100 mode: input CSV → `{input_basename}_qualified.csv` (≥threshold rows + 4 added columns) + `{input_basename}_disqualified.csv` (<threshold rows + 4 added columns) + summary report (distribution + top disqualification reasons).
- abc mode: input CSV → `tier-a.csv` / `tier-b.csv` / `tier-c.csv` / `catch-all.csv` in caller's working directory (catch-all comes from input `catch_all` column, never inferred by this skill).
- Document in §4 Brite Implementation under "Output convention" subsection.
- Verify: both modes' output paths + columns documented; catch-all isolation explicit (skill doesn't SMTP-verify, just respects input column).

**C3. Cross-link from sibling skills.**
- Add `## Consumers` entry in:
  - `plugins/marketing/tools/integrations/salesforce.md` — list icp-scoring as consumer.
  - `plugins/marketing/tools/integrations/brite-enrichment.md` — list icp-scoring as consumer (or note as upstream-pending).
- Add cross-link line in:
  - `plugins/marketing/skills/email-copywriting/SKILL.md` § Cross-Skill Boundaries → "Receives from: icp-scoring qualified list (score_0_100)".
- Note: BC-2717 (list-building), BC-2725 (lead-routing), BC-2727 (data-enrichment), BC-5832 (tam-mapping) are NOT YET SHIPPED — defer cross-link insertion to those issues' implementation, but reference them in BC-5831 SKILL.md §4 cross-skill boundaries.
- Verify: 3 in-repo cross-links land; 4 deferred cross-links called out in SKILL.md.

**C4. Run validate.sh + check-guardrails.sh.**
- `./scripts/validate.sh` — must exit 0 (validates plugin schema, frontmatter, no broken refs).
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — must exit 0 (CLAUDE.md anti-slop check).
- If either fails, fix and re-run.
- Verify: both exit 0.

**C5. Manual SKILL.md sanity grep.**
- `grep -c "^## " plugins/marketing/skills/icp-scoring/SKILL.md` — expect 8 `## ` headings (Before Starting / Methodology / Brite Implementation / MCP Tool Reference / Operational Runbook / Health Scoring / Anti-Slop / Behavioral Tests). Opener is `# Title`, no `## `.
- `grep "fit-scoring.md" plugins/marketing/skills/icp-scoring/SKILL.md` — must find ≥1 reference (per brainstorm decision 1).
- `grep -i "AskUserQuestion" plugins/marketing/skills/icp-scoring/SKILL.md` — must find references in §2 (entity-detection fallback) and §4 (cost gate).
- `grep "max-records" SKILL.md` — must NOT find any "10000 hard" or "10000 max" claims (per brainstorm decision 2).
- Verify: all 4 greps pass.

**C6. Bump marketing plugin version (BC-6000 same-commit rule).**
- Path 1: `plugins/marketing/.claude-plugin/plugin.json` — bump `version` (current `0.3.3` → `0.3.4` patch bump for new skill).
- Path 2: `.claude-plugin/marketplace.json` — find the `marketing` plugin entry, bump its `version` field to match.
- Per CLAUDE.md gotcha (BC-6000 precedent): "Bump plugin version in the SAME commit as any edit under `plugins/<plugin>/{hooks,skills,commands,agents}/**`." Adding `plugins/marketing/skills/icp-scoring/` triggers this rule.
- Verify: `jq -r '.version' plugins/marketing/.claude-plugin/plugin.json` returns `0.3.4`; `jq -r '.plugins[] | select(.name=="marketing") | .version' .claude-plugin/marketplace.json` returns `0.3.4`.

---

## Verification (objective pass/fail — pulled from issue + brainstorm)

### From issue spec (Verification section)

- [ ] `plugins/marketing/skills/icp-scoring/SKILL.md` exists with required frontmatter
- [ ] All 9 sections in required order
- [ ] `allowed-tools` matches Tool Surface exactly; no Serper
- [ ] `allowed-tools` cross-validated against `plugins/marketing/.mcp.json` — no unregistered servers (CLAUDE.md gotcha)
- [ ] §3 Methodology documents all 3 ICP criteria sources
- [ ] §3 Methodology documents BOTH rubrics: 4-bucket `score_0_100` AND Haiku letter-only `abc`
- [ ] §3 Methodology documents parallel-research flow with pre-filter optimization
- [ ] §4 Brite Implementation documents entity-specific criteria path
- [ ] §4 Brite Implementation documents tam-mapping delegation path (abc mode returning tier CSVs)
- [ ] §4 cross-skill boundaries explicitly distinguish from BC-2725 lead-routing (pre-outreach vs post-reply)
- [ ] §6 Operational Runbook has 5+ workflows including entity-auto, preview, and tam-mapping delegated batch
- [ ] §8 Anti-Slop includes reasoning-per-score (score_0_100 only), tier-aware, worker cap, LLM-timeout default
- [ ] §9 Behavioral Tests has 6+ scenarios; ≥3 per rubric mode
- [ ] `evals/evals.json` has 6+ scenarios
- [ ] Output columns documented for BOTH modes
- [ ] Cross-links added to BC-2717, BC-2725, BC-2727, BC-5832 (deferred), salesforce.md (in-repo), brite-enrichment.md (in-repo)
- [ ] `./scripts/validate.sh` exits 0
- [ ] `./scripts/check-guardrails.sh --claude-md CLAUDE.md` exits 0
- [ ] PR opened, linked via "Closes BC-5831"

### From brainstorm decisions (additional)

- [ ] abc-mode prompt is referenced from `plugins/marketing/references/tam/fit-scoring.md`, NOT inlined (decision 1)
- [ ] No `--max-records 10000` hard refuse — gate behavior only (decision 2)
- [ ] Cost-gate test (Behavioral Test #8): invocation with 1500 records in `score_0_100` mode emits AskUserQuestion gate, not auto-fail
- [ ] Entity-detection 3-way fallback documented in §2 (decision 3)
- [ ] Missing-marketing-context.md path delegates to `/marketing:product-marketing-context` skill (decision 3)
- [ ] Per-record worker shape documented in §3 (decision 4)

---

## Out of scope (per issue Non-Goals)

- Post-reply MQL routing (BC-2725 lead-routing)
- List assembly (BC-2717)
- Enrichment pipeline design (BC-2727)
- TAM construction (BC-5832)
- Score generation in `score_0_100` without reasoning
- More than 20 parallel workers

---

## Estimated effort

- Phase A (scaffold): ~10 min
- Phase B (9 sections): ~60–75 min (5–8 min per section, longest is §3 Methodology + §6 Runbook)
- Phase C (evals + cross-links + validation): ~20 min
- **Total: ~90–105 min** for a focused execution session.

If validation surfaces gaps (likely in §3 Methodology dual-mode tests or §9 scenario coverage), add 15–20 min for fixup.
