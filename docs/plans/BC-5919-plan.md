# BC-5919 — Update email-copywriting/SKILL.md with cross-links to new references

**Linear:** [BC-5919](https://linear.app/brite-nites/issue/BC-5919/update-email-copywritingskillmd-with-cross-links-to-new-references)
**Branch:** `holden/bc-5919-skill-cross-links`
**Milestone:** Marketing Plugin: GTM Workflows (R-3 of email-copywriting preset roadmap)
**Blockers:** BC-5917 ✅ (PR #175), BC-5918 ✅ (PR #177), BC-5879 (superseded)
**Blocks:** BC-5920, BC-5921, BC-5922, BC-5923, BC-5926, BC-5929, BC-5930

## Scope

Add three one-line cross-reference pointers inside `plugins/marketing/skills/email-copywriting/SKILL.md` so the skill routes readers to the new reference files:

- `plugins/marketing/references/offer-design-frameworks.md` (BC-5917, shipped)
- `plugins/marketing/references/vertical-playbooks/{vertical}.md` (Phase 2 R-4…R-9, pending)
- `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (BC-5918, shipped)

## Non-goals

- No restructuring of SKILL.md
- No deletion of inline Hormozi content (skill self-containment preserved per D3 lazy-load pattern)
- No edits outside SKILL.md
- No touching other skills / references / plugin config

## Tasks

### Task 1 — Add pointer under §3 "Hormozi value equation"

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`
**Anchor:** end of the subsection that begins at line 60 (`### Hormozi value equation`), before line 79 (`### Offer tiers + entity-aware selection matrix`).
**Insertion (after line 77 content, before blank line preceding next `###`):**

> `Full framework reference: `plugins/marketing/references/offer-design-frameworks.md` — Hormozi value equation origin + Brunson Value Ladder + Abraham strategic layer (Brite-originated synthesis).`

Verification: `grep -n 'offer-design-frameworks.md' plugins/marketing/skills/email-copywriting/SKILL.md` returns exactly 1 match inside the Hormozi subsection.

### Task 2 — Add pointer under §3 "Offer tiers + entity-aware selection matrix"

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`
**Anchor:** end of the subsection that begins at line 79 (`### Offer tiers + entity-aware selection matrix`), before line 100 (`### Recency waterfall`).
**Insertion (after the line 98 sentence `The skill RECOMMENDS the tier from this matrix then confirms with the operator per D2.`):**

> `Per-vertical offer guidance: `plugins/marketing/references/vertical-playbooks/{vertical}.md` (produced by Phase 2 roadmap issues R-4 through R-9 — e.g. `zoos.md`, `hotels-resorts.md`, `ski-resorts.md`, `sports-stadiums.md`, `aquariums.md`, `casinos.md`).`

Verification: `grep -n 'vertical-playbooks/' plugins/marketing/skills/email-copywriting/SKILL.md` returns exactly 1 match inside the Offer tiers subsection.

### Task 3 — Add pointer under §4 "Cross-skill boundaries"

**File:** `plugins/marketing/skills/email-copywriting/SKILL.md`
**Anchor:** the `### Cross-skill boundaries` subsection at line 198. Insert a new bullet (or paragraph) after the "Hands off to:" bullet at line 203.
**Insertion (new bullet after line 203):**

> `- **Competitive positioning (read-only reference):** when drafting for experiential-lighting prospects (Municipalities / Labs / event-production verticals), consult `plugins/marketing/references/experiential-lighting-vendor-landscape.md` for adjacent-not-competitive framing of named vendors (Illuminate Lights, Vincent Lighting, FAD, AWS Audio Visual, MK Illumination) — the reference's "adjacent, not competitive" guard applies verbatim to body copy.`

Verification: `grep -n 'experiential-lighting-vendor-landscape.md' plugins/marketing/skills/email-copywriting/SKILL.md` returns exactly 1 match inside the Cross-skill boundaries subsection.

### Task 4 — Validate + guardrails

Run from repo root:

```bash
./scripts/validate.sh
./scripts/check-guardrails.sh --claude-md CLAUDE.md
```

Both must exit 0. validate.sh baseline: 0 errors / 16 warnings (per latest session log BC-5924).

Additional sanity checks:

- `grep -c 'Value = (Dream Outcome' plugins/marketing/skills/email-copywriting/SKILL.md` ≥ 1 (inline Hormozi content preserved — AC from issue).
- `wc -l` delta on SKILL.md is +3 to +5 lines (pointer inserts only — no restructuring).

## Verification matrix (objective pass/fail — from issue)

- [ ] `SKILL.md` contains exact string `plugins/marketing/references/offer-design-frameworks.md` (≥ 1 hit)
- [ ] `SKILL.md` contains exact string `plugins/marketing/references/vertical-playbooks/` (≥ 1 hit)
- [ ] `SKILL.md` contains exact string `plugins/marketing/references/experiential-lighting-vendor-landscape.md` (≥ 1 hit)
- [ ] `grep -c 'Value = (Dream Outcome' plugins/marketing/skills/email-copywriting/SKILL.md` ≥ 1
- [ ] `./scripts/validate.sh` exits 0

## Execution mode

**Single authoring pass (not subagent-per-task).** Per precedent BC-5918#task-2 — 3 mechanical single-line inserts in one 467-line markdown file fit within a single turn's context budget and benefit from whole-file coherence (prose voice, pointer phrasing consistency). No parallelism available; no TDD applicable.

## Review scope

Thorough-mode review likely unnecessary — TRIVIAL triage expected (pure markdown, no runtime code, no CDR touch). Apply the BC-5924 pattern: quick review, skip P1 agent pipeline if diff is ≤ 10 lines of additive markdown. User decides at `/workflows:ship` gate.
