# BC-5825 Plan — email-copywriting Skill (Infrastructure + 2 Seed Presets)

**Issue:** [BC-5825](https://linear.app/brite-nites/issue/BC-5825/create-marketing-skill-email-copywriting-eb-formatted-sequence-copy)
**Design doc:** [bc-5825-email-copywriting.md](../designs/bc-5825-email-copywriting.md)
**Branch:** `holden/bc-5825-email-copywriting`
**Worktree:** `.claude/worktrees/bc-5825`
**Follow-ups:** BC-5879 (Active), BC-5880 (Exploring), BC-5881 (Future)

**Scope:** Skill skeleton + lazy-load infra + `presets/README.md` index + 2 seed Municipalities preset files + evals + email-bison.md cross-link. Per-vertical preset fan-out (44 files) ships in BC-5879/5880/5881.

**Verification commands** (run after implementation):
```bash
./scripts/validate.sh                                      # Plugin validator
./scripts/check-guardrails.sh --claude-md CLAUDE.md        # Size + anti-slop
grep -E "mcp__(plugin_marketing_)?emailbison" plugins/marketing/skills/email-copywriting/SKILL.md  # MUST be empty
```

---

## Task 1 — Create directory structure + open SKILL.md shell

**Files:**
- `plugins/marketing/skills/email-copywriting/` (mkdir)
- `plugins/marketing/skills/email-copywriting/evals/` (mkdir)
- `plugins/marketing/skills/email-copywriting/presets/` (mkdir)
- `plugins/marketing/skills/email-copywriting/SKILL.md` (new file, frontmatter only)

**Steps:**
1. Create the 3 directories.
2. Write SKILL.md frontmatter only (no body yet):
   ```yaml
   ---
   name: email-copywriting
   description: Generate Email-Bison-formatted subject + body for step 1 + step 2 from a situation-mining artifact + offer tier + entity. Emits a JSON artifact the /marketing:launch-campaign command ingests. Triggers on write email copy, draft sequence, email copywriting, generate outbound copy, email drafting for, campaign copy for, EB-format email, per-vertical email preset. Adapted from Revgrowth1/ai-gtm-workflows workflow 10 (MIT).
   user-invocable: true
   allowed-tools: mcp__plugin_marketing_salesforce__*, Read, Write, Glob, Grep
   metadata:
     version: 0.1.0
     upstream: Revgrowth1/ai-gtm-workflows
     category: Outbound Lead Gen
   ---

   # Email Copywriting

   <!-- body filled in subsequent tasks -->
   ```

**Verify:**
```bash
ls plugins/marketing/skills/email-copywriting/
# Should show: SKILL.md, evals/, presets/
test -f plugins/marketing/skills/email-copywriting/SKILL.md && echo OK
```

---

## Task 2 — Write §1 Opener + §2 Before Starting

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`

**Content (§1 Opener):** One paragraph continuing situation-mining's "diagnostic over promotional" framing. Frame the skill as the translator from diagnostic angles → EB-format emails. State the outcome: one JSON artifact per campaign, valid EB format guaranteed by anti-slop guardrails, entity-aware by design.

**Content (§2 Before Starting):**
- Marketing-context check: read `docs/marketing-context.md`. If missing, warn operator with the exact message from the BC-5824 precedent and PAUSE — do not default entity. (D1 hard gate.)
- Entity detection: if situation-mining artifact is in context, read `entity:` from frontmatter. If not, ask operator explicitly via AskUserQuestion.
- Situation artifact check: if operator supplied a path or the conversation has a recent `docs/research/situations/*.md` artifact, read it — extract vertical, entity, worldview, adjacent offering.
- Value-equation gate: before drafting, confirm 4 inputs (What to GIVE free / best case study + numbers / guarantee / time-to-value). If marketing-context.md omits them, interview the operator. If operator declines to supply, abort with a clear message — do not invent proof points.

**Reference:**
- Pattern: situation-mining `SKILL.md` §Before Starting (disambiguation pause as canonical precedent)
- Pattern: BC-5824 D4 decision rule for hard-gate pauses

**Verify:**
```bash
grep -n "^## Before Starting" plugins/marketing/skills/email-copywriting/SKILL.md
# Expect one match
```

---

## Task 3 — Write §3 Methodology (EB rules + frameworks + base skeletons + lazy-load pattern)

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`

**Subsections:**
1. **EB format rules** — exact list from issue body, ≥10 bullets. Cite as non-negotiable, enforced by §8 Anti-Slop.
2. **Hormozi value equation** — formula + 4 inputs + worked example for Brite (e.g. Nites T2 free design preview).
3. **Offer tiers + entity-aware selection matrix** — T1-T4 definitions + the 3-entity row matrix from the issue body (Nites / Supply / Labs).
4. **Recency waterfall** — 6-level hierarchy from the issue body: New job > LinkedIn post > Company news > CEO podcast > Company post > Fallback.
5. **Base template skeletons** — 2 inline skeletons (list-building + risk-reversal), entity-agnostic, showing exact `{VARIABLE}` slots, paragraph shape with `<br><br>`, spintax placeholders, greeting-merged first sentence, sign-off block.
6. **Lazy-load per-vertical overrides** — describe the `presets/{preset}-{vertical}.md` pattern + frontmatter shape (from design doc §Preset file shape) + fallback behavior when vertical file missing. Pointer to `presets/README.md` index.

**References to cite inline:**
- Upstream: Revgrowth1/ai-gtm-workflows workflow 10 (value equation, tiers, waterfall, base templates)
- Brite: handbook entity canon (Nites + Labs only; Supply has no verticals per BC-5824)

**Verify:**
```bash
# EB format rules enumerated
grep -c "^- " plugins/marketing/skills/email-copywriting/SKILL.md
# Expect ≥30 bullets (rules + matrices + waterfall + preset skeletons)

# Base skeletons present
grep -c "^## \|^### " plugins/marketing/skills/email-copywriting/SKILL.md
# Should reflect all subsections
```

---

## Task 4 — Write §4 Brite Implementation + §5 MCP Tool Reference

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`

**§4 Brite Implementation:**
- Tool-table: Read (primary) / Write (primary — emits JSON artifact) / Salesforce MCP (optional, for `{SENDER_*}` lookup) / Glob / Grep (preset file discovery).
- Cross-skill boundaries subsection: Owns (subject+body gen, JSON artifact emit, offer-tier + value-equation + waterfall application, preset logic). Does not own (research, sequence mechanics — BC-2718 done, launch exec — BC-5826, per-vertical fan-out — BC-5879/5880/5881). Receives from (situation-mining, optional gtm-strategy pillars). Hands off to (`/marketing:launch-campaign` via JSON at `docs/campaigns/{entity}/copy-{campaign-name}-{YYYY-MM-DD}.json`).
- JSON artifact schema: full shape from design doc §Output artifact shape. Document every field.
- Preset file path convention: `plugins/marketing/skills/email-copywriting/presets/{preset}-{vertical-slug}.md`. Vertical slug matches situation-mining's vertical frontmatter value. Fallback: when operator doesn't supply `vertical` OR file missing, use base inline skeleton + entity tone.
- Architectural rules:
  * `docs/marketing-context.md` is the entity-canon source; skill never hard-codes entity defaults (D1).
  * Offer tier always confirmed with operator (D2) — no auto-select code paths.
  * Preset files are LAZY-LOADED (D3) — one preset file read per invocation, not the whole library.
  * Supply vertical triggers are out of scope per handbook canon + BC-5824 precedent.

**§5 MCP Tool Reference:**
- Workflow 1 — `{SENDER_*}` lookup (conditional): availability check (`run_soql_query` with `SELECT Id FROM User LIMIT 1`) + Account/User read for sender first_name, email, role. Falls back to operator input if SF unavailable.
- No mutating workflows (this skill is read-only + Write to local disk).

**Verify:**
```bash
grep -n "^## Brite Implementation\|^## MCP Tool Reference" plugins/marketing/skills/email-copywriting/SKILL.md
# Expect two matches in order
```

---

## Task 5 — Write §6 Operational Runbook (6 flows)

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`

**Flows:**
1. **Flow 1 — Happy path (situation + offer + vertical → copy using preset).** Preconditions: marketing-context.md exists, situation artifact in context, vertical identified. Steps: load situation → recommend offer tier → confirm with operator → load matching `presets/{preset}-{vertical}.md` → fill slots from situation + value-equation inputs → validate against §8 anti-slop → write JSON artifact. Expected output: artifact at `docs/campaigns/{entity}/copy-{campaign-name}-{YYYY-MM-DD}.json`.
2. **Flow 2 — Scratch path (no situation, value-equation interview).** Preconditions: no situation artifact. Steps: operator supplies entity + target description → skill interviews for the 4 value-equation inputs → picks base skeleton → fills with operator-supplied proof points → validates → writes JSON.
3. **Flow 3 — Existing-preset path (operator picks base template manually).** Operator explicitly wants list-building or risk-reversal base template with no vertical override. Skill loads the base inline skeleton and fills from whatever inputs are available.
4. **Flow 4 — Seed-vertical demo (Municipalities end-to-end).** Dogfood flow — operator can run "demo Municipalities list-building" to exercise the seed preset loading + fill + artifact emission. Used for smoke-testing the lazy-load path.
5. **Flow 5 — Thin-context fallback (no marketing-context.md, hard gate pause).** D1 behavior — pause + warn + ask for entity explicitly. No silent default.
6. **Flow 6 — Unknown-vertical fallback (preset file missing).** Operator supplies a vertical but no matching preset file exists (expected for all verticals except Municipalities until BC-5879/5880/5881 ship). Skill falls back to base template + entity tone + log warning noting which fan-out issue will ship the preset.

**Verify:**
```bash
grep -c "^### Flow " plugins/marketing/skills/email-copywriting/SKILL.md
# Expect 6
```

---

## Task 6 — Write §7 Rubric + §8 Anti-Slop + §9 Behavioral Tests

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`

**§7 Health Scoring Rubric:** 10-anchor = "emits EB-format-compliant JSON artifact with: Hormozi value equation application visible in body copy + entity-aware tier from the matrix + recency-waterfall anchor in the hook + every {VARIABLE} declared in `custom_variables` + base or per-vertical preset cited + situation-mining source cited when applicable + no anti-slop violations on validation." 7-9 = minor gap. 4-6 = functional but missing structural element. 1-3 = format violations or ignored marketing-context.

**§8 Anti-Slop Guardrails:**
- 4 base (no jargon, no fabricated stats, honor marketing-context, no hallucinated tools).
- 5+ skill-specific:
  * `{{variable}}` double-braces — hard failure.
  * `<p>` tags in body — hard failure (replace with `<br><br>`).
  * em-dashes in body — hard failure (replace with comma/period/hyphen).
  * 2-step max — sequences with >2 steps = hard failure.
  * `{FIRST_NAME}` in subject — hard failure.
  * Fact-claim framing without hypothesis phrasing (inherited from situation-mining).
  * Supply-excluded vertical triggers (installers, property mgmt) — hard failure per BC-5824.

**§9 Behavioral Tests (≥6 scenarios):**
1. **Happy path — Municipalities seed.** Given a situation artifact for Denver Parks & Rec + `vertical: municipalities` + `offer_tier: 2`, output JSON artifact loads the `list-building-municipalities.md` preset, fills slots, emits valid EB-format.
2. **Scratch path — value-equation interview.** Given no situation artifact and entity input only, skill asks for 4 value-equation inputs before drafting.
3. **Format violation self-correct.** Given draft containing `{{firstname}}`, skill detects and self-corrects to `{FIRST_NAME}` before artifact emit.
4. **Em-dash auto-replace.** Given generated copy containing `—`, output body has zero em-dashes (replaced with comma/period/hyphen).
5. **Entity switching.** Same situation input, different entity (Nites vs Labs) produces different offer tier recommendation + different tone markers.
6. **Missing marketing-context hard gate.** With no `docs/marketing-context.md`, skill warns and asks operator for entity — does NOT emit artifact until operator responds.
7. **Unknown-vertical fallback.** Given `vertical: hoas` (file not yet shipped), skill falls back to base `list-building` skeleton + Nites tone, logs one-line warning citing BC-5879.
8. **Missing offer tier gate.** Given no offer tier input, skill recommends + asks for confirmation before drafting.

**Verify:**
```bash
grep -c "^- " plugins/marketing/skills/email-copywriting/SKILL.md
# Increases; anti-slop + tests add bullets

grep -c "^### Tier\|^### Flow\|^### " plugins/marketing/skills/email-copywriting/SKILL.md
# Section structure intact
```

---

## Task 7 — Write `presets/README.md` lazy-load index

**File:** `plugins/marketing/skills/email-copywriting/presets/README.md`

**Content:** Single index table listing all 46 planned preset files with status. One row per file, grouped by tier.

**Structure:**
```markdown
# Email Copywriting Preset Library — Lazy-Load Index

Presets are loaded on demand by the `email-copywriting` skill when the operator supplies both a `preset` (`list-building` | `risk-reversal`) and a `vertical` matching a handbook-canonical taxonomy entry. Runtime context cost is always one file per invocation.

## Usage

The skill reads `plugins/marketing/skills/email-copywriting/presets/{preset}-{vertical}.md`. If the file doesn't exist, skill falls back to the base inline skeleton in SKILL.md §3 plus the entity tone from `docs/marketing-context.md`.

## Preset manifest (46 files)

### Active tier — 12 files (BC-5879, Municipalities seeded in BC-5825)

| Vertical | Entity | list-building | risk-reversal |
|---|---|---|---|
| Municipalities | Labs | `list-building-municipalities.md` ✅ | `risk-reversal-municipalities.md` ✅ |
| HOAs | Nites | Pending BC-5879 | Pending BC-5879 |
| Landscape Lighting | Nites | Pending BC-5879 | Pending BC-5879 |
| Landscape Architects | Nites | Pending BC-5879 | Pending BC-5879 |
| Builders & Developers | Nites | Pending BC-5879 | Pending BC-5879 |
| Universities | Nites | Pending BC-5879 | Pending BC-5879 |

### Exploring tier — 16 files (BC-5880)

<!-- 8 rows for Casinos / Hotels & Resorts / Bars & Restaurants / Event Venues / Auto Dealerships / Ski Resorts / Country Clubs / Corporate Campuses -->

### Future tier — 18 files (BC-5881)

<!-- 9 rows for Theme Parks / Sports Stadiums / Zoos / Botanical Gardens / Historic Sites / Shopping Centers / Wineries / Churches / Hospitals -->

## Preset file shape

Every preset file follows: frontmatter (`preset`, `vertical`, `entity`, `when`, `situation_mining_row`) + Hook + Step 1 skeleton + Step 2 bump + Vertical anti-slop. See SKILL.md §3 for the canonical template.

## Seeding status

- ✅ = Available (shipped in BC-5825)
- Pending = Not shipped; skill falls back to base inline skeleton + entity tone when requested
```

**Reference:** Match vertical slug exactly to situation-mining's §3 Brite-adaptation rows. Use the vertical-canonical entity (Nites vs Labs) from that table.

**Verify:**
```bash
grep -c "Pending BC-5879\|Pending BC-5880\|Pending BC-5881" plugins/marketing/skills/email-copywriting/presets/README.md
# Expect 44 (46 total - 2 seeded)

grep -c "\u2705" plugins/marketing/skills/email-copywriting/presets/README.md
# Expect 2 (the 2 seeds)
```

---

## Task 8 — Write `presets/list-building-municipalities.md` seed preset

**File:** `plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md`

**Content:** Full preset file per design doc §Preset file shape.

**Frontmatter:**
```yaml
---
preset: list-building
vertical: municipalities
entity: brite-labs
when: RFP mentions smart city OR downtown master plan OR public placemaking bond
situation_mining_row: Municipalities — RFP mentions "smart city" or downtown master plan (SKILL.md §3 Brite-adaptation, Active tier row 1)
---
```

**Sections:**
1. **Hook (recency waterfall, municipalities-specific):** template sentence using `{CITY_PLANNER_NAME}`, `{DOWNTOWN_INITIATIVE}`, `{DATE_SIGNAL}`. Favor RFP date or press release date as recency anchor.
2. **Step 1 skeleton:** Greeting-merged first sentence (no separate "Hi X,"). 2–3 paragraphs separated by `<br><br>`. Paragraph 1 = hook + recency anchor. Paragraph 2 = one proof point from a peer municipality (placeholder `{PROOF_POINT}` filled from operator input or marketing-context.md). Paragraph 3 = T2 free-asset CTA (e.g. "would a short audit of {CITY}'s current downtown lighting be useful?"). Sign-off with `<br>{Best|Cheers},<br>{SENDER_FIRST_NAME}`. Spintax every 3-5 words where grammar permits. Subject: 1-3 words, 3-option spintax, no `{FIRST_NAME}`.
3. **Step 2 bump:** `Re: {subject}`. 1 short paragraph referencing step 1 without summarizing, reinforcing the free audit offer. No em-dashes.
4. **Vertical anti-slop:**
   - Don't pitch "outdoor lighting" — pitch placemaking + downtown experience.
   - Don't cite Nites seasonal case studies — cite Labs permanent installations.
   - Avoid "smart city" as buzzword; use "downtown experience" or "integrated public space."
   - No generic municipal pain points (parking, budget cuts); lead with the specific bond/RFP signal.
   - Don't reference installers or property management (Supply-excluded per handbook).

**Verify:**
```bash
# Frontmatter valid
head -7 plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md | grep -E "^preset:|^vertical:|^entity:|^when:|^situation_mining_row:"
# Expect all 5 keys

# Zero EB-format violations
grep -c "{{" plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md  # Expect 0
grep -c "<p>\|</p>" plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md  # Expect 0
grep -c "—" plugins/marketing/skills/email-copywriting/presets/list-building-municipalities.md  # Expect 0 in body
# Note: the handbook/spec notes above may contain em-dashes; ensure Step 1/2 skeleton bodies don't.
```

---

## Task 9 — Write `presets/risk-reversal-municipalities.md` seed preset

**File:** `plugins/marketing/skills/email-copywriting/presets/risk-reversal-municipalities.md`

**Content:** Full preset file, same shape as Task 8. T4 risk-reversal tone rather than T2 free-asset.

**Frontmatter:**
```yaml
---
preset: risk-reversal
vertical: municipalities
entity: brite-labs
when: Large budget RFP OR multi-year master plan OR committee-heavy procurement (T4 warranted)
situation_mining_row: Municipalities — RFP mentions "smart city" or downtown master plan + capital bond (SKILL.md §3 Brite-adaptation, Active tier row 1; T4 variant)
---
```

**Sections:**
1. **Hook (recency waterfall):** Similar to Task 8 Hook but tone shifted — acknowledge the larger commitment + the committee process.
2. **Step 1 skeleton:** Opens with same greeting-merged pattern. Paragraph 1 = recency hook. Paragraph 2 = performance guarantee statement ("first phase on us if it doesn't deliver X measurable outcome by Y date"). Paragraph 3 = CTA for a guaranteed pilot. Subject: 1-3 words, spintax, no `{FIRST_NAME}`.
3. **Step 2 bump:** `Re: {subject}`. Acknowledges risk-reversal takes longer deliberation; reinforces the guarantee's specificity.
4. **Vertical anti-slop:** Similar to Task 8 with additions:
   - Don't over-promise performance metrics beyond Labs' documented case studies.
   - Avoid guarantee language that would require legal review (e.g. "refund in full").
   - Don't use urgency tactics — municipal procurement runs on its own clock.

**Verify:** Same grep checks as Task 8 applied to this file.

---

## Task 10 — Write `evals/evals.json` with ≥6 scenarios

**File:** `plugins/marketing/skills/email-copywriting/evals/evals.json`

**Structure:** Match situation-mining's evals.json shape (JSON array of scenarios with `id`, `tier`, `description`, `input`, `assertions`).

**Scenarios (8 total, aligned to §9 Behavioral Tests):**
1. `happy-path-municipalities-seed` (Tier 2) — supplies situation artifact path + `vertical: municipalities` + `offer_tier: 2`. Asserts: artifact file written, `template_preset == "list-building"`, `vertical == "municipalities"`, body contains `<br><br>`, body has zero `—`, subject has zero `{FIRST_NAME}`.
2. `scratch-path-value-equation` (Tier 1) — no situation input. Asserts: first response contains "Dream Outcome" OR "Perceived Likelihood" OR "Time Delay" (4 value-equation interview prompts); no artifact written until operator responds.
3. `format-violation-self-correct` (Tier 1) — operator-supplied template contains `{{firstname}}`. Asserts: output artifact body contains zero `{{` tokens; contains `{FIRST_NAME}` instead.
4. `em-dash-auto-replace` (Tier 1) — operator-supplied proof-point text contains em-dashes. Asserts: output artifact body contains zero `—` characters.
5. `entity-switching` (Tier 2) — same situation artifact, run once with `entity: brite-nites` then once with `entity: brite-labs`. Asserts: offer_tier differs (Nites → 2, Labs → 3 or 4); subject line word choices differ; CTA differs.
6. `missing-marketing-context-hard-gate` (Tier 2) — `docs/marketing-context.md` absent. Asserts: first response does NOT contain "## Recommendations" OR JSON artifact; contains "marketing-context" OR "entity" prompt.
7. `unknown-vertical-fallback` (Tier 1) — operator supplies `vertical: hoas` (file not yet shipped). Asserts: artifact written; `template_preset == "list-building"`; `vertical == "hoas"`; body shape matches base inline skeleton (not vertical-override); log output mentions BC-5879.
8. `missing-offer-tier-gate` (Tier 1) — operator omits `offer_tier`. Asserts: first response contains "tier" prompt with entity-aware recommendation; no JSON artifact emitted until operator confirms.

**Verify:**
```bash
python3 -c "import json; d = json.load(open('plugins/marketing/skills/email-copywriting/evals/evals.json')); print(len(d['scenarios']))"
# Expect ≥6
```

---

## Task 11 — Cross-link from `email-bison.md` §Consumed by

**File:** `plugins/marketing/tools/integrations/email-bison.md`

**Edit §Consumed by** (around line 12): Add row:
```markdown
- `email-copywriting` (`plugins/marketing/skills/email-copywriting/`) — generates EB-format subject + body step 1 + step 2 as a JSON artifact for `/marketing:launch-campaign` to consume. Does NOT call EB MCP tools — pure content generation.
```

**Edit §Related skills → Primary consumers** (around line 257): Add row (alphabetize with existing):
```markdown
- `email-copywriting` (`plugins/marketing/skills/email-copywriting/`, BC-5825) — content generation for campaign sequences; feeds `/marketing:launch-campaign` command
```

**Verify:**
```bash
grep -c "email-copywriting" plugins/marketing/tools/integrations/email-bison.md
# Expect ≥2
```

---

## Task 12 — Run validation + guardrails

**Commands:**
```bash
./scripts/validate.sh
# Expect exit 0

./scripts/check-guardrails.sh --claude-md CLAUDE.md
# Expect exit 0

grep -E "mcp__(plugin_marketing_)?emailbison" plugins/marketing/skills/email-copywriting/SKILL.md
# MUST return empty (skill has no EB MCP tools)

grep -c "{{" plugins/marketing/skills/email-copywriting/SKILL.md plugins/marketing/skills/email-copywriting/presets/*.md
# Expect all 0 (no {{variable}} violations anywhere)

grep -c "—" plugins/marketing/skills/email-copywriting/presets/*.md
# Inspect — em-dashes in preset bodies = hard failure; em-dashes in documentation/spec prose are OK
```

**Fix any errors** surfaced by validate.sh or guardrails before moving to Step 7 (review).

**Verify:**
- [ ] All 17 verification items in BC-5825's issue body pass
- [ ] `validate.sh` exit 0
- [ ] `check-guardrails.sh` exit 0

---

## Post-task — Compound learnings (for ship phase, not this plan)

Expected precedent candidates:
- **Lazy-load preset pattern** — first skill in the plugin to use per-variant file fan-out with seeded proof-of-pattern. Worth a precedent entry if BC-5879/5880/5881 fan-out goes smoothly (validates the pattern) or hits unexpected friction (surfaces refinement).
- **JSON-artifact-emitting skill** — first marketing skill that emits a structured JSON artifact for command ingestion (vs markdown artifact). Contract shape worth precedent-tracing.
- **Issue-split mid-session** — capturing the brainstorm-time recognition that a 46-file fan-out is skin work that should split from skeleton work.

These are compound-learning candidates — confirm during `/workflows:ship` run.
