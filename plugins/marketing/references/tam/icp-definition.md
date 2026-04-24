---
source: Revgrowth1/tam-map@9f5c72e74b
upstream_path: prompts/icp-definition.md
license: MIT
ported: 2026-04-24
---

# ICP Definition Prompt

Use this when `/tam-map` receives an under-specified ICP and needs to resolve into a structured query.

---

## Prompt template

```
You are helping the user lock an Ideal Customer Profile (ICP) into a structured query for TAM building.

Given the user's description: "{user_icp}"

Produce a JSON block with:
{
  "industries": [primary + 1-2 adjacent verticals as keyword strings],
  "geo": { "country": "...", "regions": [...], "zip_bands": [...] },
  "size_band": { "employee_min": N, "employee_max": N, "revenue_min": N, "revenue_max": N },
  "tech_signals": [optional - if the user mentions specific tools/platforms],
  "intent_signals": [optional - hiring, expansion, funding, etc.],
  "exclusions": [franchises, public companies, existing customers, etc.]
}

Rules:
- Infer reasonable defaults when the user is vague (e.g., US-only unless they say otherwise)
- Flag ambiguities in a top-level "clarifications_needed" array
- Keep industries broad enough to hit the market but narrow enough to be actionable
- Never invent signals the user didn't mention
```

---

## Example

**User input:**
> "roofing contractors in Texas, 5-50 employees, storm-damage specialists"

**Resolved output:**
```json
{
  "industries": ["roofing contractors", "storm damage restoration", "exterior contractors"],
  "geo": {
    "country": "US",
    "regions": ["TX"],
    "zip_bands": []
  },
  "size_band": {
    "employee_min": 5,
    "employee_max": 50,
    "revenue_min": null,
    "revenue_max": null
  },
  "tech_signals": [],
  "intent_signals": ["storm damage", "hail repair", "insurance claims"],
  "exclusions": ["franchises"],
  "clarifications_needed": []
}
```
