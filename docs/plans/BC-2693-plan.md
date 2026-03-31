# BC-2693: Add handbook (Context7) as universal SoR for context-skills

**Issue:** BC-2693
**Type:** Spec + template update (no code changes)
**Files:** 2 files modified

---

## Task 1: Update BC-1966 spec — handbook as universal SoR

**File:** `docs/designs/BC-1966-context-skill-standard.md`

### 1a: Add universal SoR row to Trait-to-SoR Mapping table (line ~391-399)

Add a new row at the TOP of the table for the handbook as a universal SoR that applies to all domains:

```markdown
| All domains | (all traits) | Brite Handbook | Context7 MCP | Brand guidelines, ICP, coding standards, competitive positioning, org structure |
```

### 1b: Document the handbook query pattern

Add a new subsection under `## SoR Query Pattern` (after the Trait-to-SoR Mapping table, before `## Invocation Flow`) called `### Handbook Query Pattern`:

- Explain that Context7 handbook is a universal SoR available to all context-skills
- Document the two-step query: `resolve-library-id("brite-nites handbook")` → `query-docs` with domain-relevant topics
- List recommended handbook topics per domain:
  - Marketing → brand, ICP, positioning, competitive-landscape
  - Engineering → coding-standards, architecture, tools
  - Design → brand, design-tokens, visual-identity
  - Sales → ICP, competitive-landscape, pricing
  - Data → architecture, data-standards, tools
- Note that handbook is Tier 1 SoR (always available via Context7) vs domain-specific MCP as Tier 2

### 1c: Update fallback tiers table (line ~366-373)

Current 4 tiers → 5 tiers. Insert "Handbook-only" between "Partial enrichment" and "Interview-only":

| Tier | Available | Experience |
|------|-----------|-----------|
| Full enrichment | Handbook + domain MCP + SoR + interview | Complete context doc with handbook + SoR data |
| Domain SoR only | Domain MCP available, handbook unavailable | SoR-enriched but missing handbook context |
| Handbook-only | Context7 available, domain MCP unavailable | Handbook-enriched, `<!-- needs-enrichment -->` on domain SoR sections |
| Interview-only | No MCP available | All content from interview data |
| No SoR dependency | Domain has no relevant SoR | Context doc from interview data; no SoR section |

### 1d: Update invocation sequence (line ~351-363)

Update the SoR invocation sequence to show handbook query as the first step:

```
context-skill starts
  → query Context7 handbook (resolve-library-id → query-docs with domain topics)
  → IF handbook available: extract domain-relevant context
  → check if domain-specific MCP tool is available
  → IF available: query domain SoR, sanitize, write enriched context doc
  → IF unavailable: use handbook + interview data, mark domain SoR sections with <!-- needs-enrichment -->
  → write docs/<domain>-context.md with last_refreshed frontmatter
```

**Verify:** Read the updated spec and confirm all 5 acceptance criteria sections are addressed.

---

## Task 2: Update context-skill template — add handbook query step

**File:** `templates/domain-plugin/skills/domain-context/SKILL.md`

Update the `## SoR Integration` section (lines 39-49) to add handbook as Tier 1 SoR:

1. Add a new step 1 before the existing steps: "Query Context7 handbook for domain-relevant context"
2. Renumber existing steps
3. Add a note that handbook is Tier 1 (always available) and domain MCP is Tier 2
4. Update the fallback paragraph to reflect the new tier: "If Context7 is unavailable, proceed with domain MCP + interview data. If domain MCP is also unavailable, use interview data only."

**Verify:** Read the template and confirm handbook query is the first SoR step, existing data safety rules are preserved.

---

## Verification

After both tasks:
- [ ] Trait-to-SoR mapping table includes Context7 handbook as universal SoR
- [ ] Context-skill template includes handbook query step
- [ ] Fallback tiers updated to include handbook-only tier
- [ ] Data safety rules apply to handbook-sourced content (same as other SoR data)
- [ ] BC-1727 (product-marketing-context) can use this pattern when implemented (verify by reading the existing skill and confirming the template changes would apply)
