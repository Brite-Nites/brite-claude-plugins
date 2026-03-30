---
skill: compound-learnings
version: "1.0"
pass_threshold: 3.0
dimensions:
  - name: clarity
    threshold: 4
  - name: completeness
    threshold: 4
  - name: actionability
    threshold: 4
  - name: adherence
    threshold: 3
---

# Compound Learnings Rubric

## Clarity (1-5)

Is the output well-organized, easy to follow, and free of confusion?

| Score | Anchor |
|-------|--------|
| 1 | Incoherent — learnings jumbled together, no distinction between durable and session-specific |
| 2 | Partially organized but categories are unclear or entries are ambiguous |
| 3 | Acceptable structure — durable vs session-specific separation exists but entries could be sharper |
| 4 | Well-organized with clear categories, concise entries, logical placement in CLAUDE.md |
| 5 | Exemplary — every entry is a precise, self-contained fact; phase narration is crisp; report is scannable |

## Completeness (1-5)

Does the output cover all required aspects of the compound learnings task?

| Score | Anchor |
|-------|--------|
| 1 | Major gaps — skips most phases, no CLAUDE.md updates, no session summary |
| 2 | Addresses some phases but significant omissions (e.g., no fact-check, no trace extraction) |
| 3 | Covers basics — CLAUDE.md updated and session summary written but lacks depth |
| 4 | Thorough — all 7 phases addressed with reasonable depth, traces extracted if present |
| 5 | Comprehensive — all phases complete, stale entries pruned, traces with CDR cross-references, promotion flagged |

### Skill-Specific Completeness Criteria

- Analyzes diff, plan, and design doc (Phase 1)
- Extracts decision traces from execution trace YAML blocks with confidence >= 6 filtering (Phase 2)
- Verifies existing CLAUDE.md accuracy with up to 20 claims checked (Phase 3)
- Updates CLAUDE.md with durable learnings only, prunes stale entries (Phase 4)
- Writes session summary to auto-memory in the prescribed format (Phase 5)
- Checks if documentation updates are needed (Phase 6)
- Produces final report with fact-check stats, trace counts, and CLAUDE.md change summary (Phase 7)

## Actionability (1-5)

Are captured learnings durable and reusable in future sessions?

| Score | Anchor |
|-------|--------|
| 1 | Entries are session narrative or generic advice — no future session would benefit |
| 2 | Some entries are reusable but most are too vague or context-dependent |
| 3 | Learnings are factual but some lack the precision needed for agent consumption |
| 4 | Clear durable facts — future sessions can act on CLAUDE.md entries without interpretation |
| 5 | Every entry is a precise, actionable fact; session summary is self-contained; docs updated where needed |

## Adherence to Instructions (1-5)

Does the output follow the compound-learnings skill's defined protocol?

| Score | Anchor |
|-------|--------|
| 1 | Ignores protocol entirely — dumps learnings without phases, no artifacts. Anti-slop violations (C1 ephemeral knowledge, C2 bloat) |
| 2 | Follows some protocol but skips major steps or saves ephemeral/session-specific content to CLAUDE.md |
| 3 | Follows general protocol but misses specific requirements |
| 4 | Follows all major steps with minor deviations |
| 5 | Strict compliance — all phases, all artifacts, all rules followed |

### Skill-Specific Instruction Criteria

- Validates preconditions (diff exists, CLAUDE.md exists) before starting
- Prints activation banner with trigger reason
- Follows 7-phase structure with narration at each phase boundary
- Classifies learnings as durable, session-specific, or documentation-worthy
- Filters decision traces by confidence >= 6, max 3 per task
- Applies data safety rules to traces (sanitization, path validation, secret redaction)
- Flags traces with confidence >= 8 for org-level promotion
- Verifies at most 20 CLAUDE.md claims with priority ordering (paths, commands, configs, names)
- Checks CLAUDE.md size and extracts to docs/ with @import if over ~100 lines
- Prints completion marker with artifact summary and handoff to best-practices-audit

### Anti-Slop Criteria

Guardrail violations cap Adherence score at 3 (see `docs/quality-guardrails.md`):

- **C1**: Ephemeral knowledge in CLAUDE.md — session narrative ("today we refactored..."), generic advice, or temporary state saved as durable knowledge
- **C2**: CLAUDE.md bloat — adding entries without pruning stale ones, causing CLAUDE.md to exceed ~100 lines without extracting to `docs/` with `@import`
