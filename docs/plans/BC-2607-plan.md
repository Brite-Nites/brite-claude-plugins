# BC-2607: Port marketing skill — launch-strategy

## Summary

Port the `launch-strategy` skill from coreyhaines31/marketingskills into `plugins/marketing/skills/launch-strategy/`. Standard port — no Brite-specific adaptations needed.

## Acceptance Criteria

- [ ] SKILL.md ported with updated frontmatter
- [ ] evals/evals.json ported
- [ ] Health scoring rubric section added
- [ ] Anti-slop guardrails section added
- [ ] Behavioral test spec section added
- [ ] Cross-skill references updated to Brite plugin paths
- [ ] Context path points to `docs/marketing-context.md`
- [ ] Skill directory exists under `plugins/marketing/skills/` (auto-discovered)

## Tasks

### Task 1: Fetch upstream files
**Action:** Read upstream SKILL.md and evals.json from GitHub via `gh api`
**Files:** None (read-only)
**Commands:**
```bash
gh api "repos/coreyhaines31/marketingskills/contents/skills/launch-strategy/SKILL.md" --jq '.content' | base64 -d
gh api "repos/coreyhaines31/marketingskills/contents/skills/launch-strategy/evals/evals.json" --jq '.content' | base64 -d
```
**Verify:** Both files are non-empty and readable

### Task 2: Create directory structure and write evals.json
**Action:** Create `plugins/marketing/skills/launch-strategy/evals/` directory, write evals.json as-is
**Files:**
- CREATE `plugins/marketing/skills/launch-strategy/evals/evals.json`
**Verify:** File exists at correct path

### Task 3: Write SKILL.md with modifications
**Action:** Write the ported SKILL.md with these changes:
1. Replace frontmatter with Brite plugin format:
   ```yaml
   ---
   name: launch-strategy
   description: {preserve upstream description for trigger phrases}
   user-invocable: true
   metadata:
     version: {upstream version}
     upstream: coreyhaines31/marketingskills
     category: Strategy & Research
   ---
   ```
2. Replace all `.agents/product-marketing-context.md` and `.claude/product-marketing-context.md` → `docs/marketing-context.md`
3. Update cross-skill markdown links to Brite paths (text references stay as-is)
4. Add quality sections at the end:
   - Health Scoring Rubric (tailored to launch planning outputs)
   - Anti-Slop Guardrails (launch-specific anti-patterns)
   - Behavioral Test Spec (Tier 1 free assertions)
**Files:**
- CREATE `plugins/marketing/skills/launch-strategy/SKILL.md`
**Verify:** Frontmatter is valid YAML, no upstream context paths remain, quality sections present

### Task 4: Verify plugin discovery
**Action:** Confirm launch-strategy is auto-discovered. Plugin.json uses `"skills": "./skills/"` (directory glob) — no manual registration needed.
**Files:**
- READ `plugins/marketing/.claude-plugin/plugin.json`
**Verify:** Skill is discoverable (directory exists under skills/)

### Task 5: Final verification
**Action:** Run through the quality checklist below (inline — porting guide is on `holden/marketing-skills-enrichment`, not yet merged to main)
**Checks:**
- [ ] SKILL.md exists at `plugins/marketing/skills/launch-strategy/SKILL.md`
- [ ] Frontmatter has name, description, user-invocable, metadata fields
- [ ] No occurrences of `.agents/product-marketing-context.md` or `.claude/product-marketing-context.md`
- [ ] evals/evals.json exists
- [ ] Health scoring rubric present
- [ ] Anti-slop guardrails present
- [ ] Behavioral test spec present
- [ ] Cross-skill references use Brite paths (or are text-only references)
- [ ] No references to upstream tool paths that don't exist in Brite

## Notes

- This repo has no build/test/lint commands — verification is checklist-based
- The upstream skill has no `references/` directory — only SKILL.md and evals
- plugin.json uses `"skills": "./skills/"` directory glob, so new skills are auto-discovered by convention
- The issue says "standard port — no Brite-specific adaptations needed beyond path updates"
