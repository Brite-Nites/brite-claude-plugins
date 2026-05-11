---
source: Revgrowth1/tam-map@9f5c72e74b
upstream_path: prompts/fit-scoring.md
license: MIT
ported: 2026-04-24
---

# Fit Scoring Prompt

Claude Haiku uses this prompt (via the `icp-scoring` skill's `abc` rubric — see `plugins/marketing/skills/icp-scoring/SKILL.md` §Methodology) to classify each enriched company into tier A / B / C.

---

## Prompt template

```
ICP:
{icp_json}

Company data:
Domain: {domain}
Name: {company_name}
Website content (truncated to 3000 chars):
{website_markdown}

Task: rate this company's fit for the ICP. Reply with exactly one letter:
A = strong fit (primary target, high confidence)
B = medium fit (secondary target, some signals match)
C = weak fit (adjacent, might work but not ideal)

Letter only, nothing else.
```

---

## Rationale

- **Haiku, not Sonnet**: this runs on thousands of records. Cost + latency matter more than nuance. Haiku scores consistently enough for tier routing.
- **Letter-only output**: no chain-of-thought, no explanations. Parsing is trivial, token spend is minimal.
- **Three tiers, not five**: finer granularity doesn't improve downstream campaign performance. A/B/C gives you 3 distinct sequences at most.

---

## Tuning notes

If classifications skew too far toward A or C:
- **Too many A's**: the ICP is too broad. Add `exclusions` or narrow `industries`.
- **Too many C's**: the discovery step pulled too loosely — check AI Ark/Discolike queries.
- **Too many B's**: fine — B is often the largest tier in practice.

If a record lacks website content (crawl failed), the model will default to C due to missing signal. That's correct behavior — don't push signal-less records into A.

---

## When to swap models

Upgrade to Sonnet for:
- Very small TAMs (<200 records) where accuracy matters more than cost
- Multi-criteria scoring (fit + intent + timing) where you need weighted judgment
- Complex ICPs with many exclusion rules the model has to weigh

For everything else, Haiku is the right call.
