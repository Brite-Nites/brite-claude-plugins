# Marketing Skill Porting Guide

Standard steps for porting a skill from [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) into the Brite marketing plugin (`plugins/marketing/`).

**License:** MIT (upstream). Attribution preserved in `plugins/marketing/LICENSE`.

---

## 1. Fetch upstream files

Every upstream skill has this structure:

```
skills/{name}/
├── SKILL.md              # Main skill instructions (200-500 lines)
├── references/            # Supplementary frameworks, templates, examples
│   ├── framework-a.md
│   └── framework-b.md
└── evals/
    └── evals.json         # Behavioral test spec
```

Fetch files via GitHub API:

```bash
# Read SKILL.md
gh api "repos/coreyhaines31/marketingskills/contents/skills/{name}/SKILL.md" \
  --jq '.content' | base64 -d

# List all files in the skill directory
gh api "repos/coreyhaines31/marketingskills/git/trees/main?recursive=1" \
  --jq '.tree[] | select(.path | startswith("skills/{name}/")) | .path'

# Read a reference file
gh api "repos/coreyhaines31/marketingskills/contents/skills/{name}/references/{file}.md" \
  --jq '.content' | base64 -d
```

**Port ALL files** — SKILL.md, every reference file, and evals.json. The reference files contain the real depth (frameworks, templates, playbooks).

---

## 2. File mapping

```
Upstream                                      → Brite plugin
skills/{name}/SKILL.md                        → plugins/marketing/skills/{name}/SKILL.md
skills/{name}/references/*.md                 → plugins/marketing/skills/{name}/references/*.md
skills/{name}/evals/evals.json                → plugins/marketing/skills/{name}/evals/evals.json
```

If a stub skill already exists at the target path (e.g., `content-strategy`, `social-media-strategy`), **replace it entirely** with the upstream version. The upstream content is significantly richer.

---

## 3. Required modifications to SKILL.md

### 3a. Frontmatter

Replace the upstream frontmatter with Brite plugin format:

```yaml
---
name: {name}
description: {keep the upstream description — it contains trigger phrases for skill discovery}
user-invocable: true
metadata:
  version: {upstream version, e.g., 1.1.0}
  upstream: coreyhaines31/marketingskills
  category: {category from the issue}
---
```

### 3b. Context path

Find and replace all occurrences of:
- `.agents/product-marketing-context.md` → `docs/marketing-context.md`
- `.claude/product-marketing-context.md` → `docs/marketing-context.md`

The upstream checks both paths with a fallback. In Brite's plugin, only `docs/marketing-context.md` is used.

### 3c. Cross-skill references

Update any cross-skill references. Upstream uses relative paths or just skill names. In Brite's plugin, skills are at `plugins/marketing/skills/{name}/SKILL.md`.

Common pattern — upstream says:
> For email copy, see email-sequence. For popup copy, see popup-cro.

These text references can stay as-is (they're human-readable, not file paths). Only update actual markdown links like `[email-sequence](../email-sequence/SKILL.md)` to the Brite path.

### 3d. Tool references

If the skill links to upstream tool integration guides (e.g., `../../tools/integrations/ga4.md`), update to the Brite path: `plugins/marketing/tools/integrations/ga4.md`. If the tool hasn't been ported yet, add a comment: `<!-- TODO: port tool integration guide -->`.

---

## 4. Add Brite plugin quality sections

The upstream skills don't include these. Add them at the end of SKILL.md:

### Health Scoring Rubric

```markdown
## Health Scoring Rubric

| Score | Criteria |
|------:|----------|
| 10 | {skill-specific excellence criteria} |
| 7-9 | {good output with minor gaps} |
| 4-6 | {functional but missing key elements} |
| 1-3 | {poor output — generic, off-brand, or incorrect} |
```

Tailor the rubric to the skill's specific output. A copywriting skill scores on clarity, specificity, and conversion focus. A revops skill scores on stage definitions, SLA completeness, and CRM alignment.

### Anti-Slop Guardrails

```markdown
## Anti-Slop Guardrails

- Do not generate generic marketing jargon ("synergy," "leverage," "best-in-class")
- Do not fabricate statistics, case studies, or testimonials
- Do not produce output that ignores the product-marketing-context
- {skill-specific guardrails}
```

### Behavioral Test Spec

```markdown
## Behavioral Tests

### Tier 1 (Free assertions — no tool calls needed)
- Given {input}, output must include {expected element}
- Output must not contain {anti-pattern}

### Tier 2 (Tool-assisted — requires file read or web fetch)
- {if applicable}
```

---

## 5. Reference files

Copy all `references/*.md` files as-is. These contain the real depth:
- Frameworks and templates (e.g., `copy-frameworks.md` — 344 lines of headline formulas)
- Data and benchmarks (e.g., `benchmarks.md` — reply rate data for cold email)
- Playbooks (e.g., `scoring-models.md` — 247 lines of lead scoring models)

**No modifications needed** unless they reference tools Brite doesn't use. Check against the [validated tool stack](../../memory/project_marketing_tool_stack.md).

---

## 6. Evals

Copy `evals/evals.json` to the skill directory. These are behavioral test specs from the upstream — keep them intact as a baseline, then add Brite-specific assertions if needed.

---

## 7. Register in plugin.json

Add the skill to `plugins/marketing/.claude-plugin/plugin.json` under the `skills` array:

```json
{
  "name": "{name}",
  "path": "skills/{name}/SKILL.md",
  "description": "{short description}"
}
```

---

## 8. Quality checklist

Before marking the port issue as Done:

- [ ] SKILL.md ported with updated frontmatter
- [ ] All reference files ported (check file count against issue's content inventory)
- [ ] Evals ported
- [ ] Context path updated to `docs/marketing-context.md`
- [ ] Cross-skill references updated
- [ ] Health scoring rubric added
- [ ] Anti-slop guardrails added
- [ ] Behavioral test spec added
- [ ] Registered in `plugin.json`
- [ ] Skill description preserved from upstream (contains trigger phrases)
- [ ] If replacing a stub skill, old content fully replaced

---

## Brite-specific adaptation notes

Most skills work with standard porting — the `product-marketing-context` integration pattern handles Brite brand adaptation at runtime. However, some skills need additional changes:

| Skill | Adaptation |
|-------|-----------|
| `revops` | Brite is migrating HubSpot → Salesforce. Update CRM references and tool links. |
| `analytics-tracking` | Brite uses Snowflake + GA4. Keep GA4/GTM content, add note about Snowflake as data warehouse. |
| `content-strategy` | Replaces existing Brite stub. Merge any Brite-specific content from stub if valuable. |
| `social-content` | Replaces `social-media-strategy` stub. Merge any Brite-specific content from stub if valuable. |

Check each issue's "Brite-Specific Adaptation Notes" section for skill-specific guidance.
