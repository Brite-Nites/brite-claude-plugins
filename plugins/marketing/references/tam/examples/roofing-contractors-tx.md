---
source: Revgrowth1/tam-map@9f5c72e74b
upstream_path: examples/roofing-contractors-tx.md
license: MIT
ported: 2026-04-24
---

# Worked Example — Roofing Contractors (TX)

Full TAM build walkthrough. Shows the commands, intermediate outputs, and final segments.

---

## 1. Invoke the skill

```bash
claude /tam-map "roofing contractors in TX, 5-50 employees, storm-damage specialists"
```

## 2. ICP resolution

Claude converts the prompt into `output/roofing-tx/icp.json`:

```json
{
  "industries": ["roofing", "storm damage restoration"],
  "geo": { "country": "US", "regions": ["TX"] },
  "size_band": { "employee_min": 5, "employee_max": 50 },
  "intent_signals": ["storm damage", "hail repair", "insurance claims"],
  "exclusions": ["franchises"]
}
```

## 3. Discovery (parallel)

> **Brite note (BC-12130):** this block shows the **upstream CLI** discovery flow. In Brite's pipeline, AI Ark and Discolike discovery run through their **MCP wrappers** (`mcp__plugin_marketing_aiark__*` / `mcp__plugin_marketing_discolike__*`) — the `aiark_client.py` / `discolike_client.py` CLI scripts shown below were **removed** (never wired; see [`UPSTREAM.md`](../UPSTREAM.md) § Local deviations). Only `icypeas_client.py` remains a live CLI script. A faithful Brite rewrite of this whole example (command name, MCP discovery, JSONL data-flow) is tracked in **BC-12278**.

```bash
python scripts/aiark_client.py --icp output/roofing-tx/icp.json > output/roofing-tx/aiark.jsonl &
python scripts/discolike_client.py --icp output/roofing-tx/icp.json > output/roofing-tx/discolike.jsonl &
python scripts/icypeas_client.py --icp output/roofing-tx/icp.json > output/roofing-tx/icypeas.jsonl &
wait
```

## 4. Dedupe + crawl

```bash
jq -s 'add' output/roofing-tx/{aiark,discolike,icypeas}.jsonl | \
  jq 'unique_by(.domain)' > output/roofing-tx/companies.jsonl

python scripts/spider_crawl.py --in output/roofing-tx/companies.jsonl \
  --out output/roofing-tx/crawled.jsonl
```

## 5. Enrich + verify

```bash
python scripts/enrich_waterfall.py \
  --in output/roofing-tx/crawled.jsonl \
  --out output/roofing-tx/enriched.jsonl

python scripts/verify_smtp.py \
  --in output/roofing-tx/enriched.jsonl \
  --out output/roofing-tx/verified.jsonl
```

## 6. Tier + segment

The Labs Phase 7 LLM-scoring step runs inline in the Claude Code session via the `icp-scoring` skill's `abc` rubric — delegated from `tam-mapping` Phase 7 per BC-6907. No standalone CLI invocation. Two pieces in order:

First, reshape `verified.jsonl` to the flat CSV `abc` expects (free-mail rows excluded, `smtp.catch_all` flattened to a top-level `catch_all` column — the caller owns the reshape per icp-scoring's delegation contract):

```bash
python3 - <<'PY'
import json, csv
FREE = {"gmail.com","yahoo.com","hotmail.com","outlook.com","icloud.com"}
src = "output/roofing-tx/verified.jsonl"
dst = "output/roofing-tx/verified-flat.csv"
fields = ["domain","company_name","industry","employees","geography","catch_all"]
with open(src) as f, open(dst, "w", newline="") as g:
    w = csv.DictWriter(g, fieldnames=fields); w.writeheader()
    for line in f:
        r = json.loads(line)
        smtp = r.get("smtp", {})
        if not smtp.get("keep"): continue
        email = r.get("email","")
        if "@" in email and email.split("@",1)[1].lower() in FREE: continue
        w.writerow({
            "domain": r.get("domain",""),
            "company_name": r.get("company_name","") or r.get("name",""),
            "industry": r.get("industry",""),
            "employees": r.get("employees",""),
            "geography": r.get("geography",""),
            "catch_all": "true" if smtp.get("catch_all") else "false",
        })
PY
```

Then invoke the skill against the same `--output-dir` (it reads `verified-flat.csv` from there and writes the four tier CSVs back):

```
icp-scoring \
  --rubric abc \
  --client brite-labs \
  --output-dir output/roofing-tx/ \
  --criteria-file output/roofing-tx/icp.json \
  --max-records <N>
```

`<N>` should be ≥ the row count of `verified-flat.csv` so the cost gate is skipped (per icp-scoring `abc` mode: gate fires above 10000 rows when `--max-records` is unset).

## 7. Final output

```
output/roofing-tx/segments/
├── tier-a.csv        # high-fit, verified emails → primary campaign
├── tier-b.csv        # medium-fit → secondary campaign
├── tier-c.csv        # lower-fit → cold warmup campaign
└── catch-all.csv     # catch-all domains → isolated campaign
```

Upload each CSV to its own campaign in EmailBison. Catch-all goes to a separately-warmed sender group to contain bounce risk.

---

## Typical drop-offs

These are illustrative — your numbers will vary by vertical and geography.

| Step | Input | Drop reason | Output |
|------|-------|-------------|--------|
| Discovery | — | — | Raw companies |
| Dedupe | Raw | Same domain across sources | Unique domains |
| Crawl | Unique | No responsive website | Crawled |
| Enrich | Crawled | No owner found / no email | Enriched |
| SMTP verify | Enriched | Invalid / unknown | Verified (valid + catch-all) |
| Catch-all split | Verified | Catch-all → separate segment | Valid only |
| Tier | Valid | None (classification) | A / B / C segments |

---

## Runbook for your first campaign

1. Start with tier-a only (highest-fit, lowest risk)
2. Warm up catch-all senders for 14 days before launching catch-all campaigns
3. Track reply-only (never opens)
4. Auto-pause any segment hitting >5% bounce (circuit breaker)
5. Move unresponsive tier-a to tier-b cadence after 2 sequence steps
