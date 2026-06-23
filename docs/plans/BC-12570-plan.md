# BC-12570 Plan — Create `docs/marketing-context.md` via `/marketing:product-marketing-context`

**Issue:** [BC-12570](https://linear.app/brite-nites/issue/BC-12570) · Priority: High · Label: `ready-for-human`
**Branch:** `drake/bc-12570-create-docsmarketing-contextmd-via-marketingproduct` (off `main` — PR #432 stays independent)
**Decision context:** Brainstorm skipped (single-file output, prescribed approach, no new patterns). Operator chose: branch off main + full interview in-session.

## Goal

Create `docs/marketing-context.md` — Input 1 of the ADR-024 campaign-pipeline dependency map — with the **labs** entity populated, via the `/marketing:product-marketing-context` interview. Nites/Supply/Base follow incrementally (out of scope here).

## Key constraints (from SKILL.md + BC-1966 standard)

- Frontmatter MUST use `last_refreshed` (not `last_generated`) — session-start parses this exact key. Full schema: `domain: marketing`, `trait: needs-marketing`, `last_refreshed: 2026-06-04`, `refresh_cadence: quarterly`, `generated_by: product-marketing-context`.
- Budget: ~80–200 lines (Tier 2).
- Idempotent full regeneration — no partial merges.
- **Only labs as a populated entity section** — tam-mapping's auto-detect (`Before Starting` table, row 1) resolves silently only when exactly one entity is populated. Company-wide flywheel context is fine as shared preamble; entity *sections* = labs only.
- SoR enrichment: Salesforce MCP is available — query for labs-relevant segments/pipeline if interview confirms; otherwise mark `<!-- needs-enrichment -->`.

## Tasks

### Task 1 — Worktree + baseline (~2 min)
- Create worktree/branch `drake/bc-12570-create-docsmarketing-contextmd-via-marketingproduct` from `main`.
- Baseline: `./scripts/validate.sh` passes clean before any edit.

### Task 2 — Operator interview (~20 min, the core work)
Run the `/marketing:product-marketing-context` interview for the **labs** entity. SKILL.md's embedded brand context (`plugins/marketing/skills/product-marketing-context/SKILL.md:34-126`) is the authoritative baseline; the interview confirms/extends labs specifics:
1. Positioning — confirm/refine "turn slow months into high-revenue events" pillar set; flagship proof points (e.g., Gaylord installations).
2. ICP context — confirm/refine the Labs row (commercial venues, municipalities, entertainment properties; $50K+ budget); how the 27-vertical canonicals layer and `icp/shopping-centers.json` segments relate.
3. Voice — labs-specific deltas from the 5-value voice table, if any.
4. Channels + competitive notes specific to labs.
5. SoR enrichment decision — query Salesforce MCP or defer with `<!-- needs-enrichment -->`.

### Task 3 — Write `docs/marketing-context.md` (~5 min)
- File: `docs/marketing-context.md` (repo root docs/).
- Exact frontmatter per Key constraints above.
- Structure: company overview + flywheel (shared preamble) → **`## Entity: Brite Labs`** (the single populated entity section: positioning, ICP, voice, channels) → `## SoR Sources` (or `<!-- needs-enrichment -->`).
- Verify: file exists, 80–200 lines, `head -8` shows correct frontmatter keys.
- Guard: `git check-ignore -v docs/marketing-context.md` returns nothing (APFS case-insensitive gitignore gotcha).

### Task 4 — CLAUDE.md @import per BC-1966 Decision 2 (~2 min)
- Add `@docs/marketing-context.md` to CLAUDE.md (Tier 2 cascade; enables session-start staleness detection of `last_refreshed`).
- Verify: `./scripts/check-guardrails.sh --claude-md CLAUDE.md` passes. If the guardrail fails on size, drop the @import and record the deferral in the PR body instead.

### Task 5 — Acceptance verification (~3 min)
1. ① `docs/marketing-context.md` exists with labs populated → `grep -i 'labs' docs/marketing-context.md` + line count in budget.
2. ② plan-campaign Step 2.5 WARN clears → the branch logic (`git show drake/plan-campaign-icp-dependency-map:plugins/marketing/commands/plan-campaign.md`, Step 2.5 item 5) is a pure file-existence check on `docs/marketing-context.md` — satisfied by Task 3. Final live confirmation deferred until PR #432 merges (noted in PR body).
3. ③ tam-mapping entity auto-detect → single populated entity section = "Use it. Print `Using entity=labs ...`" path per `plugins/marketing/skills/tam-mapping/SKILL.md:38`.
4. `./scripts/validate.sh` passes.

### Task 6 — Commit + Linear (~2 min)
- Single commit: `docs(marketing): create marketing-context.md with labs entity (BC-12570)`. No plugin-version bump needed — `docs/` is outside `plugins/<plugin>/{hooks,skills,commands,agents}/**`.
- Move BC-12570 → In Progress at start, link branch; ready for `/workflows:review` → `/workflows:ship`.

## Out of scope
- Populating nites/supply/base entity sections (incremental follow-up per the issue).
- Anything in PR #432 (stays independent on its own branch).
- Building the SF Campaign picklist (ADR-023 explicitly defers it).

## Test/build commands
- `./scripts/validate.sh` — CI-equivalent validation
- `./scripts/check-guardrails.sh --claude-md CLAUDE.md` — CLAUDE.md size/anti-slop gate
